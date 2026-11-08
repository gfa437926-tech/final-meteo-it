import { HttpsError } from 'firebase-functions/v2/https';

const MAX_LOTS_PER_TRANSACTION = 400;
const MAX_QUANTITY = 1_000_000;

function fail(code, message) {
  throw new HttpsError(code, message);
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

/**
 * Trusted FIFO consumption transaction.
 *
 * The caller UID is taken only from Firebase Callable Auth context. The lot
 * query, balances, linked records and stock mutations all participate in one
 * Firestore transaction. The spare_parts document is the serialization point
 * shared with restocking and concurrent consumption.
 */
export async function consumeSparePartCore({ db, uid, data, FieldValue }) {
  if (!isNonEmptyString(uid)) fail('unauthenticated', 'يجب تسجيل الدخول أولاً');
  const partId = data?.partId;
  const maintenanceId = data?.maintenanceId;
  const quantity = data?.quantity;
  const notes = data?.notes ?? '';

  if (!isNonEmptyString(partId) || partId.length > 128 ||
      !isNonEmptyString(maintenanceId) || maintenanceId.length > 128 ||
      !Number.isSafeInteger(quantity) || quantity <= 0 ||
      quantity > MAX_QUANTITY || typeof notes !== 'string' || notes.length > 2000) {
    fail('invalid-argument', 'بيانات صرف قطع الغيار غير صالحة');
  }

  const partRef = db.collection('spare_parts').doc(partId);
  const ticketRef = db.collection('maintenance_records').doc(maintenanceId);
  const profileRef = db.collection('users').doc(uid);
  const usageRef = db.collection('maintenance_parts').doc();
  const allocationRef = db.collection('spare_part_allocations').doc(usageRef.id);

  return db.runTransaction(async (transaction) => {
    const [profileSnapshot, partSnapshot, ticketSnapshot] = await Promise.all([
      transaction.get(profileRef),
      transaction.get(partRef),
      transaction.get(ticketRef),
    ]);

    if (!profileSnapshot.exists || profileSnapshot.data()?.isActive !== true) {
      fail('permission-denied', 'الحساب غير نشط أو غير مسجل في النظام');
    }
    if (!partSnapshot.exists) fail('not-found', 'قطعة الغيار غير موجودة');
    if (!ticketSnapshot.exists) fail('not-found', 'طلب الصيانة غير موجود');

    const profile = profileSnapshot.data();
    const part = partSnapshot.data();
    const ticket = ticketSnapshot.data();
    const officeId = part.officeId;
    if (!isNonEmptyString(officeId) || ticket.officeId !== officeId) {
      fail('failed-precondition', 'يجب أن تتطابق مكاتب القطعة وطلب الصيانة');
    }
    const assigned = Array.isArray(profile.officeIds) ? profile.officeIds : [];
    if (profile.role !== 'admin' &&
        !(profile.role === 'it_manager' && assigned.includes(officeId))) {
      fail('permission-denied', 'لا تملك صلاحية صرف مخزون هذا المكتب');
    }

    const officeRef = db.collection('offices').doc(officeId);
    const assetId = ticket.assetId;
    if (!isNonEmptyString(assetId)) {
      fail('failed-precondition', 'طلب الصيانة غير مرتبط بأصل صالح');
    }
    const assetRef = db.collection('assets').doc(assetId);
    const [officeSnapshot, assetSnapshot] = await Promise.all([
      transaction.get(officeRef),
      transaction.get(assetRef),
    ]);
    if (!officeSnapshot.exists || officeSnapshot.data()?.isActive !== true) {
      fail('failed-precondition', 'المكتب غير موجود أو غير نشط');
    }
    if (!assetSnapshot.exists ||
        assetSnapshot.data()?.officeId !== officeId ||
        assetSnapshot.data()?.status !== 'maintenance') {
      fail('failed-precondition', 'الأصل غير موجود أو لا يتبع المكتب أو ليس في حالة صيانة');
    }
    if (!['open', 'inProgress'].includes(ticket.status)) {
      fail('failed-precondition', 'لا يمكن الصرف لطلب صيانة مغلق');
    }

    const available = part.quantity;
    if (!Number.isSafeInteger(available) || available < 0) {
      fail('failed-precondition', 'رصيد المخزون غير صالح');
    }
    if (available < quantity) fail('failed-precondition', 'الكمية المتاحة غير كافية');

    const lotsQuery = db.collection('spare_part_lots')
      .where('officeId', '==', officeId)
      .where('partId', '==', partId)
      .orderBy('receivedAt', 'asc')
      .orderBy('createdAt', 'asc')
      .limit(MAX_LOTS_PER_TRANSACTION + 1);
    const lotsSnapshot = await transaction.get(lotsQuery);
    if (lotsSnapshot.size > MAX_LOTS_PER_TRANSACTION) {
      fail('resource-exhausted', 'تجاوز عدد دفعات القطعة حد المعاملة؛ راجع تجزئة المخزون قبل الصرف');
    }

    // Read and validate every balance/receipt for this part before any write.
    // This proves the part total reconciles with tracked lots plus legacy stock.
    const lotRecords = await Promise.all(lotsSnapshot.docs.map(async (lotDocument) => {
      const lot = lotDocument.data();
      if (!isNonEmptyString(lot.receiptId) || lot.receiptId !== lotDocument.id) {
        fail('failed-precondition', 'دفعة التوريد لا ترتبط بإيصال صالح');
      }
      const balanceRef = db.collection('spare_part_lot_balances').doc(lotDocument.id);
      const receiptRef = db.collection('spare_part_receipts').doc(lot.receiptId);
      const [balanceSnapshot, receiptSnapshot] = await Promise.all([
        transaction.get(balanceRef),
        transaction.get(receiptRef),
      ]);
      if (!balanceSnapshot.exists || !receiptSnapshot.exists) {
        fail('failed-precondition', 'دفعة توريد أو رصيدها أو إيصالها مفقود؛ أوقف الصرف وراجع السجل');
      }
      const balance = balanceSnapshot.data();
      const receipt = receiptSnapshot.data();
      const remaining = balance.remainingQuantity;
      if (lot.partId !== partId || lot.officeId !== officeId ||
          balance.lotId !== lotDocument.id ||
          balance.partId !== partId || balance.officeId !== officeId ||
          !Number.isSafeInteger(lot.receivedQuantity) || lot.receivedQuantity <= 0 ||
          !Number.isFinite(lot.unitCost) || lot.unitCost < 0 ||
          !Number.isFinite(lot.totalCost) ||
          lot.totalCost !== lot.receivedQuantity * lot.unitCost ||
          !isNonEmptyString(lot.supplier) || !isNonEmptyString(lot.createdBy) ||
          typeof lot.receivedAt?.toMillis !== 'function' ||
          typeof lot.createdAt?.toMillis !== 'function' ||
          !Number.isSafeInteger(remaining) || remaining < 0 ||
          remaining > lot.receivedQuantity ||
          receipt.partId !== partId || receipt.officeId !== officeId ||
          receipt.lotId !== lotDocument.id ||
          receipt.quantity !== lot.receivedQuantity ||
          !Number.isSafeInteger(receipt.quantityBefore) || receipt.quantityBefore < 0 ||
          receipt.quantityAfter !== receipt.quantityBefore + receipt.quantity ||
          receipt.supplier !== lot.supplier ||
          receipt.unitCost !== lot.unitCost ||
          receipt.totalCost !== lot.totalCost ||
          receipt.createdBy !== lot.createdBy ||
          receipt.createdAt?.toMillis?.() !== lot.createdAt.toMillis() ||
          receipt.receivedAt?.toMillis?.() !== lot.receivedAt.toMillis()) {
        fail('failed-precondition', 'بيانات دفعة التوريد لا تطابق إيصالها أو رصيدها');
      }
      return { id: lotDocument.id, lot, balanceRef, remaining };
    }));

    const trackedBalance = lotRecords.reduce((sum, record) =>
      sum + record.remaining, 0);
    if (!Number.isSafeInteger(trackedBalance)) {
      fail('failed-precondition', 'مجموع أرصدة دفعات المخزون غير صالح');
    }
    const untrackedRaw = part.untrackedQuantity;
    if (untrackedRaw == null && lotRecords.length > 0) {
      fail('failed-precondition', 'يلزم تهيئة الرصيد التاريخي للقطعة قبل صرف الدفعات الموثقة');
    }
    const untracked = untrackedRaw == null ? available : untrackedRaw;
    if (!Number.isSafeInteger(untracked) || untracked < 0 ||
        untracked > available || untracked + trackedBalance !== available) {
      fail('failed-precondition', 'رصيد المخزون لا يتطابق مع الرصيد التاريخي ومجموع أرصدة الدفعات');
    }

    let remainingToAllocate = quantity;
    const legacyQuantity = Math.min(remainingToAllocate, untracked);
    remainingToAllocate -= legacyQuantity;
    const lines = [];
    if (legacyQuantity > 0) {
      lines.push({
        sourceType: 'legacy_untracked',
        lotId: null,
        receiptId: null,
        supplier: null,
        quantity: legacyQuantity,
        unitCost: null,
        totalCost: null,
      });
    }

    const balanceUpdates = [];
    for (const record of lotRecords) {
      if (remainingToAllocate === 0) break;
      if (record.remaining === 0) continue;
      const take = Math.min(remainingToAllocate, record.remaining);
      const unitCost = record.lot.unitCost;
      const totalCost = take * unitCost;
      if (!Number.isFinite(totalCost)) {
        fail('failed-precondition', 'إجمالي تكلفة دفعة التوريد يتجاوز النطاق الرقمي');
      }
      lines.push({
        sourceType: 'lot',
        lotId: record.id,
        receiptId: record.lot.receiptId,
        supplier: record.lot.supplier,
        quantity: take,
        unitCost,
        totalCost,
      });
      balanceUpdates.push({
        ref: record.balanceRef,
        remainingQuantity: record.remaining - take,
      });
      remainingToAllocate -= take;
    }

    if (remainingToAllocate > 0) {
      fail('failed-precondition', 'أرصدة الدفعات الموثقة لا تغطي الكمية المطلوبة');
    }

    const totalCost = lines.reduce((sum, line) => sum + (line.totalCost ?? 0), 0);
    const unitCost = legacyQuantity === 0 ? totalCost / quantity : null;
    const previousPartsCost = ticket.partsCost ?? 0;
    const newPartsCost = previousPartsCost + totalCost;
    if (!Number.isFinite(totalCost) || !Number.isFinite(previousPartsCost) ||
        previousPartsCost < 0 || !Number.isFinite(newPartsCost) ||
        (unitCost !== null && !Number.isFinite(unitCost))) {
      fail('failed-precondition', 'قيمة تكلفة القطع خارج النطاق الرقمي المسموح');
    }

    const now = FieldValue.serverTimestamp();
    transaction.update(partRef, {
      quantity: available - quantity,
      untrackedQuantity: untracked - legacyQuantity,
      lastUsageId: usageRef.id,
      updatedAt: now,
    });
    transaction.update(ticketRef, {
      partsCost: newPartsCost,
      lastPartsUsageId: usageRef.id,
      updatedAt: now,
    });
    for (const update of balanceUpdates) {
      transaction.update(update.ref, {
        remainingQuantity: update.remainingQuantity,
        updatedAt: now,
        lastAllocationId: usageRef.id,
      });
    }
    transaction.create(usageRef, {
      partId,
      partName: typeof part.name === 'string' ? part.name : '',
      maintenanceId,
      assetId,
      officeId,
      quantity,
      unitCost,
      totalCost,
      notes: notes.trim(),
      usedAt: now,
      createdBy: uid,
      allocationId: allocationRef.id,
      allocationCount: lines.length,
      legacyQuantity,
      costAttributionComplete: legacyQuantity === 0,
    });
    transaction.create(allocationRef, {
      usageId: usageRef.id,
      partId,
      officeId,
      maintenanceId,
      assetId,
      quantity,
      totalCost,
      lines,
      createdAt: now,
      createdBy: uid,
    });

    return {
      usageId: usageRef.id,
      allocationId: allocationRef.id,
      quantity,
      totalCost,
      legacyQuantity,
      allocationCount: lines.length,
    };
  });
}
