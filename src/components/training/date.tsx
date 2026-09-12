"use client";
import { useSyncExternalStore } from "react";
import { weekCount } from "@/lib/training";
const subscribe = () => () => {};
export function LocalDate({ value }: { value: string }) {
  const text = useSyncExternalStore(
    subscribe,
    () =>
      new Intl.DateTimeFormat(undefined, {
        month: "short",
        day: "numeric",
        year: "numeric",
        hour: "numeric",
        minute: "2-digit",
      }).format(new Date(value)),
    () => new Date(value).toISOString().slice(0, 10),
  );
  return <time dateTime={value}>{text}</time>;
}
export function WeeklyCount({ dates }: { dates: string[] }) {
  const count = useSyncExternalStore(
    subscribe,
    () =>
      weekCount(
        dates,
        new Date(),
        Intl.DateTimeFormat().resolvedOptions().timeZone,
      ),
    () => null,
  );
  return (
    <>
      <strong>{count ?? "—"}</strong>
      <span>
        workouts this week <small>Mon–Sun</small>
      </span>
    </>
  );
}
