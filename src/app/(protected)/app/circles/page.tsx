import Link from "next/link";

import { getCurrentUser } from "@/data/auth";
import { getMyCircles } from "@/data/circles";

export default async function Circles() {
  const [circles, user] = await Promise.all([getMyCircles(), getCurrentUser()]);

  return (
    <>
      <header className="page-heading">
        <p className="eyebrow">YOUR PRIVATE GROUPS</p>
        <h1>Your Circles.</h1>
        <p>Keep each training group separate and easy to find.</p>
      </header>

      <Link className="button" href="/app/circles/new">
        ＋ Create Circle
      </Link>

      {circles.length ? (
        <div className="stack compact" aria-label="Your Circles">
          {circles.map((circle) => (
            <Link
              className="list-card circle-card"
              key={circle.id}
              href={`/app/circles/${circle.id}`}
            >
              <span className="circle-card-main">
                <span className="circle-mark" aria-hidden="true">
                  ○
                </span>
                <span>
                  <strong>{circle.name}</strong>
                  <small>
                    {circle.owner_id === user?.id
                      ? "You own this Circle"
                      : "You’re a member"}
                  </small>
                </span>
              </span>
              <span aria-hidden="true">→</span>
            </Link>
          ))}
        </div>
      ) : (
        <section className="empty">
          <h2>No Circles yet.</h2>
          <p>
            Create one when you’re ready to set up a private training group.
          </p>
          <Link className="button secondary" href="/app/circles/new">
            Create your first Circle
          </Link>
        </section>
      )}
    </>
  );
}
