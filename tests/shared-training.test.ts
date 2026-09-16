import { test } from "node:test";
import assert from "node:assert/strict";

import { sharedSessionAction } from "../src/lib/shared-training";

test("shared Circle actions open only the caller's existing workout", () => {
  const workouts = [
    { id: "mine", session_id: "circle-session", completed_at: null },
  ];
  assert.deepEqual(sharedSessionAction("circle-session", workouts, "mine"), {
    kind: "open",
    workoutId: "mine",
    finished: false,
  });
  assert.deepEqual(
    sharedSessionAction(
      "circle-session",
      [{ ...workouts[0], completed_at: "2026-09-16T10:00:00Z" }],
      null,
    ),
    { kind: "open", workoutId: "mine", finished: true },
  );
});

test("joining waits for an unrelated active workout, otherwise stays available", () => {
  assert.deepEqual(sharedSessionAction("circle-session", [], "solo-workout"), {
    kind: "resume-current",
    workoutId: "solo-workout",
  });
  assert.deepEqual(sharedSessionAction("circle-session", [], null), {
    kind: "join",
  });
});
