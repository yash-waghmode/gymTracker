import Link from "next/link";
import { getTraining } from "@/data/training";
import { ActionForm } from "@/components/training/forms";
import { startWorkout } from "../training-actions";
export default async function Workout() {
  const data = await getTraining();
  const active = data.workouts.filter((w) => !w.completed_at);
  return (
    <>
      <header className="page-heading">
        <p className="eyebrow">MAKE IT HAPPEN</p>
        <h1>Your workout.</h1>
        <p>Pick a plan or follow your own lead.</p>
      </header>
      {active.length > 0 ? (
        <section className="start-card stack">
          <h2>Keep going</h2>
          {active.map((w) => (
            <Link key={w.id} className="button" href={"/app/workout/" + w.id}>
              Resume {w.title} →
            </Link>
          ))}
          <p>Finish your current workout before starting another.</p>
        </section>
      ) : (
        <>
          <ActionForm action={startWorkout} className="start-card">
            <h2>Start from scratch</h2>
            <p>Add exercises as you go.</p>
            <button>Start free workout →</button>
          </ActionForm>
          <div className="section-heading">
            <h2>Start from a routine</h2>
            <Link href="/app/routines">Manage →</Link>
          </div>
          {data.routines.map((r) => (
            <section className="card stack compact" key={r.id}>
              <h3>{r.name}</h3>
              <p className="muted">
                {
                  data.routineExercises.filter((e) => e.routine_id === r.id)
                    .length
                }{" "}
                exercises
              </p>
              <ActionForm action={startWorkout}>
                <input type="hidden" name="routine" value={r.id} />
                <button>Start routine</button>
              </ActionForm>
            </section>
          ))}
          {!data.routines.length && (
            <div className="empty">
              <p>No routines yet.</p>
              <Link href="/app/routines/new">Build your first routine →</Link>
            </div>
          )}
        </>
      )}
      <Link className="text-link" href="/app/history">
        View workout history →
      </Link>
    </>
  );
}
