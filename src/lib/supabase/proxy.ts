import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

import type { Database } from "@/types/database.generated";

import { inviteReturnPath } from "@/lib/invite";

import { getPublicSupabaseConfig, isSupabaseConfigured } from "./config";

export async function updateSupabaseSession(request: NextRequest) {
  if (!isSupabaseConfigured()) {
    return NextResponse.next({ request });
  }

  let response = NextResponse.next({ request });
  const { url, publishableKey } = getPublicSupabaseConfig();
  const supabase = createServerClient<Database>(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value);
        });
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  // Keep this immediately after client creation. It validates and refreshes the
  // cookie-backed token before Server Components read it.
  const { data } = await supabase.auth.getClaims();
  const claims = data?.claims;

  const pathname = request.nextUrl.pathname;
  if (!claims?.sub && pathname.startsWith("/app")) {
    const destination = request.nextUrl.clone();
    destination.pathname = "/auth";
    destination.search = "";
    destination.searchParams.set("notice", "signin-required");

    const redirectResponse = NextResponse.redirect(destination);
    response.cookies.getAll().forEach((cookie) => {
      redirectResponse.cookies.set(cookie);
    });
    return redirectResponse;
  }

  if (claims?.sub && pathname === "/auth") {
    const returnPath = inviteReturnPath(
      request.nextUrl.searchParams.get("next"),
    );
    const redirectResponse = NextResponse.redirect(
      new URL(returnPath ?? "/app", request.url),
    );
    response.cookies.getAll().forEach((cookie) => {
      redirectResponse.cookies.set(cookie);
    });
    return redirectResponse;
  }

  return response;
}
