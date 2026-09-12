import Link from "next/link";
import { getTraining } from "@/data/training";
import { HistoryList } from "@/components/training/history";
export default async function History() {
  const data = await getTraining();
  const completed = data.workouts
    .filter((w) => w.completed_at)
    .sort((a, b) => b.completed_at!.localeCompare(a.completed_at!));
  return (
    <>
      <header className="page-heading">
        <p className="eyebrow">THE WORK YOU PUT IN</p>
        <h1>Training history.</h1>
      </header>
      {completed.length ? (
        <HistoryList workouts={completed} />
      ) : (
        <div className="empty">
          <p>No finished workouts yet.</p>
          <Link href="/app/workout">Start a workout →</Link>
        </div>
      )}
    </>
  );
}
