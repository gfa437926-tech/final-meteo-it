# Delivery roadmap

## Completed in the repository
- [x] Initial repository and Flutter scaffold
- [x] Arabic RTL dashboard shell
- [x] Asset and office data models with serialization
- [x] Firestore asset repository and live asset register
- [x] Asset create form with basic computer specifications
- [x] Asset search and category/status filters
- [x] Firestore office directory, create flow, and search
- [x] Custody card creation linked to available assets
- [x] Transactional asset status update on custody assignment
- [x] Asset movement event written when custody is assigned
- [x] Live inventory summary by status and category
- [x] Firebase setup documentation and startup error handling
- [x] Starter Firestore rules; client deletes disabled and audit log writes denied
- [x] GitHub Actions workflow and model tests

## Remaining before operational pilot
- [ ] Verify latest CI run and fix any remaining analyzer/test failures
- [ ] Configure dedicated Firebase project and platform files
- [x] Add email/password sign-in and gate dashboard access by active admin/IT-manager profile
- [x] Add super-admin user profile management for existing Firebase Authentication accounts (admin/IT-manager roles)
- [ ] Implement trusted user provisioning and office-scoped permissions
- [x] Add asset editing and safe retirement with movement history
- [x] Add camera barcode/QR scanning and locate assets by scanned serial or asset ID
- [x] Generate and display QR labels containing stable asset IDs
- [x] Print individual QR labels as PDF from the asset register
- [x] Enforce concurrency-safe serial reservations in Firestore transactions (legacy index backfill remains a deployment task)
- [x] Add transactional custody return, asset status restoration, and movement history
- [x] Add transactional asset transfer between active offices with movement audit
- [x] Add transactional custody transfer between employees with movement audit
- [ ] Add printable custody forms and approval flow
- [x] Add maintenance ticket model, live register, and transactional ticket creation with asset status/movement updates
- [x] Add maintenance completion workflow, resolution/cost capture, asset status restoration, and movement history
- [x] Add chronological asset movement history screen
- [x] Add per-asset maintenance service history with ticket timeline and cumulative costs
- [x] Add spare-parts stock register, low-stock threshold indicators, and transactional issue against open maintenance tickets
- [x] Add purchase invoice records linked to assets, supplier, amount, purchase date, and warranty expiry
- [x] Add asset document upload, metadata register, protected Storage paths, and authenticated file sharing
- [ ] Extend attachments to purchase invoices and receipts
- [x] Add live inventory summary, Arabic CSV clipboard copy, shareable CSV file, Excel workbook export, and category/status filtered reports
- [ ] Add PDF exports and office-specific report filters
- [ ] Add Google Sheets import/export with validation and audit trail
- [ ] Add Firebase Emulator security tests and backup/restore procedures
- [ ] Build and verify Android, Windows, and Web targets; package release artifacts

## Release gate
The app is not production-ready until Firebase is configured, authorization rules are tested, CI passes on the final commit, and a release build is installed and verified on target devices.
