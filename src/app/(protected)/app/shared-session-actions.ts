"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  endSharedSession,
  joinSharedSession,
  startSharedSession,
} from "@/data/shared-sessions";

import type { ActionResult } from "./training-actions";

function formString(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === "string" ? value : "";
}

function routineChoice(form: FormData): string | null {
  return formString(form, "routine") || null;
}

function actionError(error: unknown, fallback: string): ActionResult {
  if (
    error instanceof Error &&
    (error.message.startsWith("Finish the active workout") ||
      error.message === "Shared session has ended.")
  ) {
    return { error: error.message };
  }
  return { error: fallback };
}

export async function startSharedSessionAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  let workoutId: string;
  try {
    const result = await startSharedSession(
      formString(form, "circle"),
      routineChoice(form),
    );
    workoutId = result.workoutId;
  } catch (error) {
    return actionError(
      error,
      "Workout could not be started. Please try again.",
    );
  }
  revalidatePath("/app", "layout");
  redirect(`/app/workout/${workoutId}`);
}

export async function joinSharedSessionAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  let workoutId: string;
  try {
    workoutId = await joinSharedSession(
      formString(form, "session"),
      routineChoice(form),
    );
  } catch (error) {
    return actionError(
      error,
      "Session could not be joined. Refresh and try again.",
    );
  }
  revalidatePath("/app", "layout");
  redirect(`/app/workout/${workoutId}`);
}

export async function endSharedSessionAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  try {
    await endSharedSession(formString(form, "session"));
  } catch {
    return { error: "Session could not be closed. Refresh and try again." };
  }
  revalidatePath("/app", "layout");
  return { success: "Session closed. Everyone can finish their own workout." };
}
