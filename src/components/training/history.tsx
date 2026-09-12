import Link from "next/link";
import { LocalDate } from "./date";
import type { TrainingData } from "@/data/training";
export function HistoryList({
  workouts,
}: {
  workouts: TrainingData["workouts"];
}) {
  return (
    <div className="stack compact">
      {workouts.map((w) => (
        <Link className="list-card" href={"/app/workout/" + w.id} key={w.id}>
          <span>
            <strong>{w.title}</strong>
            <small>
              <LocalDate value={w.completed_at ?? w.started_at} />
            </small>
          </span>
          <span aria-hidden="true">↗</span>
        </Link>
      ))}
    </div>
  );
}
