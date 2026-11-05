# Security model (current implementation)

## Authentication and profiles

- Firebase Authentication uses Email/Password.
- Every authenticated user must have a matching `users/{uid}` Firestore profile with `isActive: true` before accessing inventory data.
- The application currently admits only `admin` and `it_manager` roles.
- A super administrator (`admin`) can create and update profile documents for other Firebase Authentication accounts.
- The application does not create Authentication accounts or passwords. Create accounts through a trusted Firebase Admin SDK process or the Firebase Console, then register their UID in the application.
- Users may update only their own `displayName`, `email`, and `updatedAt` profile fields; they cannot change their own role or active state.
- User deletion is disabled from the client.

## Current permission matrix

| Capability | admin | it_manager |
|---|---:|---:|
| Sign in when active | Yes | Yes |
| Read inventory and movement data | Yes | Yes |
| Create/update assets, offices, custody and maintenance records | Yes | Yes |
| Manage other user profiles and roles | Yes | No |
| Disable another account | Yes | No |
| Change own role or active state | No | No |

## Data integrity

- Asset creation and serial reservation are committed in the same Firestore transaction.
- Serial values are trimmed and uppercased before indexing and persistence.
- Existing legacy assets are scanned before new reservations; editing a legacy asset can lazily create its missing serial reservation.
- Custody assignment, return, transfer, asset office transfer, retirement, and maintenance state changes use Firestore transactions and write movement history.
- Custody approval requires the authenticated approver UID, a timestamp-valued approval time, an active pending card, and an asset that remains assigned after the transaction.
- Custody rejection requires an active pending card, typed rejection metadata, and atomic release of the assigned asset.
- Custody return requires an active approved card and atomic restoration of the asset to available; transfer requires non-empty employee/office values and a matching post-transaction asset office.
- Maintenance completion reads the persisted ticket and asset state instead of trusting the screen's stale record object.

## Firestore and Storage controls

- Administrative predicates require an authenticated user with an active profile and an allowed role.
- Inventory reads require an active profile; administrative writes require an active admin/IT-manager profile.
- User role elevation is blocked by rules; only a super administrator can manage another user's profile.
- Import batch audit records are actor-bound, schema-validated, bounded to 100 rows, and append-only.
- Asset attachments are private, limited to approved MIME types and less than 10 MB; client updates and deletes are denied.
- Emulator tests cover authentication/profile gates, role elevation, custody atomicity, import audit validation, and Storage access restrictions.

## Release limitations and production gates

This remains a development and controlled pre-pilot baseline, not a production-ready enterprise authorization model.

1. **Firebase project and web app:** create/select a dedicated Firebase project for this IT inventory app, register its Web app, and set the six documented GitHub Actions repository Variables. The Pages workflow currently builds and deploys a deliberate setup screen when these values are absent; a successful Pages deployment does not prove Firebase connectivity.
2. **Rules deployment:** review the selected Firebase project ID, run the emulator suite, then deploy Firestore and Storage rules only to the dedicated inventory project. No production rules have been deployed by this repository workflow.
3. **Authorization:** office-scoped roles, office-level data isolation, and trusted server-side account provisioning remain unimplemented. Current rules allow active admin/IT-manager accounts broad inventory access.
4. **App Check and privileged sign-in:** configure and verify App Check per supported platform, enforce MFA for privileged accounts where supported, and test all production clients before enforcement.
5. **Data operations:** complete the serial reservation backfill, configure scheduled backups, and perform a documented restore drill before bulk import.
6. **Operational validation:** configure monitoring/alerts and verify Android, Windows, and Web builds on real target devices.

Never reuse or deploy to a meteorological production Firebase project. Never put service-account JSON, private keys, or Admin SDK credentials in the Flutter client, GitHub Variables, or repository.

## GitHub Pages web configuration

The Pages workflow reads these repository Actions Variables:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`

Set them under repository Settings → Secrets and variables → Actions → Variables using the Web app configuration from the dedicated inventory Firebase project. These are client configuration identifiers, not Admin SDK credentials.

Until all six values are configured, the deployed site intentionally shows a Firebase setup screen. Native Android/Windows builds require their own FlutterFire platform configuration. This setup does not create a Firebase project, enable services, provision users, or deploy security rules.
