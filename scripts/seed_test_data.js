/**
 * 테스트 계정 및 샘플 데이터 생성 스크립트
 *
 * 실행 전: npm install firebase-admin
 * 실행: node scripts/seed_test_data.js
 *
 * 테스트 계정:
 *   고객  - customer@test.com / test1234
 *   라이더 - rider@test.com    / test1234
 *   가게  - store@test.com    / test1234
 */

const admin = require('firebase-admin');

// Firebase 프로젝트 초기화 (firebase CLI 로그인 상태에서 자동 인증)
admin.initializeApp({
  projectId: 'delivery-service-98dfc',
});

const auth = admin.auth();
const db = admin.firestore();

// ── 테스트 계정 정의 ──────────────────────────────────────────────────────────
const TEST_ACCOUNTS = [
  {
    email: 'customer@test.com',
    password: 'test1234',
    displayName: '테스트 고객',
    role: 'customer',
  },
  {
    email: 'rider@test.com',
    password: 'test1234',
    displayName: '테스트 라이더',
    role: 'rider',
  },
  {
    email: 'store@test.com',
    password: 'test1234',
    displayName: '테스트 사장님',
    role: 'store',
  },
];

// ── Firebase Auth 계정 생성 (이미 있으면 재사용) ──────────────────────────────
async function getOrCreateUser(account) {
  try {
    const existing = await auth.getUserByEmail(account.email);
    console.log(`  ✓ 기존 계정 재사용: ${account.email} (uid: ${existing.uid})`);
    return existing.uid;
  } catch {
    const user = await auth.createUser({
      email: account.email,
      password: account.password,
      displayName: account.displayName,
    });
    console.log(`  ✓ 계정 생성: ${account.email} (uid: ${user.uid})`);
    return user.uid;
  }
}

// ── 가게 + 메뉴 데이터 생성 ────────────────────────────────────────────────────
async function seedStore(ownerUid) {
  // 기존 가게 확인
  const existing = await db.collection('stores')
    .where('ownerId', '==', ownerUid)
    .limit(1)
    .get();

  let storeId;
  if (!existing.empty) {
    storeId = existing.docs[0].id;
    console.log(`  ✓ 기존 가게 재사용 (id: ${storeId})`);
  } else {
    const storeRef = await db.collection('stores').add({
      name: '테스트 치킨집',
      ownerId: ownerUid,
      address: '서울시 강남구 테스트로 123',
      category: '치킨',
      description: '바삭한 테스트 치킨 전문점',
      isOpen: true,
      rating: 4.5,
      reviewCount: 12,
      minOrderAmount: 15000,
      deliveryFee: 3500,
      estimatedTime: '30~40분',
      imageUrl: '',
      fcmToken: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    storeId = storeRef.id;
    console.log(`  ✓ 가게 생성 (id: ${storeId})`);
  }

  // 메뉴 생성 (없을 때만)
  const menuSnap = await db.collection('menus')
    .where('storeId', '==', storeId)
    .limit(1)
    .get();

  if (menuSnap.empty) {
    const menus = [
      { name: '후라이드 치킨', price: 18000, category: '치킨', description: '바삭한 후라이드', isAvailable: true },
      { name: '양념 치킨', price: 19000, category: '치킨', description: '달콤 매콤 양념', isAvailable: true },
      { name: '반반 치킨', price: 20000, category: '치킨', description: '후라이드+양념 반반', isAvailable: true },
      { name: '간장 치킨', price: 20000, category: '치킨', description: '달콤한 간장소스', isAvailable: true },
      { name: '콜라 1.25L', price: 3000, category: '음료', description: '시원한 콜라', isAvailable: true },
      { name: '치킨무', price: 500, category: '사이드', description: '아삭한 치킨무', isAvailable: true },
    ];

    const batch = db.batch();
    for (const menu of menus) {
      const ref = db.collection('menus').doc();
      batch.set(ref, {
        ...menu,
        storeId,
        imageUrl: '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    console.log(`  ✓ 메뉴 ${menus.length}개 생성`);
  } else {
    console.log(`  ✓ 기존 메뉴 재사용`);
  }

  return storeId;
}

// ── 라이더 Firestore 문서 생성 ────────────────────────────────────────────────
async function seedRider(riderUid) {
  const riderRef = db.collection('riders').doc(riderUid);
  const snap = await riderRef.get();
  if (snap.exists) {
    console.log(`  ✓ 기존 라이더 문서 재사용`);
  } else {
    await riderRef.set({
      name: '테스트 라이더',
      phone: '010-1234-5678',
      email: 'rider@test.com',
      isOnline: true,
      vehicleType: '오토바이',
      totalDeliveries: 0,
      rating: 5.0,
      fcmToken: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ✓ 라이더 문서 생성`);
  }
}

// ── 메인 실행 ──────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n🚀 테스트 데이터 생성 시작...\n');

  // 1. 계정 생성
  console.log('📧 Firebase Auth 계정 생성');
  const uids = {};
  for (const account of TEST_ACCOUNTS) {
    uids[account.role] = await getOrCreateUser(account);
  }

  // 2. 가게 데이터
  console.log('\n🏪 가게 데이터 생성');
  await seedStore(uids.store);

  // 3. 라이더 데이터
  console.log('\n🏍️  라이더 데이터 생성');
  await seedRider(uids.rider);

  // 4. 결과 출력
  console.log('\n✅ 완료! 테스트 계정:\n');
  console.log('┌─────────────────────────────────────────────────┐');
  console.log('│  역할    이메일                  비밀번호        │');
  console.log('├─────────────────────────────────────────────────┤');
  console.log('│  고객    customer@test.com       test1234       │');
  console.log('│  라이더  rider@test.com          test1234       │');
  console.log('│  가게    store@test.com          test1234       │');
  console.log('└─────────────────────────────────────────────────┘');

  process.exit(0);
}

main().catch((err) => {
  console.error('❌ 오류:', err.message);
  process.exit(1);
});
