# METRA IT Assets

Arabic-first Flutter application for IT inventory and custody management for the meteorological organization.

## Current scaffold
- Flutter/Dart app foundation with Material 3 and Arabic RTL
- Responsive dashboard shell with navigation to office, asset, custody, and report screens
- Office directory screen shell
- Asset inventory filters and category/status model
- Asset form with conditional computer specifications
- Custody card and report screen shells
- Firestore data dictionary, architecture, Google integration guide, and starter security rules

## Run locally
1. Install Flutter stable and Dart.
2. Run `flutter pub get`.
3. Configure Firebase with FlutterFire CLI: `flutterfire configure`.
4. Add local `lib/firebase_options.dart` (gitignored).
5. Run `flutter run`.

Firebase configuration, service-account keys, and real inventory are not committed.

## Important
This is an initial scaffold, not a production-ready connected system. Screens currently use empty states; Firestore CRUD, authentication, Google Sheets sync, PDF generation, and tests remain planned. Review and test `firestore.rules` before deployment. See `docs/roadmap.md`.
