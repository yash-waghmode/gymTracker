export function isInviteToken(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{64}$/.test(value);
}

export function inviteReturnPath(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const match = /^\/invite\/([0-9a-f]{64})$/.exec(value);
  return match ? value : null;
}
