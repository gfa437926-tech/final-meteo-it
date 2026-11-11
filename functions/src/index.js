import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { consumeSparePartCore } from './consume-spare-part.js';

const app = getApps().length ? getApps()[0] : initializeApp();
const db = getFirestore(app);

export const consumeSparePart = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    try {
      return await consumeSparePartCore({
        db,
        uid: request.auth.uid,
        data: request.data,
        FieldValue,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      // Do not log request payloads or inventory/customer data.
      console.error('consumeSparePart transaction failed', error?.code ?? 'unknown');
      throw new HttpsError('internal', 'تعذر إتمام صرف قطع الغيار؛ لم يتم اعتماد الحركة');
    }
  },
);
