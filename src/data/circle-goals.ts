import "server-only";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { parseId } from "@/lib/training";

export type CircleWorkoutGoal = {
  goalId: string;
  circleId: string;
  createdBy: string;
  targetWorkouts: number;
  startsAt: string;
  endsAt: string;
  createdAt: string;
};

export type CircleGoalProgress = {
  goalId: string;
  circleId: string;
  targetWorkouts: number;
  startsAt: string;
  endsAt: string;
  cancelledAt: string | null;
  status: "active" | "succeeded" | "expired" | "cancelled";
  groupComplete: boolean;
  participants: {
    userId: string;
    displayName: string | null;
    completedWorkouts: number;
  }[];
};

export async function createCircleGoal(
  circleId: string,
  targetWorkouts: number,
): Promise<string> {
  if (
    !Number.isInteger(targetWorkouts) ||
    targetWorkouts < 1 ||
    targetWorkouts > 7
  )
    throw new Error("Target must be 1 to 7 workouts.");
  const db = await createServerSupabaseClient();
  const { data, error } = await db.rpc("create_circle_workout_goal", {
    p_circle_id: parseId(circleId),
    p_target_workouts: targetWorkouts,
  });
  if (error || !data) throw new Error("Circle goal could not be created.");
  return data;
}

export async function getActiveCircleGoal(
  circleId: string,
): Promise<CircleWorkoutGoal | null> {
  const db = await createServerSupabaseClient();
  const { data, error } = await db.rpc("get_active_circle_workout_goal", {
    p_circle_id: parseId(circleId),
  });
  if (error) throw new Error("Circle goal could not be loaded.");
  const goal = data[0];
  return goal
    ? {
        goalId: goal.goal_id,
        circleId: goal.circle_id,
        createdBy: goal.created_by,
        targetWorkouts: goal.target_workouts,
        startsAt: goal.starts_at,
        endsAt: goal.ends_at,
        createdAt: goal.created_at,
      }
    : null;
}

export async function getCircleGoalProgress(
  goalId: string,
): Promise<CircleGoalProgress> {
  const db = await createServerSupabaseClient();
  const { data, error } = await db.rpc("get_circle_workout_goal_progress", {
    p_goal_id: parseId(goalId),
  });
  if (error || !data[0])
    throw new Error("Circle goal progress could not be loaded.");
  const first = data[0];
  return {
    goalId: first.goal_id,
    circleId: first.circle_id,
    targetWorkouts: first.target_workouts,
    startsAt: first.starts_at,
    endsAt: first.ends_at,
    cancelledAt: first.cancelled_at,
    status: first.goal_status as CircleGoalProgress["status"],
    groupComplete: first.group_complete,
    participants: data.map((row) => ({
      userId: row.user_id,
      displayName: row.display_name,
      completedWorkouts: row.completed_workouts,
    })),
  };
}

export async function cancelCircleGoal(goalId: string): Promise<void> {
  const db = await createServerSupabaseClient();
  const { error } = await db.rpc("cancel_circle_workout_goal", {
    p_goal_id: parseId(goalId),
  });
  if (error) throw new Error("Circle goal could not be cancelled.");
}
