import assert from "node:assert/strict";
import test from "node:test";

import {
  goalTimeRemaining,
  orderedGoalParticipants,
} from "../src/lib/circle-goal";

test("goal participants follow member order without inventing eligibility", () => {
  const participants = [
    { userId: "later", displayName: "Later", completedWorkouts: 4 },
    { userId: "owner", displayName: "Owner", completedWorkouts: 1 },
  ];
  const members = [
    { user_id: "owner", display_name: "Owner" },
    { user_id: "later", display_name: "Later" },
    { user_id: "newcomer", display_name: "Newcomer" },
  ];

  assert.deepEqual(
    orderedGoalParticipants(participants, members).map(
      (person) => person.userId,
    ),
    ["owner", "later"],
  );
  assert.deepEqual(
    participants.map((person) => person.userId),
    ["later", "owner"],
  );
});

test("time remaining is legible near the seven-day deadline", () => {
  const now = new Date("2026-09-16T12:00:00Z");
  assert.equal(goalTimeRemaining("2026-09-23T12:00:00Z", now), "7 days left");
  assert.equal(goalTimeRemaining("2026-09-16T13:00:00Z", now), "1 hour left");
  assert.equal(goalTimeRemaining("2026-09-16T12:00:00Z", now), "Goal ended");
});
