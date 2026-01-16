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

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smarty Admin',
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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToDashboard();
  }

  Future<void> _navigateToDashboard() async {
    // 1. Firebase Auth ve Diğer Hazırlıklar
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: "admin-app@smartfridge.com",
          password: "GucluBirSifre123",
        );
      }
    } catch (e) {
      debugPrint("Giriş Hatası: $e");
    }

    // 2. Logonun görünmesi için kısa bir bekleme süresi (Splash efekti)
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F1F), // Koyu Teal
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO
            Hero(
              tag: 'app_logo',
              child: Image.asset(
                'assets/images/logo.png',
                width: 180,
                height: 180,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.kitchen, size: 100, color: Colors.teal);
                },
              ),
            ),
            const SizedBox(height: 40),
            // UYGULAMA ADI
            Text(
              'SMARTY',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.white,
              ),
            ),
            Text(
              'ADMIN PANEL',
              style: GoogleFonts.poppins(
                fontSize: 12,
                letterSpacing: 2,
                color: Colors.tealAccent,
              ),
            ),
            const SizedBox(height: 60),
            // YÜKLENİYOR İKONU
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
