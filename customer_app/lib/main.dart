import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Linux 개발환경에서는 Android 옵션 사용
  FirebaseOptions options = DefaultFirebaseOptions.android;
  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      options = DefaultFirebaseOptions.android;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      options = DefaultFirebaseOptions.ios;
    }
  } else {
    options = DefaultFirebaseOptions.web;
  }

  await Firebase.initializeApp(options: options);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '배달 서비스',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
