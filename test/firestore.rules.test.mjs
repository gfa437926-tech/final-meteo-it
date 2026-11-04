import { readFileSync } from 'node:fs';
import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  runTransaction,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-metra-it-assets',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', 'admin-1'), {
      role: 'admin', isActive: true, displayName: 'Admin',
    });
    await setDoc(doc(db, 'users', 'manager-1'), {
      role: 'it_manager', isActive: true, displayName: 'Manager',
    });
    await setDoc(doc(db, 'users', 'inactive-1'), {
      role: 'admin', isActive: false,
    });
    await setDoc(doc(db, 'assets', 'asset-1'), {
      brand: 'Dell', model: 'OptiPlex', status: 'available',
      officeName: 'تقنية المعلومات',
    });
  });
});

after(async () => {
  await env.cleanup();
});

test('inactive profiles cannot read inventory', async () => {
  const db = env.authenticatedContext('inactive-1').firestore();
  await assertFails(getDoc(doc(db, 'assets', 'asset-1')));
});

test('users cannot elevate their own role', async () => {
  const db = env.authenticatedContext('manager-1').firestore();
  await assertFails(updateDoc(doc(db, 'users', 'manager-1'), {
    role: 'admin',
  }));
});

test('custody assignment requires atomic asset reservation and pending approval', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  await assertSucceeds(runTransaction(db, async (tx) => {
    tx.update(doc(db, 'assets', 'asset-1'), { status: 'assigned' });
    tx.set(doc(db, 'custody_cards', 'card-1'), {
      assetId: 'asset-1',
      assetLabel: 'Dell OptiPlex',
      employeeName: 'Test Employee',
      officeName: 'تقنية المعلومات',
      status: 'active',
      approvalStatus: 'pending',
    });
  }));
  await assertFails(setDoc(doc(db, 'custody_cards', 'card-direct'), {
    assetId: 'asset-1',
    status: 'active',
    approvalStatus: 'approved',
  }));
});

test('only the authenticated approver can approve a pending custody card', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'assets', 'asset-1'), {
      status: 'assigned', officeName: 'تقنية المعلومات',
    });
    await setDoc(doc(context.firestore(), 'custody_cards', 'card-1'), {
      assetId: 'asset-1', status: 'active', approvalStatus: 'pending',
    });
  });
  const db = env.authenticatedContext('admin-1').firestore();
  await assertFails(updateDoc(doc(db, 'custody_cards', 'card-1'), {
    approvalStatus: 'approved',
    approvedBy: 'another-user',
    approvedAt: new Date(),
  }));
  await assertSucceeds(updateDoc(doc(db, 'custody_cards', 'card-1'), {
    approvalStatus: 'approved',
    approvedBy: 'admin-1',
    approvedAt: new Date(),
  }));
});

test('rejection must close the card and release its assigned asset atomically', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'assets', 'asset-1'), {
      status: 'assigned', officeName: 'تقنية المعلومات',
    });
    await setDoc(doc(db, 'custody_cards', 'card-1'), {
      assetId: 'asset-1', status: 'active', approvalStatus: 'pending',
    });
  });
  const db = env.authenticatedContext('admin-1').firestore();
  await assertSucceeds(runTransaction(db, async (tx) => {
    tx.update(doc(db, 'assets', 'asset-1'), { status: 'available' });
    tx.update(doc(db, 'custody_cards', 'card-1'), {
      status: 'rejected',
      approvalStatus: 'rejected',
      rejectedBy: 'admin-1',
      rejectedAt: new Date().toISOString(),
      rejectionReason: 'Invalid request',
    });
  }));
  const asset = await getDoc(doc(db, 'assets', 'asset-1'));
  assert.equal(asset.data().status, 'available');
});
