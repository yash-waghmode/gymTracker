import assert from "node:assert/strict";
import test from "node:test";

import {
  canNudgeGoalParticipant,
  goalTimeRemaining,
  orderedGoalParticipants,
} from "../src/lib/circle-goal";
import type { CircleGoalProgress } from "../src/data/circle-goals";

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

test("nudge action is limited to incomplete peers in the active goal cohort", () => {
  const now = new Date("2026-09-17T12:00:00Z");
  const progress: CircleGoalProgress = {
    goalId: "goal",
    circleId: "circle",
    targetWorkouts: 3,
    startsAt: "2026-09-16T12:00:00Z",
    endsAt: "2026-09-23T12:00:00Z",
    cancelledAt: null,
    status: "active",
    groupComplete: false,
    participants: [
      { userId: "self", displayName: "Self", completedWorkouts: 0 },
      { userId: "peer", displayName: "Peer", completedWorkouts: 2 },
      { userId: "done", displayName: "Done", completedWorkouts: 3 },
    ],
  };
  const [self, peer, done] = progress.participants;
  assert.equal(canNudgeGoalParticipant(progress, "self", peer, now), true);
  assert.equal(canNudgeGoalParticipant(progress, "self", self, now), false);
  assert.equal(canNudgeGoalParticipant(progress, "self", done, now), false);
  assert.equal(canNudgeGoalParticipant(progress, "late", peer, now), false);
  assert.equal(
    canNudgeGoalParticipant(
      progress,
      "self",
      { userId: "late", displayName: "Late", completedWorkouts: 0 },
      now,
    ),
    false,
  );
  assert.equal(
    canNudgeGoalParticipant(
      { ...progress, status: "expired" },
      "self",
      peer,
      now,
    ),
    false,
  );
  assert.equal(
    canNudgeGoalParticipant(
      { ...progress, cancelledAt: now.toISOString(), status: "cancelled" },
      "self",
      peer,
      now,
    ),
    false,
  );
  assert.equal(
    canNudgeGoalParticipant(
      { ...progress, startsAt: "2026-09-18T12:00:00Z" },
      "self",
      peer,
      now,
    ),
    false,
  );
  assert.equal(
    canNudgeGoalParticipant(
      progress,
      "self",
      peer,
      new Date("2026-09-23T12:00:00Z"),
    ),
    false,
  );
});
