export type OwnSessionWorkout = {
  id: string;
  session_id: string;
  completed_at: string | null;
};

export function sharedSessionAction(
  sessionId: string,
  ownWorkouts: OwnSessionWorkout[],
  activeWorkoutId: string | null,
):
  | { kind: "open"; workoutId: string; finished: boolean }
  | { kind: "resume-current"; workoutId: string }
  | { kind: "join" } {
  const ownWorkout = ownWorkouts.find(
    (workout) => workout.session_id === sessionId,
  );
  if (ownWorkout) {
    return {
      kind: "open",
      workoutId: ownWorkout.id,
      finished: ownWorkout.completed_at !== null,
    };
  }
  if (activeWorkoutId) {
    return { kind: "resume-current", workoutId: activeWorkoutId };
  }
  return { kind: "join" };
}
