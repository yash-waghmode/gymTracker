import type { ReactNode } from "react";
import { redirect } from "next/navigation";

import { getCurrentUser } from "@/data/auth";

export const dynamic = "force-dynamic";

export default async function ProtectedLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  const user = await getCurrentUser();

  if (!user) {
    redirect("/auth?notice=signin-required");
  }

  return children;
}
