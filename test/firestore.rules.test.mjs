import { readFileSync } from 'node:fs';
import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  collection,
  query,
  where,
  orderBy,
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
      role: 'admin', isActive: true, displayName: 'Admin', officeIds: [],
    });
    await setDoc(doc(db, 'users', 'manager-1'), {
      role: 'it_manager', isActive: true, displayName: 'Manager',
      email: 'manager@example.com', officeIds: ['office-a'],
    });
    await setDoc(doc(db, 'users', 'manager-b'), {
      role: 'it_manager', isActive: true, displayName: 'Manager B',
      email: 'manager-b@example.com', officeIds: ['office-b'],
    });
    await setDoc(doc(db, 'offices', 'office-a'), {
      id: 'office-a', name: 'Office A', isActive: true,
    });
    await setDoc(doc(db, 'offices', 'office-b'), {
      id: 'office-b', name: 'Office B', isActive: true,
    });
    await setDoc(doc(db, 'users', 'inactive-1'), {
      role: 'admin', isActive: false,
    });
    await setDoc(doc(db, 'assets', 'asset-1'), {
      brand: 'Dell', model: 'OptiPlex', status: 'available',
      officeId: 'office-a', officeName: 'Office A',
    });
    await setDoc(doc(db, 'assets', 'asset-2'), {
      brand: 'Lenovo', model: 'ThinkCentre', status: 'assigned',
      officeId: 'office-a', officeName: 'Office A',
    });
    await setDoc(doc(db, 'assets', 'asset-b'), {
      brand: 'HP', model: 'ProDesk', status: 'available',
      officeId: 'office-b', officeName: 'Office B',
    });
    await setDoc(doc(db, 'assets', 'legacy-asset'), {
      brand: 'Legacy', model: 'Unassigned', status: 'available',
    });
    await setDoc(doc(db, 'custody_cards', 'card-2'), {
      assetId: 'asset-2', officeId: 'office-a', assetLabel: 'Lenovo ThinkCentre',
      employeeName: 'Test Employee', officeName: 'Office A',
      status: 'active', approvalStatus: 'pending',
    });
    await setDoc(doc(db, 'custody_cards', 'card-b'), {
      assetId: 'asset-b', officeId: 'office-b', assetLabel: 'HP ProDesk',
      employeeName: 'Office B Employee', officeName: 'Office B',
      status: 'active', approvalStatus: 'pending',
    });
    await setDoc(doc(db, 'asset_documents', 'document-a'), {
      assetId: 'asset-1', officeId: 'office-a',
      fileName: 'office-a.pdf', storagePath: 'asset_documents/asset-1/office-a.pdf',
    });
    await setDoc(doc(db, 'asset_documents', 'document-b'), {
      assetId: 'asset-b', officeId: 'office-b',
      fileName: 'office-b.pdf', storagePath: 'asset_documents/asset-b/office-b.pdf',
    });
    // A forged metadata office must not override the office on the linked asset.
    await setDoc(doc(db, 'asset_documents', 'document-mismatch'), {
      assetId: 'asset-1', officeId: 'office-b',
      fileName: 'forged.pdf', storagePath: 'asset_documents/asset-1/forged.pdf',
    });
  });
});

after(async () => {
  await env.cleanup();
});

