import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:metra_it_assets/screens/auth_screen.dart';
import 'package:metra_it_assets/screens/dashboard_screen.dart';

class MetraItAssetsApp extends StatelessWidget {
  const MetraItAssetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF183B56);
    const teal = Color(0xFF168C8C);
    return MaterialApp(
      title: 'METRA IT Assets',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: navy),
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
        textTheme: GoogleFonts.cairoTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: navy,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: _AuthenticationGate(),
      ),
    );
  }
}

class _AuthenticationGate extends StatelessWidget {
  const _AuthenticationGate();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, auth) {
      if (auth.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = auth.data;
      if (user == null) return const AuthScreen();
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, profile) {
          if (profile.hasError) return _AccessMessage(
            message: 'تعذر التحقق من صلاحيات الحساب. راجع مسؤول النظام.',
            onSignOut: () => FirebaseAuth.instance.signOut(),
          );
          if (!profile.hasData) { return const Scaffold(body: Center(child: CircularProgressIndicator())); }
          final data = profile.data!.data();
          final role = data?['role'] as String? ?? '';
          final active = data?['isActive'] != false;
          final allowed = profile.data!.exists && active && ['admin', 'it_manager'].contains(role);
          if (!allowed) return _AccessMessage(
            message: 'الحساب غير مفعّل أو لا يملك صلاحية الدخول إلى لوحة الإدارة.',
            onSignOut: () => FirebaseAuth.instance.signOut(),
          );
          return const DashboardScreen();
        },
      );
    },
  );
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({required this.message, required this.onSignOut});
  final String message;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_accounts_outlined, size: 52),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: onSignOut, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
          ],
        ),
      ),
    ),
  );
}
