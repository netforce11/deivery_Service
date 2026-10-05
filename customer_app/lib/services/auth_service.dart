import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 현재 로그인된 유저
  User? get currentUser => _auth.currentUser;

  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 회원가입
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = UserModel(
        id: result.user!.uid,
        name: name,
        phone: phone,
        address: '',
        createdAt: DateTime.now(),
      );

      await _db.collection('users').doc(user.id).set(user.toMap());
      return user;
    } catch (e) {
      throw Exception('회원가입 실패: $e');
    }
  }

  // 로그인
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final doc = await _db
          .collection('users')
          .doc(result.user!.uid)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('로그인 실패: $e');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 유저 정보 가져오기
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
