import { redirect } from "next/navigation";

import { getCurrentUser } from "@/data/auth";
import { isSupabaseConfigured } from "@/lib/supabase/config";

import { signIn, signUp } from "./actions";
import styles from "./auth.module.css";

type AuthPageProps = {
  searchParams: Promise<{
    error?: string;
    notice?: string;
  }>;
};

const messages: Record<string, string> = {
  "not-configured": "Add the Supabase environment variables before signing in.",
  "invalid-input":
    "Enter a valid email and a password of at least 8 characters.",
  "signin-failed": "We could not sign you in with those credentials.",
  "signup-failed": "We could not create that account.",
  confirmation: "We could not confirm that sign-in link. Request a new one.",
  "signin-required": "Sign in to continue.",
  "check-email": "Check your email to confirm your account.",
};

export default async function AuthPage({ searchParams }: AuthPageProps) {
  const configured = isSupabaseConfigured();
  const user = await getCurrentUser();
  const params = await searchParams;

  if (user) {
    redirect("/app");
  }

  const messageKey = params.error ?? params.notice;
  const message = messageKey ? messages[messageKey] : null;

  return (
    <main className={styles.shell}>
      <section className={styles.card} aria-labelledby="auth-title">
        <p className={styles.brand}>GymTracker</p>
        <h1 id="auth-title">Sign in to your training</h1>
        <p className={styles.intro}>
          Use an email and password. New accounts may require email
          confirmation.
        </p>

        {message ? (
          <p className={styles.message} role="status">
            {message}
          </p>
        ) : null}

        {!configured ? (
          <p className={styles.setup}>
            Authentication is ready for configuration. See the README for local
            setup.
          </p>
        ) : null}

        <form className={styles.form} action={signIn}>
          <label htmlFor="email">Email</label>
          <input
            id="email"
            name="email"
            type="email"
            autoComplete="email"
            required
            disabled={!configured}
          />
          <label htmlFor="password">Password</label>
          <input
            id="password"
            name="password"
            type="password"
            minLength={8}
            autoComplete="current-password"
            required
            disabled={!configured}
          />
          <div className={styles.actions}>
            <button type="submit" disabled={!configured}>
              Sign in
            </button>
            <button
              className={styles.secondary}
              type="submit"
              formAction={signUp}
              disabled={!configured}
            >
              Create account
            </button>
          </div>
        </form>
      </section>
    </main>
  );
}
