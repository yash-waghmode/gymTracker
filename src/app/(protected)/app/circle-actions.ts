"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  acceptCircleInvite,
  createCircle,
  createCircleInvite,
  deleteCircle,
  leaveCircle,
  revokeCircleInvite,
  type CircleInviteCredential,
} from "@/data/circles";
import { cancelCircleGoal, createCircleGoal } from "@/data/circle-goals";
import { parseId } from "@/lib/training";

import type { ActionResult } from "./training-actions";

export type CreateInviteResult = {
  error?: string;
  credential?: CircleInviteCredential;
};

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

export async function createCircleInviteAction(
  _: CreateInviteResult,
  form: FormData,
): Promise<CreateInviteResult> {
  const circleId = formString(form, "circle");
  try {
    const credential = await createCircleInvite(circleId);
    revalidatePath(`/app/circles/${circleId}`);
    return { credential };
  } catch {
    return { error: "Invite could not be created. Please try again." };
  }
}

export async function revokeCircleInviteAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  try {
    const circleId = parseId(formString(form, "circle"));
    await revokeCircleInvite(formString(form, "invite"));
    revalidatePath(`/app/circles/${circleId}`);
    return { success: "Invite revoked." };
  } catch {
    return { error: "Invite could not be revoked. Please try again." };
  }
}

export async function acceptCircleInviteAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  let circleId: string;
  try {
    circleId = await acceptCircleInvite(formString(form, "token"));
  } catch {
    return {
      error:
        "This invite can no longer be used. Ask the Circle owner for a new link.",
    };
  }

  revalidatePath("/app/circles");
  redirect(`/app/circles/${circleId}`);
}

export async function createCircleGoalAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  let circleId: string;
  try {
    circleId = parseId(formString(form, "circle"));
    const target = Number(formString(form, "target"));
    await createCircleGoal(circleId, target);
  } catch {
    return {
      error: "Goal could not be started. Check the target and try again.",
    };
  }
  revalidatePath(`/app/circles/${circleId}`);
  return { success: "Goal started for everyone." };
}

export async function cancelCircleGoalAction(
  _: ActionResult,
  form: FormData,
): Promise<ActionResult> {
  if (formString(form, "confirm") !== "cancel") {
    return { error: "Confirm that you want to end this goal." };
  }
  try {
    const circleId = parseId(formString(form, "circle"));
    await cancelCircleGoal(formString(form, "goal"));
    revalidatePath(`/app/circles/${circleId}`);
    return { success: "Goal ended. Everyone’s workouts remain intact." };
  } catch {
    return { error: "Goal could not be ended. Please try again." };
  }
}
