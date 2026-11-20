#!/usr/bin/env node
// Static site generator for the Cúram on Kubernetes runbook.
//
// Reads Markdown pages from src/pages, renders them with markdown-it, wraps
// them in the theme in src/theme, and writes a plain HTML tree to public/.
// Replaces the previous Gatsby + gatsby-theme-carbon toolchain.

import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import * as yaml from 'js-yaml';
import hljs from 'highlight.js';
import MarkdownIt from 'markdown-it';
import anchor from 'markdown-it-anchor';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PAGES = path.join(ROOT, 'src', 'pages');
const THEME = path.join(ROOT, 'src', 'theme');
const OUT = path.join(ROOT, 'public');

const SITE_TITLE = 'Cúram on Kubernetes Runbook';
const SITE_DESCRIPTION = 'Deploying Cúram Social Program Management on Kubernetes';
// SITE_PREFIX lets the site be served from a sub-path (e.g. GitHub Pages
// project sites). Normalised to '' or '/some/prefix'.
const PREFIX = (process.env.SITE_PREFIX || '').replace(/\/+$/, '');

const argv = new Set(process.argv.slice(2));

/* ------------------------------------------------------------------ utils */

const slugify = (s) =>
  String(s)
    .trim()
    .toLowerCase()
    .replace(/[''`"]/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-+|-+$/g, '');

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => `&${{ '&': 'amp', '<': 'lt', '>': 'gt', '"': 'quot', "'": '#39' }[c]};`);

const isExternalWebUrl = (url) => /^(?:https?:)?\/\//i.test(url);

/** Prefix a site-root-relative URL. Leaves external/anchor URLs alone. */
const withPrefix = (url) =>
  (PREFIX && url.startsWith('/') && !isExternalWebUrl(url) ? PREFIX + url : url);

function walk(dir, ext, acc = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, ext, acc);
    else if (entry.name.endsWith(ext)) acc.push(full);
  }
  return acc;
}

function copyDir(from, to) {
  if (!fs.existsSync(from)) return;
  fs.mkdirSync(to, { recursive: true });
  fs.cpSync(from, to, { recursive: true });
}

/* ------------------------------------------------------- frontmatter parse */

function parseFrontmatter(raw) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(raw);
  if (!match) return { data: {}, body: raw };
  return { data: yaml.load(match[1]) || {}, body: raw.slice(match[0].length) };
}

/* --------------------------------------------- legacy component transforms */

/*
 * The pages were authored as MDX against gatsby-theme-carbon, so they contain
 * a small, fixed vocabulary of React components. Rather than rewrite 78
 * content files, we translate that vocabulary to plain HTML here. Block-level
 * tags are emitted surrounded by blank lines so that markdown-it treats the
 * tag as an HTML block and still parses the content between as Markdown.
 */

const block = (html) => `\n\n${html}\n\n`;

/** Collect `<AnchorLink>` labels into an in-page table of contents. */
function transformAnchorLinks(src) {
  return src.replace(/<AnchorLinks\b[^>]*>([\s\S]*?)<\/AnchorLinks>/g, (_m, inner) => {
    const items = [...inner.matchAll(/<AnchorLink[^>]*>([\s\S]*?)<\/AnchorLink>/g)].map((m) => m[1].trim());
    if (!items.length) return '';
    const list = items
      .map((label) => `<li><a href="#${slugify(label)}">${escapeHtml(label)}</a></li>`)
      .join('');
    return block(`<nav class="anchor-links" aria-label="On this page"><ul>${list}</ul></nav>`);
  });
}

/** `<Tabs><Tab label="x">…</Tab></Tabs>` -> panels driven by site.js. */
function transformTabs(src) {
  let group = 0;
  return src.replace(/<Tabs\b[^>]*>([\s\S]*?)<\/Tabs>/g, (_m, inner) => {
    const id = `tabs-${++group}`;
    let index = 0;
    const panels = inner.replace(
      /<Tab\s+label=["']([^"']*)["']\s*>([\s\S]*?)<\/Tab>/g,
      (_t, label, content) =>
        block(
          `<section class="tab-panel" data-label="${escapeHtml(label)}" id="${id}-panel-${index++}">`
        ) +
          content.trim() +
          block('</section>')
    );
    return block(`<div class="tabs" data-tabs id="${id}">`) + panels + block('</div>');
  });
}

/** `<Video title="…" youtubeId="…" />` -> a lazily-loaded responsive embed. */
function transformVideo(src) {
  return src.replace(/<Video\b([^>]*)\/>/g, (_m, attrs) => {
    const id = /youtubeId=["']([^"']+)["']/.exec(attrs)?.[1];
    const title = /title=["']([^"']*)["']/.exec(attrs)?.[1] || 'Video';
    if (!id) return '';
    return block(
      `<div class="video"><iframe src="https://www.youtube-nocookie.com/embed/${escapeHtml(id)}" ` +
        `title="${escapeHtml(title)}" loading="lazy" allowfullscreen ` +
        `allow="accelerometer; clipboard-write; encrypted-media; picture-in-picture"></iframe></div>`
    );
  });
}

/**
 * `<Cards>` wraps a run of `### [Title](url)` headings, each followed by a
 * short paragraph, and turns every pair into a single clickable card.
 */
function transformCards(src) {
  return src.replace(/<Cards>([\s\S]*?)<\/Cards>/g, (_m, inner) => {
    const cards = [...inner.matchAll(/###\s+\[([^\]]+)\]\(([^)]+)\)\s*\n+([\s\S]*?)(?=\n###\s|\s*$)/g)]
      .map(([, title, href, body]) => {
        const text = body.trim().replace(/\s+/g, ' ');
        return (
          `<a class="card" href="${withPrefix(href)}"${isExternalWebUrl(href) ? ' target="_blank" rel="noopener noreferrer"' : ''}>` +
          `<span class="card-title">${escapeHtml(title)}</span>` +
          `<span class="card-body">${escapeHtml(text)}</span></a>`
        );
      })
      .join('');
    return cards ? block(`<div class="cards">${cards}</div>`) : '';
  });
}

function transformAccordion(src) {
  return src
    .replace(/<Accordion\b[^>]*>/g, block('<div class="accordion">'))
    .replace(/<\/Accordion>/g, block('</div>'))
    .replace(/<AccordionItem\s+title=["']([^"']*)["']\s*>/g, (_m, title) =>
      block(`<details class="accordion-item"><summary>${escapeHtml(title)}</summary>`)
    )
    .replace(/<\/AccordionItem>/g, block('</details>'));
}

function transformComponents(src) {
  let out = src;

  // MDX module syntax has no meaning in a plain Markdown pipeline.
  out = out.replace(/^\s*import\s+[^\n]*?(?:;|\n)/gm, '');
  out = out.replace(/^\s*export\s+default\s+[^\n]*\n/gm, '');

  out = transformAnchorLinks(out);
  out = transformCards(out);
  out = transformTabs(out);
  out = transformAccordion(out);
  out = transformVideo(out);

  // Carbon's 16-column grid; the new layout is single-column, so drop it.
  out = out.replace(/<\/?(?:Row|Column)\b[^>]*>/g, '');

  // `kind` maps onto a severity modifier; default is an informational note.
  out = out.replace(/<InlineNotification\b([^>]*)>/g, (_m, attrs) => {
    const kind = /kind=["']([^"']+)["']/.exec(attrs)?.[1] || 'info';
    const cls = /className=["']([^"']+)["']/.exec(attrs)?.[1] || '';
    const classes = ['note', `note--${kind}`, cls].filter(Boolean).join(' ');
    return block(`<div class="${escapeHtml(classes)}">`);
  });
  out = out.replace(/<\/InlineNotification>/g, block('</div>'));

  out = out.replace(/<PageDescription\b[^>]*>/g, block('<div class="page-description">'));
  out = out.replace(/<\/PageDescription>/g, block('</div>'));

  out = out.replace(/<Caption\b[^>]*>/g, block('<div class="caption">'));
  out = out.replace(/<\/Caption>/g, block('</div>'));

  out = out.replace(/<OkIcon\s*\/>/g, '<span class="status status--ok" title="Supported">&#10004;</span>');
  out = out.replace(/<NoIcon\s*\/>/g, '<span class="status status--no" title="Not supported">&#10008;</span>');

  // Inline availability markers. These replace remote shields.io images, so
  // they must stay inline: no block() wrapping, or they would break the
  // table cells and list items they sit in.
  out = out.replace(/<Badge\b([^>]*)>([\s\S]*?)<\/Badge>/g, (_m, attrs, text) => {
    const kind = /kind=["']([^"']+)["']/.exec(attrs)?.[1] || 'version';
    return `<span class="badge badge--${escapeHtml(kind)}">${text.trim()}</span>`;
  });

  // JSX self-closing <br/> etc. are already valid HTML; nothing more to do.
  return out;
}

/* -------------------------------------------------------------- markdown-it */

const md = new MarkdownIt({
  html: true,
  linkify: false,
  typographer: false,
  highlight(code, lang) {
    if (lang && hljs.getLanguage(lang)) {
      try {
        return hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
      } catch {
        /* fall through to escaped output */
      }
    }
    return escapeHtml(code);
  },
}).use(anchor, {
  slugify,
  tabIndex: false,
  permalink: anchor.permalink.linkInsideHeader({ symbol: '#', placement: 'after', class: 'heading-anchor' }),
});

// Collect headings so each page can render an "On this page" rail.
/*
 * The plain text of an inline token, for the "On this page" rail.
 * Using token.content directly would leak raw markup into the rail, because
 * it is the unparsed source: a heading containing a <Badge> or an image would
 * show its HTML or Markdown verbatim.
 */
function inlineText(token) {
  if (!token) return '';
  if (!token.children) return (token.content || '').trim();
  let out = '';
  for (const child of token.children) {
    switch (child.type) {
      case 'text':
      case 'code_inline':
        out += child.content;
        break;
      case 'image':
        out += child.attrGet('alt') || '';
        break;
      case 'softbreak':
      case 'hardbreak':
        out += ' ';
        break;
      case 'html_inline':
        break; // drop tags such as <span class="badge">
      default:
        out += child.content && !child.children ? child.content : '';
    }
  }
  return out.replace(/\s+/g, ' ').trim();
}

function collectHeadings(tokens) {
  const headings = [];
  tokens.forEach((token, i) => {
    if (token.type !== 'heading_open') return;
    const level = Number(token.tag.slice(1));
    if (level < 2 || level > 3) return;
    const id = token.attrGet('id');
    const text = inlineText(tokens[i + 1]);
    if (id && text) headings.push({ id, text, level });
  });
  return headings;
}

// Add the site prefix to root-relative hrefs/srcs at render time.
for (const [rule, attr] of [['link_open', 'href'], ['image', 'src']]) {
  const base = md.renderer.rules[rule] || ((t, i, o, _e, s) => s.renderToken(t, i, o));
  md.renderer.rules[rule] = (tokens, idx, options, env, self) => {
    const value = tokens[idx].attrGet(attr);
    if (value) tokens[idx].attrSet(attr, withPrefix(value));
    if (rule === 'link_open' && isExternalWebUrl(value)) {
      tokens[idx].attrSet('target', '_blank');
      tokens[idx].attrSet('rel', 'noopener noreferrer');
    }
    return base(tokens, idx, options, env, self);
  };
}

// Wrap tables so wide config references can scroll on narrow screens.
md.renderer.rules.table_open = () => '<div class="table-wrap">\n<table>\n';
md.renderer.rules.table_close = () => '</table>\n</div>\n';

/* -------------------------------------------------------------- navigation */

function loadNav() {
  const file = path.join(ROOT, 'src', 'data', 'nav-items.yaml');
  return yaml.load(fs.readFileSync(file, 'utf8')) || [];
}

/** Normalise a nav path to the canonical trailing-slash form. */
const normalise = (p) => `/${String(p).replace(/^\/+|\/+$/g, '')}/`.replace('//', '/');

function renderNav(nav, currentUrl, titles, tabs) {
  const navUrls = nav.flatMap((section) => (section.pages || []).map((p) => normalise(p.path)));
  const activeUrl = navUrls.includes(currentUrl)
    ? currentUrl
    : navUrls.find((url) => tabs.some((tab) => tab.url === url));
  const activeAttributes = (url) => url === activeUrl
    ? ` class="active" aria-current="${url === currentUrl ? 'page' : 'location'}"`
    : '';

  return nav
    .map((section) => {
      const links = (section.pages || [])
        .map((page) => {
          const url = normalise(page.path);
          const label = page.title || titles.get(url) || url;
          return `<li><a href="${withPrefix(url)}"${activeAttributes(url)}>${escapeHtml(label)}</a></li>`;
        })
        .join('\n');
      // A single untitled page is a standalone link rather than a group.
      const solo = (section.pages || []).length === 1 && !section.pages[0].title;
      const sectionUrl = solo ? normalise(section.pages[0].path) : null;
      if (solo) {
        return `<li class="nav-solo${section.hasDivider ? ' nav-divider' : ''}">` +
          `<a href="${withPrefix(sectionUrl)}"${activeAttributes(sectionUrl)}>${escapeHtml(section.title)}</a></li>`;
      }
      const open = (section.pages || []).some((p) => normalise(p.path) === activeUrl);
      return (
        `<li class="nav-group${section.hasDivider ? ' nav-divider' : ''}">` +
        `<details${open ? ' open' : ''}><summary>${escapeHtml(section.title)}</summary>` +
        `<ul>${links}</ul></details></li>`
      );
    })
    .join('\n');
}

/* ------------------------------------------------------------ page grouping */

/**
 * gatsby-theme-carbon used a `tabs:` frontmatter key to join sibling pages in
 * the same directory under one tab bar. Resolve each label to a sibling page
 * by, in order: filename slug, title slug, then best word overlap (labels are
 * not always identical to the page title, e.g. 'Logging on Cloud' for
 * logging.mdx).
 */
function resolvePageTabs(page, pages) {
  if (!Array.isArray(page.data.tabs) || !page.data.tabs.length) return [];
  const dir = path.dirname(page.source);
  const siblings = pages.filter((p) => path.dirname(p.source) === dir);
  const words = (s) => new Set(slugify(s).split('-').filter(Boolean));

  const resolve = (label) => {
    const wanted = slugify(label);
    const byFile = siblings.find((p) => slugify(path.basename(p.source, '.mdx')) === wanted);
    if (byFile) return byFile;
    const byTitle = siblings.find((p) => slugify(p.data.title || '') === wanted);
    if (byTitle) return byTitle;

    const labelWords = words(label);
    let best = null;
    let bestScore = 0;
    for (const candidate of siblings) {
      const candidateWords = new Set([
        ...words(path.basename(candidate.source, '.mdx')),
        ...words(candidate.data.title || ''),
      ]);
      let score = 0;
      labelWords.forEach((w) => {
        if (candidateWords.has(w)) score++;
      });
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  };

  return page.data.tabs
    .map((label) => {
      const match = resolve(label);
      if (!match) {
        console.warn(`  ! ${page.url} tab '${label}' matches no sibling page`);
        return null;
      }
      return { label, url: match.url };
    })
    .filter(Boolean);
}

function renderPageTabs(page, tabs) {
  const links = tabs
    .map(({ label, url }) => {
      const active = url === page.url ? ' class="active" aria-current="page"' : '';
      return `<a href="${withPrefix(url)}"${active}>${escapeHtml(label)}</a>`;
    })
    .join('');

  return links ? `<nav class="page-tabs" aria-label="Section">${links}</nav>` : '';
}

/* ----------------------------------------------------------------- layout */

function layout({ page, content, navHtml, tabsHtml, headings, prev, next }) {
  const title = page.data.title || SITE_TITLE;
  const description = page.data.description || SITE_DESCRIPTION;
  const isHero = page.data.hero === true;

  const toc = headings.length && !isHero
    ? `<aside class="toc"><h2>On this page</h2><ul>${headings
        .map(
          (h) =>
            `<li class="toc-l${h.level}"><a href="#${h.id}">${escapeHtml(h.text)}</a></li>`
        )
        .join('')}</ul></aside>`
    : '';

  const header = isHero
    ? `<div class="hero">
      ${page.data.eyebrow ? `<p class="hero-eyebrow">${escapeHtml(page.data.eyebrow)}</p>` : ''}
      <h1>${escapeHtml(title)}</h1>
      <p class="hero-lede">${escapeHtml(description)}</p>
    </div>`
    : `<div class="page-header">
      <h1>${escapeHtml(title)}</h1>
      ${tabsHtml}
    </div>`;

  const pager = [
    prev ? `<a class="pager-prev" href="${withPrefix(prev.url)}"><span>Previous</span>${escapeHtml(prev.label)}</a>` : '<span></span>',
    next ? `<a class="pager-next" href="${withPrefix(next.url)}"><span>Next</span>${escapeHtml(next.label)}</a>` : '<span></span>',
  ].join('');

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)} | ${escapeHtml(SITE_TITLE)}</title>
<meta name="description" content="${escapeHtml(description)}">
<meta name="keywords" content="merative,curam,containers,kubernetes">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<link rel="icon" href="${withPrefix('/images/curam-favicon-32.svg')}" type="image/svg+xml">
<link rel="stylesheet" href="${withPrefix('/theme/styles.css')}">
</head>
<body${isHero ? ' class="is-home"' : ''}>
<a class="skip-link" href="#main">Skip to main content</a>
<header class="masthead">
  <button class="nav-toggle" aria-label="Toggle navigation" aria-expanded="false"></button>
  <a class="brand" href="${withPrefix('/')}">
    <img class="brand-logo" src="${withPrefix('/images/curam-favicon-32.svg')}" alt="" width="26" height="26">
    <span class="brand-mark">Cúram</span>
    <span class="brand-title">Kubernetes Runbook</span>
  </a>
  <div class="masthead-actions">
    <input type="search" id="nav-search" class="nav-search" placeholder="Filter pages" aria-label="Filter pages">
    <a class="gh-link" href="https://github.com/merative/curam-kubernetes" target="_blank" rel="noopener noreferrer">GitHub</a>
  </div>
</header>
<div class="shell">
  <nav class="sidebar" aria-label="Main navigation"><ul>${navHtml}</ul></nav>
  <main id="main" class="content">
    ${header}
    <article class="markdown">${content}</article>
    ${isHero ? '' : `<nav class="pager" aria-label="Pagination">${pager}</nav>`}
  </main>
  ${toc}
</div>
<footer class="site-footer">
  <p>© ${new Date().getFullYear()} Merative L.P. Licensed under Apache 2.0.</p>
  <p><a href="${withPrefix('/notices/')}">Notices</a> · <a href="${withPrefix('/contributing/')}">Contributing</a> · <a href="${withPrefix('/contact/contact_us/')}">Contact us</a></p>
</footer>
<script src="${withPrefix('/theme/site.js')}" defer></script>
</body>
</html>
`;
}

/* ------------------------------------------------------------------ build */

function build() {
  const started = Date.now();
  fs.rmSync(OUT, { recursive: true, force: true });
  fs.mkdirSync(OUT, { recursive: true });

  const sources = walk(PAGES, '.mdx').sort();
  const pages = sources.map((source) => {
    const raw = fs.readFileSync(source, 'utf8');
    const { data, body } = parseFrontmatter(raw);
    const rel = path.relative(PAGES, source).replace(/\.mdx$/, '');
    const url = rel === 'index' ? '/' : `/${rel.split(path.sep).join('/')}/`;
    return { source, data, body, url };
  });

  const titles = new Map(pages.map((p) => [p.url, p.data.title]));
  const nav = loadNav();
  const tabsByUrl = new Map(pages.map((page) => [page.url, resolvePageTabs(page, pages)]));

  // Include tabbed siblings in the reading order without duplicating pages.
  const order = [];
  const orderedUrls = new Set();
  for (const section of nav) {
    for (const item of section.pages || []) {
      const url = normalise(item.path);
      const entries = [
        { url, label: item.title || titles.get(url) || section.title },
        ...(tabsByUrl.get(url) || []),
      ];
      for (const entry of entries) {
        if (orderedUrls.has(entry.url)) continue;
        orderedUrls.add(entry.url);
        order.push(entry);
      }
    }
  }

  let warnings = 0;
  for (const page of pages) {
    const transformed = transformComponents(page.body);
    const env = {};
    const tokens = md.parse(transformed, env);
    const headings = collectHeadings(tokens);
    const content = md.renderer.render(tokens, md.options, env);
    const tabs = tabsByUrl.get(page.url);

    if (/<[A-Z][A-Za-z]*[\s/>]/.test(content)) {
      const leftover = [...content.matchAll(/<([A-Z][A-Za-z]*)[\s/>]/g)].map((m) => m[1]);
      console.warn(`  ! ${page.url} has unconverted component(s): ${[...new Set(leftover)].join(', ')}`);
      warnings++;
    }

    const index = order.findIndex((o) => o.url === page.url);
    const outFile =
      page.url === '/' ? path.join(OUT, 'index.html') : path.join(OUT, page.url, 'index.html');

    fs.mkdirSync(path.dirname(outFile), { recursive: true });
    fs.writeFileSync(
      outFile,
      layout({
        page,
        content,
        navHtml: renderNav(nav, page.url, titles, tabs),
        tabsHtml: renderPageTabs(page, tabs),
        headings,
        prev: index > 0 ? order[index - 1] : null,
        next: index >= 0 && index < order.length - 1 ? order[index + 1] : null,
      })
    );
  }

  copyDir(path.join(ROOT, 'src', 'images'), path.join(OUT, 'images'));
  copyDir(path.join(ROOT, 'static'), OUT);
  copyDir(THEME, path.join(OUT, 'theme'));

  console.log(
    `Built ${pages.length} pages to public/ in ${Date.now() - started}ms` +
      (PREFIX ? ` (prefix '${PREFIX}')` : '') +
      (warnings ? ` — ${warnings} page(s) with warnings` : '')
  );
  return pages.length;
}

/* ------------------------------------------------------------ link check */

/**
 * Validate every internal link and anchor in the generated output.
 * External URLs are left to the `linkchecker` step in CI.
 */
function checkLinks() {
  const files = walk(OUT, '.html');
  const idsFor = new Map();
  const idsOf = (file) => {
    if (!idsFor.has(file)) {
      const html = fs.readFileSync(file, 'utf8');
      idsFor.set(file, new Set([...html.matchAll(/id="([^"]+)"/g)].map((m) => m[1])));
    }
    return idsFor.get(file);
  };

  const problems = [];
  for (const file of files) {
    const html = fs.readFileSync(file, 'utf8');
    const from = path.relative(OUT, file);
    for (const match of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
      const url = match[1];
      if (/^(?:https?:|mailto:|data:|\/\/)/.test(url)) continue;
      const [rawPath, hash] = url.split('#');

      let target = file;
      if (rawPath) {
        target = rawPath.startsWith('/')
          ? path.join(OUT, PREFIX && rawPath.startsWith(PREFIX) ? rawPath.slice(PREFIX.length) : rawPath)
          : path.join(path.dirname(file), rawPath);
        target = decodeURIComponent(target);
      }

      if (!fs.existsSync(target)) {
        problems.push(`${from} -> ${url} (not found)`);
        continue;
      }
      if (fs.statSync(target).isDirectory()) {
        target = path.join(target, 'index.html');
        if (!fs.existsSync(target)) {
          problems.push(`${from} -> ${url} (no index.html)`);
          continue;
        }
      }
      if (hash && target.endsWith('.html') && !idsOf(target).has(decodeURIComponent(hash))) {
        problems.push(`${from} -> ${url} (no such anchor)`);
      }
    }
  }

  if (problems.length) {
    console.error(`\n${problems.length} broken internal link(s):`);
    problems.forEach((p) => console.error(`  ${p}`));
    return false;
  }
  console.log(`Checked internal links across ${files.length} pages: all resolve.`);
  return true;
}

/* ------------------------------------------------------------- dev server */

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.yaml': 'text/yaml; charset=utf-8',
  '.yml': 'text/yaml; charset=utf-8',
};

function serve(port = Number(process.env.PORT) || 8000) {
  http
    .createServer((req, res) => {
      let rel = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
      if (PREFIX && rel.startsWith(PREFIX)) rel = rel.slice(PREFIX.length) || '/';
      let file = path.join(OUT, rel);
      // Guard against path traversal outside the output directory.
      if (!file.startsWith(OUT)) {
        res.writeHead(403).end('Forbidden');
        return;
      }
      if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
      if (!fs.existsSync(file)) {
        res.writeHead(404, { 'content-type': 'text/html; charset=utf-8' });
        res.end('<h1>404</h1>');
        return;
      }
      res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' });
      fs.createReadStream(file).pipe(res);
    })
    .listen(port, () => console.log(`Serving public/ on http://localhost:${port}${PREFIX}/`));
}

if (!argv.has('--no-build')) build();
if (argv.has('--check') && !checkLinks()) process.exit(1);
if (argv.has('--serve')) serve();
