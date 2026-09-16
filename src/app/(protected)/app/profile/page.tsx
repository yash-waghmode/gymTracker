import { trainingContext } from "@/data/training";
import { getMyProfile } from "@/data/profile";
import { signOut } from "../actions";
import { ActionForm } from "@/components/training/forms";
import { createExercise } from "../training-actions";
import { updateDisplayNameAction } from "../profile-actions";
export default async function Profile() {
  const [{ user }, profile] = await Promise.all([
    trainingContext(),
    getMyProfile(),
  ]);
  return (
    <>
      <header className="page-heading">
        <h1>Your corner.</h1>
      </header>
      <section className="card stack">
        <h2>Account</h2>
        <p className="wrap">{user.email}</p>
        <p className="muted">
          Your workouts and progress are private to your account.
        </p>
        <p>
          Weight unit: <strong>kilograms (kg)</strong>
        </p>
        <form action={signOut}>
          <button className="secondary">Sign out</button>
        </form>
      </section>
      <section className="card stack">
        <h2>Circle display name</h2>
        <p className="muted">
          Only people who currently share a Circle with you can see this name.
          Your email stays private.
        </p>
        <ActionForm action={updateDisplayNameAction}>
          <label className="stack compact">
            Display name
            <input
              name="displayName"
              defaultValue={profile.display_name ?? ""}
              maxLength={80}
              autoComplete="name"
              placeholder="e.g. Asha"
              required
            />
          </label>
          <button className="secondary">Save display name</button>
        </ActionForm>
      </section>
      <section className="card stack">
        <h2>Add a custom exercise</h2>
        <p className="muted">
          It will be available in your routines and workouts.
        </p>
        <ActionForm action={createExercise}>
          <label className="stack compact">
            Exercise name
            <input
              name="name"
              maxLength={120}
              placeholder="e.g. Single-arm cable row"
              required
            />
          </label>
          <button>Add exercise</button>
        </ActionForm>
      </section>
    </>
  );
}
