# Security model (current implementation)

## Authentication and profiles

- Firebase Authentication uses Email/Password.
- Every authenticated user must have a matching `users/{uid}` Firestore profile with `isActive: true` before accessing inventory data.
- The application currently admits only `admin` and `it_manager` roles.
- A super administrator (`admin`) can create and update profile documents for other Firebase Authentication accounts.
- The application does not create Authentication accounts or passwords. Create accounts through the approved identity-admin process, then register their UID in the application or use the guarded create-only CLI in `scripts/provision-user.mjs`.
- Active users may update only their own `displayName`, `email`, and `updatedAt` profile fields; inactive accounts cannot use self-service profile updates, and users cannot change their own role, active state, or `officeIds`.
- A global administrator profile stores `officeIds: []`; an IT manager profile must have 1–20 office IDs. Legacy profiles without `officeIds` remain readable but have no office access until assigned by a super administrator.
- Only the super administrator can provision users or assign/change their `officeIds`.
- User deletion is disabled from the client.

## Current permission matrix

| Capability | admin | it_manager |
|---|---:|---:|
| Sign in when active | Yes | Yes |
| Read all offices and assets, including legacy unassigned assets | Yes | No |
| Read assigned offices and assets only | Yes | Yes |
| Create/update assets in an assigned active office | Yes | Yes |
| Transfer an asset between offices | Yes | Only when assigned to both source and destination |
| Create/update office catalogue records | Yes | No |
| Read linked custody cards, asset documents, maintenance-part usage and movement records | All offices | Only through assigned assets/offices |
| Read/write spare-parts stock | All records | Only records carrying an assigned `officeId` |
| Manage other user profiles and assign offices | Yes | No |
| Disable another account | Yes | No |
| Change own role, active state or office assignments | No | No |

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
- Office and asset reads are office-scoped in Firestore. An asset without `officeId` is legacy/unassigned and is visible only to the global administrator.
- Asset creates and updates require an active assigned office for IT managers. An update must be authorized for both the old and new office; a transfer therefore requires access to both offices.
- Office catalogue creation and updates are restricted to the global administrator; office deletion remains disabled.
- Serial indexes, movement records, custody cards, Firestore attachment metadata, and maintenance-part usage are linked to the asset office. Storage reads/uploads resolve the asset document and enforce the same office check.
- Spare-parts stock is scoped by its own `officeId`; records without an office remain admin-only. Shared lookup catalogues remain available to active users.
- Import batch audit records are actor-bound, schema-validated, bounded to 100 rows, and append-only; this audit area remains role-based rather than office-scoped.
- Emulator tests cover authentication/profile gates, office A/B isolation, scoped queries, dual-office transfer, custody/document metadata, Storage access, role elevation, and import audit validation.

## Release limitations and production gates

This remains a development and controlled pre-pilot baseline, not a production-ready enterprise authorization model.

1. **Firebase project and web app:** create/select a dedicated Firebase project for this IT inventory app, register its Web app, and set the six documented GitHub Actions repository Variables. The Pages workflow currently builds and deploys a deliberate setup screen when these values are absent; a successful Pages deployment does not prove Firebase connectivity.
2. **Rules deployment:** review the selected Firebase project ID, run the emulator suite, then deploy Firestore and Storage rules only to the dedicated inventory project. No production rules have been deployed by this repository workflow.
3. **Authorization completion:** office scoping is implemented in this branch for offices, assets, serial indexes, movements, linked custody/document/maintenance-part records, spare-parts records with `officeId`, and Storage attachments. Do not merge/deploy until CI passes and the PR is reviewed. `maintenance_records` and `purchase_records` remain denied to client access until their office/asset linkage and rules are implemented. Legacy IT-manager profiles must be assigned offices by the super administrator before access is restored. A trusted create-only profile provisioning CLI remains available; Authentication account creation is a separate identity-admin operation.
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
