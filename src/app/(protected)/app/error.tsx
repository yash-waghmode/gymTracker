"use client";
export default function ErrorPage({ reset }: { reset: () => void }) {
  return (
    <div className="empty">
      <h1>Let’s try that again.</h1>
      <p>Your training could not be loaded. Check your connection.</p>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
