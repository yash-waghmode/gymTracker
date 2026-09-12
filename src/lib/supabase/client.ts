"use client";

import { createBrowserClient } from "@supabase/ssr";

import type { Database } from "@/types/database.generated";

import { getPublicSupabaseConfig } from "./config";

export function createBrowserSupabaseClient() {
  const { url, publishableKey } = getPublicSupabaseConfig();

  return createBrowserClient<Database>(url, publishableKey);
}
