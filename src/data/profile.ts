import "server-only";

import { cache } from "react";

import { getCurrentUser } from "@/data/auth";
import { parseDisplayName } from "@/lib/profile";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Tables } from "@/types/database.generated";

export type Profile = Tables<"profiles">;

const profileContext = cache(async () => {
  const user = await getCurrentUser();
  if (!user) throw new Error("Authentication required.");
  return { user, db: await createServerSupabaseClient() };
});

export const getMyProfile = cache(async (): Promise<Profile> => {
  const { db, user } = await profileContext();
  const { data, error } = await db
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();

  if (error)
    throw new Error("Your profile could not be loaded. Please try again.");
  return data;
});

export async function updateMyDisplayName(value: unknown): Promise<void> {
  const displayName = parseDisplayName(value);
  const { db, user } = await profileContext();
  const { error } = await db
    .from("profiles")
    .update({ display_name: displayName })
    .eq("id", user.id)
    .select("id")
    .single();

  if (error)
    throw new Error("Display name could not be saved. Please try again.");
}
