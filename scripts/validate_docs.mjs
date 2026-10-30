// Documentation validation only; no AWS calls or infrastructure commands.
// Install tools locally: npm install --prefix evidence/docs-tools --no-save --ignore-scripts mermaid markdown-it yaml jsdom
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
const root = process.cwd();
const require = createRequire(path.join(root, 'evidence/docs-tools/package.json'));
const MarkdownIt = require('markdown-it');
const YAML = require('yaml');
const md = new MarkdownIt();
const docs = ['README.md', 'VALIDATION.md', 'IMAGE_PREPARATION.md', ...fs.readdirSync('docs').filter(x => x.endsWith('.md')).map(x => 'docs/' + x)];
const parsed = new Map();
const slug = text => text.toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, '').replace(/\s/g, '-');
for (const file of docs) {
  const text = fs.readFileSync(file, 'utf8');
  assert.equal((text.match(/^```/gm) || []).length % 2, 0, `${file}: unbalanced code fences`);
  assert(!/[\uFFFD]|â€|â€“|â†|Ã—/.test(text), `${file}: damaged encoding`);
  const tokens = md.parse(text, {});
  const anchors = new Set();
  for (let i = 0; i < tokens.length; i++) if (tokens[i].type === 'heading_open') anchors.add(slug(tokens[i + 1].content));
  parsed.set(file, {tokens, anchors});
  fs.writeFileSync(path.join('evidence', path.basename(file) + '.html'), md.render(text));
}
let checkedLinks = 0;
for (const [file, {tokens}] of parsed) {
  for (const token of tokens.flatMap(t => t.children || [])) {
    if (token.type !== 'link_open') continue;
    const href = token.attrGet('href');
    if (!href || /^[a-z][a-z0-9+.-]*:/i.test(href)) continue;
    const [relative, fragment] = href.split('#');
    const target = path.resolve(path.dirname(file), decodeURIComponent(relative || path.basename(file)));
    assert(target === root || target.startsWith(root + path.sep), `${file}: link leaves project`);
    assert(fs.existsSync(target), `${file}: broken link ${href}`);
    const targetKey = path.relative(root, target).replaceAll(path.sep, '/');
    if (fragment && parsed.has(targetKey)) assert(parsed.get(targetKey).anchors.has(fragment), `${file}: missing anchor ${href}`);
    checkedLinks++;
  }
}
const diagram = fs.readFileSync('docs/architecture.mmd', 'utf8').replaceAll('\r\n', '\n').trim();
const readmeDiagram = parsed.get('README.md').tokens.find(t => t.type === 'fence' && t.info === 'mermaid');
assert(readmeDiagram && readmeDiagram.content.trim() === diagram, 'README/standalone architecture mismatch');
const {JSDOM} = require('jsdom');
const dom = new JSDOM('<!doctype html><html><body></body></html>');
globalThis.window = dom.window;
globalThis.document = dom.window.document;
const mermaid = (await import(pathToFileURL(require.resolve('mermaid')).href)).default;
mermaid.initialize({startOnLoad: false, securityLevel: 'strict'});
await mermaid.parse(diagram);
for (const file of fs.readdirSync('.github/workflows').filter(x => x.endsWith('.yml'))) {
  const workflow = YAML.parse(fs.readFileSync('.github/workflows/' + file, 'utf8'));
  assert(workflow.on && workflow.jobs, `${file}: missing workflow structure`);
  if (file === 'terraform-plan.yml') assert.equal(workflow.jobs.plan.if, '${{ false }}');
  if (file === 'terraform-apply.yml') for (const job of ['merged-pr','apply']) assert.equal(workflow.jobs[job].if, '${{ false }}');
  if (file === 'terraform-validate.yml') assert(!JSON.stringify(workflow).includes('terraform apply'));
}
const result = {markdownDocuments: docs.length, localLinks: checkedLinks, mermaid: 'parsed; source matches README', workflowYaml: 3, cloudJobs: 'explicitly disabled', encodingAndFences: 'passed'};
fs.writeFileSync('evidence/docs-validation.json', JSON.stringify(result, null, 2));
console.log(JSON.stringify(result));