test('office records enforce a bounded schema and cannot be deleted', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  const validOffice = {
    id: 'office-1',
    name: 'مكتب الاختبار',
    building: 'المبنى الرئيسي',
    directorate: 'تقنية المعلومات',
    department: 'الدعم',
    room: '12',
    manager: 'مسؤول المكتب',
    phone: '+000000000',
    notes: '',
    isActive: true,
  };

  await assertSucceeds(setDoc(doc(db, 'offices', 'office-1'), validOffice));
  await assertSucceeds(updateDoc(doc(db, 'offices', 'office-1'), {
    name: 'مكتب محدث',
    isActive: false,
  }));
  await assertFails(setDoc(doc(db, 'offices', 'office-extra-field'), {
    ...validOffice,
    id: 'office-extra-field',
    adminOverride: true,
  }));
  await assertFails(setDoc(doc(db, 'offices', 'office-bad-name'), {
    ...validOffice,
    id: 'office-bad-name',
    name: '',
  }));
  await assertFails(setDoc(doc(db, 'offices', 'office-id-mismatch'), {
    ...validOffice,
    id: 'different-id',
  }));
  await assertFails(deleteDoc(doc(db, 'offices', 'office-1')));
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
    role: 'it_manager', isActive: true, displayName: 'New User', officeIds: ['office-a'], email: 'new@example.com', createdAt: 1,
  }));

  const adminDb = env.authenticatedContext('admin-1').firestore();
  await assertSucceeds(setDoc(doc(adminDb, 'users', 'new-user'), {
    role: 'it_manager',
    isActive: true,
    displayName: 'New User',
    email: 'new@example.com',
    officeIds: ['office-a'],
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


test('inactive users cannot update their own profile', async () => {
  const db = env.authenticatedContext('inactive-1').firestore();
  await assertFails(updateDoc(doc(db, 'users', 'inactive-1'), {
    displayName: 'Inactive account edit',
  }));
});

test('active users can update their own permitted profile fields', async () => {
  const db = env.authenticatedContext('manager-1').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users', 'manager-1'), {
    displayName: 'Active account edit',
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
      officeId: 'office-a',
      assetLabel: 'Dell OptiPlex',
      employeeName: 'Test Employee',
      officeName: 'Office A',
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

test('only the authenticated approver can approve a pending custody card with an assigned asset', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  await assertFails(updateDoc(doc(db, 'custody_cards', 'card-2'), {
    approvalStatus: 'approved',
    approvedBy: 'another-user',
    approvedAt: new Date(),
  }));
  await assertFails(updateDoc(doc(db, 'custody_cards', 'card-2'), {
    approvalStatus: 'approved',
    approvedBy: 'admin-1',
    approvedAt: 'not-a-timestamp',
  }));
  await assertFails(runTransaction(db, async (tx) => {
    tx.update(doc(db, 'assets', 'asset-2'), { status: 'available' });
    tx.update(doc(db, 'custody_cards', 'card-2'), {
      approvalStatus: 'approved',
      approvedBy: 'admin-1',
      approvedAt: new Date(),
    });
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


test('import batch audit records validate counts, types, actor and remain append-only', async () => {
  const db = env.authenticatedContext('admin-1').firestore();
  const validBatch = {
    sourceName: 'assets.csv',
    createdBy: 'admin-1',
    createdAt: new Date(),
    completedAt: new Date(),
    totalRows: 4,
    attemptedRows: 4,
    succeededRows: 4,
    failedRows: 0,
    skippedInvalidRows: 0,
    status: 'completed',
    rowErrors: [],
  };
  await assertFails(setDoc(doc(db, 'import_batches', 'forged'), {
    ...validBatch, createdBy: 'manager-1',
  }));
  await assertSucceeds(setDoc(doc(db, 'import_batches', 'batch-1'), validBatch));
  await assertFails(setDoc(doc(db, 'import_batches', 'bad-counts'), {
    ...validBatch, succeededRows: 3,
  }));
  await assertFails(setDoc(doc(db, 'import_batches', 'bad-type'), {
    ...validBatch, totalRows: '4',
  }));
  await assertFails(setDoc(doc(db, 'import_batches', 'extra-field'), {
    ...validBatch, password: 'must-not-be-stored',
  }));
  await assertFails(setDoc(doc(db, 'import_batches', 'negative-count'), {
    ...validBatch, failedRows: -1,
  }));
  await assertFails(setDoc(doc(db, 'import_batches', 'status-mismatch'), {
    ...validBatch, status: 'partial',
  }));
  await assertFails(setDoc(doc(db, 'import_batches', 'error-count-mismatch'), {
    ...validBatch, failedRows: 1, succeededRows: 3, status: 'partial',
  }));
  await assertFails(setDoc(doc(db, 'import_batches', 'too-many-rows'), {
    ...validBatch, totalRows: 101, attemptedRows: 101, succeededRows: 101,
  }));
  await assertSucceeds(setDoc(doc(db, 'import_batches', 'partial-batch'), {
    ...validBatch,
    succeededRows: 3,
    failedRows: 1,
    status: 'partial',
    rowErrors: ['السطر 3: تعذر الحفظ'],
  }));
  await assertSucceeds(setDoc(doc(db, 'import_batches', 'failed-batch'), {
    ...validBatch,
    totalRows: 2,
    attemptedRows: 2,
    succeededRows: 0,
    failedRows: 2,
    status: 'failed',
    rowErrors: ['فشل 1', 'فشل 2'],
  }));
  await assertFails(updateDoc(doc(db, 'import_batches', 'batch-1'), {
    succeededRows: 500,
  }));
  await assertFails(deleteDoc(doc(db, 'import_batches', 'batch-1')));
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
    email: 'bad@example.com', officeIds: ['office-a'], createdAt: 1,
  }));
  await assertFails(setDoc(doc(db, 'users', 'extra-field'), {
    role: 'it_manager', isActive: true, displayName: 'Extra Field',
    email: 'extra@example.com', officeIds: ['office-a'], createdAt: 1, password: 'must-not-be-stored',
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


test('office A manager cannot read or write office B records; admin retains global access', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  const managerB = env.authenticatedContext('manager-b').firestore();
  const admin = env.authenticatedContext('admin-1').firestore();

  await assertSucceeds(getDoc(doc(managerA, 'offices', 'office-a')));
  await assertFails(getDoc(doc(managerA, 'offices', 'office-b')));
  await assertSucceeds(getDoc(doc(managerB, 'offices', 'office-b')));
  await assertFails(getDoc(doc(managerB, 'offices', 'office-a')));
  await assertSucceeds(getDoc(doc(admin, 'offices', 'office-a')));
  await assertSucceeds(getDoc(doc(admin, 'offices', 'office-b')));

  await assertFails(updateDoc(doc(managerA, 'offices', 'office-a'), {
    name: 'Manager cannot administer office catalogue',
  }));
  await assertFails(updateDoc(doc(managerA, 'offices', 'office-b'), {
    name: 'Cross-office write',
  }));
});

test('inactive offices revoke manager access to linked assets and attachments', async () => {
  const admin = env.authenticatedContext('admin-1').firestore();
  const managerStorage = env.authenticatedContext('manager-1').storage();
  const managerDb = env.authenticatedContext('manager-1').firestore();
  const adminStorage = env.authenticatedContext('admin-1').storage();

  const attachment = storageRef(adminStorage, 'asset_documents/asset-1/inactive-office.pdf');
  await assertSucceeds(uploadBytes(attachment, new Uint8Array([1, 2, 3]), {
    contentType: 'application/pdf',
  }));
  await assertSucceeds(getDoc(doc(managerDb, 'assets', 'asset-1')));
  await assertSucceeds(getBytes(storageRef(managerStorage, 'asset_documents/asset-1/inactive-office.pdf')));

  await assertSucceeds(updateDoc(doc(admin, 'offices', 'office-a'), {
    isActive: false,
  }));
  await assertFails(getDoc(doc(managerDb, 'offices', 'office-a')));
  await assertFails(getDoc(doc(managerDb, 'assets', 'asset-1')));
  await assertFails(updateDoc(doc(managerDb, 'assets', 'asset-1'), {
    brand: 'Must not update an inactive-office asset',
  }));
  await assertFails(getBytes(storageRef(managerStorage, 'asset_documents/asset-1/inactive-office.pdf')));
  await assertFails(uploadBytes(
    storageRef(managerStorage, 'asset_documents/asset-1/new-inactive-office.pdf'),
    new Uint8Array([4, 5, 6]),
    { contentType: 'application/pdf' },
  ));
});

test('asset reads and writes are isolated by officeId and legacy records are admin-only', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  const managerB = env.authenticatedContext('manager-b').firestore();
  const admin = env.authenticatedContext('admin-1').firestore();

  await assertSucceeds(getDoc(doc(managerA, 'assets', 'asset-1')));
  await assertFails(getDoc(doc(managerA, 'assets', 'asset-b')));
  await assertFails(getDoc(doc(managerA, 'assets', 'legacy-asset')));
  await assertSucceeds(getDoc(doc(managerB, 'assets', 'asset-b')));
  await assertFails(getDoc(doc(managerB, 'assets', 'asset-1')));
  await assertSucceeds(getDoc(doc(admin, 'assets', 'legacy-asset')));

  await assertSucceeds(updateDoc(doc(managerA, 'assets', 'asset-1'), {
    brand: 'Dell Updated',
  }));
  await assertFails(updateDoc(doc(managerA, 'assets', 'asset-b'), {
    brand: 'Forged cross-office edit',
  }));
  await assertFails(updateDoc(doc(managerA, 'assets', 'asset-1'), {
    officeId: 'office-b',
  }));
  await assertSucceeds(setDoc(doc(managerA, 'assets', 'asset-a-new'), {
    id: 'asset-a-new', brand: 'A', model: 'A1', officeId: 'office-a',
    status: 'available',
  }));
  await assertFails(setDoc(doc(managerA, 'assets', 'asset-b-forged'), {
    id: 'asset-b-forged', brand: 'B', model: 'B1', officeId: 'office-b',
    status: 'available',
  }));
  await assertFails(setDoc(doc(managerA, 'assets', 'asset-unassigned'), {
    id: 'asset-unassigned', brand: 'Legacy', model: 'Unknown',
    status: 'available',
  }));
});

test('office manager cannot change own or another user office assignments', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  const admin = env.authenticatedContext('admin-1').firestore();
  await assertFails(updateDoc(doc(manager, 'users', 'manager-1'), {
    officeIds: ['office-b'],
  }));
  await assertFails(updateDoc(doc(manager, 'users', 'manager-b'), {
    officeIds: ['office-a'],
  }));
  await assertSucceeds(updateDoc(doc(admin, 'users', 'manager-1'), {
    officeIds: ['office-a', 'office-b'],
  }));
  await assertFails(updateDoc(doc(admin, 'users', 'manager-1'), {
    officeIds: [],
  }));
  await assertSucceeds(updateDoc(doc(admin, 'users', 'manager-1'), {
    officeIds: ['office-a'],
  }));
});

test('new user profiles require valid office assignments and admins remain global', async () => {
  const admin = env.authenticatedContext('admin-1').firestore();
  const base = {
    displayName: 'Provisioned', email: 'provisioned@example.com',
    isActive: true, createdAt: new Date(),
  };
  await assertSucceeds(setDoc(doc(admin, 'users', 'new-office-manager'), {
    ...base, role: 'it_manager', officeIds: ['office-a'],
  }));
  await assertFails(setDoc(doc(admin, 'users', 'manager-no-office'), {
    ...base, role: 'it_manager', officeIds: [],
  }));
  await assertFails(setDoc(doc(admin, 'users', 'manager-malformed'), {
    ...base, role: 'it_manager', officeIds: [42],
  }));
  await assertFails(setDoc(doc(admin, 'users', 'admin-with-office'), {
    ...base, role: 'admin', officeIds: ['office-a'],
  }));
  await assertSucceeds(setDoc(doc(admin, 'users', 'global-admin'), {
    ...base, role: 'admin', officeIds: [],
  }));
});

test('storage reads and uploads are authorized through the linked asset office', async () => {
  const adminStorage = env.authenticatedContext('admin-1').storage();
  const fileA = storageRef(adminStorage, 'asset_documents/asset-1/office-a.pdf');
  const fileB = storageRef(adminStorage, 'asset_documents/asset-b/office-b.pdf');
  await assertSucceeds(uploadBytes(fileA, new Uint8Array([1, 2, 3]), {
    contentType: 'application/pdf',
  }));
  await assertSucceeds(uploadBytes(fileB, new Uint8Array([4, 5, 6]), {
    contentType: 'application/pdf',
  }));

  const managerA = env.authenticatedContext('manager-1').storage();
  const managerB = env.authenticatedContext('manager-b').storage();
  await assertSucceeds(getBytes(storageRef(managerA, 'asset_documents/asset-1/office-a.pdf')));
  await assertFails(getBytes(storageRef(managerA, 'asset_documents/asset-b/office-b.pdf')));
  await assertSucceeds(getBytes(storageRef(managerB, 'asset_documents/asset-b/office-b.pdf')));
  await assertFails(getBytes(storageRef(managerB, 'asset_documents/asset-1/office-a.pdf')));

  await assertSucceeds(uploadBytes(
    storageRef(managerA, 'asset_documents/asset-1/manager-upload.pdf'),
    new Uint8Array([7, 8, 9]),
    { contentType: 'application/pdf' },
  ));
  await assertFails(uploadBytes(
    storageRef(managerA, 'asset_documents/asset-b/forbidden-upload.pdf'),
    new Uint8Array([7, 8, 9]),
    { contentType: 'application/pdf' },
  ));
  await assertFails(getBytes(storageRef(managerA, 'asset_documents/missing-asset/no-link.pdf')));
});


test('office-scoped asset queries must prove the manager office constraint', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  const scoped = query(
    collection(managerA, 'assets'),
    where('officeId', '==', 'office-a'),
  );
  await assertSucceeds(getDocs(scoped));
  await assertFails(getDocs(collection(managerA, 'assets')));
});

test('movement records must match the linked asset before and after the transaction', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  await assertSucceeds(setDoc(doc(manager, 'asset_movements', 'valid-movement'), {
    assetId: 'asset-1', officeId: 'office-a',
    movementType: 'maintenance_note', occurredAt: new Date(),
  }));
  await assertFails(setDoc(doc(manager, 'asset_movements', 'missing-office-id'), {
    assetId: 'asset-1', movementType: 'forged', occurredAt: new Date(),
  }));
  await assertFails(setDoc(doc(manager, 'asset_movements', 'forged-asset-movement'), {
    assetId: 'asset-b', officeId: 'office-a',
    movementType: 'forged', occurredAt: new Date(),
  }));
  await assertFails(setDoc(doc(manager, 'asset_movements', 'forged-source'), {
    assetId: 'asset-1', officeId: 'office-a', fromOfficeId: 'office-b',
    movementType: 'forged', occurredAt: new Date(),
  }));
  await assertFails(setDoc(doc(manager, 'asset_movements', 'forged-destination'), {
    assetId: 'asset-1', officeId: 'office-a', toOfficeId: 'office-b',
    movementType: 'forged', occurredAt: new Date(),
  }));
});

test('a transfer requires access to both the source and destination offices', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  await assertFails(updateDoc(doc(managerA, 'assets', 'asset-1'), {
    officeId: 'office-b',
    officeName: 'Office B',
  }));

  const admin = env.authenticatedContext('admin-1').firestore();
  await assertSucceeds(updateDoc(doc(admin, 'users', 'manager-1'), {
    officeIds: ['office-a', 'office-b'],
  }));
  const managerBoth = env.authenticatedContext('manager-1').firestore();
  await assertSucceeds(runTransaction(managerBoth, async (tx) => {
    tx.update(doc(managerBoth, 'assets', 'asset-1'), {
      officeId: 'office-b',
      officeName: 'Office B',
    });
    tx.set(doc(managerBoth, 'asset_movements', 'move-a-to-b'), {
      assetId: 'asset-1',
      officeId: 'office-b',
      fromOfficeId: 'office-a',
      toOfficeId: 'office-b',
      movementType: 'transferred',
      occurredAt: new Date(),
    });
  }));
});


test('custody cards are office-scoped and legacy cards without officeId are admin-only', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  const managerB = env.authenticatedContext('manager-b').firestore();
  const admin = env.authenticatedContext('admin-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'custody_cards', 'legacy-card'), {
      assetId: 'legacy-asset', employeeName: 'Legacy employee',
      officeName: 'Unknown', status: 'active',
    });
  });
  await assertSucceeds(getDocs(query(
    collection(managerA, 'custody_cards'), where('officeId', '==', 'office-a'),
  )));
  await assertFails(getDocs(collection(managerA, 'custody_cards')));
  await assertFails(getDoc(doc(managerA, 'custody_cards', 'card-b')));
  await assertSucceeds(getDoc(doc(managerB, 'custody_cards', 'card-b')));
  await assertFails(getDoc(doc(managerA, 'custody_cards', 'legacy-card')));
  await assertSucceeds(getDoc(doc(admin, 'custody_cards', 'legacy-card')));
  await assertFails(setDoc(doc(managerA, 'custody_cards', 'forged-office-card'), {
    assetId: 'asset-1', officeId: 'office-b', assetLabel: 'Forged',
    employeeName: 'X', officeName: 'Office A', assignedAt: new Date().toISOString(),
    status: 'active', approvalStatus: 'pending',
  }));
});

test('custody cards and Firestore attachment metadata follow the linked asset office', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  const managerB = env.authenticatedContext('manager-b').firestore();
  await assertSucceeds(getDoc(doc(managerA, 'custody_cards', 'card-2')));
  await assertFails(getDoc(doc(managerA, 'custody_cards', 'card-b')));
  await assertSucceeds(getDoc(doc(managerB, 'custody_cards', 'card-b')));
  await assertFails(getDoc(doc(managerB, 'custody_cards', 'card-2')));

  await assertSucceeds(getDoc(doc(managerA, 'asset_documents', 'document-a')));
  await assertFails(getDoc(doc(managerA, 'asset_documents', 'document-b')));
  await assertSucceeds(getDoc(doc(managerB, 'asset_documents', 'document-b')));
  await assertFails(getDoc(doc(managerB, 'asset_documents', 'document-a')));
  await assertFails(getDoc(doc(managerA, 'asset_documents', 'document-mismatch')));
  await assertFails(getDoc(doc(managerB, 'asset_documents', 'document-mismatch')));
  await assertFails(setDoc(doc(managerA, 'asset_documents', 'forged-office'), {
    assetId: 'asset-1',
    officeId: 'office-b',
    fileName: 'forged.pdf',
    storagePath: 'asset_documents/asset-1/forged.pdf',
  }));
});

