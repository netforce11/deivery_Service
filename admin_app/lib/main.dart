import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/dashboard/admin_home_screen.dart';
import 'screens/auth/admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '관리자 콘솔',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0D1117),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF5C6BC0)),
              ),
            );
          }

          if (!snap.hasData) return const AdminLoginScreen();

          // Firebase Custom Claims에서 admin 역할 확인
          return FutureBuilder<IdTokenResult>(
            future: snap.data!.getIdTokenResult(true), // forceRefresh
            builder: (context, tokenSnap) {
              if (tokenSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0D1117),
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF5C6BC0)),
                  ),
                );
              }

              final claims = tokenSnap.data?.claims ?? {};
              final isAdmin = claims['role'] == 'admin';

              if (!isAdmin) {
                // 관리자 권한 없는 계정 — 로그아웃 후 오류 표시
                return _UnauthorizedScreen(
                  email: snap.data!.email ?? '',
                );
              }

              return const AdminHomeScreen();
            },
          );
        },
      ),
    );
  }
}

// ── 권한 없음 화면 ────────────────────────────────────────────────────────────
class _UnauthorizedScreen extends StatelessWidget {
  final String email;
  const _UnauthorizedScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                '접근 권한 없음',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$email\n\n관리자 권한이 없는 계정입니다.\n'
                '담당자에게 권한 부여를 요청하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
