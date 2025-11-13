import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

export const claimDevice = functions.https.onCall(async (req) => {
  // req.auth en v4
  if (!req.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Debes iniciar sesión.",
    );
  }

  const uid = req.auth.uid;

  // req.data en v4
  const {deviceId, claimCode} = (req.data || {}) as {
    deviceId?: string;
    claimCode?: string;
  };

  if (!deviceId || !claimCode) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Faltan parámetros.",
    );
  }

  const ref = admin.firestore().doc(`devices/${deviceId}`);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new functions.https.HttpsError(
      "not-found", "El dispositivo no existe.");
  }

  const dev = snap.data() as { claimCode?: string };
  if (!dev.claimCode || dev.claimCode !== claimCode) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Código incorrecto.",
    );
  }

  await ref.update({
    ownerUID: uid,
    claimedAt: admin.firestore.FieldValue.serverTimestamp(),
    claimCode: admin.firestore.FieldValue.delete(),
  });

  await admin.firestore().doc(`usuarios/${uid}`).set(
    {currentDeviceId: deviceId},
    {merge: true},
  );

  return {ok: true, deviceId};
});
