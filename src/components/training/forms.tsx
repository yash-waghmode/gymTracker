"use client";
import { useActionState, useState, type ReactNode } from "react";
import { useFormStatus } from "react-dom";
import type { ActionResult } from "@/app/(protected)/app/training-actions";
import {
  changeWorkout,
  saveRoutine,
} from "@/app/(protected)/app/training-actions";
type Action = (state: ActionResult, form: FormData) => Promise<ActionResult>;
function FormFields({ children }: { children: ReactNode }) {
  const { pending } = useFormStatus();
  return (
    <fieldset disabled={pending} aria-busy={pending}>
      {children}
      {pending && (
        <span className="saving" role="status">
          Saving…
        </span>
      )}
    </fieldset>
  );
}
export function ActionForm({
  action,
  children,
  className = "",
}: {
  action: Action;
  children: ReactNode;
  className?: string;
}) {
  const [state, submit] = useActionState(
    async (previous: ActionResult, data: FormData) => {
      try {
        return await action(previous, data);
      } catch (error) {
        if (
          error instanceof Error &&
          "digest" in error &&
          String(error.digest).startsWith("NEXT_REDIRECT")
        )
          throw error;
        return {
          error:
            "Save could not be confirmed. Check your connection and saved data before retrying.",
        };
      }
    },
    {},
  );
  return (
    <form action={submit} className={className}>
      <FormFields>{children}</FormFields>
      <div aria-live="polite">
        {state.error && (
          <p className="error-message" role="alert">
            {state.error}
          </p>
        )}
        {state.success && <p className="save-message">{state.success}</p>}
      </div>
    </form>
  );
}
export function ExerciseSelect({
  catalog,
  name = "target",
}: {
  catalog: { id: string; name: string }[];
  name?: string;
}) {
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState("");
  return (
    <div className="stack compact">
      <input
        aria-label="Search exercises"
        placeholder="Search exercises…"
        type="search"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      <select
        name={name}
        aria-label="Exercise"
        value={selected}
        onChange={(e) => setSelected(e.target.value)}
        required
      >
        <option value="">Choose an exercise</option>
        {catalog
          .filter(
            (e) =>
              e.id === selected ||
              e.name.toLowerCase().includes(search.toLowerCase()),
          )
          .map((e) => (
            <option key={e.id} value={e.id}>
              {e.name}
            </option>
          ))}
      </select>
    </div>
  );
}
export function RoutineEditor({
  catalog,
  id,
  initialName = "",
  initialExercises = [],
}: {
  catalog: { id: string; name: string }[];
  id?: string;
  initialName?: string;
  initialExercises?: string[];
}) {
  const [name, setName] = useState(initialName);
  const [exercises, setExercises] = useState(initialExercises);
  const [search, setSearch] = useState("");
  function move(index: number, direction: number) {
    const next = [...exercises];
    [next[index], next[index + direction]] = [
      next[index + direction],
      next[index],
    ];
    setExercises(next);
  }
  return (
    <ActionForm action={saveRoutine} className="stack">
      <input type="hidden" name="id" value={id ?? ""} />
      <label className="stack compact">
        Routine name
        <input
          name="name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          maxLength={120}
          placeholder="e.g. Upper body A"
          required
        />
      </label>
      <h2>Exercise order</h2>
      {exercises.length === 0 && (
        <p className="muted">
          Choose exercises below. You can also save an empty routine.
        </p>
      )}
      <ol className="exercise-order">
        {exercises.map((exercise, index) => (
          <li key={exercise + "-" + index}>
            <input type="hidden" name="exercise" value={exercise} />
            <span>
              <small>{String(index + 1).padStart(2, "0")}</small>{" "}
              {catalog.find((e) => e.id === exercise)?.name ?? "Exercise"}
            </span>
            <div className="row">
              <button
                className="icon-button secondary"
                type="button"
                onClick={() => move(index, -1)}
                disabled={index === 0}
                aria-label={"Move exercise " + (index + 1) + " up"}
              >
                ↑
              </button>
              <button
                className="icon-button secondary"
                type="button"
                onClick={() => move(index, 1)}
                disabled={index === exercises.length - 1}
                aria-label={"Move exercise " + (index + 1) + " down"}
              >
                ↓
              </button>
              <button
                className="icon-button secondary"
                type="button"
                onClick={() =>
                  setExercises(exercises.filter((_, i) => i !== index))
                }
                aria-label={"Remove exercise " + (index + 1)}
              >
                ×
              </button>
            </div>
          </li>
        ))}
      </ol>
      <label className="stack compact">
        Add exercises
        <input
          type="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search the catalog…"
        />
      </label>
      <div className="catalog-list">
        {catalog
          .filter((e) => e.name.toLowerCase().includes(search.toLowerCase()))
          .map((e) => (
            <button
              key={e.id}
              type="button"
              className="catalog-item secondary"
              disabled={exercises.length >= 50}
              onClick={() => setExercises([...exercises, e.id])}
            >
              <span>{e.name}</span>
              <span aria-hidden="true">＋</span>
            </button>
          ))}
      </div>
      <button type="submit">Save routine</button>
    </ActionForm>
  );
}
export function SetForm({
  workout,
  target,
  initialWeight = "",
  initialReps = "",
  edit = false,
}: {
  workout: string;
  target: string;
  initialWeight?: string;
  initialReps?: string;
  edit?: boolean;
}) {
  const [weight, setWeight] = useState(initialWeight);
  const [reps, setReps] = useState(initialReps);
  return (
    <ActionForm action={changeWorkout}>
      <input type="hidden" name="workout" value={workout} />
      <input type="hidden" name="target" value={target} />
      <input
        type="hidden"
        name="operation"
        value={edit ? "edit_set" : "add_set"}
      />
      <div className="set-entry">
        <label>
          kg
          <input
            aria-label={edit ? "Edit weight in kg" : "Weight in kg"}
            name="weight"
            type="number"
            inputMode="decimal"
            min="0"
            max="1500"
            step="0.001"
            placeholder="0"
            value={weight}
            onChange={(e) => setWeight(e.target.value)}
            required
          />
        </label>
        <label>
          reps
          <input
            aria-label={edit ? "Edit reps" : "Reps"}
            name="reps"
            type="number"
            inputMode="numeric"
            min="1"
            max="1000"
            step="1"
            placeholder="8"
            value={reps}
            onChange={(e) => setReps(e.target.value)}
            required
          />
        </label>
        <button type="submit">{edit ? "Save" : "Log set"}</button>
      </div>
    </ActionForm>
  );
}
