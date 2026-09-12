import Link from "next/link";
import { getTraining } from "@/data/training";
import { ActionForm } from "@/components/training/forms";
import { WeeklyCount } from "@/components/training/date";
import { HistoryList } from "@/components/training/history";
import { startWorkout } from "./training-actions";
export default async function Home() {
  const data = await getTraining();
  const active = data.workouts.find((w) => !w.completed_at);
  const completed = data.workouts
    .filter((w) => w.completed_at)
    .sort((a, b) => b.completed_at!.localeCompare(a.completed_at!));
  return (
    <>
      <header className="page-heading">
        <p className="eyebrow">YOUR TRAINING, YOUR PACE</p>
        <h1>Let’s get to work.</h1>
      </header>
      <section className="start-card">
        <p className="eyebrow">
          {active ? "WORKOUT IN PROGRESS" : "READY WHEN YOU ARE"}
        </p>
        <h2>{active ? active.title : "A little stronger today."}</h2>
        {active ? (
          <Link className="button" href={"/app/workout/" + active.id}>
            Resume workout →
          </Link>
        ) : (
          <ActionForm action={startWorkout}>
            <button>Start free workout →</button>
          </ActionForm>
        )}
        <Link href="/app/workout" className="text-link">
          Or choose a routine
        </Link>
      </section>
      <div className="stat-strip">
        <WeeklyCount dates={completed.map((w) => w.completed_at!)} />
      </div>
      <section className="stack">
        <div className="section-heading">
          <h2>Your routines</h2>
          <Link href="/app/routines">Manage →</Link>
        </div>
        {data.routines.length ? (
          <div className="routine-grid">
            {data.routines.slice(0, 4).map((r) => (
              <div className="card stack compact" key={r.id}>
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
                  <button className="secondary">
                    {active ? "Resume workout" : "Start routine"}
                  </button>
                </ActionForm>
              </div>
            ))}
          </div>
        ) : (
          <div className="empty">
            <h3>Your next workout, already planned.</h3>
            <p>Save the exercises you like to train together.</p>
            <Link className="button secondary" href="/app/routines/new">
              Create a routine
            </Link>
          </div>
        )}
      </section>
      <section className="stack">
        <div className="section-heading">
          <h2>Recent training</h2>
          <Link href="/app/history">History →</Link>
        </div>
        {completed.length ? (
          <HistoryList workouts={completed.slice(0, 3)} />
        ) : (
          <p className="empty">
            Your first finished workout will appear here. Every set counts.
          </p>
        )}
      </section>
    </>
  );
}
