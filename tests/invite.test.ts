import assert from "node:assert/strict";
import test from "node:test";

import { inviteReturnPath, isInviteToken } from "../src/lib/invite";

const token = "a".repeat(64);

test("invitation return path allows only one well-formed invite route", () => {
  assert.equal(isInviteToken(token), true);
  assert.equal(inviteReturnPath(`/invite/${token}`), `/invite/${token}`);
  for (const value of [
    "/app",
    "/invite/bad",
    `/invite/${token}/extra`,
    `/invite/${token}?x=1`,
    `//example.com/invite/${token}`,
    `https://example.com/invite/${token}`,
    `/invite/${token}%2Fextra`,
    null,
  ]) {
    assert.equal(inviteReturnPath(value), null);
  }
});
