import { ActionForm } from "@/components/training/forms";

import { createCircleAction } from "../../circle-actions";

export default function NewCircle() {
  return (
    <>
      <header className="page-heading">
        <p className="eyebrow">START A PRIVATE GROUP</p>
        <h1>Name your Circle.</h1>
        <p>You’ll be its owner and first member.</p>
      </header>

      <ActionForm action={createCircleAction} className="card stack">
        <label className="stack compact">
          Circle name
          <input
            name="name"
            maxLength={120}
            placeholder="e.g. Saturday crew"
            autoComplete="off"
            autoFocus
            required
          />
        </label>
        <p className="input-hint">
          Use a name your training group will recognize.
        </p>
        <button type="submit">Create Circle</button>
      </ActionForm>
    </>
  );
}
