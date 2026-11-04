import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:metra_it_assets/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    runApp(const MetraItAssetsApp());
  } on FirebaseException catch (error) {
    runApp(_FirebaseSetupApp(message: error.message ?? error.code));
  } catch (error) {
    runApp(_FirebaseSetupApp(message: error.toString()));
  }
}

class _FirebaseSetupApp extends StatelessWidget {
  const _FirebaseSetupApp({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 52),
                      const SizedBox(height: 16),
                      const Text('يلزم إعداد Firebase قبل تشغيل النظام',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text('أضف ملفات إعداد Firebase الخاصة بهذا التطبيق ثم أعد تشغيله.'),
                      const SizedBox(height: 12),
                      SelectableText(message, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
