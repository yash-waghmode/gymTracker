"use client";

import { useActionState, useState } from "react";

import {
  createCircleInviteAction,
  revokeCircleInviteAction,
} from "@/app/(protected)/app/circle-actions";
import { ActionForm } from "@/components/training/forms";
import type { ActiveCircleInvite } from "@/data/circles";

export function InviteManager({
  circleId,
  activeInvites,
}: {
  circleId: string;
  activeInvites: ActiveCircleInvite[];
}) {
  const [state, create, pending] = useActionState(createCircleInviteAction, {});
  const [copyMessage, setCopyMessage] = useState<{
    inviteId: string;
    message: string;
  } | null>(null);

  const credential = state.credential;
  const origin = typeof window === "undefined" ? "" : window.location.origin;
  const shareable =
    credential &&
    activeInvites.some((invite) => invite.inviteId === credential.inviteId);
  const inviteUrl =
    shareable && origin ? `${origin}/invite/${credential.token}` : "";

  async function copyInvite() {
    if (!inviteUrl || !credential) return;
    try {
      await navigator.clipboard.writeText(inviteUrl);
      setCopyMessage({
        inviteId: credential.inviteId,
        message: "Invite link copied.",
      });
    } catch {
      setCopyMessage({
        inviteId: credential.inviteId,
        message: "Select the link to copy it.",
      });
    }
  }

  return (
    <section className="card stack compact" aria-labelledby="invite-title">
      <div className="section-heading">
        <h2 id="invite-title">Invite someone</h2>
      </div>
      <p className="muted">Each link works once and expires after 7 days.</p>

      <form action={create}>
        <input type="hidden" name="circle" value={circleId} />
        <button type="submit" disabled={pending}>
          {pending ? "Creating…" : "Create invite link"}
        </button>
      </form>
      <div aria-live="polite">
        {state.error && (
          <p className="error-message" role="alert">
            {state.error}
          </p>
        )}
      </div>

      {inviteUrl && (
        <div className="stack compact invite-share">
          <label htmlFor="circle-invite-url">Invite link</label>
          <input
            id="circle-invite-url"
            type="text"
            readOnly
            value={inviteUrl}
            onFocus={(event) => event.currentTarget.select()}
          />
          <button className="secondary" type="button" onClick={copyInvite}>
            Copy link
          </button>
          <p className="input-hint">
            Share this link directly. It can’t be shown again after you leave
            this page.
          </p>
          <p className="save-message" role="status" aria-live="polite">
            {copyMessage?.inviteId === credential?.inviteId
              ? copyMessage?.message
              : ""}
          </p>
        </div>
      )}

      {activeInvites.length > 0 && (
        <div className="stack compact">
          <h3>Unused invites</h3>
          <p className="input-hint">
            Existing links can be revoked, but their link text can’t be
            recovered.
          </p>
          <ul className="invite-list">
            {activeInvites.map((invite) => (
              <li key={invite.inviteId}>
                <span>
                  Expires{" "}
                  <time dateTime={invite.expiresAt}>
                    {new Intl.DateTimeFormat("en", {
                      month: "short",
                      day: "numeric",
                      timeZone: "UTC",
                    }).format(new Date(invite.expiresAt))}
                  </time>
                </span>
                <ActionForm action={revokeCircleInviteAction}>
                  <input type="hidden" name="circle" value={circleId} />
                  <input type="hidden" name="invite" value={invite.inviteId} />
                  <button className="text-button danger" type="submit">
                    Revoke
                  </button>
                </ActionForm>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