test('maintenance completion must atomically restore the linked asset status', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'maintenance_records', 'maintenance-completion'), {
      assetId: 'asset-1', officeId: 'office-a', title: 'Atomic completion',
      status: 'open', reportedAt: new Date(), previousAssetStatus: 'available',
    });
    await updateDoc(doc(db, 'assets', 'asset-1'), { status: 'maintenance' });
  });
  await assertFails(updateDoc(doc(manager, 'maintenance_records', 'maintenance-completion'), {
    status: 'completed', resolution: 'Repaired', cost: 10, completedAt: new Date(),
  }));
  await assertSucceeds(runTransaction(manager, async (tx) => {
    tx.update(doc(manager, 'assets', 'asset-1'), { status: 'available' });
    tx.update(doc(manager, 'maintenance_records', 'maintenance-completion'), {
      status: 'completed', resolution: 'Repaired', cost: 10, completedAt: new Date(),
    });
  }));
});

test('maintenance and purchases are isolated by linked asset office', async () => {
  const a = env.authenticatedContext('manager-1').firestore();
  const b = env.authenticatedContext('manager-b').firestore();
  const admin = env.authenticatedContext('admin-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'maintenance_records', 'maintenance-a'), {
      assetId: 'asset-1', officeId: 'office-a', title: 'Office A repair',
      status: 'open', reportedAt: new Date(),
    });
    await setDoc(doc(db, 'maintenance_records', 'maintenance-b'), {
      assetId: 'asset-b', officeId: 'office-b', title: 'Office B repair',
      status: 'open', reportedAt: new Date(),
    });
    await setDoc(doc(db, 'purchase_records', 'purchase-a'), {
      assetId: 'asset-1', officeId: 'office-a', supplier: 'Supplier A',
      purchaseDate: new Date(), totalCost: 10,
    });
    await setDoc(doc(db, 'purchase_records', 'purchase-b'), {
      assetId: 'asset-b', officeId: 'office-b', supplier: 'Supplier B',
      purchaseDate: new Date(), totalCost: 20,
    });
  });
  await assertSucceeds(getDoc(doc(a, 'maintenance_records', 'maintenance-a')));
  await assertFails(getDoc(doc(a, 'maintenance_records', 'maintenance-b')));
  await assertSucceeds(getDoc(doc(b, 'maintenance_records', 'maintenance-b')));
  await assertFails(getDoc(doc(b, 'maintenance_records', 'maintenance-a')));
  await assertSucceeds(getDoc(doc(a, 'purchase_records', 'purchase-a')));
  await assertFails(getDoc(doc(a, 'purchase_records', 'purchase-b')));
  await assertSucceeds(getDoc(doc(b, 'purchase_records', 'purchase-b')));
  await assertFails(getDoc(doc(b, 'purchase_records', 'purchase-a')));
  await assertFails(setDoc(doc(a, 'purchase_records', 'forged'), {
    assetId: 'asset-1', officeId: 'office-b', supplier: 'Forged',
    purchaseDate: new Date(), totalCost: 1,
  }));
  await assertFails(setDoc(doc(a, 'maintenance_records', 'forged'), {
    assetId: 'asset-1', officeId: 'office-b', title: 'Forged',
    status: 'open', reportedAt: new Date(),
  }));
  await assertSucceeds(getDoc(doc(admin, 'maintenance_records', 'maintenance-b')));
  await assertSucceeds(getDoc(doc(admin, 'purchase_records', 'purchase-b')));
});



