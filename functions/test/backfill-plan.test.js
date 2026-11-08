import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildLegacyStockBackfillPlan } from '../src/backfill-plan.js';

test('dry-run proposes only the untracked remainder after verified lot balances', () => {
  const plan = buildLegacyStockBackfillPlan({
    parts: [{ id: 'part-a', officeId: 'office-a', quantity: 17 }],
    balances: [
      { id: 'lot-1', partId: 'part-a', officeId: 'office-a', remainingQuantity: 4 },
      { id: 'lot-2', partId: 'part-a', officeId: 'office-a', remainingQuantity: 5 },
    ],
  });
  assert.equal(plan.writesPerformed, 0);
  assert.equal(plan.safeToApply, true);
  assert.equal(plan.parts[0].proposedUntrackedQuantity, 8);
  assert.equal(plan.parts[0].status, 'needs_untracked_initialization');
});

test('existing untracked quantity is accepted only when stock reconciles exactly', () => {
  const plan = buildLegacyStockBackfillPlan({
    parts: [{ id: 'part-a', officeId: 'office-a', quantity: 17, untrackedQuantity: 8 }],
    balances: [{ id: 'lot-1', partId: 'part-a', officeId: 'office-a', remainingQuantity: 9 }],
  });
  assert.equal(plan.safeToApply, true);
  assert.equal(plan.parts[0].status, 'already_consistent');
});

test('mismatched or negative reconciliation is never marked safe', () => {
  const plan = buildLegacyStockBackfillPlan({
    parts: [
      { id: 'part-a', officeId: 'office-a', quantity: 17, untrackedQuantity: 6 },
      { id: 'part-b', officeId: 'office-a', quantity: 3 },
    ],
    balances: [{ id: 'lot-1', partId: 'part-b', officeId: 'office-a', remainingQuantity: 4 }],
  });
  assert.equal(plan.safeToApply, false);
  assert.equal(plan.parts[0].status, 'stock_balance_mismatch');
  assert.equal(plan.parts[1].status, 'stock_balance_mismatch');
});

test('legacy records without officeId stay admin-only and are not backfilled', () => {
  const plan = buildLegacyStockBackfillPlan({
    parts: [{ id: 'legacy-part', quantity: 9 }],
    balances: [],
  });
  assert.equal(plan.parts[0].status, 'legacy_admin_only');
  assert.equal(plan.safeToApply, true);
});

test('orphaned and malformed balances block a safe backfill plan', () => {
  const plan = buildLegacyStockBackfillPlan({
    parts: [{ id: 'part-a', officeId: 'office-a', quantity: 5 }],
    balances: [
      { id: 'orphan', partId: 'missing-part', officeId: 'office-a', remainingQuantity: 2 },
      { id: 'bad', partId: 'part-a', officeId: 'office-a', remainingQuantity: -1 },
    ],
  });
  assert.equal(plan.safeToApply, false);
  assert.equal(plan.orphanBalances.length, 1);
  assert.equal(plan.malformedBalances.length, 1);
});
