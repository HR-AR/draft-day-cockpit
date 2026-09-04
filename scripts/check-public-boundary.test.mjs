import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import test from "node:test";

const checker = resolve(import.meta.dirname, "check-public-boundary.mjs");

function fixture() {
  const root = mkdtempSync(resolve(tmpdir(), "draft-day-public-boundary-"));
  mkdirSync(resolve(root, "Sources"));
  writeFileSync(resolve(root, "Sources/example.swift"), "public let status = \"ready\"\n");
  return root;
}

function check(root) {
  return execFileSync(process.execPath, [checker, root], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
}

test("a sanitized repository passes", () => {
  assert.match(check(fixture()), /public files passed/u);
});

test("a local home path fails closed", () => {
  const root = fixture();
  writeFileSync(resolve(root, "README.md"), ["/", "Users", "person", "private"].join("/") + "\n");
  assert.throws(() => check(root), /sensitive pattern/u);
});

test("a long identifier fails closed", () => {
  const root = fixture();
  writeFileSync(resolve(root, "README.md"), `room ${"123" + "45678"}\n`);
  assert.throws(() => check(root), /sensitive pattern/u);
});
