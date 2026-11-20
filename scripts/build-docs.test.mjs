import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { before, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { load } from 'js-yaml';

const root = fileURLToPath(new URL('../', import.meta.url));
const prefix = (process.env.SITE_PREFIX || '').replace(/\/+$/, '');

before(() => {
  execFileSync(process.execPath, ['scripts/build-docs.mjs'], { cwd: root });
});

function readPage(route) {
  const html = fs.readFileSync(new URL(`../public${route}index.html`, import.meta.url), 'utf8');
  return {
    html,
    sidebar: html.match(/<nav class="sidebar"[\s\S]*?<\/nav>/)[0],
  };
}

for (const tab of ['minikube', 'aks', 'eks']) {
  test(`Kubernetes sidebar context stays active on the ${tab} tab`, () => {
    const route = `/prereq/kubernetes/${tab}/`;
    const { html, sidebar } = readPage(route);
    assert.ok(sidebar.includes('<details open><summary>Prerequisites</summary>'));
    assert.ok(sidebar.includes(
      `<a href="${prefix}/prereq/kubernetes/kubernetes-overview/" class="active" aria-current="location">Kubernetes</a>`,
    ));
    assert.ok(html.includes(`<a href="${prefix}${route}" class="active" aria-current="page">`));
    assert.equal((sidebar.match(/class="active"/g) || []).length, 1);
  });
}

test('direct navigation to Kubernetes Overview marks the actual page current', () => {
  const { sidebar } = readPage('/prereq/kubernetes/kubernetes-overview/');
  assert.ok(sidebar.includes('<details open><summary>Prerequisites</summary>'));
  assert.ok(sidebar.includes(
    `<a href="${prefix}/prereq/kubernetes/kubernetes-overview/" class="active" aria-current="page">Kubernetes</a>`,
  ));
});

test('other tabbed sections retain their sidebar context', () => {
  const { sidebar } = readPage('/prereq/mq/mq-containers/');
  assert.ok(sidebar.includes('<details open><summary>Prerequisites</summary>'));
  assert.ok(sidebar.includes(
    `<a href="${prefix}/prereq/mq/mq-overview/" class="active" aria-current="location">MQ Overview and Configuration</a>`,
  ));
});

test('unrelated pages do not activate the Kubernetes sidebar section', () => {
  const { sidebar } = readPage('/faq/');
  assert.ok(!sidebar.includes('<details open><summary>Prerequisites</summary>'));
  assert.ok(sidebar.includes(`<a href="${prefix}/faq/" class="active" aria-current="page">FAQ</a>`));
  assert.equal((sidebar.match(/class="active"/g) || []).length, 1);
});

function assertReadingOrder(routes) {
  for (let index = 0; index < routes.length; index++) {
    const { html } = readPage(routes[index]);
    for (const [direction, offset] of [['prev', -1], ['next', 1]]) {
      const target = routes[index + offset];
      if (!target) continue;
      const link = html.match(new RegExp(`<a class="pager-${direction}" href="([^"]+)"`));
      assert.equal(link?.[1], `${prefix}${target}`, `${routes[index]} ${direction}`);
    }
  }
}

test('pagination follows prerequisite tabs and section boundaries in both directions', () => {
  assertReadingOrder([
    '/prereq/docker-helm/',
    '/prereq/kubernetes/kubernetes-overview/',
    '/prereq/kubernetes/minikube/',
    '/prereq/kubernetes/aks/',
    '/prereq/kubernetes/eks/',
    '/prereq/openshift/openshift-overview/',
    '/prereq/openshift/codeready-containers/',
    '/prereq/mq/mq-overview/',
    '/prereq/mq/mq-on-vms/',
    '/prereq/mq/mq-containers/',
    '/prereq/chartmuseum/',
  ]);
});

test('pagination includes architecture tabs before the next sidebar group', () => {
  assertReadingOrder([
    '/architecture/arch-overview/architecture-overview/',
    '/architecture/arch-overview/reference-architecture/',
    '/architecture/arch-overview/dev-workstation/',
    '/architecture/arch-overview/static-content/',
    '/architecture/aks-consideration/security/',
    '/architecture/aks-consideration/networking/',
    '/architecture/aks-consideration/authentication/',
    '/architecture/aks-consideration/container-registry/',
    '/architecture/aks-consideration/storage/',
    '/architecture/eks-consideration/security/',
  ]);
});

test('pagination resolves tab labels that differ from their page titles', () => {
  assertReadingOrder([
    '/supporting-infrastructure/KeyCloak/',
    '/supporting-infrastructure/logging/',
    '/supporting-infrastructure/log4j/',
    '/supporting-infrastructure/persistent-timers/',
  ]);
});

test('pagination keeps the first and last pages as boundaries', () => {
  const first = readPage('/Introduction/').html;
  const nav = load(fs.readFileSync(path.join(root, 'src/data/nav-items.yaml'), 'utf8'));
  // Release preparation removes the Contributing section from navigation.
  const lastRoute = nav.some((section) => section.title === 'Contributing') ? '/contributing/' : '/notices/';
  const last = readPage(lastRoute).html;
  assert.ok(!first.includes('class="pager-prev"'));
  assert.ok(!last.includes('class="pager-next"'));
  assert.ok(!readPage('/').html.includes('class="pager"'));
});

test('external web links open separately while internal links stay in the current context', () => {
  const output = new URL('../public/', import.meta.url);
  for (const file of fs.readdirSync(output, { recursive: true })) {
    if (!file.endsWith('.html')) continue;
    const html = fs.readFileSync(new URL(file, output), 'utf8');
    for (const [tag, href] of html.matchAll(/<a\b[^>]*\bhref="([^"]*)"[^>]*>/g)) {
      const location = `${file}: ${href}`;
      if (/^(?:https?:)?\/\//i.test(href)) {
        assert.match(tag, /\btarget="_blank"/, location);
        const rel = tag.match(/\brel="([^"]*)"/)?.[1].split(/\s+/) || [];
        assert.ok(rel.includes('noopener'), location);
        assert.ok(rel.includes('noreferrer'), location);
      } else {
        assert.doesNotMatch(tag, /\btarget=/, location);
      }
    }
  }
});

