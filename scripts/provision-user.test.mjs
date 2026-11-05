import test from 'node:test';
import assert from 'node:assert/strict';
import { validateProvisioningInput } from './provision-user-validation.mjs';

const valid = {
  projectId: 'metra-it-assets-2026',
  confirmation: 'metra-it-assets-2026',
  uid: 'firebase-auth-uid_123',
  displayName: 'Inventory Manager',
  email: 'MANAGER@EXAMPLE.COM',
  role: 'it_manager',
};

test('accepts a valid manager profile and normalizes email', () => {
  assert.deepEqual(validateProvisioningInput(valid), {
    projectId: valid.projectId,
    uid: valid.uid,
    displayName: 'Inventory Manager',
    email: 'manager@example.com',
    role: 'it_manager',
  });
});

test('accepts the administrator role', () => {
  assert.equal(validateProvisioningInput({ ...valid, role: 'admin' }).role, 'admin');
});

for (const [name, changes] of [
  ['project mismatch', { confirmation: 'another-project' }],
  ['invalid project id', { projectId: 'Bad_Project' }],
  ['empty UID', { uid: '' }],
  ['UID path injection', { uid: '../users/admin' }],
  ['UID control characters', { uid: 'uid\nforged' }],
  ['oversized UID', { uid: 'u'.repeat(129) }],
  ['empty display name', { displayName: '   ' }],
  ['oversized display name', { displayName: 'x'.repeat(121) }],
  ['invalid email', { email: 'not-an-email' }],
  ['unsupported role', { role: 'superuser' }],
]) {
  test(`rejects ${name} before any network operation`, () => {
    assert.throws(() => validateProvisioningInput({ ...valid, ...changes }));
  });
}
