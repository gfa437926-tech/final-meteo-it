# Google integration setup

1. Create or select a Firebase project dedicated to this application.
2. Enable Authentication and Firestore.
3. Install FlutterFire CLI and run `flutterfire configure`.
4. Keep generated `lib/firebase_options.dart` local; it is gitignored.
5. Set up Firestore rules before importing any real office or asset data.
6. Use Google Drive for document attachments and Google Sheets for controlled exports.

Never commit service-account JSON files, OAuth client secrets, or private keys.