test('asset document purchase links must match the same asset and office', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'purchase_records', 'purchase-link-a'), {
      assetId: 'asset-1', officeId: 'office-a', supplier: 'Supplier A',
      purchaseDate: new Date(), totalCost: 50,
    });
    await setDoc(doc(db, 'purchase_records', 'purchase-link-b'), {
      assetId: 'asset-b', officeId: 'office-b', supplier: 'Supplier B',
      purchaseDate: new Date(), totalCost: 75,
    });
  });

  const base = {
    assetId: 'asset-1', officeId: 'office-a',
    fileName: 'invoice.pdf', storagePath: 'asset_documents/asset-1/invoice.pdf',
    purchaseRecordId: 'purchase-link-a',
  };
  await assertSucceeds(setDoc(doc(manager, 'asset_documents', 'valid-purchase-link'), base));
  await assertFails(setDoc(doc(manager, 'asset_documents', 'wrong-purchase-office'), {
    ...base, purchaseRecordId: 'purchase-link-b',
  }));
  await assertFails(setDoc(doc(manager, 'asset_documents', 'wrong-purchase-asset'), {
    ...base, assetId: 'asset-b', officeId: 'office-b',
    storagePath: 'asset_documents/asset-b/wrong.pdf',
  }));
  await assertFails(setDoc(doc(manager, 'asset_documents', 'missing-purchase'), {
    ...base, purchaseRecordId: 'does-not-exist',
  }));
});

