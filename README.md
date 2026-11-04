# METRA IT Assets

Arabic-first Flutter/Dart application for managing IT equipment inventory, office locations, purchase records, maintenance, and employee custody for a meteorological organization.

## Implemented foundation

- Flutter Material 3 application shell with Arabic RTL layout.
- Firebase initialization with an explicit setup/error state.
- Email/password sign-in and an authentication gate requiring an active Firestore user profile.
- Admin and IT-manager roles, with a user-profile management screen for existing Firebase Authentication accounts.
- Firestore asset register with search, category/status filters, and live inventory summaries.
- Asset creation/editing, conditional computer specifications, serial normalization, and transactional serial reservations.
- Safe asset retirement with reason capture and movement-history logging.
- Office directory with search and create/update support.
- Custody assignment, return, employee transfer, and asset transfer with transactional status updates and movement history.
- QR label generation, PDF label printing, and camera scanning by asset ID/serial.
- Maintenance ticket creation and completion with transactional asset status changes and movement history.
- Purchase invoice, supplier, purchase date, amount, and warranty-expiry records linked to assets.
- Chronological asset movement register and Arabic CSV report copy/export.
- Starter Firestore rules, security documentation, GitHub Actions, and model serialization tests.

## Run locally

1. Install the current Flutter stable SDK and Dart.
2. Run `flutter pub get`.
3. Create a dedicated Firebase project for this application.
4. Configure platform Firebase files with `flutterfire configure` and complete native platform setup.
5. Enable Firebase Authentication (Email/Password) and Cloud Firestore.
6. Provision the first administrator profile through the trusted Firebase Console/Admin SDK process described in [Firebase setup](docs/firebase-setup.md).
7. Review and test `firestore.rules` in the Firebase Emulator before deploying them.
8. Run `flutter run`.

See [Firebase setup](docs/firebase-setup.md), [architecture](docs/architecture.md), [data dictionary](docs/data-dictionary.md), [security model](docs/security-model.md), and [roadmap](docs/roadmap.md).

## Remaining before operational pilot

- Office-scoped roles and per-office data access; current application roles are global admin/IT-manager roles.
- Trusted server-side account provisioning and stronger administrative audit trail.
- Printable custody forms and custody approval workflow.
- Service-history views, spare-parts records, and invoice/document attachments.
- Downloadable filtered Excel/PDF reports and Google Sheets/Drive synchronization.
- Firebase Emulator security-rule tests, legacy serial-index backfill, and backup/restore procedures.
- Firebase project configuration, platform builds, and verification on Android, Windows, and Web.

The repository CI currently runs Flutter analysis and model tests. The application is not production-ready until Firebase is configured, authorization rules are tested, backups are defined, and release builds are installed and verified on target devices.

Do not use real operational data until Firebase is configured, access rules are reviewed, and authorization tests are completed.
