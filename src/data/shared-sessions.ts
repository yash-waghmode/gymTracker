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
export type SharedSessionParticipant = {
  userId: string;
  displayName: string | null;
  workoutFinished: boolean;
};
export type SharedWorkoutChoices = {
  routines: { id: string; name: string }[];
  activeWorkout: { id: string } | null;
  sessionWorkouts: {
    id: string;
    session_id: string;
    completed_at: string | null;
  }[];
};
export type SharedWorkoutContext = {
  circleId: string;
  circleName: string;
  sessionStatus: string;
  participants: SharedSessionParticipant[];
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
  if (error?.code === "22023") throw new Error(error.message);
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

export const getSharedSessionParticipants = cache(
  async (sessionId: string): Promise<SharedSessionParticipant[]> => {
    const db = await sharedSessionContext();
    const { data, error } = await db.rpc("get_shared_session_participants", {
      p_session_id: parseId(sessionId),
    });
    if (error)
      throw new Error(
        "Training partners could not be loaded. Please try again.",
      );
    return data.map((participant) => ({
      userId: participant.user_id,
      displayName: participant.display_name,
      workoutFinished: participant.workout_finished,
    }));
  },
);

export async function getSharedWorkoutChoices(
  sessionIds: string[],
): Promise<SharedWorkoutChoices> {
  const db = await sharedSessionContext();
  const [activeResult, sessionResult] = await Promise.all([
    db
      .from("workouts")
      .select("id")
      .is("completed_at", null)
      .order("started_at")
      .limit(1)
      .maybeSingle(),
    sessionIds.length
      ? db
          .from("workouts")
          .select("id,session_id,completed_at")
          .in("session_id", sessionIds.map(parseId))
      : Promise.resolve({ data: [], error: null }),
  ]);
  if (activeResult.error || sessionResult.error)
    throw new Error("Your workout choices could not be loaded.");

  const routines: SharedWorkoutChoices["routines"] = [];
  for (let from = 0; ; from += 500) {
    const { data, error } = await db
      .from("routines")
      .select("id,name")
      .order("name")
      .order("id")
      .range(from, from + 499);
    if (error) throw new Error("Your routines could not be loaded.");
    routines.push(...data);
    if (data.length < 500) break;
  }
  return {
    routines,
    activeWorkout: activeResult.data,
    sessionWorkouts: sessionResult.data ?? [],
  };
}

export const getSharedWorkoutContext = cache(
  async (sessionId: string): Promise<SharedWorkoutContext | null> => {
    const db = await sharedSessionContext();
    const { data: session, error } = await db
      .from("workout_sessions")
      .select("circle_id,is_shared,status")
      .eq("id", parseId(sessionId))
      .maybeSingle();
    if (error) throw new Error("Workout context could not be loaded.");
    if (!session?.is_shared || !session.circle_id) return null;

    const { data: circle, error: circleError } = await db
      .from("gym_circles")
      .select("id,name")
      .eq("id", session.circle_id)
      .maybeSingle();
    if (circleError) throw new Error("Circle could not be loaded.");
    if (!circle) return null;

    return {
      circleId: circle.id,
      circleName: circle.name,
      sessionStatus: session.status,
      participants: await getSharedSessionParticipants(sessionId),
    };
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
  if (error?.code === "22023") throw new Error(error.message);
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
