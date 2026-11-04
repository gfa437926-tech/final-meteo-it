# Architecture

## Data ownership
Firestore is the primary application datastore. Google Sheets is an import/export and analysis surface, not the system of record. Google Drive stores scanned receipts, custody documents, photos, and generated reports.

## Collections
- offices
- employees
- assets
- asset_categories
- asset_models
- custody_cards
- custody_items
- asset_movements
- asset_documents
- maintenance_records
- purchase_records
- users
- audit_logs

## Asset identity
Every physical item receives an immutable Asset ID. Serial numbers are indexed and checked for duplicates when present. Office assignment and custodian changes create movement records instead of deleting history.

## Security
Firebase Authentication identifies users. Firestore Security Rules enforce role and office scope. UI hiding is not an authorization mechanism. Generated Firebase configuration and credentials are excluded from Git.

## Status
The initial scaffold uses zero-valued dashboard metrics and has no Firebase connection yet. Real inventory must be imported only after column mapping and duplicate validation.
