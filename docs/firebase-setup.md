# Firebase setup (development)

The asset register now uses the Cloud Firestore collection `assets`.

## Configure a local Flutter build

1. Create a dedicated Firebase project for this IT inventory application. Do not reuse or modify any unrelated meteorological production database.
2. Enable Cloud Firestore and Authentication.
3. From the repository root, run FlutterFire CLI configuration:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

4. Confirm that `lib/firebase_options.dart` is generated and initialize Firebase before calling `runApp`:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

5. Deploy the reviewed Firestore rules:

```bash
firebase deploy --only firestore:rules
```

## Asset document

Each document in `assets` contains:
- `category`, `brand`, `model`, `serialNumber`, `status`
- optional `cpu`, `ram`, `storage`
- optional `officeId`, `officeName`, `receivedAt`

## First administrator provisioning

The first administrator must be provisioned through a trusted administrative channel because client-side rules intentionally do not allow an unauthenticated user to grant themselves an administrator role.

1. Enable Email/Password in Firebase Authentication and create the first administrator account in the Firebase Console.
2. Copy that account's Firebase Authentication UID.
3. In Firestore, create `users/{UID}` with at least these fields:

```json
{
  "displayName": "System Administrator",
  "email": "admin@example.invalid",
  "role": "admin",
  "isActive": true
}
```

4. Replace the sample display name and email with the actual account details. Do not use the example address as a real account.
5. Sign in through the app. Access is denied unless the profile exists, `isActive` is explicitly `true`, and `role` is `admin` or `it_manager`.

Create subsequent Authentication accounts using a trusted Admin SDK/service process, then provision their profile documents. Never embed a service-account key in the Flutter client or commit it to this repository.

## Important security notes

- Do not commit service-account keys, private keys, or local credential files.
- Configure Firebase Authentication before granting access to staff.
- Review and test Firestore rules with the Firebase Emulator before production.
- The current rules are a starter baseline, not a completed authorization model. Add role and office-level access checks before operational deployment.
- Asset serial numbers are reserved transactionally in `asset_serials/{encodedNormalizedSerial}`. Firestore rules restrict this reservation index to active administrators/IT managers. Before opening the transaction, the app performs a compatibility scan of existing asset records to detect legacy serials that predate the index; this scan is O(number of assets), so a controlled one-time backfill of `asset_serials` should be completed before a large inventory rollout. The unique reservation itself is then checked and written atomically with the asset record.
- Keep serial reservation and asset create/update in the same Firestore transaction. Do not write asset records directly from scripts or alternate clients without maintaining the reservation index.

## Camera scanning platform permissions

The asset scanner uses the `mobile_scanner` package. When generating the native platform folders for a deployment build, add the platform camera permissions before testing scanning on devices:

- Android: add `<uses-permission android:name="android.permission.CAMERA" />` to `android/app/src/main/AndroidManifest.xml`.
- iOS: add `NSCameraUsageDescription` to `ios/Runner/Info.plist` with a clear Arabic explanation that the camera is used to scan asset barcodes and QR labels.
- Web: test from HTTPS or localhost and grant the browser camera permission.

Do not assume that a successful Dart analysis proves camera access or native packaging is configured. Verify scanning on each target platform.

## User management in the application

After the first administrator profile is configured, the super administrator can open **المستخدمون والصلاحيات** from the dashboard. Create the Authentication account first through Firebase Console or a trusted Admin SDK process, then add its UID, display name, email, role, and active state in the application. The app manages Firestore profiles only; it never creates passwords or Firebase Authentication accounts.

Only the `admin` role can create or change other users' profile roles and active state. An account can update only its own display name and email. The `it_manager` role can operate inventory workflows but cannot administer other accounts. See [security-model.md](security-model.md) for the current permission matrix and remaining production limitations.


## Asset document storage

The repository includes `firebase.json`, `firestore.rules`, and `storage.rules`. Install Firebase CLI, authenticate, select the dedicated project with `firebase use --add`, then deploy both rule sets using `firebase deploy --only firestore:rules,storage` from the repository root. Verify the selected project ID before deployment; do not deploy these rules to any legacy project. The rules require an active user profile for reads and an active admin/IT-manager profile for uploads, restrict file types to PDF, PNG/JPEG, DOCX and XLSX, cap uploads below 10 MB, and deny update/delete. Firestore metadata is stored in `asset_documents`; files are kept under `asset_documents/{assetId}/...`. The app shares downloaded file bytes through the platform share sheet instead of persisting public download-token URLs.


