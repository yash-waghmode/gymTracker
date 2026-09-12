import { notFound } from "next/navigation";
import { getTraining } from "@/data/training";
import { ActionForm, RoutineEditor } from "@/components/training/forms";
import { deleteRoutine } from "../../training-actions";
export default async function EditRoutine({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const data = await getTraining();
  const routine = data.routines.find((r) => r.id === id);
  if (!routine) notFound();
  return (
    <>
      <header className="page-heading">
        <h1>Edit routine.</h1>
      </header>
      <RoutineEditor
        id={id}
        catalog={data.catalog}
        initialName={routine.name}
        initialExercises={data.routineExercises
          .filter((e) => e.routine_id === id)
          .sort((a, b) => a.position - b.position)
          .map((e) => e.exercise_id)}
      />
      <details className="card">
        <summary>Delete routine</summary>
        <p>This removes the plan. Past workouts are kept.</p>
        <ActionForm action={deleteRoutine}>
          <input type="hidden" name="id" value={id} />
          <button className="danger">Delete this routine</button>
        </ActionForm>
      </details>
    </>
  );
}
