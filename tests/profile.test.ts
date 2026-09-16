import { test } from "node:test";
import assert from "node:assert/strict";

import { parseDisplayName } from "../src/lib/profile";

test("display names are trimmed and constrained to the profile limit", () => {
  assert.equal(parseDisplayName("  Asha Strong  "), "Asha Strong");
  assert.throws(() => parseDisplayName(null));
  assert.throws(() => parseDisplayName("   "));
  assert.throws(() => parseDisplayName("x".repeat(81)));
});
