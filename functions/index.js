const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError }                  = require("firebase-functions/v2/https");
const { initializeApp }                       = require("firebase-admin/app");
const { getFirestore, FieldValue }            = require("firebase-admin/firestore");
const { getMessaging }                        = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ── FCM 알림 헬퍼 ────────────────────────────────────────────────────────────
async function sendNotification(token, title, body, data = {}) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data,
      webpush: {
        notification: { title, body, icon: "/icons/Icon-192.png" },
        fcmOptions: { link: "/" },
      },
    });
  } catch (err) {
    console.error("❌ 알림 발송 실패:", err.message);
  }
}

// ── 관리자 여부 확인 헬퍼 ────────────────────────────────────────────────────
function assertAdmin(auth) {
  if (!auth) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  if (auth.token.role !== "admin")
    throw new HttpsError("permission-denied", "관리자 권한이 필요합니다.");
}

// ═══════════════════════════════════════════════════════════════════════════════
// CALLABLE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

// ── [보안 핵심] 라이언 콜 완료 처리 (서버 사이드) ────────────────────────────
// 클라이언트에서 riderEarnings 를 직접 넘기면 조작 가능하므로
// 서버에서 실제 orders/{orderId}.deliveryFee 를 읽어서 계산합니다.
exports.completeRyanCall = onCall(async (request) => {
  const { campaignId, orderId, riderName } = request.data;
  const uid = request.auth?.uid;

  if (!uid)         throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  if (!campaignId)  throw new HttpsError("invalid-argument", "campaignId 필요");
  if (!orderId)     throw new HttpsError("invalid-argument", "orderId 필요");

  // ① 주문 실제 수익 서버에서 직접 읽기
  const orderSnap = await db.collection("orders").doc(orderId).get();
  if (!orderSnap.exists) throw new HttpsError("not-found", "주문을 찾을 수 없습니다.");

  const order = orderSnap.data();
  if (order.riderId !== uid)
    throw new HttpsError("permission-denied", "본인 주문만 처리 가능합니다.");
  if (order.status !== "delivered")
    throw new HttpsError("failed-precondition", "완료된 주문이 아닙니다.");
  if (order.isRyanCall)
    throw new HttpsError("already-exists", "이미 라이언 콜 처리된 주문입니다.");

  // ② 실제 라이더 수익 = deliveryFee 의 80% (플랫폼 20% 제외)
  const deliveryFee   = (order.deliveryFee ?? 0);
  const riderEarnings = Math.floor(deliveryFee * 0.8);
  if (riderEarnings <= 0)
    throw new HttpsError("invalid-argument", "수익 정보가 올바르지 않습니다.");

  // ③ 캠페인 유효성 확인
  const campSnap = await db.collection("riderAidCampaigns").doc(campaignId).get();
  if (!campSnap.exists) throw new HttpsError("not-found", "캠페인을 찾을 수 없습니다.");

  const camp = campSnap.data();
  if (camp.status !== "active")
    throw new HttpsError("failed-precondition", "진행 중인 캠페인이 아닙니다.");
  if (camp.currentAmount >= camp.goalAmount)
    throw new HttpsError("failed-precondition", "이미 목표 금액이 달성된 캠페인입니다.");

  // ④ 금액 계산
  const riderContribution = Math.floor(riderEarnings * 0.5);
  const companyMatch      = riderContribution;
  const total             = riderContribution + companyMatch;

  const newTotal     = (camp.currentAmount ?? 0) + total;
  const goalReached  = newTotal >= camp.goalAmount;

  // ⑤ 트랜잭션 처리
  await db.runTransaction(async (tx) => {
    // 참여 기록
    const contribRef = db.collection("riderAidContributions").doc();
    tx.set(contribRef, {
      campaignId,
      riderId: uid,
      riderName: riderName ?? "라이더",
      orderId,
      riderContribution,
      companyMatch,
      totalContribution: total,
      createdAt: FieldValue.serverTimestamp(),
    });

    // 캠페인 누계 업데이트
    const campUpdate = {
      currentAmount:    FieldValue.increment(total),
      companyMatchAmount: FieldValue.increment(companyMatch),
      participantCount: FieldValue.increment(1),
    };
    if (goalReached) campUpdate.status = "completed";
    tx.update(db.collection("riderAidCampaigns").doc(campaignId), campUpdate);

    // 주문 플래그
    tx.update(db.collection("orders").doc(orderId), {
      isRyanCall:         true,
      ryanCallCampaignId: campaignId,
      ryanCallContribution: total,
    });
  });

  // ⑥ 보상 포인트 +7 적립 (트랜잭션 밖 — 실패해도 기부는 완료)
  try {
    const pointRef  = db.collection("riderPoints").doc(uid);
    const pointSnap = await pointRef.get();
    const current   = pointSnap.exists ? (pointSnap.data().totalPoints ?? 0) : 0;
    const newTotal2 = current + 7;

    const historyEntry = {
      reason:   "ryanCall",
      points:   7,
      earnedAt: FieldValue.serverTimestamp(),
    };

    await pointRef.set({
      totalPoints:  FieldValue.increment(7),
      dailyPoints:  FieldValue.increment(7),
      todayHistory: FieldValue.arrayUnion(historyEntry),
      // 100점 도달 시 부스터 자동 충전
      ...(Math.floor(newTotal2 / 100) > Math.floor(current / 100)
        ? {
            boosterCharges:  FieldValue.increment(1),
            boosterGrantedAt: FieldValue.serverTimestamp(),
          }
        : {}),
    }, { merge: true });
  } catch (e) {
    console.error("포인트 적립 실패 (기부는 완료됨):", e.message);
  }

  return {
    success:     true,
    goalReached,
    contributed: total,
    message: goalReached
      ? "🎉 목표 달성! 전우를 도왔습니다. +7 포인트 적립!"
      : "🪖 참여 완료! +7 포인트가 적립됐습니다.",
  };
});

