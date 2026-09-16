import Link from "next/link";

import { ActionForm } from "@/components/training/forms";
import { getCurrentUser } from "@/data/auth";
import { getCircleInvitePreview } from "@/data/circles";
import { isSupabaseConfigured } from "@/lib/supabase/config";

import { acceptCircleInviteAction } from "@/app/(protected)/app/circle-actions";
import "../../(protected)/product.css";

export const dynamic = "force-dynamic";

const unavailableMessages = {
  invalid: "This invite link isn’t valid.",
  expired: "This invite link has expired.",
  revoked: "This invite link was revoked.",
  consumed: "This invite link has already been used.",
} as const;

export default async function InvitePage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const returnPath = `/invite/${token}`;
  const configured = isSupabaseConfigured();
  const [user, preview] = await Promise.all([
    getCurrentUser(),
    configured ? getCircleInvitePreview(token).catch(() => null) : null,
  ]);

  const isMember = Boolean(preview?.alreadyMember && preview.circleId);
  const canJoin = preview?.status === "active" && !isMember;
  const signInUrl = `/auth?${new URLSearchParams({
    notice: "signin-required",
    next: returnPath,
  })}`;

  return (
    <div className="product invite-shell">
      <header className="product-header">
        <Link href="/app" className="wordmark">
          GYM<span>TRACKER</span>
          <i aria-hidden="true">↗</i>
        </Link>
        <span className="private-label">Private training</span>
      </header>

      <main className="product-main" id="main">
        <section className="card stack">
          <header className="page-heading">
            <p className="eyebrow">GYM CIRCLE INVITE</p>
            <h1>
              {preview?.circleName && (canJoin || isMember)
                ? preview.circleName
                : "Circle invitation"}
            </h1>
          </header>

          {isMember ? (
            <>
              <p>You’re already a member of this Circle.</p>
              <Link
                className="button"
                href={`/app/circles/${preview!.circleId}`}
              >
                Open Circle
              </Link>
            </>
          ) : canJoin ? (
            <>
              <p>
                Join this private Circle to see its members. Your workouts,
                routines, and sets stay private.
              </p>
              {user ? (
                <ActionForm action={acceptCircleInviteAction}>
                  <input type="hidden" name="token" value={token} />
                  <button type="submit">Join Circle</button>
                </ActionForm>
              ) : (
                <Link className="button" href={signInUrl} prefetch={false}>
                  Sign in to join
                </Link>
              )}
            </>
          ) : (
            <>
              <p>
                {!configured
                  ? "Invitations aren’t available until GymTracker is configured."
                  : preview
                    ? (unavailableMessages[
                        preview.status as keyof typeof unavailableMessages
                      ] ?? "This invitation isn’t available right now.")
                    : "This invitation couldn’t be loaded. Please try again."}
              </p>
              <p className="muted">
                Ask the Circle owner for a new link if you still want to join.
              </p>
              <Link className="button secondary" href="/app/circles">
                Your Circles
              </Link>
            </>
          )}
        </section>
      </main>
    </div>
  );
}
