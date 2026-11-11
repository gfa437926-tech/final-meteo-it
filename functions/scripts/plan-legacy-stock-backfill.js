import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { buildLegacyStockBackfillPlan } from '../src/backfill-plan.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    'Safety stop: this planner runs only against Firestore Emulator. ' +
    'No production connection or write mode is supported.',
  );
}

const app = initializeApp({
  projectId: process.env.GCLOUD_PROJECT || 'demo-metra-it-assets',
}, 'legacy-stock-backfill-dry-run');
const db = getFirestore(app);

try {
  const [partSnapshot, balanceSnapshot] = await Promise.all([
    db.collection('spare_parts').get(),
    db.collection('spare_part_lot_balances').get(),
  ]);
  const plan = buildLegacyStockBackfillPlan({
    parts: partSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    balances: balanceSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
  });
  process.stdout.write(`${JSON.stringify(plan, null, 2)}\n`);
  if (!plan.reconciliationPassed) process.exitCode = 2;
} finally {
  await deleteApp(app);
}
