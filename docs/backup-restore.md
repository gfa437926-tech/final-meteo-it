# Backup and restore runbook

This runbook is for the dedicated production Firebase project created specifically for the IT asset inventory application. Never substitute a legacy METRA/weather project ID. Keep backup buckets in the same approved organization and region policy, with access restricted to designated administrators.

## Before the first backup

1. Confirm the Firebase project ID from the project owner and verify it in the Firebase Console.
2. Enable billing and the required Firestore, Cloud Storage, and Cloud Scheduler services.
3. Create a separate Cloud Storage backup bucket with uniform bucket-level access, public access prevention, and an approved retention/lifecycle policy.
4. Grant the backup operator only the roles required to export/import Firestore and copy Storage objects. Do not use owner credentials for scheduled jobs.
5. Store the project ID, bucket name, retention duration, and recovery contacts in the organization's secret manager/runbook, never in Flutter source code or this repository.

## Firestore export

Run from a trusted administrative environment with Google Cloud CLI authenticated as the approved backup operator:

```bash
gcloud config set project YOUR_DEDICATED_FIREBASE_PROJECT_ID
gcloud firestore export gs://YOUR_BACKUP_BUCKET/firestore/$(date -u +%Y%m%dT%H%M%SZ)
```

Use a new timestamped prefix for each backup. Do not overwrite an existing export. Record the operation result and verify that export metadata and data files exist in the destination bucket.

## Cloud Storage attachment backup

Copy the Firebase Storage bucket to a separate backup prefix. Confirm the actual bucket name in Firebase Console before running:

```bash
gcloud storage rsync --recursive gs://YOUR_FIREBASE_STORAGE_BUCKET gs://YOUR_BACKUP_BUCKET/storage/YYYYMMDD
```

For production, use a dedicated scheduled service identity, retention controls, object versioning/retention policy where appropriate, and monitoring for failed or incomplete syncs. Do not make either bucket public.

## Restore procedure

1. Declare an incident and stop writes to the application while the restore is being prepared.
2. Confirm the destination project and obtain approval from the system owner. A restore overwrites/imports data and must never target an old METRA database.
3. Restore Firestore from the selected timestamped export:

```bash
gcloud config set project YOUR_DEDICATED_FIREBASE_PROJECT_ID
gcloud firestore import gs://YOUR_BACKUP_BUCKET/firestore/EXPORT_PREFIX
```

4. Restore Storage objects to the verified Firebase bucket:

```bash
gcloud storage rsync --recursive gs://YOUR_BACKUP_BUCKET/storage/YYYYMMDD gs://YOUR_FIREBASE_STORAGE_BUCKET
```

5. Re-apply and verify Firestore/Storage security rules, indexes, authentication settings, and App Check configuration separately. A Firestore data export is not a replacement for rules or index configuration.
6. Verify sign-in, role documents, asset serial reservations, custody transactions, attachments, and report screens with a controlled test account.
7. Re-enable writes only after the owner approves the verification results.

## Recovery limitations and operational controls

- Firestore export/import does not back up Firebase Authentication users, security rules, indexes, app secrets, or deployment configuration. Maintain separate approved recovery procedures for these.
- A Storage rsync is not an immutable point-in-time snapshot unless the bucket's versioning/retention controls provide that guarantee.
- This repository does not configure or execute production backups. Set up Cloud Scheduler/Cloud Run or an approved backup product, alerting, and a recurring restore drill in the actual Firebase/GCP project.
- Never commit service-account JSON, OAuth client secrets, production exports, real inventory data, or employee personal information.
- Define and test RPO/RTO with the system owner before operational launch.
