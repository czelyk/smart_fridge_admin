import * as admin from "firebase-admin";

// V2 Imports
import { logger } from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

// V1 Imports (for Auth trigger)
import { auth } from "firebase-functions/v1";

// Firebase Admin SDK'yı başlat
admin.initializeApp();
const db = admin.firestore();

/**
 * (v2 Syntax) Her gün sabah 3'te çalışır.
 */
export const dailyUserDataUpdate = onSchedule(
  "every day 03:00",
  async (event) => {
    logger.info("Günlük kullanıcı güncelleme işlemi (v2) başladı.");
    const usersSnapshot = await db.collection("users").get();
    if (usersSnapshot.empty) {
      logger.info("Güncellenecek kullanıcı bulunamadı.");
      return;
    }
    const batch = db.batch();
    usersSnapshot.forEach((userDoc) => {
      const userRef = db.collection("users").doc(userDoc.id);
      batch.update(userRef, { dailyBonusReceived: false });
    });
    try {
      await batch.commit();
      logger.info(
        `Başarılı: ${usersSnapshot.size} kullanıcının verisi güncellendi.`
      );
    } catch (error) {
      logger.error("V2 günlük güncellemede hata:", error);
    }
    return;
  }
);

/**
 * (v2 Syntax) Manuel olarak tetiklenir.
 */
export const manualUserDataUpdate = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Yetkiniz yok.");
  }
  logger.info("Manuel kullanıcı güncelleme işlemi başlatıldı.", {
    uid: request.auth.uid,
  });
  const usersSnapshot = await db.collection("users").get();
  if (usersSnapshot.empty) {
    return { message: "Kullanıcı bulunamadı.", updatedCount: 0 };
  }
  const batch = db.batch();
  usersSnapshot.forEach((userDoc) => {
    const userRef = db.collection("users").doc(userDoc.id);
    batch.update(userRef, { dailyBonusReceived: false });
  });
  try {
    await batch.commit();
    const successMessage = `Başarılı: ${usersSnapshot.size} kullanıcı güncellendi.`;
    logger.info(successMessage);
    return { message: successMessage, updatedCount: usersSnapshot.size };
  } catch (error) {
    logger.error("V2 manuel güncellemede hata:", error);
    throw new HttpsError("internal", "Güncelleme başarısız.", error);
  }
});

/**
 * (v1 Syntax) Yeni bir kullanıcı oluşturulduğunda tetiklenir.
 */
export const createUserProfile = auth.user().onCreate((user) => {
  logger.info(`Yeni kullanıcı için profil oluşturuluyor: ${user.uid}`);
  const userRef = db.collection("users").doc(user.uid);
  return userRef.set({
    email: user.email,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    dailyBonusReceived: false,
  });
});
