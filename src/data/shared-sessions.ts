import "server-only";

import { cache } from "react";

import { getCurrentUser } from "@/data/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { parseId } from "@/lib/training";

export type SharedSessionPresence = {
  sessionId: string;
  circleId: string;
  startedAt: string | null;
  createdBy: string;
  creatorDisplayName: string | null;
  status: "active";
  participantCount: number;
};

const sharedSessionContext = cache(async () => {
  const user = await getCurrentUser();
  if (!user) throw new Error("Authentication required.");
  return createServerSupabaseClient();
});

export async function startSharedSession(
  circleId: string,
  routineId?: string | null,
): Promise<{ sessionId: string; workoutId: string }> {
  const db = await sharedSessionContext();
  const { data, error } = await db.rpc("start_shared_session", {
    p_circle_id: parseId(circleId),
    p_routine: routineId ? parseId(routineId) : null,
  });
  const result = data?.[0];
  if (error || !result)
    throw new Error("Shared session could not be started. Please try again.");
  return { sessionId: result.session_id, workoutId: result.workout_id };
}

export const getActiveSharedSessions = cache(
  async (circleId: string): Promise<SharedSessionPresence[]> => {
    const db = await sharedSessionContext();
    const { data, error } = await db.rpc("get_active_shared_sessions", {
      p_circle_id: parseId(circleId),
    });
    if (error)
      throw new Error("Shared sessions could not be loaded. Please try again.");
    return data.map((session) => ({
      sessionId: session.session_id,
      circleId: session.circle_id,
      startedAt: session.started_at,
      createdBy: session.created_by,
      creatorDisplayName: session.creator_display_name,
      status: "active",
      participantCount: session.participant_count,
    }));
  },
);

export async function joinSharedSession(
  sessionId: string,
  routineId?: string | null,
): Promise<string> {
  const db = await sharedSessionContext();
  const { data, error } = await db.rpc("join_shared_session", {
    p_session_id: parseId(sessionId),
    p_routine: routineId ? parseId(routineId) : null,
  });
  if (error || !data)
    throw new Error("Shared session could not be joined. Please try again.");
  return data;
}

export async function endSharedSession(sessionId: string): Promise<void> {
  const db = await sharedSessionContext();
  const { error } = await db.rpc("end_shared_session", {
    p_session_id: parseId(sessionId),
  });
  if (error)
    throw new Error("Shared session could not be ended. Please try again.");
}
