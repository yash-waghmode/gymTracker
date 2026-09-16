"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createCircle, deleteCircle, leaveCircle } from "@/data/circles";

import type { ActionResult } from "./training-actions";

function formString(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === "string" ? value : "";
}

export async function createCircleAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  let circleId: string;
  try {
    circleId = await createCircle(formString(form, "name"));
  } catch (error) {
    return {
      error:
        error instanceof Error
          ? error.message
          : "Circle could not be created. Please try again.",
    };
  }

  revalidatePath("/app/circles");
  redirect(`/app/circles/${circleId}`);
}

export async function leaveCircleAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  try {
    await leaveCircle(formString(form, "circle"));
  } catch (error) {
    return {
      error:
        error instanceof Error
          ? error.message
          : "Circle could not be left. Please try again.",
    };
  }

  revalidatePath("/app/circles");
  redirect("/app/circles");
}

export async function deleteCircleAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  if (formString(form, "confirm") !== "delete") {
    return { error: "Confirm that you want to delete this Circle." };
  }

  try {
    await deleteCircle(formString(form, "circle"));
  } catch {
    return { error: "Circle could not be deleted. Please try again." };
  }

  revalidatePath("/app/circles");
  redirect("/app/circles");
}
