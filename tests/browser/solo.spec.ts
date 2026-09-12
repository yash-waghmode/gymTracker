import { test, expect } from "@playwright/test";
test("mobile solo journey persists routines, sets, history and private progress", async ({
  page,
  browser,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/auth");
  await page
    .getByLabel("Email", { exact: true })
    .fill("browser-a@example.test");
  await page.getByLabel("Password", { exact: true }).fill("Test-password-123");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Let’s get to work." }),
  ).toBeVisible();
  await page
    .getByRole("link", { name: "Create a routine", exact: true })
    .click();
  await page.getByLabel("Routine name").fill("Full body A");
  await page
    .getByRole("button", { name: "Barbell squat", exact: false })
    .click();
  await page
    .getByRole("button", { name: "Barbell bench press", exact: false })
    .click();
  await page.getByRole("button", { name: "Move exercise 2 up" }).click();
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Routines.", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: /Full body A/ }).click();
  await expect(page.getByLabel("Routine name")).toHaveValue("Full body A");
  await page.getByLabel("Routine name").fill("Full body");
  await page.getByRole("button", { name: "Remove exercise 2" }).click();
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Routines.", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Workout", exact: true }).click();
  await page
    .getByRole("button", { name: "Start routine", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Full body", exact: true }),
  ).toBeVisible();
  await expect(page).toHaveURL(/\/app\/workout\/[0-9a-f-]{36}$/);
  const workoutUrl = page.url();
  await expect(
    page.getByRole("heading", { name: "Barbell bench press", exact: true }),
  ).toBeVisible();
  await page.getByLabel("Weight in kg", { exact: true }).fill("60");
  await page.getByLabel("Reps", { exact: true }).fill("8");
  await page.route("**/app/workout/*", (route) => route.abort(), { times: 1 });
  await page.getByRole("button", { name: "Log set", exact: true }).click();
  await expect(
    page.getByText("Save could not be confirmed.", { exact: false }),
  ).toBeVisible();
  await expect(page.getByLabel("Weight in kg", { exact: true })).toHaveValue(
    "60",
  );
  await expect(page.getByLabel("Reps", { exact: true })).toHaveValue("8");
  await page.getByRole("button", { name: "Log set", exact: true }).click();
  await expect(
    page.locator("summary").filter({ hasText: "60 kg × 8" }),
  ).toBeVisible();
  await page.reload();
  await expect(
    page.locator("summary").filter({ hasText: "60 kg × 8" }),
  ).toBeVisible();
  await page.locator("summary").filter({ hasText: "60 kg × 8" }).click();
  await page.getByLabel("Edit weight in kg").fill("62.5");
  await page.getByLabel("Edit reps").fill("10");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(
    page.locator("summary").filter({ hasText: "62.5 kg × 10" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Log set", exact: true }).click();
  await expect(page.locator(".saved-set")).toHaveCount(2);
  await page.locator(".saved-set").last().locator("summary").click();
  await page
    .locator(".saved-set")
    .last()
    .getByRole("button", { name: "Remove set" })
    .click();
  await expect(page.locator(".saved-set")).toHaveCount(1);
  await page.locator("summary").filter({ hasText: "Add exercise" }).click();
  await page
    .getByRole("combobox", { name: "Exercise", exact: true })
    .selectOption({ label: "Lat pulldown" });
  await page.getByRole("button", { name: "Add to workout" }).click();
  await expect(
    page.getByRole("heading", { name: "Lat pulldown", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Finish workout" }).click();
  await expect(page.getByText("WORKOUT COMPLETE. NICE WORK.")).toBeVisible();
  await expect(
    page.getByText("Personal record", { exact: false }).first(),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Log set", exact: true }),
  ).toHaveCount(0);
  await page.getByRole("link", { name: "View history", exact: true }).click();
  await expect(page.getByRole("link", { name: /Full body/ })).toBeVisible();
  await page.getByRole("link", { name: "Progress", exact: true }).click();
  await page.getByRole("link", { name: /Barbell bench press/ }).click();
  await expect(
    page.getByText("62.5 kg × 10", { exact: false }).first(),
  ).toBeVisible();
  await page.screenshot({
    path: "test-results/progress-mobile.png",
    fullPage: true,
  });
  const other = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const p = await other.newPage();
  await p.goto("http://localhost:3100/auth");
  await p.getByLabel("Email", { exact: true }).fill("browser-b@example.test");
  await p.getByLabel("Password", { exact: true }).fill("Test-password-123");
  await p.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(
    p.getByRole("heading", { name: "Let’s get to work." }),
  ).toBeVisible();
  await p.goto(workoutUrl);
  await expect(p.getByRole("heading", { name: "Nothing here." })).toBeVisible();
  await other.close();
  await page.getByRole("link", { name: "Home", exact: true }).click();
  await page.getByRole("button", { name: "Start free workout" }).click();
  await expect(
    page.getByRole("heading", { name: "Free workout", exact: true }),
  ).toBeVisible();
  await page
    .getByRole("combobox", { name: "Exercise", exact: true })
    .selectOption({ label: "Barbell bench press" });
  await page.getByRole("button", { name: "Add to workout" }).click();
  await expect(
    page.getByText("62.5 kg × 10", { exact: false }).first(),
  ).toBeVisible();
  await page.getByLabel("Weight in kg", { exact: true }).fill("65");
  await page.getByLabel("Reps", { exact: true }).fill("8");
  await page.getByRole("button", { name: "Log set", exact: true }).click();
  await expect(page.locator(".saved-set")).toHaveCount(1);
  await page.screenshot({
    path: "test-results/workout-mobile.png",
    fullPage: true,
  });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.getByRole("button", { name: "Finish workout" }).click();
  await expect(page.getByText("WORKOUT COMPLETE. NICE WORK.")).toBeVisible();
  await page.goto("/app/routines");
  await page.getByRole("link", { name: /Full body/ }).click();
  await page.locator("summary").filter({ hasText: "Delete routine" }).click();
  await page.getByRole("button", { name: "Delete this routine" }).click();
  await expect(page.getByRole("link", { name: /Full body/ })).toHaveCount(0);
  await page.goto(workoutUrl);
  await expect(
    page.getByRole("heading", { name: "Full body", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Profile", exact: true }).click();
  await page
    .getByLabel("Exercise name", { exact: true })
    .fill("Single-arm cable row");
  await page.getByRole("button", { name: "Add exercise", exact: true }).click();
  await expect(page.getByText("Exercise added to your catalog.")).toBeVisible();
  await page.goto("/app/routines/new");
  await expect(
    page.getByRole("button", { name: "Single-arm cable row", exact: false }),
  ).toBeVisible();
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto("/app");
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: "test-results/home-desktop.png",
    fullPage: true,
  });
  await page.getByRole("link", { name: "Profile", exact: true }).click();
  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Sign in to your training" }),
  ).toBeVisible();
  await page.goto(workoutUrl);
  await expect(
    page.getByRole("heading", { name: "Sign in to your training" }),
  ).toBeVisible();
  expect(errors).toEqual([]);
});
