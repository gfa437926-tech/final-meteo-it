# Google integration plan and setup

## Current status

Google Sheets synchronization is **not implemented yet**. The app currently exports filtered inventory to CSV and Excel files, which can be uploaded to Google Sheets manually. Asset attachments currently use Firebase Storage with authenticated access; do not place service-account credentials or private keys in the Flutter client.

## Safe Sheets integration design

1. Register an OAuth client for the intended platforms and configure the exact redirect origins/URIs.
2. Prefer a trusted server-side integration for scheduled or bidirectional synchronization. The Flutter app must never contain a Google service-account private key or client secret.
3. Grant the minimum Google Sheets scope needed for the selected workflow; request write access only if users need to publish updates.
4. Import into a staging area first. Validate required columns, asset identifiers, serial-number uniqueness, enum values, and office references before committing changes.
5. Require an explicit preview and approval before applying imported changes. Do not overwrite an existing asset silently.
6. Record source spreadsheet ID, sheet/tab, import batch ID, actor, timestamps, row-level outcomes, and validation errors in an append-only audit trail.
7. Export only fields authorized for the current user. Exclude authentication data, private notes, and unnecessary personal information.

## Manual workflow available now

- Open **التقارير والجرد** and apply category, status, and office filters.
- Export the filtered result as CSV or Excel.
- Upload the exported file to Google Sheets using Google Sheets' own import workflow.

## Firebase setup

1. Create or select a Firebase project dedicated to this application.
2. Enable Authentication, Firestore, and Firebase Storage.
3. Install FlutterFire CLI and run `flutterfire configure`.
4. Keep generated `lib/firebase_options.dart` local; it is gitignored.
5. Deploy and verify Firestore and Storage rules before importing real office or asset data.

Never commit service-account JSON files, OAuth client secrets, or private keys.
