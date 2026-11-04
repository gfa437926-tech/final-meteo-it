import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: DashboardScreen(),
      ),
    );
  }
}
