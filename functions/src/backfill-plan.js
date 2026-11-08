/**
 * Pure, read-only planning for legacy spare-stock provenance.
 * It never writes to Firestore and never infers a supplier or purchase cost.
 */
export function buildLegacyStockBackfillPlan({ parts, balances }) {
  const partsById = new Map(parts.map((part) => [part.id, part]));
  const balancesByPart = new Map();
  const orphanBalances = [];
  const malformedBalances = [];

  for (const balance of balances) {
    const quantity = balance.remainingQuantity;
    if (typeof balance.partId !== 'string' ||
        typeof balance.officeId !== 'string' ||
        !Number.isSafeInteger(quantity) || quantity < 0) {
      malformedBalances.push({ balanceId: balance.id, reason: 'invalid_balance_schema' });
      continue;
    }
    const part = partsById.get(balance.partId);
    if (!part || part.officeId !== balance.officeId) {
      orphanBalances.push({
        balanceId: balance.id,
        partId: balance.partId,
        officeId: balance.officeId,
        reason: !part ? 'part_missing' : 'office_mismatch',
      });
      continue;
    }
    const entries = balancesByPart.get(balance.partId) ?? [];
    entries.push(balance);
    balancesByPart.set(balance.partId, entries);
  }

  const rows = parts.map((part) => {
    const rawQuantity = part.quantity;
    const partBalances = balancesByPart.get(part.id) ?? [];
    const trackedBalance = partBalances.reduce(
      (sum, balance) => sum + balance.remainingQuantity, 0,
    );
    if (!Number.isSafeInteger(rawQuantity) || rawQuantity < 0) {
      return {
        partId: part.id,
        officeId: part.officeId ?? null,
        quantity: rawQuantity ?? null,
        trackedBalance,
        status: 'invalid_part_quantity',
      };
    }
    if (typeof part.officeId !== 'string' || part.officeId.trim().length === 0) {
      return {
        partId: part.id,
        officeId: null,
        quantity: rawQuantity,
        trackedBalance,
        status: 'legacy_admin_only',
      };
    }
    const proposedUntrackedQuantity = rawQuantity - trackedBalance;
    if (!Number.isSafeInteger(proposedUntrackedQuantity) || proposedUntrackedQuantity < 0) {
      return {
        partId: part.id,
        officeId: part.officeId,
        quantity: rawQuantity,
        trackedBalance,
        currentUntrackedQuantity: part.untrackedQuantity ?? null,
        status: 'stock_balance_mismatch',
      };
    }
    const current = part.untrackedQuantity;
    if (current === undefined || current === null) {
      return {
        partId: part.id,
        officeId: part.officeId,
        quantity: rawQuantity,
        trackedBalance,
        proposedUntrackedQuantity,
        status: 'needs_untracked_initialization',
      };
    }
    if (!Number.isSafeInteger(current) || current < 0 ||
        current !== proposedUntrackedQuantity) {
      return {
        partId: part.id,
        officeId: part.officeId,
        quantity: rawQuantity,
        trackedBalance,
        currentUntrackedQuantity: current,
        proposedUntrackedQuantity,
        status: 'stock_balance_mismatch',
      };
    }
    return {
      partId: part.id,
      officeId: part.officeId,
      quantity: rawQuantity,
      trackedBalance,
      currentUntrackedQuantity: current,
      proposedUntrackedQuantity,
      status: 'already_consistent',
    };
  });

  const counts = rows.reduce((result, row) => {
    result[row.status] = (result[row.status] ?? 0) + 1;
    return result;
  }, {});
  return {
    mode: 'read_only_dry_run',
    writesPerformed: 0,
    safeToApply: Object.keys(counts).every((status) =>
      ['needs_untracked_initialization', 'already_consistent', 'legacy_admin_only'].includes(status),
    ) && orphanBalances.length === 0 && malformedBalances.length === 0,
    counts,
    parts: rows,
    orphanBalances,
    malformedBalances,
  };
}
