import Link from "next/link";
import { getTraining } from "@/data/training";
export default async function Routines() {
  const data = await getTraining();
  return (
    <>
      <header className="page-heading">
        <p className="eyebrow">YOUR GO-TO PLANS</p>
        <h1>Routines.</h1>
      </header>
      <Link className="button" href="/app/routines/new">
        ＋ Create routine
      </Link>
      {data.routines.map((r) => (
        <Link className="list-card" key={r.id} href={"/app/routines/" + r.id}>
          <span>
            <strong>{r.name}</strong>
            <small>
              {
                data.routineExercises.filter((e) => e.routine_id === r.id)
                  .length
              }{" "}
              exercises
            </small>
          </span>
          <span>Edit →</span>
        </Link>
      ))}
      {!data.routines.length && (
        <p className="empty">
          Build a routine once. Come back to it whenever you train.
        </p>
      )}
    </>
  );
}
