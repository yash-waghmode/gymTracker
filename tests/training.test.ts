import { test } from "node:test";
import assert from "node:assert/strict";
import {
  bestSet,
  beats,
  parseId,
  parseName,
  parseSet,
  workoutStats,
  weekCount,
} from "../src/lib/training";
test("record uses weight then reps, ignores failed and unknown-load sets", () => {
  assert.deepEqual(
    bestSet([
      { weight_kg: 60, reps: 12 },
      { weight_kg: 65, reps: 5 },
      { weight_kg: 65, reps: 8 },
      { weight_kg: 80, reps: 0 },
      { weight_kg: null, reps: 20 },
    ]),
    { weight_kg: 65, reps: 8 },
  );
  assert.equal(bestSet([]), null);
  assert.equal(
    beats({ weight_kg: 65, reps: 8 }, { weight_kg: 65, reps: 8 }),
    false,
  );
  assert.equal(
    beats({ weight_kg: 65, reps: 9 }, { weight_kg: 65, reps: 8 }),
    true,
  );
  assert.equal(
    beats({ weight_kg: 60, reps: 20 }, { weight_kg: 65, reps: 8 }),
    false,
  );
  assert.equal(
    beats({ weight_kg: 0, reps: 15 }, { weight_kg: 0, reps: 12 }),
    true,
  );
});
test("server validation rejects missing, negative, non-finite, fractional reps and excessive input", () => {
  assert.deepEqual(parseSet("62.5", "8"), { weight: 62.5, reps: 8 });
  assert.deepEqual(parseSet("0", "1"), { weight: 0, reps: 1 });
  for (const [w, r] of [
    ["", "8"],
    ["-1", "8"],
    ["NaN", "8"],
    ["Infinity", "8"],
    ["1e2", "8"],
    ["5", "0"],
    ["5", "1.5"],
    ["1501", "8"],
    ["1", "1001"],
    ["1.2345", "8"],
  ])
    assert.throws(() => parseSet(w, r));
  assert.throws(() => parseId("not-an-id"));
  assert.throws(() => parseName("  "));
  assert.throws(() => parseName("x".repeat(121)));
  assert.equal(parseName("  Leg day  "), "Leg day");
});
test("summary counts actual sets/reps and rounds elapsed minutes", () => {
  assert.deepEqual(
    workoutStats(
      [
        { weight_kg: 60, reps: 8 },
        { weight_kg: 60, reps: 10 },
      ],
      "2026-09-12T10:00:00Z",
      "2026-09-12T10:42:20Z",
    ),
    { sets: 2, reps: 18, minutes: 42 },
  );
  assert.equal(workoutStats([], "2026-09-12T10:00:00Z", null).minutes, null);
});
test("weekly count respects Monday and device time zone, excludes future dates", () => {
  const now = new Date("2026-09-14T01:00:00Z");
  const dates = [
    "2026-09-13T18:00:00Z",
    "2026-09-13T20:00:00Z",
    "2026-09-14T00:00:00Z",
    "2026-09-15T00:00:00Z",
  ];
  assert.equal(weekCount(dates, now, "Asia/Kolkata"), 2);
  assert.equal(weekCount(dates, now, "UTC"), 1);
});
