# Delivery roadmap

## Completed in the repository

- [x] Initial repository and Flutter scaffold
- [x] Arabic RTL dashboard shell and Material 3 theme
- [x] Asset and office data models with serialization
- [x] Firestore asset repository and live asset register
- [x] Asset create/edit forms with basic computer specifications
- [x] Asset search and category/status filters
- [x] Office directory, create/update flow, and search
- [x] Email/password sign-in and active-profile access gate
- [x] Admin/IT-manager role handling and super-admin profile management for existing Firebase Authentication accounts
- [x] Transactional custody assignment, return, and employee transfer
- [x] Transactional asset transfer between active offices
- [x] Asset movement history and retirement audit events
- [x] Transactional serial reservation and duplicate checks (legacy index backfill remains pending)
- [x] QR label generation, PDF label printing, and camera scanning
- [x] Maintenance ticket creation and completion with asset status transitions
- [x] Purchase invoice, supplier, amount, purchase date, and warranty tracking
- [x] Live inventory summary and Arabic CSV copy/export
- [x] Starter Firestore rules and Firebase/security setup documentation
- [x] GitHub Actions workflow and model serialization tests

## Remaining before operational pilot

- [ ] Verify latest CI run and retain its result against the release candidate
- [ ] Configure the dedicated Firebase project and native platform files
- [ ] Implement trusted server-side account provisioning
- [ ] Implement office-scoped roles and data access
- [ ] Add printable custody forms and custody approval workflow
- [ ] Add service-history views and spare-parts records
- [ ] Add invoice/document file attachments and receipt workflow
- [ ] Add downloadable Excel/CSV/PDF exports and filtered office/asset reports
- [ ] Add Google Sheets import/export with validation and audit trail
- [ ] Add Firebase Emulator security-rule tests and backup/restore procedures
- [ ] Backfill the asset serial reservation index for legacy inventory
- [ ] Build and verify Android, Windows, and Web targets; package release artifacts
- [ ] Complete end-to-end pilot and security acceptance testing

## Latest repository verification

The latest recorded workflow for commit `77dabe142c2a92982b338e14cde44c2d688f853d` completed successfully: Flutter dependency resolution, `flutter analyze` (no issues), and all 11 tests passed. This is CI verification only; it does not replace Firebase Emulator tests or device builds.

## Release gate

The app is not production-ready until Firebase is configured, authorization rules are tested, CI passes on the final release candidate, backups and recovery are defined, and release builds are installed and verified on target devices.