test('purchase attachment queries require asset and office constraints', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'purchase_records', 'purchase-query-a'), {
      assetId: 'asset-1', officeId: 'office-a', supplier: 'Supplier A',
      purchaseDate: new Date(), totalCost: 50,
    });
    await setDoc(doc(db, 'asset_documents', 'purchase-query-doc'), {
      assetId: 'asset-1', officeId: 'office-a',
      purchaseRecordId: 'purchase-query-a',
      fileName: 'invoice.pdf', storagePath: 'asset_documents/asset-1/invoice.pdf',
    });
  });
  await assertSucceeds(getDocs(query(
    collection(manager, 'asset_documents'),
    where('purchaseRecordId', '==', 'purchase-query-a'),
    where('assetId', '==', 'asset-1'),
    where('officeId', '==', 'office-a'),
  )));
  await assertFails(getDocs(query(
    collection(manager, 'asset_documents'),
    where('purchaseRecordId', '==', 'purchase-query-a'),
  )));
});

test('purchase records are immutable after creation', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'purchase_records', 'immutable-purchase'), {
      assetId: 'asset-1', officeId: 'office-a', supplier: 'Original Supplier',
      purchaseDate: new Date(), totalCost: 125,
    });
  });

  await assertFails(updateDoc(doc(manager, 'purchase_records', 'immutable-purchase'), {
    supplier: 'Tampered Supplier',
    totalCost: 1,
  }));
  await assertFails(deleteDoc(doc(manager, 'purchase_records', 'immutable-purchase')));
});


