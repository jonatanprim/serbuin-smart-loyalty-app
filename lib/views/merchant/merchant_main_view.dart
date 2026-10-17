import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'merchant_home_view.dart';
import 'merchant_members_view.dart';
import 'merchant_profile_view.dart';
import 'merchant_scan_view.dart';

class MerchantMainView extends StatefulWidget {
  final AppUser user;

  const MerchantMainView({super.key, required this.user});

  @override
  State<MerchantMainView> createState() => _MerchantMainViewState();
}

class _MerchantMainViewState extends State<MerchantMainView> {
  int _currentIndex = 0;

  void _openScanView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantScanView(merchantId: widget.user.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MerchantHomeView(user: widget.user),
      MerchantMembersView(merchantId: widget.user.id),
      MerchantProfileView(user: widget.user),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 24),
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
          onPressed: _openScanView,
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomAppBar(
          color: AppColors.surface,
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          elevation: 0,
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Home
              _NavBarItem(
                icon: Icons.storefront_rounded,
                label: 'Home',
                isSelected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),

              // Left-Center: Members
              _NavBarItem(
                icon: Icons.people_alt_rounded,
                label: 'Members',
                isSelected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),

              // Spacer for the center floating button
              const SizedBox(width: 48),

              // Right-Center: Guide / Quick Scan label indicator
              _NavBarItem(
                icon: Icons.center_focus_strong_rounded,
                label: 'Scan QR',
                isSelected: false,
                onTap: _openScanView,
              ),

              // Right: Profile
              _NavBarItem(
                icon: Icons.account_circle_rounded,
                label: 'Profile',
                isSelected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primaryLight : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
