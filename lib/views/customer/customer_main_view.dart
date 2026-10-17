import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'customer_home_view.dart';
import 'customer_profile_view.dart';
import 'customer_vouchers_view.dart';

class CustomerMainView extends StatefulWidget {
  final AppUser user;

  const CustomerMainView({super.key, required this.user});

  @override
  State<CustomerMainView> createState() => _CustomerMainViewState();
}

class _CustomerMainViewState extends State<CustomerMainView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CustomerHomeView(user: widget.user),
      CustomerVouchersView(customerId: widget.user.id),
      CustomerProfileView(user: widget.user),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.style_rounded),
              activeIcon: Icon(Icons.style_rounded, color: AppColors.primaryLight),
              label: 'Cards',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_num_rounded),
              activeIcon: Icon(Icons.confirmation_num_rounded, color: AppColors.primaryLight),
              label: 'Vouchers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_rounded),
              activeIcon: Icon(Icons.account_circle_rounded, color: AppColors.primaryLight),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