## Local authorization test suite

The repository includes Firestore and Storage rules tests under `test/firestore.rules.test.mjs`. They use demo project ID `demo-metra-it-assets` and local emulators only; they do not connect to a production Firebase project.

Run from the repository root after installing Node.js 20+ and Java 21:

```bash
npm install
npx firebase emulators:exec --only firestore,storage --project demo-metra-it-assets "npm run test:rules"
```

The GitHub Actions workflow runs these checks independently from Flutter analysis and unit tests. A passing local test run is required before deploying changed rules.


## Production hardening and App Check

Before inviting staff:

1. Register each intended Android, Web, and Windows app in the dedicated Firebase project and generate platform configuration with FlutterFire. Keep generated local config out of public commits if it contains environment identifiers that your organization treats as confidential.
2. Enable Firebase App Check for supported platforms. Start in monitoring mode, inspect legitimate traffic, then enforce it for Firestore and Storage only after all production clients have valid App Check providers configured. Do not enable enforcement blindly before verifying the actual clients.
3. Use a production App Check provider appropriate to each platform (for example Play Integrity on Android and reCAPTCHA Enterprise on Web). Validate the supported provider path for Windows separately; do not assume parity with Android/Web.
4. Restrict Authentication sign-in methods to those approved by the organization. Enforce MFA for privileged accounts through the supported Identity Platform/Firebase Authentication configuration.
5. Complete the serial reservation backfill and a restore drill before bulk import.
6. Confirm that the actual selected Firebase project is the dedicated asset inventory project before deploying any rules or functions.

The app currently supports the admin and it_manager profile roles only. Office-scoped roles and staff-level data isolation are not implemented; do not use this baseline for a multi-tenant or office-isolated production rollout.


## GitHub Pages web configuration

The Pages workflow reads these repository Actions **Variables** and passes them to the Flutter web build as compile-time defines:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`

Create a Firebase **Web app** inside the dedicated IT inventory Firebase project, then copy the corresponding values from its Firebase SDK configuration into the repository's Settings → Secrets and variables → Actions → Variables. These web configuration values identify the Firebase app; they are not Admin SDK credentials. Never put service-account JSON, private keys, or Admin SDK credentials in Actions Variables, Dart defines, or the Flutter client.

Until all six values are configured, the Pages site deliberately displays a clear Firebase setup screen instead of attempting an anonymous or guessed connection. Native Android/Windows builds must use their own FlutterFire-generated platform options. This setup does not create a Firebase project, enable billing/services, provision users, or deploy security rules.


## Repeatable trusted user provisioning (CLI)

The repository now includes `scripts/provision-user.mjs` for creating a Firestore profile for an Authentication account that already exists. It uses Google Cloud Application Default Credentials (ADC), calls the Firestore REST API, and deliberately does not create passwords or Authentication users.

1. Install and authenticate Google Cloud CLI in a trusted administrator workstation:
   `gcloud auth application-default login`
2. Create the staff account in Firebase Authentication using the approved identity process and copy its UID.
3. Run the script from the repository root, supplying the exact dedicated inventory Firebase project ID:

```bash
node scripts/provision-user.mjs --project YOUR_DEDICATED_PROJECT_ID --confirm-project YOUR_DEDICATED_PROJECT_ID --uid FIREBASE_AUTH_UID --name "Staff Display Name" --email "staff@example.com" --role it_manager
```

4. Type `CREATE PROFILE` when prompted. The script validates every argument and requires both project-ID confirmation and the explicit phrase.
5. Verify the resulting `users/{uid}` document and sign-in with the account.

The operation is create-only: Firestore's `currentDocument.exists=false` precondition prevents overwriting an existing profile. If the UID already has a profile, the script stops and leaves it unchanged. The ADC identity must have narrowly scoped permission to create documents in the dedicated project's Firestore database. Do not grant broad project-owner access just to run this script, and never copy ADC files or tokens into the repository or Flutter application. The script does not modify Firestore rules, create Authentication accounts, or touch any other Firebase project.
