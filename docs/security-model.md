# Security model (current implementation)

## Authentication and profiles

- Firebase Authentication uses Email/Password.
- Every authenticated user must have a matching `users/{uid}` Firestore profile with `isActive: true`.
- The application currently admits only `admin` and `it_manager` roles.
- A super administrator (`admin`) can create and update profile documents for other Firebase Authentication accounts.
- The application does not create Authentication accounts or passwords. Create accounts through a trusted Firebase Admin SDK process or the Firebase Console, then register their UID in the application.
- Users may update only their own `displayName`, `email`, and `updatedAt` profile fields; name/email must remain strings and `updatedAt` must be a Firestore timestamp. They cannot change their own role or active state. New profiles require a supported role, boolean active flag, string name/email, and timestamp creation metadata; optional update metadata must also be a timestamp.
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
- Maintenance completion reads the persisted ticket and asset state instead of trusting the screen's stale record object.

## Release limitations

This is a baseline for development and controlled pre-pilot validation, not a complete enterprise authorization model. Office-scoped roles and trusted server-side account provisioning remain unimplemented. Firestore/Storage Emulator authorization tests now run in CI, but production Firebase configuration/deployment, backup execution and restore drills, and production monitoring remain required before operational use.


## Firestore rule hardening

- The `isAdmin` and `isSuperAdmin` predicates require an active profile as well as the corresponding role.
- Inventory, office, custody, maintenance, purchase, movement, spare-parts, and parts-usage reads require an active profile.
- Spare-part stock can be created/updated by active admin/IT-manager accounts; usage events can be created but not edited or deleted by clients.
- Firestore and Storage Emulator tests are maintained in `test/firestore.rules.test.mjs` and run in a separate GitHub Actions job. The latest verified run (#249, commit `3c017d5a`) passed both this job and Flutter analysis/unit tests, including valid/invalid completed, partial, and failed import-batch summaries. Recheck the latest run before any rules deployment.


## File attachment controls

- Asset documents are stored in Firebase Storage under an asset-specific path; Firestore stores metadata and the storage path, not a public download-token URL.
- Storage reads require an active user profile; uploads require an active `admin` or `it_manager` profile.
- Upload rules restrict content types and enforce a 10 MB limit. Client-side upload and download are performed through authenticated Firebase Storage SDK calls.
- Storage updates and deletes are denied from the client. Deploy and verify `storage.rules` before enabling this feature.


## Custody approval workflow

- New custody cards are created with `approvalStatus: pending`; the asset is reserved as assigned in the same transaction to prevent a second active handover.
- An active admin/IT-manager can approve a pending card. The approval actor and server timestamp are recorded, and an immutable movement event is added.
- Rejection requires the card to remain pending and the linked asset to remain assigned. The transaction closes the card, restores the asset to available, records the rejection actor/reason, and writes a movement event.
- Pending cards cannot be returned or transferred. Legacy cards without an approval field are treated as approved for compatibility.
- Current approval permission is shared by admin and IT-manager roles; separation-of-duties and office-scoped approvers remain future authorization work.


## Printable custody records

The custody register can generate a self-contained Arabic RTL A4 HTML handover form for each card. The form escapes all user-supplied values before embedding them, includes custody and asset identifiers, employee/office details, current approval/return state, a receipt declaration, and signature/approval spaces. The generated HTML is shared as a file so it can be opened in a browser and printed; it is not a signed digital approval or a PDF archive.


## CSV import audit

CSV import writes an `import_batches/{batchId}` outcome record containing the initiating UID, source filename, row totals, success/failure counts, and row-level errors. Firestore rules bind `createdBy` to the authenticated actor and make the record append-only. The import itself is sequential; a batch record summarizes the result and does not imply all-or-nothing rollback.


## Import batch audit integrity

- Import batch documents are actor-bound to the authenticated administrator and are append-only.
- Firestore rules require the complete, allowlisted audit schema, typed timestamps and counters, a bounded source filename, and no more than 100 row errors.
- The rules verify the arithmetic invariants: attempted rows plus skipped invalid rows equal total rows, and successful plus failed rows equal attempted rows.
- The status must agree with the outcome counters (`completed`, `partial`, or `failed`). Updates and deletes are denied.
- These controls validate the audit summary; they do not make the CSV import itself an all-or-nothing transaction.
