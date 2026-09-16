"use server";

import { revalidatePath } from "next/cache";

import { updateMyDisplayName } from "@/data/profile";

import type { ActionResult } from "./training-actions";

export async function updateDisplayNameAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  try {
    await updateMyDisplayName(form.get("displayName"));
  } catch (error) {
    return {
      error:
        error instanceof Error
          ? error.message
          : "Display name could not be saved. Please try again.",
    };
  }

  revalidatePath("/app/profile");
  revalidatePath("/app/circles", "layout");
  return { success: "Display name saved." };
}
