import Link from "next/link";
import { notFound } from "next/navigation";
import { getTraining } from "@/data/training";
import { bestSet, beats } from "@/lib/training";
import { exerciseHistory } from "@/lib/training-history";
import { LocalDate } from "@/components/training/date";
export default async function ExerciseProgress({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const data = await getTraining();
  const exercise = data.catalog.find((e) => e.id === id);
  if (!exercise) notFound();
  const history = exerciseHistory(data, id);
  const record = bestSet(history.flatMap((h) => h.sets));
  return (
    <>
      <header className="page-heading">
        <Link className="text-link" href="/app/progress">
          ← All progress
        </Link>
        <h1>{exercise.name}</h1>
      </header>
      {record && (
        <section className="start-card">
          <p className="eyebrow">PERSONAL RECORD</p>
          <h2>
            {record.weight_kg} <small>kg ×</small> {record.reps}{" "}
            <small>reps</small>
          </h2>
          <p>
            Heaviest completed set. Reps break ties at the same weight. At 0 kg,
            reps are your record.
          </p>
        </section>
      )}
      <h2>Performance over time</h2>
      {history.length ? (
        [...history].reverse().map((h) => {
          const index = history.indexOf(h);
          const pr = beats(
            h.best,
            bestSet(history.slice(0, index).flatMap((x) => x.sets)),
          );
          return (
            <section className="card stack compact" key={h.workout.id}>
              <div className="section-heading">
                <Link href={"/app/workout/" + h.workout.id}>
                  <LocalDate value={h.workout.completed_at!} />
                </Link>
                {pr && <span className="record-label">↗ New record</span>}
              </div>
              <h3>{h.workout.title}</h3>
              <div className="performance-sets">
                {h.sets.map((s) => (
                  <span key={s.id}>
                    {s.weight_kg ?? 0} kg × {s.reps}
                  </span>
                ))}
              </div>
            </section>
          );
        })
      ) : (
        <div className="empty">
          <p>No completed sets for this exercise yet.</p>
          <Link href="/app/workout">Start a workout →</Link>
        </div>
      )}
    </>
  );
}
