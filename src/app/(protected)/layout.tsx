import type { ReactNode } from "react";
import { redirect } from "next/navigation";

import { getCurrentUser } from "@/data/auth";
import Link from "next/link";
import { Navigation } from "@/components/training/navigation";
import "./product.css";

export const dynamic = "force-dynamic";

export default async function ProtectedLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  const user = await getCurrentUser();

  if (!user) {
    redirect("/auth?notice=signin-required");
  }

  return (
    <div className="product">
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="product-header">
        <Link href="/app" className="wordmark">
          GYM<span>TRACKER</span>
          <i aria-hidden="true">↗</i>
        </Link>
        <span className="private-label">Personal training</span>
      </header>
      <main id="main" className="product-main">
        {children}
      </main>
      <Navigation />
    </div>
  );
}
