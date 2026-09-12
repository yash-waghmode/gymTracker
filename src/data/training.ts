import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/data/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Tables } from "@/types/database.generated";

export const trainingContext = cache(async () => {
  const user = await getCurrentUser();
  if (!user) redirect("/auth?notice=signin-required");
  return { user, db: await createServerSupabaseClient() };
});

// Explicit paging avoids Supabase's default 1000-row truncation in derived records.
async function allRows<T>(
  read: (
    from: number,
    to: number,
  ) => PromiseLike<{ data: T[] | null; error: unknown }>,
): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += 500) {
    const result = await read(from, from + 499);
    if (result.error)
      throw new Error("Training data could not be loaded. Please try again.");
    rows.push(...(result.data ?? []));
    if (!result.data || result.data.length < 500) return rows;
  }
}

export type TrainingData = {
  catalog: Tables<"exercises">[];
  routines: Tables<"routines">[];
  routineExercises: Tables<"routine_exercises">[];
  workouts: Tables<"workouts">[];
  workoutExercises: Tables<"workout_exercises">[];
  sets: Tables<"workout_sets">[];
};

export const getTraining = cache(async (): Promise<TrainingData> => {
  const { db, user } = await trainingContext();
  const [
    catalog,
    routines,
    routineExercises,
    workouts,
    workoutExercises,
    sets,
  ] = await Promise.all([
    allRows((a, b) =>
      db.from("exercises").select("*").order("name").order("id").range(a, b),
    ),
    allRows((a, b) =>
      db
        .from("routines")
        .select("*")
        .eq("owner_id", user.id)
        .order("name")
        .order("id")
        .range(a, b),
    ),
    allRows((a, b) =>
      db
        .from("routine_exercises")
        .select("*")
        .eq("owner_id", user.id)
        .order("id")
        .range(a, b),
    ),
    allRows((a, b) =>
      db
        .from("workouts")
        .select("*")
        .eq("owner_id", user.id)
        .order("started_at", { ascending: false })
        .order("id")
        .range(a, b),
    ),
    allRows((a, b) =>
      db
        .from("workout_exercises")
        .select("*")
        .eq("owner_id", user.id)
        .order("id")
        .range(a, b),
    ),
    allRows((a, b) =>
      db
        .from("workout_sets")
        .select("*")
        .eq("owner_id", user.id)
        .order("id")
        .range(a, b),
    ),
  ]);
  return {
    catalog,
    routines,
    routineExercises,
    workouts,
    workoutExercises,
    sets,
  };
});
