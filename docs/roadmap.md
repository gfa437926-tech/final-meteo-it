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
- [ ] Implement sign-in, user provisioning, role management, and office-scoped permissions
- [ ] Add asset editing, retirement, barcode/QR identifiers, and stronger duplicate-serial enforcement
- [ ] Add custody return, transfer, printable custody forms, and approval flow
- [x] Add maintenance ticket model, live register, and transactional ticket creation with asset status/movement updates
- [x] Add maintenance completion workflow, resolution/cost capture, asset status restoration, and movement history
- [ ] Add service history views and spare-parts records
- [ ] Add purchase/receipt records, warranties, invoices, and file attachments
- [ ] Add office/asset reports and Excel/CSV/PDF exports
- [ ] Add Google Sheets import/export with validation and audit trail
- [ ] Add Firebase Emulator security tests and backup/restore procedures
- [ ] Build and verify Android, Windows, and Web targets; package release artifacts

## Release gate
The app is not production-ready until Firebase is configured, authorization rules are tested, CI passes on the final commit, and a release build is installed and verified on target devices.
