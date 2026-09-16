import "server-only";

import { cache } from "react";

import { getCurrentUser } from "@/data/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { parseId, parseName } from "@/lib/training";
import type { Tables } from "@/types/database.generated";

export type Circle = Tables<"gym_circles">;
export type CircleMemberIdentity = {
  user_id: string;
  display_name: string | null;
};

const circleContext = cache(async () => {
  const user = await getCurrentUser();
  if (!user) throw new Error("Authentication required.");
  return { user, db: await createServerSupabaseClient() };
});

export const getMyCircles = cache(async (): Promise<Circle[]> => {
  const { db } = await circleContext();
  const { data, error } = await db
    .from("gym_circles")
    .select("*")
    .order("created_at", { ascending: false })
    .order("id");

  if (error) throw new Error("Circles could not be loaded. Please try again.");
  return data;
});

export const getCircle = cache(
  async (circleId: string): Promise<Circle | null> => {
    const id = parseId(circleId);
    const { db } = await circleContext();
    const { data, error } = await db
      .from("gym_circles")
      .select("*")
      .eq("id", id)
      .maybeSingle();

    if (error) throw new Error("Circle could not be loaded. Please try again.");
    return data;
  },
);

export const getCircleMembers = cache(
  async (circleId: string): Promise<CircleMemberIdentity[]> => {
    const id = parseId(circleId);
    const { db } = await circleContext();
    const { data, error } = await db.rpc("get_circle_member_identities", {
      p_circle_id: id,
    });

    if (error)
      throw new Error("Circle members could not be loaded. Please try again.");
    return data;
  },
);

export async function createCircle(name: string): Promise<string> {
  const normalizedName = parseName(name);
  const { db } = await circleContext();
  const { data, error } = await db.rpc("create_circle", {
    p_name: normalizedName,
  });

  if (error || !data)
    throw new Error("Circle could not be created. Please try again.");
  return data;
}

export async function leaveCircle(circleId: string): Promise<void> {
  const id = parseId(circleId);
  const { db } = await circleContext();
  const { error } = await db.rpc("leave_circle", { p_circle_id: id });

  if (error) {
    if (error.code === "22023") throw new Error(error.message);
    throw new Error("Circle could not be left. Please try again.");
  }
}

export async function deleteCircle(circleId: string): Promise<void> {
  const id = parseId(circleId);
  const { db } = await circleContext();
  const { error } = await db.rpc("delete_circle", { p_circle_id: id });

  if (error) throw new Error("Circle could not be deleted. Please try again.");
}
