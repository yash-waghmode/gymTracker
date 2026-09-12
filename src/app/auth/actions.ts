"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { getSiteUrl, isSupabaseConfigured } from "@/lib/supabase/config";
import { createServerSupabaseClient } from "@/lib/supabase/server";

type Credentials = {
  email: string;
  password: string;
};

function readCredentials(formData: FormData): Credentials | null {
  const email = formData.get("email");
  const password = formData.get("password");

  if (
    typeof email !== "string" ||
    !email.includes("@") ||
    typeof password !== "string" ||
    password.length < 8
  ) {
    return null;
  }

  return { email: email.trim(), password };
}

function requireSupabaseConfiguration() {
  if (!isSupabaseConfigured()) {
    redirect("/auth?error=not-configured");
  }
}

export async function signIn(formData: FormData) {
  requireSupabaseConfiguration();
  const credentials = readCredentials(formData);

  if (!credentials) {
    redirect("/auth?error=invalid-input");
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.signInWithPassword(credentials);

  if (error) {
    redirect("/auth?error=signin-failed");
  }

  revalidatePath("/", "layout");
  redirect("/app");
}

export async function signUp(formData: FormData) {
  requireSupabaseConfiguration();
  const credentials = readCredentials(formData);

  if (!credentials) {
    redirect("/auth?error=invalid-input");
  }

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.auth.signUp({
    ...credentials,
    options: {
      emailRedirectTo: `${getSiteUrl()}/auth/confirm`,
    },
  });

  if (error) {
    redirect("/auth?error=signup-failed");
  }

  revalidatePath("/", "layout");
  redirect(data.session ? "/app" : "/auth?notice=check-email");
}
