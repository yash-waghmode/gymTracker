import type { CircleGoalProgress } from "@/data/circle-goals";
import type { CircleMemberIdentity } from "@/data/circles";

export function orderedGoalParticipants(
  participants: CircleGoalProgress["participants"],
  members: CircleMemberIdentity[],
) {
  const memberOrder = new Map(
    members.map((member, index) => [member.user_id, index]),
  );
  return [...participants].sort(
    (a, b) =>
      (memberOrder.get(a.userId) ?? Infinity) -
      (memberOrder.get(b.userId) ?? Infinity),
  );
}

export function goalTimeRemaining(endsAt: string, now: Date): string {
  const milliseconds = new Date(endsAt).getTime() - now.getTime();
  if (milliseconds <= 0) return "Goal ended";
  const hours = Math.ceil(milliseconds / 3_600_000);
  if (hours < 24) return `${hours} ${hours === 1 ? "hour" : "hours"} left`;
  const days = Math.ceil(milliseconds / 86_400_000);
  return `${days} ${days === 1 ? "day" : "days"} left`;
}
