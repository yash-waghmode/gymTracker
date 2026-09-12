"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
export function Navigation() {
  const path = usePathname();
  const items = [
    ["/app", "Home", "⌂"],
    ["/app/workout", "Workout", "＋"],
    ["/app/progress", "Progress", "↗"],
    ["/app/profile", "Profile", "◉"],
  ];
  return (
    <nav className="product-nav" aria-label="Main navigation">
      {items.map(([href, title, icon]) => (
        <Link
          key={href}
          href={href}
          aria-current={
            (href === "/app" ? path === href : path.startsWith(href))
              ? "page"
              : undefined
          }
        >
          <span aria-hidden="true">{icon}</span>
          {title}
        </Link>
      ))}
    </nav>
  );
}