// ── 관리자 전용: Custom Claim 설정 ──────────────────────────────────────────
// 최초 1회 — 이미 admin인 사람만 호출 가능 (첫 admin은 Firebase Console에서 직접 설정)
exports.setAdminRole = onCall(async (request) => {
  assertAdmin(request.auth);
  const { targetUid } = request.data;
  if (!targetUid) throw new HttpsError("invalid-argument", "targetUid 필요");

  const { getAuth } = require("firebase-admin/auth");
  await getAuth().setCustomUserClaims(targetUid, { role: "admin" });
  return { success: true, message: `${targetUid} 에 admin 권한 부여 완료` };
});

// ── 관리자 전용: 라이언 콜 발송 ────────────────────────────────────────────
exports.dispatchRyanCall = onCall(async (request) => {
  assertAdmin(request.auth);
  const { campaignId, targetCount = 50 } = request.data;
  if (!campaignId) throw new HttpsError("invalid-argument", "campaignId 필요");

  // 캠페인 확인
  const campSnap = await db.collection("riderAidCampaigns").doc(campaignId).get();
  if (!campSnap.exists || campSnap.data().status !== "active")
    throw new HttpsError("not-found", "활성 캠페인이 없습니다.");

  const camp = campSnap.data();
  const displayName = camp.isAnonymous ? "익명의 라이더" : camp.injuredRiderName;

  // 온라인 라이더 조회
  const ridersSnap = await db.collection("riders")
    .where("isOnline", "==", true)
    .limit(targetCount)
    .get();

  if (ridersSnap.empty)
    return { success: true, sent: 0, message: "온라인 라이더 없음" };

  // FCM 멀티캐스트 발송
  const tokens = ridersSnap.docs
    .map((d) => d.data().fcmToken)
    .filter(Boolean);

  if (tokens.length > 0) {
    const chunks = [];
    for (let i = 0; i < tokens.length; i += 500)
      chunks.push(tokens.slice(i, i + 500));

    for (const chunk of chunks) {
      await getMessaging().sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: "🪖 라이언 일병 구하기",
          body:  `${displayName} 전우를 도와주세요! 이 콜을 수락하면 +7 포인트`,
        },
        data: {
          type:       "ryan_call",
          campaignId,
          campaignName: displayName,
        },
        android: { priority: "high" },
        apns:    { payload: { aps: { sound: "default" } } },
      });
    }
  }

  // 발송 이벤트 기록
  await db.collection("ryanCallDispatches").add({
    campaignId,
    sentCount:   tokens.length,
    dispatchedBy: request.auth.uid,
    createdAt:   FieldValue.serverTimestamp(),
  });

  return { success: true, sent: tokens.length };
});

