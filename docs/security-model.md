# Security model (current implementation)

## Authentication and profiles

- Firebase Authentication uses Email/Password.
- Every authenticated user must have a matching `users/{uid}` Firestore profile with `isActive: true`.
- The application currently admits only `admin` and `it_manager` roles.
- A super administrator (`admin`) can create and update profile documents for other Firebase Authentication accounts.
- The application does not create Authentication accounts or passwords. Create accounts through a trusted Firebase Admin SDK process or the Firebase Console, then register their UID in the application.
- Users may update only their own `displayName`, `email`, and `updatedAt` profile fields. They cannot change their own role or active state.
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

This is a baseline for a controlled pilot, not a complete enterprise authorization model. Office-scoped roles, trusted server-side account provisioning, Firebase Emulator rules tests, backups, and production monitoring remain required before wider deployment.


## Spare-parts transaction boundary

- Spare-part stock documents may be created and updated only by authorized admin/IT-manager profiles; client deletes are denied.
- A maintenance-parts usage document is append-only from the client rules perspective. It is created in the same Firestore transaction that decrements stock and adds the consumed parts cost to the open maintenance ticket.
- Firebase Emulator tests are still required before deploying these rules to a production Firebase project.
