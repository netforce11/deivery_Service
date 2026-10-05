const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ── FCM 토큰으로 알림 발송 헬퍼 ──────────────────────────────────────────
async function sendNotification(token, title, body, data = {}) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data,
      webpush: {
        notification: {
          title,
          body,
          icon: "/icons/Icon-192.png",
        },
        fcmOptions: { link: "/" },
      },
    });
    console.log(`✅ 알림 발송 성공: ${title}`);
  } catch (err) {
    console.error("❌ 알림 발송 실패:", err.message);
  }
}

// ── 1. 새 주문 생성 → 업체에 알림 ────────────────────────────────────────
exports.onNewOrder = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data?.data();
  if (!order) return;

  const storeId = order.storeId;
  const storeDoc = await db.collection("stores").doc(storeId).get();
  const fcmToken = storeDoc.data()?.fcmToken;

  const itemSummary = (order.items || [])
    .map((i) => `${i.name} ${i.quantity}개`)
    .join(", ");

  await sendNotification(
    fcmToken,
    "🛎️ 새 주문이 들어왔어요!",
    `${itemSummary} · ${order.totalPrice?.toLocaleString()}원`,
    { orderId: event.params.orderId, type: "new_order" }
  );
});

// ── 2. 주문 상태 변경 → 고객 / 라이더 알림 ──────────────────────────────
exports.onOrderStatusChanged = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;

  const prevStatus = before.status;
  const newStatus = after.status;
  if (prevStatus === newStatus) return;

  const orderId = event.params.orderId;
  const customerId = after.customerId;
  const riderId = after.riderId;

  // 고객 FCM 토큰 조회
  const customerDoc = await db.collection("customers").doc(customerId).get();
  const customerToken = customerDoc.data()?.fcmToken;

  // 라이더 FCM 토큰 조회
  let riderToken = null;
  if (riderId) {
    const riderDoc = await db.collection("riders").doc(riderId).get();
    riderToken = riderDoc.data()?.fcmToken;
  }

  // 상태별 알림 발송
  switch (newStatus) {
    case "accepted":
      // 업체가 주문 수락 → 고객에게 알림
      await sendNotification(
        customerToken,
        "✅ 주문이 수락되었어요",
        "업체에서 주문을 확인하고 준비 중이에요",
        { orderId, type: "order_accepted" }
      );
      break;

    case "assigned":
      // 라이더 배정 → 고객에게 알림
      await sendNotification(
        customerToken,
        "🛵 라이더가 배정되었어요",
        "라이더가 픽업하러 가고 있어요",
        { orderId, type: "rider_assigned" }
      );
      break;

    case "picked_up":
      // 픽업 완료 → 고객에게 알림
      await sendNotification(
        customerToken,
        "🎁 음식을 픽업했어요!",
        "라이더가 배달 중이에요. 조금만 기다려주세요 🚴",
        { orderId, type: "picked_up" }
      );
      break;

    case "delivered":
      // 배달 완료 → 고객에게 알림
      await sendNotification(
        customerToken,
        "🎉 배달이 완료되었어요!",
        "맛있게 드세요! 리뷰를 남겨주세요 ⭐",
        { orderId, type: "delivered" }
      );
      break;

    case "cancelled":
      // 취소 → 고객에게 알림
      await sendNotification(
        customerToken,
        "❌ 주문이 취소되었어요",
        "불편을 드려 죄송합니다",
        { orderId, type: "cancelled" }
      );
      // 라이더에게도 알림 (배정된 경우)
      if (riderToken) {
        await sendNotification(
          riderToken,
          "❌ 배달이 취소되었어요",
          "배정된 주문이 취소되었습니다",
          { orderId, type: "cancelled" }
        );
      }
      break;
  }
});

// ── 3. accepted 상태 주문 발생 → 온라인 라이더 전체에 알림 ──────────────
exports.onOrderAccepted = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;
  if (before.status === after.status) return;
  if (after.status !== "accepted") return;

  // 온라인 상태인 라이더 모두 조회
  const ridersSnap = await db
    .collection("riders")
    .where("isOnline", "==", true)
    .get();

  const itemSummary = (after.items || [])
    .map((i) => `${i.name} ${i.quantity}개`)
    .join(", ");

  const sends = ridersSnap.docs.map((doc) => {
    const token = doc.data().fcmToken;
    return sendNotification(
      token,
      "📦 새 배달 요청이 있어요!",
      `${itemSummary} → ${after.deliveryAddress}`,
      { orderId: event.params.orderId, type: "new_delivery" }
    );
  });

  await Promise.all(sends);
});
