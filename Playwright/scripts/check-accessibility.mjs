import AxeBuilder from '@axe-core/playwright';
import { chromium } from '@playwright/test';
import { access, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '../..');
const outputDirectory = path.join(repositoryRoot, 'public');
const baseUrl = new URL(
  process.env.ACCESSIBILITY_BASE_URL ??
    `http://localhost:${process.env.PORT ?? '8000'}/`,
);
if (!baseUrl.pathname.endsWith('/')) baseUrl.pathname += '/';

async function findPages(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const pages = [];

  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      pages.push(...(await findPages(entryPath)));
    } else if (entry.isFile() && entry.name === 'index.html') {
      pages.push(entryPath);
    }
  }

  return pages;
}

try {
  await access(path.join(outputDirectory, 'index.html'));
} catch {
  throw new Error('Built site not found. Run `npm run build` first.');
}

const pages = (await findPages(outputDirectory)).sort();
const urls = pages.map((page) => {
  const relativeDirectory = path.relative(
    outputDirectory,
    path.dirname(page),
  );
  const route = relativeDirectory
    ? `${relativeDirectory
        .split(path.sep)
        .map(encodeURIComponent)
        .join('/')}/`
    : '';
  return new URL(route, baseUrl).href;
});

if (urls.length === 0) {
  throw new Error(`No generated pages found under ${outputDirectory}.`);
}

const response = await fetch(baseUrl);
if (!response.ok) {
  throw new Error(
    `Cannot reach ${baseUrl} (HTTP ${response.status}). Start the site with \`npm run dev\`.`,
  );
}

const browser = await chromium.launch();
let violationCount = 0;

try {
  for (const url of urls) {
    const context = await browser.newContext();
    try {
      const page = await context.newPage();
      const pageResponse = await page.goto(url, { waitUntil: 'networkidle' });
      if (!pageResponse?.ok()) {
        throw new Error(
          `Cannot load ${url} (HTTP ${pageResponse?.status() ?? 'no response'}).`,
        );
      }

      const { violations } = await new AxeBuilder({ page }).analyze();
      if (violations.length === 0) {
        console.log(`${url}: no violations`);
        continue;
      }

      violationCount += violations.length;
      console.error(`\n${url}: ${violations.length} violation(s)`);
      for (const violation of violations) {
        console.error(
          `  Violation of "${violation.id}" with ${violation.nodes.length} occurrence(s)!`,
        );
        console.error(`    [${violation.impact ?? 'unknown'}] ${violation.help}`);
        console.error(`    ${violation.description}`);
        for (const node of violation.nodes) {
          console.error(`    ${node.target.join(', ')}`);
          if (node.failureSummary) {
            console.error(
              node.failureSummary
                .split('\n')
                .map((line) => `      ${line}`)
                .join('\n'),
            );
          }
        }
        console.error(`    For details: ${violation.helpUrl}`);
      }
    } finally {
      await context.close();
    }
  }
} finally {
  await browser.close();
}

console.log(`\nScanned ${urls.length} pages; ${violationCount} violation(s).`);
if (violationCount > 0) process.exitCode = 1;
