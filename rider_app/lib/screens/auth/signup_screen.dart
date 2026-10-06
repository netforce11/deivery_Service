import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// 차량 유형
enum VehicleType {
  bicycle('bicycle', '자전거', Icons.directions_bike, Colors.green,
      '단거리 배달 전용\n7km 이내'),
  motorcycle('motorcycle', '오토바이', Icons.two_wheeler, Colors.orange,
      '일반 배달\n제한 없음'),
  car('car', '자동차', Icons.directions_car, Colors.blue,
      '장거리 배달 가능\n중계 배달 참여 가능');

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String desc;

  const VehicleType(
      this.value, this.label, this.icon, this.color, this.desc);
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();
  VehicleType? _selectedVehicle;
  bool _loading = false;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('이동 수단을 선택해주세요'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        vehicleType: _selectedVehicle!.value,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가입 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: AppBar(
        title: const Text('라이더 등록'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _field(_nameCtrl, '이름', Icons.person_outline,
                  validator: (v) => v!.isEmpty ? '이름을 입력해주세요' : null),
              const SizedBox(height: 12),
              _field(_phoneCtrl, '전화번호', Icons.phone,
                  type: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? '전화번호를 입력해주세요' : null),
              const SizedBox(height: 12),
              _field(_emailCtrl, '이메일', Icons.email_outlined,
                  type: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? '이메일을 입력해주세요' : null),
              const SizedBox(height: 12),
              _field(_passwordCtrl, '비밀번호 (6자 이상)', Icons.lock_outlined,
                  obscure: true,
                  validator: (v) => v!.length < 6 ? '비밀번호 6자 이상' : null),

              const SizedBox(height: 24),

              // ── 이동 수단 선택 ──────────────────────────────────────────
              const Text('이동 수단',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87)),
              const SizedBox(height: 4),
              Text('이동 수단에 따라 배달 가능 유형이 달라집니다',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 12),

              Row(
                children: VehicleType.values.map((v) {
                  final selected = _selectedVehicle == v;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedVehicle = v),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? v.color.withOpacity(0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? v.color : Colors.grey.shade300,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color: v.color.withOpacity(0.2),
                                      blurRadius: 8)
                                ]
                              : [],
                        ),
                        child: Column(
                          children: [
                            Icon(v.icon,
                                color: selected ? v.color : Colors.grey,
                                size: 32),
                            const SizedBox(height: 6),
                            Text(v.label,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selected
                                        ? v.color
                                        : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(v.desc,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? v.color.withOpacity(0.8)
                                        : Colors.grey,
                                    height: 1.4),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // 자동차 선택 시 장거리 안내
              if (_selectedVehicle == VehicleType.car) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '자동차 라이더는 장거리 중계 배달에 참여할 수 있으며, 협업 포인트 +3점이 추가 적립됩니다.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 자전거 선택 시 제한 안내
              if (_selectedVehicle == VehicleType.bicycle) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '자전거는 7km 이내 단거리 배달만 수신됩니다. 장거리 및 중계 배달은 제외됩니다.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _signup,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('라이더 등록',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
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
            borderSide: BorderSide(color: Colors.green.shade600)),
      ),
      keyboardType: type,
      obscureText: obscure,
      validator: validator,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
