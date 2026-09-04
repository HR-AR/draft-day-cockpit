import { readFileSync, readdirSync, statSync } from "node:fs";
import { relative, resolve } from "node:path";

const publicRoot = resolve(process.argv[2] ?? "");
if (!process.argv[2]) throw new Error("PUBLIC_BOUNDARY_REFUSED: pass the repository path");

const ignored = new Set([".git", ".build", "node_modules"]);
const forbiddenPaths = /(^|\/)(\.claude|\.ai|data|evidence|runtime|captures?)(\/|$)|\.(sqlite|db|jsonl|pem|p12|pfx)$/iu;
const forbiddenContent = [
  /\/Users\/(?!example\/)[A-Za-z0-9._-]+\//u,
  /BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY/u,
  /\b(?:ghp_|sk-|AIza|AKIA)[A-Za-z0-9_-]{16,}\b/u,
  /\b\d{6,}\b/u,
  /(?:cookie|authorization|x-api-key)\s*[:=]\s*["'][^"']+["']/iu,
];
const files = [];

function walk(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) walk(path);
    else if (entry.isFile()) files.push(path);
    else throw new Error(`PUBLIC_BOUNDARY_REFUSED: unsupported entry ${relative(publicRoot, path)}`);
  }
}

walk(publicRoot);
for (const path of files) {
  const publicPath = relative(publicRoot, path);
  if (forbiddenPaths.test(publicPath)) throw new Error(`PUBLIC_BOUNDARY_REFUSED: forbidden path ${publicPath}`);
  if (statSync(path).size > 256_000) throw new Error(`PUBLIC_BOUNDARY_REFUSED: oversized file ${publicPath}`);
  const content = readFileSync(path, "utf8");
  for (const pattern of forbiddenContent) {
    if (pattern.test(content)) throw new Error(`PUBLIC_BOUNDARY_REFUSED: sensitive pattern in ${publicPath}`);
  }
}

process.stdout.write(`check-public-boundary: ${files.length} public files passed\n`);
