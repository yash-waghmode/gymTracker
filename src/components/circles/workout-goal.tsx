import {
  cancelCircleGoalAction,
  createCircleGoalAction,
} from "@/app/(protected)/app/circle-actions";
import { ActionForm } from "@/components/training/forms";
import type { CircleGoalProgress } from "@/data/circle-goals";
import type { CircleMemberIdentity } from "@/data/circles";
import { goalTimeRemaining, orderedGoalParticipants } from "@/lib/circle-goal";

export function CircleWorkoutGoal({
  circleId,
  currentUserId,
  isOwner,
  members,
  progress,
}: {
  circleId: string;
  currentUserId: string;
  isOwner: boolean;
  members: CircleMemberIdentity[];
  progress: CircleGoalProgress | null;
}) {
  if (!progress) {
    return (
      <section
        className="card circle-goal stack compact"
        aria-labelledby="goal-title"
      >
        <div className="section-heading">
          <h2 id="goal-title">Workout goal</h2>
        </div>
        {members.length === 1 ? (
          <p className="muted">
            Invite a training partner to work toward a goal together.
            {isOwner && (
              <>
                {" "}
                <a href="#circle-invites">Invite someone →</a>
              </>
            )}
          </p>
        ) : isOwner ? (
          <ActionForm action={createCircleGoalAction} className="stack compact">
            <input type="hidden" name="circle" value={circleId} />
            <label className="stack compact">
              Workouts each in the next 7 days
              <select name="target" defaultValue="3" required>
                {Array.from({ length: 7 }, (_, index) => index + 1).map(
                  (target) => (
                    <option key={target} value={target}>
                      {target} {target === 1 ? "workout" : "workouts"}
                    </option>
                  ),
                )}
              </select>
            </label>
            <button type="submit">Start goal for everyone</button>
          </ActionForm>
        ) : (
          <p className="muted">No group goal right now.</p>
        )}
      </section>
    );
  }

  const participants = orderedGoalParticipants(progress.participants, members);
  const currentUserIncluded = participants.some(
    (participant) => participant.userId === currentUserId,
  );
  const completedCount = participants.filter(
    (participant) => participant.completedWorkouts >= progress.targetWorkouts,
  ).length;
  const endsAt = new Date(progress.endsAt);
  const endLabel = new Intl.DateTimeFormat("en", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZone: "UTC",
    timeZoneName: "short",
  }).format(endsAt);

  return (
    <section className="card circle-goal stack" aria-labelledby="goal-title">
      <div className="section-heading">
        <h2 id="goal-title">Workout goal</h2>
        <span className="goal-window">7 days together</span>
      </div>
      <div className="goal-summary">
        <strong>
          {progress.targetWorkouts}{" "}
          {progress.targetWorkouts === 1 ? "workout" : "workouts"} each
        </strong>
        <p>
          <time dateTime={progress.endsAt}>Ends {endLabel}</time>
          <span aria-hidden="true"> · </span>
          {goalTimeRemaining(progress.endsAt, new Date())}
        </p>
      </div>
      <p
        className={
          progress.groupComplete ? "goal-group-done" : "goal-group-active"
        }
      >
        {progress.groupComplete
          ? "Everyone reached the goal. Nice work together!"
          : `${completedCount} of ${participants.length} finished — keep going together.`}
      </p>
      <ul className="goal-participants" aria-label="Goal progress by member">
        {participants.map((participant) => {
          const complete =
            participant.completedWorkouts >= progress.targetWorkouts;
          const name =
            participant.displayName ??
            (participant.userId === currentUserId ? "You" : "Circle member");
          return (
            <li key={participant.userId}>
              <div className="goal-participant-line">
                <span>
                  <strong>{name}</strong>
                  {participant.userId === currentUserId &&
                    participant.displayName && (
                      <span className="goal-you"> (you)</span>
                    )}
                </span>
                <span className="goal-count">
                  {participant.completedWorkouts} / {progress.targetWorkouts}
                  <span
                    className={complete ? "goal-complete" : "goal-in-progress"}
                  >
                    {complete ? " ✓ Done" : " · In progress"}
                  </span>
                </span>
              </div>
              <progress
                max={progress.targetWorkouts}
                value={Math.min(
                  participant.completedWorkouts,
                  progress.targetWorkouts,
                )}
                aria-label={`${name}: ${participant.completedWorkouts} of ${progress.targetWorkouts} workouts`}
              />
            </li>
          );
        })}
      </ul>
      {!currentUserIncluded && (
        <p className="input-hint">
          You joined after this goal began. You’ll be included in the next one.
        </p>
      )}
      <div className="goal-footer">
        <a className="text-link" href={`/app/circles/${circleId}`}>
          Refresh progress
        </a>
        {isOwner && (
          <details className="goal-cancel">
            <summary>End goal</summary>
            <p className="input-hint">
              This ends the shared goal, not anyone’s workouts.
            </p>
            <ActionForm
              action={cancelCircleGoalAction}
              className="stack compact"
            >
              <input type="hidden" name="circle" value={circleId} />
              <input type="hidden" name="goal" value={progress.goalId} />
              <label className="confirm-choice">
                <input type="checkbox" name="confirm" value="cancel" required />
                End this goal for everyone
              </label>
              <button className="secondary" type="submit">
                End goal
              </button>
            </ActionForm>
          </details>
        )}
      </div>
    </section>
  );
}
