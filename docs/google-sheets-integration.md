# Google Sheets integration — implementation contract

## Goal

Provide controlled import and export between the METRA IT Assets register and an explicitly authorized Google spreadsheet. Firestore remains the system of record; Sheets is an exchange/reporting surface, not a second live database.

## Security boundary

- Never place a Google service-account private key, OAuth client secret, refresh token, or Firebase Admin credential in Flutter assets, source code, remote config, or the Git repository.
- Use a trusted server-side integration (Cloud Functions/Cloud Run or another authenticated backend) for Google API calls. The Flutter client requests an operation and receives a job identifier and progress/result summary.
- Authorize each operation against the caller's Firebase UID, active user profile, role, and permitted office scope. Until office-scoped authorization is implemented, restrict integration operations to explicitly approved admin accounts.
- Keep spreadsheet IDs and allowed worksheet names in server-side configuration. Use least-privilege Google scopes and share only the designated workbook with the integration identity.
- Store secrets in Secret Manager or the hosting platform's managed secret store. Rotate credentials and document revocation.
- Record an append-only integration audit event: actor UID, operation, spreadsheet ID (not credentials), worksheet, started/completed timestamps, counts, validation failures, and outcome.

## Import workflow

1. Admin selects a pre-authorized spreadsheet and worksheet; the backend verifies it against an allowlist.
2. Backend reads the header row and maps columns to a versioned import schema. Unknown columns are ignored only when configured; required columns must be present.
3. Parse into a staging batch. Normalize serial numbers (trim + uppercase), category/status values, office references, dates, and currency/number fields.
4. Validate every row before writing: required fields, allowed enum values, valid office reference, date/number ranges, serial uniqueness within the batch, and conflicts with existing asset serial reservations.
5. Return a preview with insert/update/reject counts and row-level Arabic error messages. No Firestore writes occur before explicit confirmation.
6. On confirmation, process bounded batches with idempotency keys and transactional serial reservations. Never overwrite an existing asset merely because its serial matches; updates require an explicit matching stable asset ID and a separately authorized update mode.
7. Persist the import job result and audit summary. Failed rows remain downloadable as a rejection report; retrying a completed job must not duplicate records.

## Export workflow

- Export only fields authorized for the requesting user and selected office scope.
- Exclude secrets, authentication identifiers, private attachment URLs, and unnecessary personal information.
- Produce a timestamped snapshot with schema version and stable asset IDs. Mark the export as a point-in-time report; do not imply continuous synchronization.
- Audit who exported, which scope, row count, and destination. Do not write files to arbitrary spreadsheet IDs supplied by the client.

## Data mapping baseline

| METRA field | Suggested sheet column | Validation |
|---|---|---|
| stable asset ID | Asset ID | Required for update matching; immutable |
| serial number | Serial Number | Required; normalized unique value |
| category | Category | Must match configured category code |
| brand | Brand | Trimmed text |
| model | Model | Trimmed text |
| office ID | Office ID | Must reference an existing active office |
| office name | Office | Display-only; server resolves from office ID |
| status | Status | Controlled lifecycle enum; imported transitions restricted |
| received date | Received Date | ISO-8601 date |
| purchase cost | Purchase Cost | Non-negative decimal and explicit currency |

The actual column names and fields must be reconciled with the current Dart model before implementation. This table is a contract proposal, not a claim that the import/export feature is already implemented.

## Acceptance criteria

- Unauthorized, inactive, or out-of-scope users cannot start, inspect, or download a job.
- No Google or Firebase privileged credential is present in the client or repository.
- Preview is side-effect free.
- Duplicate serials and invalid office references are rejected with row numbers.
- Replaying the same confirmed job is idempotent.
- A mid-job failure can be resumed safely without duplicating successful rows.
- Export respects field-level and office-level permissions.
- Emulator/integration tests cover authorization, validation, duplicate handling, retries, and audit events.