"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { trainingContext } from "@/data/training";
import { parseId, parseName, parseSet } from "@/lib/training";

export type ActionResult = { error?: string; success?: string };

export async function saveRoutine(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  const { db } = await trainingContext();
  let result;
  try {
    const name = parseName(form.get("name"));
    const ids = form.getAll("exercise").map(parseId);
    if (ids.length > 50) throw new Error("Use at most 50 exercises.");
    const id = form.get("id") ? parseId(form.get("id")) : null;
    result = await db.rpc("save_routine", {
      p_id: id,
      p_name: name,
      p_exercises: ids,
    });
  } catch (e) {
    return { error: e instanceof Error ? e.message : "Check your routine." };
  }
  if (result.error)
    return {
      error: "Routine could not be saved. Check the exercises and try again.",
    };
  revalidatePath("/app", "layout");
  redirect("/app/routines");
}

export async function deleteRoutine(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  const { db, user } = await trainingContext();
  let id;
  try {
    id = parseId(form.get("id"));
  } catch {
    return { error: "Routine not found." };
  }
  const { data, error } = await db
    .from("routines")
    .delete()
    .eq("id", id)
    .eq("owner_id", user.id)
    .select("id");
  if (error || !data?.length)
    return { error: "Routine could not be deleted. Try again." };
  revalidatePath("/app", "layout");
  redirect("/app/routines");
}

export async function startWorkout(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  const { db } = await trainingContext();
  let routine;
  try {
    routine = form.get("routine") ? parseId(form.get("routine")) : null;
  } catch {
    return { error: "Choose a valid routine." };
  }
  const { data, error } = await db.rpc("start_workout", { p_routine: routine });
  if (error || !data)
    return { error: "Workout could not be started. Please try again." };
  revalidatePath("/app", "layout");
  redirect(`/app/workout/${data}`);
}

export async function changeWorkout(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  const { db } = await trainingContext();
  let workout: string,
    operation: string,
    target: string | null,
    set: { weight: number; reps: number } | null;
  try {
    workout = parseId(form.get("workout"));
    operation = String(form.get("operation"));
    if (
      !["add_exercise", "add_set", "edit_set", "delete_set", "finish"].includes(
        operation,
      )
    )
      throw new Error("Unknown action.");
    target = operation === "finish" ? null : parseId(form.get("target"));
    set = ["add_set", "edit_set"].includes(operation)
      ? parseSet(form.get("weight"), form.get("reps"))
      : null;
  } catch (e) {
    return { error: e instanceof Error ? e.message : "Check your set." };
  }
  const { error } = await db.rpc("change_workout", {
    p_workout: workout,
    p_operation: operation,
    p_target: target,
    p_weight: set?.weight,
    p_reps: set?.reps,
  });
  if (error)
    return {
      error:
        error.code === "22023"
          ? error.message
          : "Change was not saved. Check your connection and try again.",
    };
  revalidatePath("/app", "layout");
  if (operation === "finish") redirect(`/app/workout/${workout}`);
  return { success: "Saved" };
}

export async function createExercise(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  const { db, user } = await trainingContext();
  let name;
  try {
    name = parseName(form.get("name"));
  } catch (e) {
    return { error: (e as Error).message };
  }
  const { error } = await db
    .from("exercises")
    .insert({ name, owner_id: user.id });
  if (error)
    return {
      error:
        error.code === "23505"
          ? "You already have an exercise with that name."
          : "Exercise could not be created. Try again.",
    };
  revalidatePath("/app", "layout");
  return { success: "Exercise added to your catalog." };
}
