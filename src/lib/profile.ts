export function parseDisplayName(value: unknown): string {
  if (typeof value !== "string")
    throw new Error("Use a display name between 1 and 80 characters.");

  const name = value.trim();
  if (!name || name.length > 80)
    throw new Error("Use a display name between 1 and 80 characters.");
  return name;
}
