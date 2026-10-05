import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _saveCredentials = true;
  String? _savedEmail;
  String? _savedPassword;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final password = prefs.getString('saved_password');
    if (email != null && password != null) {
      setState(() {
        _savedEmail = email;
        _savedPassword = password;
        _emailController.text = email;
        _passwordController.text = password;
      });
    }
  }

  Future<void> _saveOrClearCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_saveCredentials) {
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    }
  }

  Future<void> _login({String? email, String? password}) async {
    final loginEmail = email ?? _emailController.text.trim();
    final loginPassword = password ?? _passwordController.text.trim();

    if (email == null && !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signIn(email: loginEmail, password: loginPassword);
      await _saveOrClearCredentials(loginEmail, loginPassword);
      // 로그인 성공 시 main.dart의 StreamBuilder가 자동으로 StoreListScreen으로 전환
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패: 이메일/비밀번호를 확인해주세요'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 로고
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.delivery_dining, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('배달 서비스',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('전주 배달대행', style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 40),

              // 저장된 계정 빠른 로그인 버튼
              if (_savedEmail != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _savedEmail!,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('saved_email');
                              await prefs.remove('saved_password');
                              setState(() {
                                _savedEmail = null;
                                _savedPassword = null;
                                _emailController.clear();
                                _passwordController.clear();
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(40, 24),
                            ),
                            child: Text('삭제',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () => _login(
                                  email: _savedEmail,
                                  password: _savedPassword),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('이 계정으로 바로 로그인',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('또는', style: TextStyle(color: Colors.grey.shade400)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // 이메일/비밀번호 폼
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: '이메일',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.orange)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? '이메일을 입력해주세요' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.orange)),
                      ),
                      obscureText: true,
                      validator: (v) => v!.length < 6 ? '비밀번호는 6자 이상이어야 합니다' : null,
                    ),
                    const SizedBox(height: 8),
                    // 로그인 정보 저장 체크박스
                    Row(
                      children: [
                        Checkbox(
                          value: _saveCredentials,
                          onChanged: (v) => setState(() => _saveCredentials = v!),
                          activeColor: Colors.orange,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const Text('로그인 정보 저장', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : () => _login(),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('로그인',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: Text('계정이 없으신가요? 회원가입',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
