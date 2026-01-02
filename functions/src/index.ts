
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Firebase Admin SDK'yı başlat
admin.initializeApp();
const db = admin.firestore();

/**
 * Her gün belirli bir saatte (örneğin sabah 3'te) çalışır ve
 * tüm kullanıcıların verilerini günceller.
 * Zamanlamayı cron formatında "at 03:00" olarak ayarladık.
 * Farklı bir saat için https://crontab.guru/ sitesini kullanabilirsiniz.
 */
export const dailyUserDataUpdate = functions.pubsub
  .schedule("at 03:00")
  .timeZone("Europe/Istanbul") // Zaman dilimini ayarlamayı unutmayın
  .onRun(async (context) => {
    logger.info("Günlük kullanıcı güncelleme işlemi başladı.", {
      structuredData: true,
    });

    // 'users' koleksiyonundaki tüm kullanıcıları al
    const usersSnapshot = await db.collection("users").get();

    if (usersSnapshot.empty) {
      logger.info("Güncellenecek kullanıcı bulunamadı.");
      return null;
    }

    // Toplu yazma işlemi (batch) oluştur. Bu daha verimlidir.
    const batch = db.batch();

    usersSnapshot.forEach((userDoc) => {
      const userRef = db.collection("users").doc(userDoc.id);
      
      // --- GÜNCELLEMEK İSTEDİĞİNİZ ALANLARI BURADA DEĞİŞTİRİN ---
      // Örnek: Kullanıcının 'dailyBonusReceived' alanını false yapmak
      // Örnek: Kullanıcının 'lastUpdate' alanına günün tarihini yazmak
      batch.update(userRef, {
        "dailyBonusReceived": false,
        "lastUpdate": admin.firestore.FieldValue.serverTimestamp(),
        // Başka bir alanı güncellemek isterseniz buraya ekleyin
        // "alanAdi": "yeniDeger",
      });
      // -------------------------------------------------------------
    });

    try {
      // Toplu güncellemeyi veritabanına işle
      await batch.commit();
      logger.info(
        `Başarılı: ${usersSnapshot.size} kullanıcının verisi güncellendi.`
      );
    } catch (error) {
      logger.error("Kullanıcı verileri güncellenirken hata oluştu:", error);
    }

    return null;
  });

