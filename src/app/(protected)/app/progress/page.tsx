import Link from "next/link";
import { getTraining } from "@/data/training";
import { exerciseHistory } from "@/lib/training-history";
import { bestSet } from "@/lib/training";
export default async function Progress() {
  const data = await getTraining();
  const exercises = data.catalog
    .map((e) => ({ ...e, history: exerciseHistory(data, e.id) }))
    .filter((e) => e.history.length);
  return (
    <>
      <header className="page-heading">
        <p className="eyebrow">PROOF OF THE WORK</p>
        <h1>Your progress.</h1>
        <p>
          Records from completed workouts. Heaviest weight wins; more reps at
          that weight breaks a tie.
        </p>
      </header>
      {exercises.map((e) => {
        const best = bestSet(e.history.flatMap((h) => h.sets));
        return (
          <Link key={e.id} className="list-card" href={"/app/progress/" + e.id}>
            <span>
              <strong>{e.name}</strong>
              <small>{e.history.length} workouts</small>
            </span>
            <span className="record-value">
              {best ? best.weight_kg + " kg × " + best.reps : "—"} ↗
            </span>
          </Link>
        );
      })}
      {!exercises.length && (
        <div className="empty">
          <h2>Set your starting mark.</h2>
          <p>
            Finish a workout to see exercise history and personal records here.
          </p>
          <Link href="/app/workout">Start training →</Link>
        </div>
      )}
    </>
  );
}
