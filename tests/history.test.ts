import { test } from "node:test";
import assert from "node:assert/strict";
import {
  exerciseHistory,
  recordsForWorkout,
} from "../src/lib/training-history";
import type { TrainingData } from "../src/data/training";

test("history excludes active workouts and records recognize improvements, not equal performances", () => {
  const base = { owner_id: "owner", created_at: "", updated_at: "" };
  const workouts = ["first", "tie", "improved", "active"].map((id, i) => ({
    ...base,
    id,
    session_id: id,
    routine_id: null,
    title: id,
    notes: null,
    started_at: "2026-09-01T00:00:00Z",
    completed_at: i === 3 ? null : `2026-09-0${i + 1}T01:00:00Z`,
  }));
  const data: TrainingData = {
    catalog: [],
    routines: [],
    routineExercises: [],
    workouts,
    workoutExercises: workouts.map((w) => ({
      ...base,
      id: w.id,
      workout_id: w.id,
      exercise_id: "bench",
      position: 0,
      notes: null,
    })),
    sets: workouts.map((w, i) => ({
      ...base,
      id: w.id,
      workout_exercise_id: w.id,
      position: 0,
      weight_kg: i === 3 ? 200 : 60,
      reps: i === 2 ? 10 : 8,
      performed_at: "",
    })),
  };
  assert.equal(exerciseHistory(data, "bench").length, 3);
  assert.deepEqual(recordsForWorkout(data, "first"), ["bench"]);
  assert.deepEqual(recordsForWorkout(data, "tie"), []);
  assert.deepEqual(recordsForWorkout(data, "improved"), ["bench"]);
  assert.deepEqual(recordsForWorkout(data, "active"), []);
});
