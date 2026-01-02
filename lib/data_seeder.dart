
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Veritabanına başlangıç verilerini (seed data) eklemek için kullanılan yardımcı sınıf.
/// Bu sınıf sadece geliştirme aşamasında, veritabanını hazırlamak için kullanılır.
class DataSeeder {
  
  /// Ana ürün listesini ve test kullanıcısı için tercihleri Firestore'a yazar.
  /// Bu fonksiyonun birden fazla çalıştırılması, mevcut verilerin üzerine yazılmasına
  /// neden olabilir, bu yüzden dikkatli kullanılmalıdır.
  static Future<void> seedInitialData() async {
    final firestore = FirebaseFirestore.instance;

    // --- 1. Adım: Ana Ürün Listesini Oluşturma ---
    // products koleksiyonuna referans al
    final productsCollection = firestore.collection('products');

    // Toplu yazma işlemi (batch) oluştur. Bu, birden fazla işlemi tek seferde
    // ve atomik olarak yapmamızı sağlar.
    final batch = firestore.batch();

    // Eklenecek ürünler ve özellikleri
    final products = {
      'PROD-YUM-001': {
        'name': 'Yumurta',
        'isVegan': false,
        'isVegetarian': true,
        'containsPork': false,
      },
      'PROD-DOM-001': {
        'name': 'Domuz Pastırması',
        'isVegan': false,
        'isVegetarian': false,
        'containsPork': true,
      },
       'PROD-ELM-001': {
        'name': 'Elma',
        'isVegan': true,
        'isVegetarian': true,
        'containsPork': false,
      },
    };

    // Her bir ürünü batch işlemine ekle
    products.forEach((docId, data) {
      final docRef = productsCollection.doc(docId);
      batch.set(docRef, data);
    });

    debugPrint('Ürünler toplu yazma işlemine eklendi.');

    // --- 2. Adım: Test Kullanıcısını Güncelleme ---
    // Daha önce ekran görüntüsünde belirttiğiniz test kullanıcısının ID'si
    const testUserId = '1EayzGUe8oVNWVo57Fx9r';
    final userRef = firestore.collection('users').doc(testUserId);

    // Kullanıcıya diyet ve kültürel tercihleri ekle.
    // `set` yerine `update` kullanmak yerine `set` ile `Merge:true` kullanmak
    // document yoksa bile oluşturur, `update` ise document yoksa hata verir.
    // Varolan bir kullanıcıyı güncellediğimiz için merge daha güvenli.
    batch.set(userRef, {
      'dietaryPreference': 'vegan',
      'culturalRestrictions': ['no_pork'],
    }, SetOptions(merge: true));

    debugPrint('Test kullanıcısı güncellemesi toplu yazma işlemine eklendi.');

    // --- 3. Adım: Tüm Değişiklikleri Veritabanına Yazma ---
    try {
      await batch.commit();
      debugPrint('Başlangıç verileri başarıyla Firestore'a yazıldı!');
    } catch (e) {
      debugPrint('Veriler yazılırken bir hata oluştu: $e');
    }
  }
}
