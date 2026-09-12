import Link from "next/link";
import { notFound } from "next/navigation";
import { getTraining } from "@/data/training";
import {
  ActionForm,
  ExerciseSelect,
  SetForm,
} from "@/components/training/forms";
import { LocalDate } from "@/components/training/date";
import { workoutStats } from "@/lib/training";
import { exerciseHistory, recordsForWorkout } from "@/lib/training-history";
import { changeWorkout } from "../../training-actions";
export default async function WorkoutDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const data = await getTraining();
  const workout = data.workouts.find((w) => w.id === id);
  if (!workout) notFound();
  const exercises = data.workoutExercises
    .filter((e) => e.workout_id === id)
    .sort((a, b) => a.position - b.position);
  const allSets = data.sets.filter((s) =>
    exercises.some((e) => e.id === s.workout_exercise_id),
  );
  const stats = workoutStats(allSets, workout.started_at, workout.completed_at);
  const records = workout.completed_at ? recordsForWorkout(data, id) : [];
  return (
    <>
      <header className="page-heading">
        <p className="eyebrow">
          {workout.completed_at
            ? "WORKOUT COMPLETE. NICE WORK."
            : "IN PROGRESS"}
        </p>
        <h1>{workout.title}</h1>
        <p>
          <LocalDate value={workout.started_at} />
        </p>
      </header>
      <div className="summary-grid">
        <div>
          <strong>{stats.sets}</strong>
          <span>sets logged</span>
        </div>
        <div>
          <strong>{stats.reps}</strong>
          <span>total reps</span>
        </div>
        {stats.minutes !== null && (
          <div>
            <strong>{stats.minutes}</strong>
            <span>minutes</span>
          </div>
        )}
      </div>
      {records.length > 0 && (
        <div className="record-banner">
          ↗ {records.length} exercise record{records.length > 1 ? "s" : ""}. A
          new mark to build on.
        </div>
      )}
      {!exercises.length && (
        <div className="empty">
          <h2>Your first set starts here.</h2>
          <p>Add an exercise below to begin.</p>
        </div>
      )}
      {exercises.map((exercise, index) => {
        const sets = data.sets
          .filter((s) => s.workout_exercise_id === exercise.id)
          .sort((a, b) => a.position - b.position);
        const previous = exerciseHistory(data, exercise.exercise_id)
          .filter(
            (h) =>
              h.workout.id !== id &&
              h.workout.completed_at! <= workout.started_at,
          )
          .at(-1);
        const last = sets.at(-1) ?? previous?.sets.at(-1);
        return (
          <section className="card exercise-card" key={exercise.id}>
            <div className="exercise-heading">
              <span className="exercise-number">
                {String(index + 1).padStart(2, "0")}
              </span>
              <div>
                <h2>
                  {data.catalog.find((e) => e.id === exercise.exercise_id)
                    ?.name ?? "Exercise"}
                </h2>
                {records.includes(exercise.exercise_id) && (
                  <span className="record-label">↗ Personal record</span>
                )}
              </div>
              <Link
                href={"/app/progress/" + exercise.exercise_id}
                aria-label="View exercise progress"
              >
                ↗
              </Link>
            </div>
            {!workout.completed_at && (
              <div className="previous">
                <strong>Last time</strong>
                {previous ? (
                  <>
                    <LocalDate value={previous.workout.completed_at!} />
                    <p>
                      {previous.sets
                        .map((s) => (s.weight_kg ?? 0) + " kg × " + s.reps)
                        .join(" · ")}
                    </p>
                  </>
                ) : (
                  <p>No previous sets. Make your starting mark.</p>
                )}
              </div>
            )}
            <div className="logged-sets">
              {sets.map((set, i) =>
                workout.completed_at ? (
                  <div className="set-line" key={set.id}>
                    <span>Set {i + 1}</span>
                    <strong>
                      {set.weight_kg ?? 0} kg × {set.reps}
                    </strong>
                    <span className="saved-tick">✓</span>
                  </div>
                ) : (
                  <details key={set.id} className="saved-set">
                    <summary>
                      <span>Set {i + 1}</span>
                      <strong>
                        {set.weight_kg ?? 0} kg × {set.reps}
                      </strong>
                      <span className="edit-label">Edit</span>
                    </summary>
                    <SetForm
                      workout={id}
                      target={set.id}
                      initialWeight={String(set.weight_kg ?? 0)}
                      initialReps={String(set.reps)}
                      edit
                    />
                    <ActionForm action={changeWorkout}>
                      <input type="hidden" name="workout" value={id} />
                      <input type="hidden" name="target" value={set.id} />
                      <input
                        type="hidden"
                        name="operation"
                        value="delete_set"
                      />
                      <button className="text-button danger">Remove set</button>
                    </ActionForm>
                  </details>
                ),
              )}
            </div>
            {!workout.completed_at && (
              <>
                <SetForm
                  workout={id}
                  target={exercise.id}
                  initialWeight={last ? String(last.weight_kg ?? 0) : ""}
                  initialReps={last ? String(last.reps) : ""}
                />
                <p className="input-hint">
                  Use 0 kg for bodyweight. Each logged set is saved.
                </p>
              </>
            )}
            {workout.completed_at && !sets.length && (
              <p className="muted">No sets logged.</p>
            )}
          </section>
        );
      })}
      {!workout.completed_at ? (
        <>
          <details className="card add-exercise" open={exercises.length === 0}>
            <summary>＋ Add exercise</summary>
            <ActionForm action={changeWorkout}>
              <input type="hidden" name="workout" value={id} />
              <input type="hidden" name="operation" value="add_exercise" />
              <ExerciseSelect catalog={data.catalog} />
              <button>Add to workout</button>
            </ActionForm>
          </details>
          <section className="finish-bar">
            <ActionForm action={changeWorkout}>
              <input type="hidden" name="workout" value={id} />
              <input type="hidden" name="operation" value="finish" />
              <button disabled={allSets.length === 0}>Finish workout ✓</button>
            </ActionForm>
            <p className="input-hint">
              {allSets.length
                ? "Finish when all your sets are saved. Your workout becomes read-only."
                : "Log at least one set to finish."}
            </p>
          </section>
        </>
      ) : (
        <div className="row wrap">
          <Link className="button" href="/app/workout">
            Next workout →
          </Link>
          <Link className="button secondary" href="/app/history">
            View history
          </Link>
        </div>
      )}
    </>
  );
}
