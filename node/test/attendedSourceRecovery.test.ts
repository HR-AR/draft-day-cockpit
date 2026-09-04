import assert from "node:assert/strict";
import test from "node:test";
import { ATTENDED_SOURCE_RECOVERY } from "../src/attendedSourceRecovery.ts";

test("the disconnected message names the attended recovery action", () => {
  assert.equal(
    ATTENDED_SOURCE_RECOVERY,
    "ATTENDED_SOURCE_REQUIRED: open dedicated YFF Chrome and keep the current Yahoo mock lobby or draft room selected until Connected and Bound",
  );
  assert.doesNotMatch(ATTENDED_SOURCE_RECOVERY, /Playwright/u);
});
