"use client";

export default function CircleError({ reset }: { reset: () => void }) {
  return (
    <div className="empty">
      <h1>Circles couldn’t load.</h1>
      <p>Check your connection and try again.</p>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
