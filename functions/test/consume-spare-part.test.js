import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { consumeSparePartCore } from '../src/consume-spare-part.js';

const projectId = 'demo-metra-it-assets-functions';
let app;
let db;

async function clearCollections() {
  for (const name of [
    'users', 'offices', 'assets', 'maintenance_records', 'spare_parts',
    'spare_part_lots', 'spare_part_lot_balances', 'spare_part_receipts',
    'maintenance_parts', 'spare_part_allocations',
  ]) {
    const snapshot = await db.collection(name).get();
    for (let offset = 0; offset < snapshot.docs.length; offset += 400) {
      const batch = db.batch();
      for (const document of snapshot.docs.slice(offset, offset + 400)) {
        batch.delete(document.ref);
      }
      await batch.commit();
    }
  }
}

async function seedInventory({
  quantity = 14,
  untrackedQuantity = 3,
  lots = [
    { id: 'lot-1', quantity: 4, remaining: 4, unitCost: 10, supplier: 'Supplier A', day: 1 },
    { id: 'lot-2', quantity: 7, remaining: 7, unitCost: 20, supplier: 'Supplier B', day: 2 },
  ],
  officeIds = ['office-a'],
} = {}) {
  const now = new Date('2026-01-01T00:00:00.000Z');
  await db.doc('users/manager-1').set({
    role: 'it_manager', isActive: true, officeIds,
  });
  await db.doc('users/admin-1').set({
    role: 'admin', isActive: true, officeIds: [],
  });
  await db.doc('offices/office-a').set({ isActive: true });
  await db.doc('offices/office-b').set({ isActive: true });
  await db.doc('assets/asset-a').set({ officeId: 'office-a', status: 'maintenance' });
  await db.doc('maintenance_records/ticket-a').set({
    officeId: 'office-a', assetId: 'asset-a', status: 'open', partsCost: 0,
  });
  await db.doc('spare_parts/part-a').set({
    officeId: 'office-a', name: 'SSD', quantity, untrackedQuantity,
    unitCost: 99, supplier: 'Last supplier',
  });

  for (const lot of lots) {
    const receivedAt = new Date(Date.UTC(2026, 0, lot.day));
    const createdAt = new Date(Date.UTC(2026, 0, lot.day, 1));
    await db.doc(`spare_part_receipts/${lot.id}`).set({
      partId: 'part-a', officeId: 'office-a', lotId: lot.id,
      quantity: lot.quantity, quantityBefore: 0, quantityAfter: lot.quantity,
      unitCost: lot.unitCost, totalCost: lot.quantity * lot.unitCost,
      supplier: lot.supplier, notes: '', receivedAt, createdAt, createdBy: 'manager-1',
    });
    await db.doc(`spare_part_lots/${lot.id}`).set({
      partId: 'part-a', officeId: 'office-a', receiptId: lot.id,
      supplier: lot.supplier, receivedQuantity: lot.quantity,
      unitCost: lot.unitCost, totalCost: lot.quantity * lot.unitCost,
      receivedAt, createdAt, createdBy: 'manager-1',
    });
    await db.doc(`spare_part_lot_balances/${lot.id}`).set({
      lotId: lot.id, partId: 'part-a', officeId: 'office-a',
      remainingQuantity: lot.remaining, createdAt, updatedAt: createdAt,
      lastAllocationId: null,
    });
  }
}

before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('FIRESTORE_EMULATOR_HOST is required; tests must run against Firestore Emulator');
  }
  app = initializeApp({ projectId }, 'consume-spare-part-tests');
  db = getFirestore(app);
});

beforeEach(clearCollections);

after(async () => {
  if (app) await deleteApp(app);
});

test('trusted transaction consumes legacy balance first then every FIFO lot required', async () => {
  await seedInventory();
  const result = await consumeSparePartCore({
    db, uid: 'manager-1',
    data: { partId: 'part-a', maintenanceId: 'ticket-a', quantity: 9, notes: 'SSD replacement' },
    FieldValue,
  });
  assert.equal(result.quantity, 9);
  assert.equal(result.totalCost, 80);
  assert.equal(result.legacyQuantity, 3);
  assert.equal(result.allocationCount, 3);

  const [part, ticket, firstBalance, secondBalance, usage, allocation] = await Promise.all([
    db.doc('spare_parts/part-a').get(),
    db.doc('maintenance_records/ticket-a').get(),
    db.doc('spare_part_lot_balances/lot-1').get(),
    db.doc('spare_part_lot_balances/lot-2').get(),
    db.doc(`maintenance_parts/${result.usageId}`).get(),
    db.doc(`spare_part_allocations/${result.allocationId}`).get(),
  ]);
  assert.equal(part.data().quantity, 5);
  assert.equal(part.data().untrackedQuantity, 0);
  assert.equal(ticket.data().partsCost, 80);
  assert.equal(firstBalance.data().remainingQuantity, 0);
  assert.equal(secondBalance.data().remainingQuantity, 5);
  assert.equal(usage.data().unitCost, null);
  assert.equal(usage.data().costAttributionComplete, false);
  assert.deepEqual(allocation.data().lines.map((line) => line.sourceType),
    ['legacy_untracked', 'lot', 'lot']);
  assert.deepEqual(allocation.data().lines.map((line) => line.supplier),
    [null, 'Supplier A', 'Supplier B']);
});

test('manager cannot consume stock outside assigned office', async () => {
  await seedInventory({ officeIds: ['office-b'] });
  await assert.rejects(
    consumeSparePartCore({
      db, uid: 'manager-1',
      data: { partId: 'part-a', maintenanceId: 'ticket-a', quantity: 1 },
      FieldValue,
    }),
    (error) => error.code === 'permission-denied',
  );
  assert.equal((await db.doc('spare_parts/part-a').get()).data().quantity, 14);
});

test('insufficient tracked and legacy balance leaves every record unchanged', async () => {
  await seedInventory();
  await assert.rejects(
    consumeSparePartCore({
      db, uid: 'manager-1',
      data: { partId: 'part-a', maintenanceId: 'ticket-a', quantity: 15 },
      FieldValue,
    }),
    (error) => error.code === 'failed-precondition',
  );
  assert.equal((await db.doc('spare_parts/part-a').get()).data().quantity, 14);
  assert.equal((await db.doc('maintenance_records/ticket-a').get()).data().partsCost, 0);
  assert.equal((await db.collection('maintenance_parts').get()).size, 0);
  assert.equal((await db.collection('spare_part_allocations').get()).size, 0);
});

test('concurrent consumption cannot oversell a lot or stock quantity', async () => {
  await seedInventory({
    quantity: 10,
    untrackedQuantity: 0,
    lots: [{ id: 'lot-1', quantity: 10, remaining: 10, unitCost: 7, supplier: 'Supplier A', day: 1 }],
  });
  const issue = () => consumeSparePartCore({
    db, uid: 'manager-1',
    data: { partId: 'part-a', maintenanceId: 'ticket-a', quantity: 7 },
    FieldValue,
  });
  const results = await Promise.allSettled([issue(), issue()]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
  assert.equal((await db.doc('spare_parts/part-a').get()).data().quantity, 3);
  assert.equal((await db.doc('spare_part_lot_balances/lot-1').get()).data().remainingQuantity, 3);
  assert.equal((await db.collection('maintenance_parts').get()).size, 1);
});
