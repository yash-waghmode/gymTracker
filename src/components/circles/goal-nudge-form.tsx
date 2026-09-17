"use client";

import { useActionState } from "react";

import { sendCircleGoalNudgeAction } from "@/app/(protected)/app/circle-actions";

export function GoalNudgeForm({
  circleId,
  goalId,
  recipientId,
  recipientName,
}: {
  circleId: string;
  goalId: string;
  recipientId: string;
  recipientName: string;
}) {
  const [state, submit, pending] = useActionState(
    sendCircleGoalNudgeAction,
    {},
  );
  const sent = Boolean(state.success);

  return (
    <form action={submit} className="goal-nudge-form">
      <input type="hidden" name="circle" value={circleId} />
      <input type="hidden" name="goal" value={goalId} />
      <input type="hidden" name="recipient" value={recipientId} />
      <button
        className="secondary goal-nudge-button"
        type="submit"
        disabled={pending || sent}
        aria-label={
          sent
            ? `Nudged ${recipientName} about the goal`
            : `Nudge ${recipientName} about the goal`
        }
      >
        {pending ? "Sending…" : sent ? "Nudged" : "Nudge"}
      </button>
      <span className="goal-nudge-feedback" role="status" aria-live="polite">
        {state.error ?? (sent ? `Nudge sent to ${recipientName}.` : "")}
      </span>
    </form>
  );
}
