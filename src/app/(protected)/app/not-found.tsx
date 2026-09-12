import Link from "next/link";
export default function NotFound() {
  return (
    <div className="empty">
      <h1>Nothing here.</h1>
      <p>This item is unavailable or doesn’t belong to your account.</p>
      <Link href="/app">Back to home →</Link>
    </div>
  );
}