test('the build instructions link to prerequisites within the current runbook', () => {
  const { html } = readPage('/deploy-curam/build-curam/');
  const article = html.match(/<article class="markdown">([\s\S]*?)<\/article>/)[1];
  assert.ok(article.includes(
    `<a href="${prefix}/prereq/prereq/">Prerequisite software</a>`,
  ));
});

function checkLinkFixture(t, html) {
  const directory = fs.mkdtempSync(path.join(root, 'public', 'anchor-check-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.writeFileSync(path.join(directory, 'index.html'), html);
  return spawnSync(process.execPath, ['scripts/build-docs.mjs', '--no-build', '--check'], {
    cwd: root,
    encoding: 'utf8',
  });
}

test('the link checker rejects missing same-page anchors', (t) => {
  const result = checkLinkFixture(t, '<a href="#missing-heading">Missing heading</a>');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /index\.html -> #missing-heading \(no such anchor\)/);
});

test('the link checker accepts existing, encoded, empty and cross-page fragments', (t) => {
  const result = checkLinkFixture(t, `
    <h2 id="existing-heading">Existing heading</h2>
    <h2 id="cúram">Cúram</h2>
    <a href="#existing-heading">Same-page heading</a>
    <a href="#c%C3%BAram">Encoded heading</a>
    <a href="#">Top of page</a>
    <a href="index.html#existing-heading">Relative page and heading</a>
    <a href="${prefix}/troubleshooting/must_gather/#mustgather-to-collect-logs-and-other-artifacts">Cross-page heading</a>
  `);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