// ── 관리자 전용: 부스터 가격 검증 후 마켓 등록 ──────────────────────────────
exports.listBoosterForSale = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

  const { price, sellerName } = request.data;

  // 가격 검증
  if (typeof price !== "number" || !Number.isInteger(price))
    throw new HttpsError("invalid-argument", "가격은 정수여야 합니다.");
  if (price < 1000)
    throw new HttpsError("invalid-argument", "최소 가격은 1,000원입니다.");
  if (price > 50000)
    throw new HttpsError("invalid-argument", "최대 가격은 50,000원입니다.");

  // 라이더 포인트 확인
  const pointSnap = await db.collection("riderPoints").doc(uid).get();
  if (!pointSnap.exists) throw new HttpsError("not-found", "포인트 정보 없음");

  const pt = pointSnap.data();
  if ((pt.boosterCharges ?? 0) <= 0)
    throw new HttpsError("failed-precondition", "보유 부스터가 없습니다.");

  // 판매 기한 확인 (7일 이내)
  const grantedAt = pt.boosterGrantedAt?.toDate?.();
  if (!grantedAt)
    throw new HttpsError("failed-precondition", "부스터 획득 정보가 없습니다.");
  const expiry = new Date(grantedAt.getTime() + 7 * 24 * 60 * 60 * 1000);
  if (new Date() > expiry)
    throw new HttpsError("deadline-exceeded", "판매 기한(7일)이 만료됐습니다.");

  // 트랜잭션: 부스터 차감 + 마켓 등록
  const listingRef = db.collection("boosterMarket").doc();
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(db.collection("riderPoints").doc(uid));
    if ((fresh.data()?.boosterCharges ?? 0) <= 0)
      throw new HttpsError("failed-precondition", "보유 부스터가 없습니다.");

    tx.update(db.collection("riderPoints").doc(uid), {
      boosterCharges: FieldValue.increment(-1),
    });
    tx.set(listingRef, {
      sellerId:        uid,
      sellerName:      sellerName ?? "라이더",
      price,
      boosterGrantedAt: pt.boosterGrantedAt,
      boosterExpiry:   expiry,
      status:          "available",
      buyerId:         null,
      createdAt:       FieldValue.serverTimestamp(),
      soldAt:          null,
    });
  });

  return { success: true, listingId: listingRef.id };
});

// ═══════════════════════════════════════════════════════════════════════════════
// FIRESTORE TRIGGERS
// ═══════════════════════════════════════════════════════════════════════════════

// ── 1. 새 주문 생성 → 업체에 알림 ────────────────────────────────────────────
exports.onNewOrder = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data?.data();
  if (!order) return;

  const storeDoc   = await db.collection("stores").doc(order.storeId).get();
  const fcmToken   = storeDoc.data()?.fcmToken;
  const itemSummary = (order.items || [])
    .map((i) => `${i.name} ${i.quantity}개`).join(", ");

  await sendNotification(
    fcmToken,
    "🛎️ 새 주문이 들어왔어요!",
    `${itemSummary} · ${order.totalPrice?.toLocaleString()}원`,
    { orderId: event.params.orderId, type: "new_order" }
  );
});

// ── 2. 주문 상태 변경 → 고객 / 라이더 알림 ───────────────────────────────────
exports.onOrderStatusChanged = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!before || !after || before.status === after.status) return;

  const orderId     = event.params.orderId;
  const customerDoc = await db.collection("customers").doc(after.customerId).get();
  const customerToken = customerDoc.data()?.fcmToken;

  let riderToken = null;
  if (after.riderId) {
    const riderDoc = await db.collection("riders").doc(after.riderId).get();
    riderToken = riderDoc.data()?.fcmToken;
  }

  switch (after.status) {
    case "accepted":
      await sendNotification(customerToken, "✅ 주문이 수락되었어요",
        "업체에서 주문을 확인하고 준비 중이에요", { orderId, type: "order_accepted" });
      break;
    case "assigned":
      await sendNotification(customerToken, "🛵 라이더가 배정되었어요",
        "라이더가 픽업하러 가고 있어요", { orderId, type: "rider_assigned" });
      break;
    case "picked_up":
      await sendNotification(customerToken, "🎁 음식을 픽업했어요!",
        "라이더가 배달 중이에요. 조금만 기다려주세요 🚴", { orderId, type: "picked_up" });
      break;
    case "delivered":
      await sendNotification(customerToken, "🎉 배달이 완료되었어요!",
        "맛있게 드세요! 리뷰를 남겨주세요 ⭐", { orderId, type: "delivered" });
      break;
    case "cancelled":
      await sendNotification(customerToken, "❌ 주문이 취소되었어요",
        "불편을 드려 죄송합니다", { orderId, type: "cancelled" });
      if (riderToken) {
        await sendNotification(riderToken, "❌ 배달이 취소되었어요",
          "배정된 주문이 취소되었습니다", { orderId, type: "cancelled" });
      }
      break;
  }
});

// ── 3. 주문 accepted → 온라인 라이더 전체 알림 ──────────────────────────────
exports.onOrderAccepted = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!before || !after || before.status === after.status) return;
  if (after.status !== "accepted") return;

  const ridersSnap = await db.collection("riders")
    .where("isOnline", "==", true).get();

  const itemSummary = (after.items || [])
    .map((i) => `${i.name} ${i.quantity}개`).join(", ");

  await Promise.all(
    ridersSnap.docs.map((doc) =>
      sendNotification(
        doc.data().fcmToken,
        "📦 새 배달 요청이 있어요!",
        `${itemSummary} → ${after.deliveryAddress}`,
        { orderId: event.params.orderId, type: "new_delivery" }
      )
    )
  );
});
