import styles from "./page.module.css";

export default function Home() {
  return (
    <main className={styles.shell}>
      <div className={styles.header}>
        <span className={styles.mark} aria-hidden="true" />
        <span className={styles.brand}>GymTracker</span>
      </div>

      <section className={styles.content} aria-labelledby="foundation-title">
        <p className={styles.eyebrow}>Foundation ready</p>
        <h1 id="foundation-title">Your training, kept clear.</h1>
        <p className={styles.summary}>
          A focused space for personal progress and shared sessions with gym
          buddies.
        </p>
        <p className={styles.note}>
          Workout features will arrive in the next implementation phase.
        </p>
      </section>
    </main>
  );
}
