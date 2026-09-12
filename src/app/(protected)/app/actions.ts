"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { getCurrentUser } from "@/data/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export async function signOut() {
  const user = await getCurrentUser();

  if (!user) {
    redirect("/auth");
  }

  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut();
  revalidatePath("/", "layout");
  redirect("/auth");
}
