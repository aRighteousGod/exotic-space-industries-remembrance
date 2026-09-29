// Optional diagram syntax validation; install Mermaid/JSDOM in ignored staging.
// Structural preflight itself remains Python standard-library only.
import { createRequire } from 'node:module';
import { readdir, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const repo = resolve(process.argv[2] ?? '.');
const dependencyRoot = resolve(process.argv[3] ?? 'output/blueprint-rollout/mermaid-check');
const require = createRequire(resolve(dependencyRoot, 'package.json'));
const { JSDOM } = require('jsdom');
globalThis.window = new JSDOM('').window;
globalThis.document = window.document;
const { default: mermaid } = await import(pathToFileURL(require.resolve('mermaid')).href);
mermaid.initialize({ startOnLoad: false });

const modelRoot = resolve(repo, '.codex/esir/blueprints');
let diagrams = 0;
const errors = [];
for (const file of (await readdir(modelRoot)).filter(name => name.endsWith('.md')).sort()) {
  const source = await readFile(resolve(modelRoot, file), 'utf8');
  for (const match of source.matchAll(/```mermaid\r?\n([\s\S]*?)```/g)) {
    diagrams++;
    try { await mermaid.parse(match[1]); }
    catch (error) { errors.push({ file, error: String(error) }); }
  }
}
console.log(JSON.stringify({ diagrams, errors, scope: 'Mermaid syntax; no layout or behavior validation' }, null, 2));
process.exitCode = errors.length ? 1 : 0;
