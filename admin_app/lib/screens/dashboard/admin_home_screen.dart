import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../dashboard/dashboard_screen.dart';
import '../orders/order_management_screen.dart';
import '../management/store_rider_management_screen.dart';
import '../settlement/settlement_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard,
        label: '대시보드'),
    _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long,
        label: '주문관리'),
    _NavItem(icon: Icons.manage_accounts_outlined,
        activeIcon: Icons.manage_accounts, label: '가게/라이더'),
    _NavItem(icon: Icons.account_balance_outlined,
        activeIcon: Icons.account_balance, label: '정산'),
  ];

  final List<Widget> _screens = [
    const DashboardScreen(),
    const OrderManagementScreen(),
    const StoreRiderManagementScreen(),
    const SettlementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('관리자 콘솔',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // 현재 접속 계정
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey, size: 20),
            tooltip: '로그아웃',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          // 사이드 네비게이션
          Container(
            width: 72,
            color: const Color(0xFF161B22),
            child: Column(
              children: [
                const SizedBox(height: 16),
                ...List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final selected = _selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Tooltip(
                      message: item.label,
                      preferBelow: false,
                      child: InkWell(
                        onTap: () => setState(() => _selectedIndex = i),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF1A237E).withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: selected
                                ? Border.all(
                                    color: const Color(0xFF5C6BC0)
                                        .withOpacity(0.5))
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selected ? item.activeIcon : item.icon,
                                color: selected
                                    ? const Color(0xFF7986CB)
                                    : Colors.grey.shade600,
                                size: 22,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: selected
                                      ? const Color(0xFF7986CB)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // 구분선
          Container(width: 1, color: Colors.grey.shade900),
          // 메인 콘텐츠
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon, required this.activeIcon, required this.label});
}
