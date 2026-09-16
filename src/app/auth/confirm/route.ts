import type { EmailOtpType } from "@supabase/supabase-js";
import { type NextRequest, NextResponse } from "next/server";

import { inviteReturnPath } from "@/lib/invite";
import { isSupabaseConfigured } from "@/lib/supabase/config";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const emailOtpTypes = new Set<EmailOtpType>([
  "signup",
  "invite",
  "magiclink",
  "recovery",
  "email_change",
  "email",
]);

function isEmailOtpType(value: string): value is EmailOtpType {
  return emailOtpTypes.has(value as EmailOtpType);
}

export async function GET(request: NextRequest) {
  const returnPath = inviteReturnPath(request.nextUrl.searchParams.get("next"));
  if (!isSupabaseConfigured()) {
    const destination = new URL("/auth", request.url);
    destination.searchParams.set("error", "not-configured");
    if (returnPath) destination.searchParams.set("next", returnPath);
    return NextResponse.redirect(destination);
  }

  const tokenHash = request.nextUrl.searchParams.get("token_hash");
  const type = request.nextUrl.searchParams.get("type");
  const code = request.nextUrl.searchParams.get("code");
  const supabase = await createServerSupabaseClient();

  if (tokenHash && type && isEmailOtpType(type)) {
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type,
    });
    if (!error) {
      return NextResponse.redirect(new URL(returnPath ?? "/app", request.url));
    }
  } else if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(new URL(returnPath ?? "/app", request.url));
    }
  }

  const destination = new URL("/auth", request.url);
  destination.searchParams.set("error", "confirmation");
  if (returnPath) destination.searchParams.set("next", returnPath);
  return NextResponse.redirect(destination);
}
