"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { inviteReturnPath } from "@/lib/invite";
import { parseDisplayName } from "@/lib/profile";
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

function authDestination(
  reason: string,
  returnPath: string | null,
  mode: "signin" | "signup" = "signin",
) {
  const params = new URLSearchParams({ error: reason });
  if (returnPath) params.set("next", returnPath);
  if (mode === "signup") params.set("mode", mode);
  return `/auth?${params}`;
}

function requireSupabaseConfiguration(
  returnPath: string | null,
  mode: "signin" | "signup" = "signin",
) {
  if (!isSupabaseConfigured()) {
    redirect(authDestination("not-configured", returnPath, mode));
  }
}

export async function signIn(formData: FormData) {
  const returnPath = inviteReturnPath(formData.get("next"));
  requireSupabaseConfiguration(returnPath);
  const credentials = readCredentials(formData);

  if (!credentials) {
    redirect(authDestination("invalid-input", returnPath));
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.signInWithPassword(credentials);

  if (error) {
    redirect(authDestination("signin-failed", returnPath));
  }

  revalidatePath("/", "layout");
  redirect(returnPath ?? "/app");
}

export async function signUp(formData: FormData) {
  const returnPath = inviteReturnPath(formData.get("next"));
  requireSupabaseConfiguration(returnPath, "signup");
  const credentials = readCredentials(formData);

  if (!credentials) {
    redirect(authDestination("invalid-input", returnPath, "signup"));
  }

  let displayName: string;
  try {
    displayName = parseDisplayName(formData.get("displayName"));
  } catch {
    redirect(authDestination("invalid-display-name", returnPath, "signup"));
  }

  const supabase = await createServerSupabaseClient();
  const callback = new URL("/auth/confirm", getSiteUrl());
  callback.searchParams.set("next", returnPath ?? "/app");
  const { data, error } = await supabase.auth.signUp({
    ...credentials,
    options: {
      emailRedirectTo: callback.toString(),
      data: { display_name: displayName },
    },
  });

  if (error) {
    redirect(authDestination("signup-failed", returnPath, "signup"));
  }

  revalidatePath("/", "layout");
  if (data.session) redirect(returnPath ?? "/app");

  const params = new URLSearchParams({ notice: "check-email" });
  if (returnPath) params.set("next", returnPath);
  params.set("mode", "signup");
  redirect(`/auth?${params}`);
}
