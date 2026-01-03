import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Gizli servis kullanıcısı olarak giriş yap
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: "admin-app@smartfridge.com",
      password: "GucluBirSifre123",
    );
    print("Servis kullanıcısı olarak başarıyla giriş yapıldı.");
  } on FirebaseAuthException catch (e) {
    print("Servis kullanıcısı girişi sırasında hata oluştu: ${e.code}");
    print(e.message);
  }

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Fridge Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const AdminDashboard(),
    );
  }
}
