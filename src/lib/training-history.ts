import type { TrainingData } from "@/data/training";
import { bestSet, beats } from "./training";
export function exerciseHistory(data: TrainingData, exercise: string) {
  return data.workouts
    .filter((w) => w.completed_at)
    .sort(
      (a, b) =>
        a.completed_at!.localeCompare(b.completed_at!) ||
        a.id.localeCompare(b.id),
    )
    .flatMap((workout) => {
      const ids = new Set(
        data.workoutExercises
          .filter(
            (e) => e.workout_id === workout.id && e.exercise_id === exercise,
          )
          .map((e) => e.id),
      );
      const sets = data.sets
        .filter((s) => ids.has(s.workout_exercise_id))
        .sort((a, b) => a.position - b.position);
      return sets.length ? [{ workout, sets, best: bestSet(sets) }] : [];
    });
}
export function recordsForWorkout(data: TrainingData, workoutId: string) {
  return data.workoutExercises
    .filter((e) => e.workout_id === workoutId)
    .filter(
      (e, index, list) =>
        list.findIndex((x) => x.exercise_id === e.exercise_id) === index,
    )
    .filter((e) => {
      const history = exerciseHistory(data, e.exercise_id);
      const index = history.findIndex((h) => h.workout.id === workoutId);
      return (
        index >= 0 &&
        beats(
          history[index].best,
          bestSet(history.slice(0, index).flatMap((h) => h.sets)),
        )
      );
    })
    .map((e) => e.exercise_id);
}
