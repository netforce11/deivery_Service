/**
 * 최초 관리자 계정에 admin Custom Claim 설정 스크립트
 *
 * 사용법:
 *   node scripts/set_admin.js <uid>
 *
 * 예시:
 *   node scripts/set_admin.js abc123xyz
 *
 * UID 확인 방법: Firebase Console → Authentication → 사용자 목록
 *
 * ⚠️  scripts/serviceAccountKey.json 이 필요합니다.
 *     절대 git에 커밋하지 마세요! (.gitignore에 등록되어 있어야 함)
 */

const admin = require('firebase-admin');
const path  = require('path');

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
const serviceAccount = require(keyPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2];
if (!uid) {
  console.error('❌ UID를 인자로 전달해주세요: node set_admin.js <uid>');
  process.exit(1);
}

admin.auth().setCustomUserClaims(uid, { role: 'admin' })
  .then(() => {
    console.log(`✅ 성공: ${uid} 에 role=admin Custom Claim 설정 완료`);
    console.log('   → 해당 계정으로 다시 로그인하면 관리자 앱에 접속 가능합니다.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ 실패:', err.message);
    process.exit(1);
  });
