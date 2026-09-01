import { getApps, initializeApp } from "firebase-admin/app";
import { UserRecord } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

export const onUserCreatedFunction = functions.auth
  .user()
  .onCreate(async (user: UserRecord) => {
    if (!user?.uid || !user.email) {
      logger.warn("Missing uid/email on created auth user", {
        uid: user?.uid,
        email: user?.email,
      });
      return;
    }

    const now = new Date();
    await db.collection("users").doc(user.uid).set({
      uid: user.uid,
      email: user.email,
      firstName: "",
      lastName: "",
      phoneNumber: "",
      role: [],
      profileImageUrl: "https://placehold.net/600x600.png",
      createdAt: now,
      updatedAt: now,
    });

    logger.info("Created default user profile from Auth trigger", {
      uid: user.uid,
    });
  });
