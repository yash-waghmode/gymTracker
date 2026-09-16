import Link from "next/link";

import {
  endSharedSessionAction,
  joinSharedSessionAction,
  startSharedSessionAction,
} from "@/app/(protected)/app/shared-session-actions";
import { ActionForm } from "@/components/training/forms";
import type {
  SharedSessionParticipant,
  SharedSessionPresence,
  SharedWorkoutChoices,
} from "@/data/shared-sessions";
import { sharedSessionAction } from "@/lib/shared-training";

type TrainingSession = SharedSessionPresence & {
  participants: SharedSessionParticipant[];
};

function RoutineChoice({
  routines,
}: {
  routines: SharedWorkoutChoices["routines"];
}) {
  return (
    <label className="stack compact">
      Your workout
      <select name="routine" defaultValue="">
        <option value="">Empty workout — add exercises as you go</option>
        {routines.map((routine) => (
          <option key={routine.id} value={routine.id}>
            {routine.name}
          </option>
        ))}
      </select>
    </label>
  );
}

export function SharedPartners({
  participants,
  userId,
}: {
  participants: SharedSessionParticipant[];
  userId: string;
}) {
  return (
    <ul className="shared-partners" aria-label="Training partners">
      {participants.map((participant) => (
        <li key={participant.userId}>
          <span className="shared-partner-name">
            {participant.userId === userId
              ? "You"
              : (participant.displayName ?? "Circle member")}
          </span>
          <span className="shared-partner-status">
            {participant.workoutFinished ? "Finished workout" : "Training"}
          </span>
        </li>
      ))}
    </ul>
  );
}

export function SharedTraining({
  circleId,
  userId,
  sessions,
  choices,
}: {
  circleId: string;
  userId: string;
  sessions: TrainingSession[];
  choices: SharedWorkoutChoices;
}) {
  return (
    <section
      className="card shared-training stack"
      aria-label="Work out together"
    >
      <div className="section-heading">
        <h2>Work out together</h2>
        {sessions.length > 0 && (
          <span className="training-live">Training now</span>
        )}
      </div>
      {sessions.length === 0 ? (
        choices.activeWorkout ? (
          <div className="stack compact">
            <p>Finish your current workout before starting one together.</p>
            <Link
              className="button secondary"
              href={`/app/workout/${choices.activeWorkout.id}`}
            >
              Resume your workout →
            </Link>
          </div>
        ) : (
          <ActionForm
            action={startSharedSessionAction}
            className="stack compact"
          >
            <input type="hidden" name="circle" value={circleId} />
            <RoutineChoice routines={choices.routines} />
            <button type="submit">Start workout together →</button>
            <p className="input-hint">
              Everyone logs their own workout. Your sets stay private.
            </p>
          </ActionForm>
        )
      ) : (
        <div className="stack">
          {sessions.map((session) => {
            const action = sharedSessionAction(
              session.sessionId,
              choices.sessionWorkouts,
              choices.activeWorkout?.id ?? null,
            );
            return (
              <div
                className="shared-session stack compact"
                key={session.sessionId}
              >
                <p className="shared-session-lead">
                  Started by{" "}
                  {session.createdBy === userId
                    ? "you"
                    : (session.creatorDisplayName ?? "a Circle member")}
                </p>
                <SharedPartners
                  participants={session.participants}
                  userId={userId}
                />
                {action.kind === "open" ? (
                  <div className="stack compact">
                    <Link
                      className="button"
                      href={`/app/workout/${action.workoutId}`}
                    >
                      {action.finished
                        ? "View your finished workout →"
                        : "Resume your workout →"}
                    </Link>
                    {action.finished && (
                      <p className="input-hint">
                        You’re done; others can keep training.
                      </p>
                    )}
                  </div>
                ) : action.kind === "resume-current" ? (
                  <div className="stack compact">
                    <p>Finish your current workout before joining.</p>
                    <Link
                      className="button secondary"
                      href={`/app/workout/${action.workoutId}`}
                    >
                      Resume your workout →
                    </Link>
                  </div>
                ) : (
                  <ActionForm
                    action={joinSharedSessionAction}
                    className="stack compact"
                  >
                    <input
                      type="hidden"
                      name="session"
                      value={session.sessionId}
                    />
                    <RoutineChoice routines={choices.routines} />
                    <button type="submit">Join workout →</button>
                  </ActionForm>
                )}
                {session.createdBy === userId && (
                  <details className="shared-close">
                    <summary>Close session</summary>
                    <p className="input-hint">
                      No one else can join. Everyone keeps their own workout and
                      can finish it later.
                    </p>
                    <ActionForm action={endSharedSessionAction}>
                      <input
                        type="hidden"
                        name="session"
                        value={session.sessionId}
                      />
                      <button className="secondary" type="submit">
                        Close session for everyone
                      </button>
                    </ActionForm>
                  </details>
                )}
              </div>
            );
          })}
          <p className="input-hint">
            Refresh to see the latest training status.
          </p>
        </div>
      )}
    </section>
  );
}
