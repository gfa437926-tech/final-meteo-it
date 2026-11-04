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
- Asset serial numbers are reserved transactionally in `asset_serials/{encodedNormalizedSerial}`. Firestore rules restrict this reservation index to active administrators/IT managers. The transaction also scans existing asset records to detect legacy serials that predate the index; this compatibility scan is O(number of assets), so a controlled one-time backfill of `asset_serials` should be completed before a large inventory rollout.\n- Keep serial reservation and asset create/update in the same Firestore transaction. Do not write asset records directly from scripts or alternate clients without maintaining the reservation index.
