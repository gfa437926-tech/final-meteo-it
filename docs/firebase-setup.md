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

## Important security notes

- Do not commit service-account keys, private keys, or local credential files.
- Configure Firebase Authentication before granting access to staff.
- Review and test Firestore rules with the Firebase Emulator before production.
- The current rules are a starter baseline, not a completed authorization model. Add role and office-level access checks before operational deployment.
- Duplicate serial-number validation in the client is a usability check, not a concurrency-safe uniqueness constraint. Enforce uniqueness with a trusted backend transaction or callable function before production.
