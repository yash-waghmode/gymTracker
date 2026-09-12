export type Performance = { weight_kg: number | null; reps: number };

export function parseId(value: unknown): string {
  if (
    typeof value !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    )
  )
    throw new Error("Choose a valid item.");
  return value;
}

export function parseName(value: unknown): string {
  if (typeof value !== "string" || !value.trim() || value.trim().length > 120)
    throw new Error("Use a name between 1 and 120 characters.");
  return value.trim();
}

export function parseSet(
  weight: unknown,
  reps: unknown,
): { weight: number; reps: number } {
  if (
    typeof weight !== "string" ||
    !/^\d+(\.\d{1,3})?$/.test(weight.trim()) ||
    typeof reps !== "string" ||
    !/^\d+$/.test(reps.trim())
  )
    throw new Error("Enter weight in kg and whole-number reps.");
  const w = Number(weight),
    r = Number(reps);
  if (!Number.isFinite(w) || w < 0 || w > 1500 || r < 1 || r > 1000)
    throw new Error("Use 0–1500 kg and 1–1000 reps.");
  return { weight: w, reps: r };
}

// A record is the heaviest successful set; more reps at that weight wins ties.
// Zero kg represents bodyweight/unloaded movements; their records compare reps.
export function bestSet(sets: Performance[]): Performance | null {
  return sets
    .filter(
      (s) =>
        s.reps > 0 &&
        s.weight_kg !== null &&
        Number.isFinite(s.weight_kg) &&
        s.weight_kg >= 0,
    )
    .reduce<Performance | null>((best, set) => {
      if (
        !best ||
        set.weight_kg! > best.weight_kg! ||
        (set.weight_kg === best.weight_kg && set.reps > best.reps)
      )
        return set;
      return best;
    }, null);
}

export function beats(
  candidate: Performance | null,
  previous: Performance | null,
): boolean {
  if (!candidate) return false;
  return (
    !previous ||
    candidate.weight_kg! > previous.weight_kg! ||
    (candidate.weight_kg === previous.weight_kg &&
      candidate.reps > previous.reps)
  );
}

export function workoutStats(
  sets: Performance[],
  start: string,
  end: string | null,
) {
  return {
    sets: sets.length,
    reps: sets.reduce((sum, s) => sum + s.reps, 0),
    minutes: end
      ? Math.max(0, Math.round((Date.parse(end) - Date.parse(start)) / 60000))
      : null,
  };
}

export function weekCount(
  dates: string[],
  now: Date,
  timeZone: string,
): number {
  const parts = (date: Date) => {
    const p = new Intl.DateTimeFormat("en-CA", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(date);
    return Date.UTC(
      Number(p.find((x) => x.type === "year")!.value),
      Number(p.find((x) => x.type === "month")!.value) - 1,
      Number(p.find((x) => x.type === "day")!.value),
    );
  };
  const today = parts(now);
  const monday = today - ((new Date(today).getUTCDay() + 6) % 7) * 86400000;
  return dates.filter((d) => {
    const date = parts(new Date(d));
    return date >= monday && date <= today && Date.parse(d) <= now.getTime();
  }).length;
}
