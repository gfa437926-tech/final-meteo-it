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
import { ref as storageRef, uploadBytes, getBytes, deleteObject } from 'firebase/storage';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-metra-it-assets',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
    storage: {
      rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8'),
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
    await setDoc(doc(db, 'assets', 'asset-2'), {
      brand: 'Lenovo', model: 'ThinkCentre', status: 'assigned',
      officeName: 'تقنية المعلومات',
    });
    await setDoc(doc(db, 'custody_cards', 'card-2'), {
      assetId: 'asset-2', assetLabel: 'Lenovo ThinkCentre',
      employeeName: 'Test Employee', officeName: 'تقنية المعلومات',
      status: 'active', approvalStatus: 'pending',
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

test('only a super administrator can provision another user profile', async () => {
  const managerDb = env.authenticatedContext('manager-1').firestore();
  await assertFails(setDoc(doc(managerDb, 'users', 'new-user'), {
    role: 'it_manager', isActive: true, displayName: 'New User', email: 'new@example.com', createdAt: 1,
  }));

  const adminDb = env.authenticatedContext('admin-1').firestore();
  await assertSucceeds(setDoc(doc(adminDb, 'users', 'new-user'), {
    role: 'it_manager',
    isActive: true,
    displayName: 'New User',
    email: 'new@example.com',
    createdAt: new Date(),
  }));
});

test('users can edit only string profile fields and timestamp metadata', async () => {
  const db = env.authenticatedContext('manager-1').firestore();
  await assertFails(updateDoc(doc(db, 'users', 'manager-1'), {
    displayName: { forged: true },
  }));
  await assertFails(updateDoc(doc(db, 'users', 'manager-1'), {
    email: 42,
  }));
  await assertFails(updateDoc(doc(db, 'users', 'manager-1'), {
    updatedAt: 'not-a-timestamp',
  }));
  await assertSucceeds(updateDoc(doc(db, 'users', 'manager-1'), {
    displayName: 'Updated Manager',
    updatedAt: new Date(),
  }));
});

test('super administrator cannot change own role or active state', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  await assertFails(updateDoc(doc(db, 'users', 'admin-1'), {
    role: 'it_manager',
  }));
  await assertFails(updateDoc(doc(db, 'users', 'admin-1'), {
    isActive: false,
  }));
});

test('inactive administrator cannot provision or modify user profiles', async () => {
  const db = env.authenticatedContext('inactive-1').firestore();
  await assertFails(setDoc(doc(db, 'users', 'new-user'), {
    role: 'it_manager', isActive: true, displayName: 'New User',
  }));
  await assertFails(updateDoc(doc(db, 'users', 'manager-1'), {
    isActive: false,
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
  const db = env.authenticatedContext('admin-1').firestore();
  await assertFails(updateDoc(doc(db, 'custody_cards', 'card-2'), {
    approvalStatus: 'approved',
    approvedBy: 'another-user',
    approvedAt: new Date(),
  }));
  await assertSucceeds(updateDoc(doc(db, 'custody_cards', 'card-2'), {
    approvalStatus: 'approved',
    approvedBy: 'admin-1',
    approvedAt: new Date(),
  }));
});

test('rejection must close the card and release its assigned asset atomically', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  await assertSucceeds(runTransaction(db, async (tx) => {
    tx.update(doc(db, 'assets', 'asset-2'), { status: 'available' });
    tx.update(doc(db, 'custody_cards', 'card-2'), {
      status: 'rejected',
      approvalStatus: 'rejected',
      rejectedBy: 'admin-1',
      rejectedAt: new Date().toISOString(),
      rejectionReason: 'Invalid request',
    });
  }));
  const asset = await getDoc(doc(db, 'assets', 'asset-2'));
  assert.equal(asset.data().status, 'available');
});


test('import batch audit records are append-only and actor-bound', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  await assertFails(setDoc(doc(db, 'import_batches', 'forged'), {
    createdBy: 'manager-1',
    status: 'completed',
    succeededRows: 4,
  }));
  await assertSucceeds(setDoc(doc(db, 'import_batches', 'batch-1'), {
    createdBy: 'admin-1',
    status: 'completed',
    succeededRows: 4,
    failedRows: 0,
  }));
  await assertFails(updateDoc(doc(db, 'import_batches', 'batch-1'), {
    succeededRows: 500,
  }));
});

test('active users can read private asset attachments', async () => {
  const adminStorage = env.authenticatedContext('admin-1').storage();
  const file = storageRef(adminStorage, 'asset_documents/asset-1/sample.pdf');
  await assertSucceeds(uploadBytes(file, new Uint8Array([37, 80, 68, 70]), {
    contentType: 'application/pdf',
  }));
  const activeStorage = env.authenticatedContext('manager-1').storage();
  await assertSucceeds(getBytes(storageRef(activeStorage, 'asset_documents/asset-1/sample.pdf')));
  const inactiveStorage = env.authenticatedContext('inactive-1').storage();
  await assertFails(getBytes(storageRef(inactiveStorage, 'asset_documents/asset-1/sample.pdf')));
  await assertFails(uploadBytes(file, new Uint8Array([1, 2]), {
    contentType: 'application/pdf',
  }));
  await assertFails(deleteObject(file));
});

test('unauthenticated users cannot read asset attachments', async () => {
  const adminStorage = env.authenticatedContext('admin-1').storage();
  const file = storageRef(adminStorage, 'asset_documents/asset-1/private.pdf');
  await assertSucceeds(uploadBytes(file, new Uint8Array([1, 2, 3]), {
    contentType: 'application/pdf',
  }));
  const publicStorage = env.unauthenticatedContext().storage();
  await assertFails(getBytes(storageRef(publicStorage, 'asset_documents/asset-1/private.pdf')));
});

test('storage uploads reject unsupported content types', async () => {
  const adminStorage = env.authenticatedContext('admin-1').storage();
  const file = storageRef(adminStorage, 'asset_documents/asset-1/malware.exe');
  await assertFails(uploadBytes(file, new Uint8Array([1, 2, 3]), {
    contentType: 'application/x-msdownload',
  }));
});


test('user profile creation rejects unsupported roles and unexpected fields', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  await assertFails(setDoc(doc(db, 'users', 'bad-role'), {
    role: 'superuser', isActive: true, displayName: 'Bad Role',
    email: 'bad@example.com', createdAt: 1,
  }));
  await assertFails(setDoc(doc(db, 'users', 'extra-field'), {
    role: 'it_manager', isActive: true, displayName: 'Extra Field',
    email: 'extra@example.com', createdAt: 1, password: 'must-not-be-stored',
  }));
});

test('administrator profile updates reject unexpected privilege fields', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  await assertFails(updateDoc(doc(db, 'users', 'manager-1'), {
    role: 'it_manager', isActive: true, isRoot: true,
  }));
  await assertFails(updateDoc(doc(db, 'users', 'manager-1'), {
    role: 'superuser',
  }));
  await assertSucceeds(updateDoc(doc(db, 'users', 'manager-1'), {
    displayName: 'Updated Manager', role: 'it_manager', isActive: true,
  }));
});
