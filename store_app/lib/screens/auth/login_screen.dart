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
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _saveCredentials = true;
  String? _savedEmail;
  String? _savedPassword;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('store_saved_email');
    final pw = prefs.getString('store_saved_password');
    if (email != null && pw != null) {
      setState(() {
        _savedEmail = email;
        _savedPassword = pw;
        _emailCtrl.text = email;
        _passwordCtrl.text = pw;
      });
    }
  }

  Future<void> _login({String? email, String? pw}) async {
    final loginEmail = email ?? _emailCtrl.text.trim();
    final loginPw = pw ?? _passwordCtrl.text.trim();
    if (email == null && !_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _authService.signIn(email: loginEmail, password: loginPw);
      final prefs = await SharedPreferences.getInstance();
      if (_saveCredentials) {
        await prefs.setString('store_saved_email', loginEmail);
        await prefs.setString('store_saved_password', loginPw);
      } else {
        await prefs.remove('store_saved_email');
        await prefs.remove('store_saved_password');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('로그인 실패: 이메일/비밀번호를 확인해주세요'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // 로고
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.store, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('업체 관리자',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('배달 서비스 파트너',
                  style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 40),

              // 저장된 계정 빠른 로그인
              if (_savedEmail != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.indigo, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_savedEmail!,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          TextButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('store_saved_email');
                              await prefs.remove('store_saved_password');
                              setState(() {
                                _savedEmail = null;
                                _savedPassword = null;
                                _emailCtrl.clear();
                                _passwordCtrl.clear();
                              });
                            },
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 24)),
                            child: Text('삭제',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _loading
                              ? null
                              : () => _login(
                                  email: _savedEmail, pw: _savedPassword),
                          child: _loading
                              ? const SizedBox(
                                  width: 20, height: 20,
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
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('또는',
                        style: TextStyle(color: Colors.grey.shade400)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ]),
                const SizedBox(height: 20),
              ],

              // 로그인 폼
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field(_emailCtrl, '이메일', Icons.email_outlined,
                        type: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty ? '이메일을 입력해주세요' : null),
                    const SizedBox(height: 12),
                    _field(_passwordCtrl, '비밀번호', Icons.lock_outlined,
                        obscure: true,
                        validator: (v) =>
                            v!.length < 6 ? '비밀번호 6자 이상' : null),
                    const SizedBox(height: 8),
                    Row(children: [
                      Checkbox(
                        value: _saveCredentials,
                        onChanged: (v) =>
                            setState(() => _saveCredentials = v!),
                        activeColor: Colors.indigo,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('로그인 정보 저장',
                          style: TextStyle(fontSize: 14)),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _loading ? null : () => _login(),
                        child: _loading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('로그인',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: Text('업체 등록 (회원가입)',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type,
      bool obscure = false,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo)),
      ),
      keyboardType: type,
      obscureText: obscure,
      validator: validator,
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