test('spare stock is office-scoped and managers cannot forge stock office assignments', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  const managerB = env.authenticatedContext('manager-b').firestore();
  const admin = env.authenticatedContext('admin-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const stock = {
      name: 'SSD', sku: 'SSD-1', quantity: 12, minimumQuantity: 2,
      unitCost: 25, supplier: 'Supplier', createdAt: new Date(),
      updatedAt: new Date(),
    };
    await setDoc(doc(db, 'spare_parts', 'part-a'), {
      ...stock, officeId: 'office-a',
    });
    await setDoc(doc(db, 'spare_parts', 'part-b'), {
      ...stock, officeId: 'office-b',
    });
  });

  await assertSucceeds(getDoc(doc(managerA, 'spare_parts', 'part-a')));
  await assertFails(getDoc(doc(managerA, 'spare_parts', 'part-b')));
  await assertSucceeds(getDoc(doc(managerB, 'spare_parts', 'part-b')));
  await assertFails(getDocs(collection(managerA, 'spare_parts')));
  await assertSucceeds(getDocs(query(
    collection(managerA, 'spare_parts'), where('officeId', '==', 'office-a'),
    orderBy('name'),
  )));
  await assertSucceeds(getDocs(collection(admin, 'spare_parts')));

  const newPart = {
    officeId: 'office-a', name: 'RAM', sku: 'RAM-1', quantity: 5,
    minimumQuantity: 1, unitCost: 10, supplier: '',
    createdAt: new Date(), updatedAt: new Date(),
  };
  await assertSucceeds(setDoc(doc(managerA, 'spare_parts', 'part-a-new'), newPart));
  await assertFails(setDoc(doc(managerA, 'spare_parts', 'part-forged-office'), {
    ...newPart, officeId: 'office-b',
  }));
});

test('spare part consumption requires one atomic stock, maintenance cost and usage transaction', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await updateDoc(doc(db, 'assets', 'asset-1'), { status: 'maintenance' });
    await setDoc(doc(db, 'maintenance_records', 'parts-maintenance-a'), {
      assetId: 'asset-1', officeId: 'office-a', title: 'Repair',
      status: 'open', previousAssetStatus: 'available',
      partsCost: 0, reportedAt: new Date(),
    });
    await setDoc(doc(db, 'spare_parts', 'parts-part-a'), {
      officeId: 'office-a', name: 'SSD', sku: 'SSD-1',
      quantity: 10, minimumQuantity: 2, unitCost: 5,
      supplier: 'Supplier', createdAt: new Date(), updatedAt: new Date(),
    });
  });

  // None of the three legs may be written independently.
  await assertFails(updateDoc(doc(manager, 'spare_parts', 'parts-part-a'), {
    quantity: 8, updatedAt: new Date(),
  }));
  await assertFails(updateDoc(doc(manager, 'maintenance_records', 'parts-maintenance-a'), {
    partsCost: 10, updatedAt: new Date(), lastPartsUsageId: 'usage-cost-only',
  }));
  await assertFails(setDoc(doc(manager, 'maintenance_parts', 'usage-only'), {
    partId: 'parts-part-a', partName: 'SSD',
    maintenanceId: 'parts-maintenance-a', assetId: 'asset-1',
    officeId: 'office-a', quantity: 2, unitCost: 5, totalCost: 10,
    notes: '', usedAt: new Date(), createdBy: 'manager-1',
  }));

  await assertSucceeds(runTransaction(manager, async (tx) => {
    const partRef = doc(manager, 'spare_parts', 'parts-part-a');
    const ticketRef = doc(manager, 'maintenance_records', 'parts-maintenance-a');
    const assetRef = doc(manager, 'assets', 'asset-1');
    const usageRef = doc(manager, 'maintenance_parts', 'usage-valid');
    const part = await tx.get(partRef);
    const ticket = await tx.get(ticketRef);
    const asset = await tx.get(assetRef);
    assert.equal(part.data().quantity, 10);
    assert.equal(ticket.data().partsCost, 0);
    assert.equal(asset.data().officeId, 'office-a');
    tx.update(partRef, {
      quantity: 8, lastUsageId: 'usage-valid', updatedAt: new Date(),
    });
    tx.update(ticketRef, {
      partsCost: 10, lastPartsUsageId: 'usage-valid', updatedAt: new Date(),
    });
    tx.set(usageRef, {
      partId: 'parts-part-a', partName: 'SSD',
      maintenanceId: 'parts-maintenance-a', assetId: 'asset-1',
      officeId: 'office-a', quantity: 2, unitCost: 5, totalCost: 10,
      notes: 'Replacement', usedAt: new Date(), createdBy: 'manager-1',
    });
  }));

  const partAfter = await getDoc(doc(manager, 'spare_parts', 'parts-part-a'));
  const ticketAfter = await getDoc(doc(manager, 'maintenance_records', 'parts-maintenance-a'));
  assert.equal(partAfter.data().quantity, 8);
  assert.equal(ticketAfter.data().partsCost, 10);
});

