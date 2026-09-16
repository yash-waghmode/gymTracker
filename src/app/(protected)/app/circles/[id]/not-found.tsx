import Link from "next/link";

export default function CircleNotFound() {
  return (
    <div className="empty">
      <h1>Circle unavailable.</h1>
      <p>This Circle doesn’t exist or you’re not a member.</p>
      <Link href="/app/circles">Back to your Circles →</Link>
    </div>
  );
}
