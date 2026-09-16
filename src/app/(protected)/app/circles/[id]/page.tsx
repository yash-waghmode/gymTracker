import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { ActionForm } from "@/components/training/forms";
import { InviteManager } from "@/components/circles/invite-manager";
import { getCurrentUser } from "@/data/auth";
import {
  getCircle,
  getCircleActiveInvites,
  getCircleMembers,
} from "@/data/circles";
import { parseId } from "@/lib/training";

import { deleteCircleAction, leaveCircleAction } from "../../circle-actions";

export default async function CircleDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  let circleId: string;
  try {
    circleId = parseId(id);
  } catch {
    notFound();
  }

  const [circle, members, user] = await Promise.all([
    getCircle(circleId),
    getCircleMembers(circleId),
    getCurrentUser(),
  ]);

  if (!circle) notFound();
  if (!user) redirect("/auth?notice=signin-required");

  const isOwner = circle.owner_id === user.id;
  const activeInvites = isOwner ? await getCircleActiveInvites(circleId) : [];

  return (
    <>
      <Link className="text-link back-link" href="/app/circles">
        ← All Circles
      </Link>

      <header className="page-heading circle-heading">
        <span className="circle-mark circle-mark-large" aria-hidden="true">
          ○
        </span>
        <p className="eyebrow">PRIVATE CIRCLE</p>
        <h1>{circle.name}</h1>
        <p>
          {members.length} {members.length === 1 ? "member" : "members"}
        </p>
      </header>

      <section className="card stack">
        <div className="section-heading">
          <h2>Members</h2>
          <span className="member-count">{members.length}</span>
        </div>
        <ul className="member-list">
          {members.map((member) => {
            const isCurrentUser = member.user_id === user.id;
            const isCircleOwner = member.user_id === circle.owner_id;
            const memberName =
              member.display_name ?? (isCurrentUser ? "You" : "Name not set");
            const memberInitial =
              Array.from(memberName.trim())[0]?.toLocaleUpperCase() ?? "•";
            return (
              <li key={member.user_id}>
                <span className="member-mark" aria-hidden="true">
                  {memberInitial}
                </span>
                <span className="member-name">
                  <strong>{memberName}</strong>
                  <small>
                    {isCurrentUser ? "You · Current member" : "Current member"}
                  </small>
                </span>
                {isCircleOwner && <span className="owner-badge">Owner</span>}
              </li>
            );
          })}
        </ul>
      </section>

      {isOwner && (
        <InviteManager circleId={circle.id} activeInvites={activeInvites} />
      )}

      {isOwner ? (
        <details className="card circle-lifecycle">
          <summary>Delete Circle</summary>
          <div className="stack compact">
            <p>
              This removes the Circle and its memberships. Everyone’s personal
              workout history stays private and intact.
            </p>
            <ActionForm action={deleteCircleAction} className="stack compact">
              <input type="hidden" name="circle" value={circle.id} />
              <label className="confirm-choice">
                <input type="checkbox" name="confirm" value="delete" required />
                I understand this Circle cannot be recovered.
              </label>
              <button className="danger" type="submit">
                Delete Circle
              </button>
            </ActionForm>
          </div>
        </details>
      ) : (
        <details className="card circle-lifecycle">
          <summary>Leave Circle</summary>
          <div className="stack compact">
            <p>
              You’ll lose access to this Circle. Your personal workout history
              stays with you.
            </p>
            <ActionForm action={leaveCircleAction}>
              <input type="hidden" name="circle" value={circle.id} />
              <button className="secondary" type="submit">
                Leave Circle
              </button>
            </ActionForm>
          </div>
        </details>
      )}
    </>
  );
}
