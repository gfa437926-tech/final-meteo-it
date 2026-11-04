# METRA IT Assets

Arabic-first Flutter/Dart application for managing IT equipment inventory, office locations, and employee custody records for a meteorological organization.

## Implemented foundation
- Flutter Material 3 application shell with Arabic RTL layout.
- Asset model with localized categories and lifecycle statuses.
- Firestore asset repository, live inventory list, search and category/status filters.
- Asset creation and editing forms with conditional CPU, RAM, and storage fields for desktop/laptop devices.
- Safe asset retirement with reason capture, movement-history logging, and safeguards for assigned or maintenance assets.
- Chronological asset movement register connected from the main navigation.
- Office directory with Firestore listing, search, and office creation.
- Custody records with transactional asset assignment and status update.
- Live inventory summary by status and device category.
- Firebase initialization with a clear setup error screen.
- Firestore starter rules with admin-only writes, no client deletes, and protected audit logs.
- GitHub Actions workflow and model serialization tests.

## Run locally
1. Install the current Flutter stable SDK and Dart.
2. Run `flutter pub get`.
3. Create a dedicated Firebase project for this application.
4. Configure platform Firebase files with `flutterfire configure` and the required native platform setup.
5. Enable Firebase Authentication and Cloud Firestore.
6. Create the initial authorized user profile in `users/{uid}` with role `admin` or `it_manager` using a trusted administrative process.
7. Review and deploy `firestore.rules` only after testing them in the Firebase Emulator.
8. Run `flutter run`.

See [Firebase setup](docs/firebase-setup.md), [architecture](docs/architecture.md), [data dictionary](docs/data-dictionary.md), and [roadmap](docs/roadmap.md).

## Current limitations
- Firebase project credentials and real organization data are intentionally not included.
- Authentication UI, role administration, office-scoped permissions, spare-parts records, and document attachments are not complete.
- Duplicate serial detection currently runs in the client and is not a concurrency-safe uniqueness guarantee.
- Excel/PDF exports and Google Sheets synchronization remain pending.
- The repository has not yet been verified by a production build or deployed to end-user devices.

Do not use real operational data until Firebase is configured, access rules are reviewed, and authorization tests are completed.
