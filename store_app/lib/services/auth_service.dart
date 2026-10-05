import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String storeName,
    required String phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    // stores 컬렉션에 업체 등록
    await _db.collection('stores').doc(cred.user!.uid).set({
      'name': storeName,
      'category': '기타',
      'address': '',
      'lat': 0.0,
      'lng': 0.0,
      'phone': phone,
      'ownerId': cred.user!.uid,
      'isOpen': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() async => _auth.signOut();
}
