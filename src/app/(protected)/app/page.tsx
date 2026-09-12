import { getCurrentUser } from "@/data/auth";

import { signOut } from "./actions";
import styles from "./page.module.css";

export default async function AppFoundationPage() {
  const user = await getCurrentUser();

  return (
    <main className={styles.shell}>
      <section className={styles.card}>
        <p className={styles.brand}>GymTracker</p>
        <h1>Account foundation ready</h1>
        <p>
          Signed in{user?.email ? ` as ${user.email}` : ""}. Workout features
          are intentionally deferred to the next product milestone.
        </p>
        <form action={signOut}>
          <button type="submit">Sign out</button>
        </form>
      </section>
    </main>
  );
}
