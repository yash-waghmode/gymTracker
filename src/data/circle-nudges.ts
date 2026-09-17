import "server-only";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { parseId } from "@/lib/training";

export type MyCircleGoalNudge = {
  nudgeId: string;
  senderDisplayName: string | null;
  circleName: string;
  createdAt: string;
};

export class GoalNudgeCooldownError extends Error {}

export async function sendGoalNudge(
  goalId: string,
  recipientUserId: string,
): Promise<string> {
  const db = await createServerSupabaseClient();
  const { data, error } = await db.rpc("send_circle_goal_nudge", {
    p_goal_id: parseId(goalId),
    p_recipient_id: parseId(recipientUserId),
  });
  if (
    error?.code === "22023" &&
    error.message === "You recently nudged this member."
  ) {
    throw new GoalNudgeCooldownError();
  }
  if (error || !data) throw new Error("Goal nudge could not be sent.");
  return data;
}

export async function getMyGoalNudges(
  goalId: string,
): Promise<MyCircleGoalNudge[]> {
  const db = await createServerSupabaseClient();
  const { data, error } = await db.rpc("get_my_circle_goal_nudges", {
    p_goal_id: parseId(goalId),
  });
  if (error) throw new Error("Goal nudges could not be loaded.");
  return data.map((nudge) => ({
    nudgeId: nudge.nudge_id,
    senderDisplayName: nudge.sender_display_name,
    circleName: nudge.circle_name,
    createdAt: nudge.created_at,
  }));
}