test('spare usage cannot connect a part, maintenance ticket and asset across offices', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await updateDoc(doc(db, 'assets', 'asset-b'), { status: 'maintenance' });
    await setDoc(doc(db, 'maintenance_records', 'parts-maintenance-b'), {
      assetId: 'asset-b', officeId: 'office-b', title: 'Office B repair',
      status: 'open', previousAssetStatus: 'available',
      partsCost: 0, reportedAt: new Date(),
    });
    await setDoc(doc(db, 'spare_parts', 'parts-part-b'), {
      officeId: 'office-b', name: 'RAM', sku: 'RAM-B',
      quantity: 4, minimumQuantity: 1, unitCost: 3,
      supplier: 'Supplier B', createdAt: new Date(), updatedAt: new Date(),
    });
  });

  await assertFails(runTransaction(managerA, async (tx) => {
    const partRef = doc(managerA, 'spare_parts', 'parts-part-b');
    const ticketRef = doc(managerA, 'maintenance_records', 'parts-maintenance-b');
    const usageRef = doc(managerA, 'maintenance_parts', 'cross-office-usage');
    const part = await tx.get(partRef);
    const ticket = await tx.get(ticketRef);
    tx.update(partRef, {
      quantity: part.data().quantity - 1,
      lastUsageId: 'cross-office-usage', updatedAt: new Date(),
    });
    tx.update(ticketRef, {
      partsCost: 3, lastPartsUsageId: 'cross-office-usage',
      updatedAt: new Date(),
    });
    tx.set(usageRef, {
      partId: 'parts-part-b', partName: 'RAM',
      maintenanceId: 'parts-maintenance-b', assetId: 'asset-b',
      officeId: 'office-b', quantity: 1, unitCost: 3, totalCost: 3,
      notes: '', usedAt: new Date(), createdBy: 'manager-1',
    });
  }));
});


test('office-scoped inventory and open maintenance queries used by the UI are authorized', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await updateDoc(doc(db, 'assets', 'asset-1'), { status: 'maintenance' });
    await setDoc(doc(db, 'maintenance_records', 'query-maintenance-a'), {
      assetId: 'asset-1', officeId: 'office-a', title: 'Office A open ticket',
      status: 'open', reportedAt: new Date(),
    });
    await setDoc(doc(db, 'spare_parts', 'query-part-a'), {
      officeId: 'office-a', name: 'SSD', sku: 'SSD-Q',
      quantity: 5, minimumQuantity: 1, unitCost: 10,
      supplier: '', createdAt: new Date(), updatedAt: new Date(),
    });
  });

  await assertSucceeds(getDocs(query(
    collection(manager, 'spare_parts'),
    where('officeId', 'in', ['office-a']),
    orderBy('name'),
  )));
  const tickets = await getDocs(query(
    collection(manager, 'maintenance_records'),
    where('officeId', 'in', ['office-a']),
  ));
  assert.deepEqual(
    tickets.docs.map((ticket) => ticket.data().status)
      .filter((status) => status === 'open' || status === 'inProgress'),
    ['open'],
  );
});


test('spare stock restocking requires an immutable office-scoped receipt in the same transaction', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  const managerB = env.authenticatedContext('manager-b').firestore();
  const admin = env.authenticatedContext('admin-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'spare_parts', 'restock-part-a'), {
      officeId: 'office-a', name: 'SSD', sku: 'SSD-R',
      quantity: 10, minimumQuantity: 2, unitCost: 20,
      supplier: 'Old Supplier', createdAt: new Date(), updatedAt: new Date(),
    });
  });

  // Stock cannot be increased without an immutable receipt.
  await assertFails(updateDoc(doc(managerA, 'spare_parts', 'restock-part-a'), {
    quantity: 15, updatedAt: new Date(),
  }));
  // A receipt cannot be forged or written without the matching stock update.
  const orphanReceipt = {
    partId: 'restock-part-a', officeId: 'office-a',
    quantity: 5, quantityBefore: 10, quantityAfter: 15,
    unitCost: 12, totalCost: 60, supplier: 'New Supplier', notes: '',
    receivedAt: new Date(), createdAt: new Date(), createdBy: 'manager-1',
  };
  await assertFails(setDoc(doc(managerA, 'spare_part_receipts', 'orphan'), orphanReceipt));
  await assertFails(setDoc(doc(managerB, 'spare_part_receipts', 'forged-office'), {
    ...orphanReceipt, officeId: 'office-a',
  }));

  await assertSucceeds(runTransaction(managerA, async (tx) => {
    const partRef = doc(managerA, 'spare_parts', 'restock-part-a');
    const receiptRef = doc(managerA, 'spare_part_receipts', 'restock-valid');
    const part = await tx.get(partRef);
    const oldQuantity = part.data().quantity;
    const receivedQuantity = 5;
    const purchaseUnitCost = 12;
    const totalCost = receivedQuantity * purchaseUnitCost;
    const newQuantity = oldQuantity + receivedQuantity;
    tx.update(partRef, {
      quantity: newQuantity,
      unitCost: purchaseUnitCost,
      supplier: 'New Supplier',
      lastRestockId: 'restock-valid',
      updatedAt: new Date(),
    });
    tx.set(receiptRef, {
      partId: 'restock-part-a', officeId: 'office-a',
      quantity: receivedQuantity, quantityBefore: oldQuantity,
      quantityAfter: newQuantity, unitCost: purchaseUnitCost,
      totalCost, supplier: 'New Supplier', notes: 'Invoice INV-5',
      receivedAt: new Date(), createdAt: new Date(), createdBy: 'manager-1',
    });
  }));

  const partAfter = await getDoc(doc(managerA, 'spare_parts', 'restock-part-a'));
  const receiptAfter = await getDoc(doc(managerA, 'spare_part_receipts', 'restock-valid'));
  assert.equal(partAfter.data().quantity, 15);
  assert.equal(partAfter.data().unitCost, 12);
  assert.equal(partAfter.data().supplier, 'New Supplier');
  assert.equal(receiptAfter.data().createdBy, 'manager-1');
  assert.equal(receiptAfter.data().totalCost, 60);

  await assertFails(updateDoc(doc(managerA, 'spare_part_receipts', 'restock-valid'), {
    supplier: 'Tampered Supplier',
  }));
  await assertFails(deleteDoc(doc(managerA, 'spare_part_receipts', 'restock-valid')));
  await assertFails(getDoc(doc(managerB, 'spare_part_receipts', 'restock-valid')));
  await assertSucceeds(getDoc(doc(admin, 'spare_part_receipts', 'restock-valid')));
});

test('restocking cannot alter weighted cost or supplier independently of its receipt', async () => {
  const manager = env.authenticatedContext('manager-1').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'spare_parts', 'restock-tamper'), {
      officeId: 'office-a', name: 'RAM', sku: 'RAM-R',
      quantity: 4, minimumQuantity: 1, unitCost: 8,
      supplier: 'Original', createdAt: new Date(), updatedAt: new Date(),
    });
  });
  await assertFails(updateDoc(doc(manager, 'spare_parts', 'restock-tamper'), {
    unitCost: 1, updatedAt: new Date(),
  }));
  await assertFails(updateDoc(doc(manager, 'spare_parts', 'restock-tamper'), {
    supplier: 'Forged Supplier', updatedAt: new Date(),
  }));
});


test('spare part movement reads are office-scoped and usage events are immutable and actor-bound', async () => {
  const managerA = env.authenticatedContext('manager-1').firestore();
  const managerB = env.authenticatedContext('manager-b').firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'maintenance_records', 'history-ticket-a'), { assetId: 'asset-1', officeId: 'office-a', status: 'open' });
    await setDoc(doc(db, 'maintenance_parts', 'history-use-a'), { partId: 'history-part-a', partName: 'SSD', maintenanceId: 'history-ticket-a', assetId: 'asset-1', officeId: 'office-a', quantity: 2, unitCost: 10, totalCost: 20, notes: '', usedAt: new Date(), createdBy: 'manager-1' });
    await setDoc(doc(db, 'maintenance_records', 'history-ticket-b'), { assetId: 'asset-b', officeId: 'office-b', status: 'open' });
    await setDoc(doc(db, 'maintenance_parts', 'history-use-b'), { partId: 'history-part-b', partName: 'RAM', maintenanceId: 'history-ticket-b', assetId: 'asset-b', officeId: 'office-b', quantity: 1, unitCost: 5, totalCost: 5, notes: '', usedAt: new Date(), createdBy: 'manager-b' });
  });
  await assertSucceeds(getDocs(query(collection(managerA, 'maintenance_parts'), where('partId', '==', 'history-part-a'), where('officeId', '==', 'office-a'))));
  await assertFails(getDocs(query(collection(managerA, 'maintenance_parts'), where('partId', '==', 'history-part-b'), where('officeId', '==', 'office-b'))));
  await assertFails(updateDoc(doc(managerA, 'maintenance_parts', 'history-use-a'), { quantity: 200 }));
  await assertFails(deleteDoc(doc(managerA, 'maintenance_parts', 'history-use-a')));
});
