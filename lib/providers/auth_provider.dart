import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isMerchant => _currentUser?.role == UserRole.merchant;
  bool get isCustomer => _currentUser?.role == UserRole.customer;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('serbuin_current_user');
    if (userJson != null) {
      try {
        _currentUser = AppUser.fromMap(jsonDecode(userJson));
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Error loading saved user: $e');
      }
    }

    // Default to Customer demo on clean start
    _currentUser = _buildCustomerDemo();
    await _saveUser();
    notifyListeners();
  }

  AppUser _buildCustomerDemo() {
    return AppUser(
      id: 'cust-alex',
      email: 'alex@serbuin.com',
      name: 'Alex Morgan',
      role: UserRole.customer,
      phone: '+62 812-3456-7890',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      isProfileComplete: true,
      customerProfile: CustomerProfile(
        phone: '+62 812-3456-7890',
        birthDate: '1998-05-14',
        bio: 'Coffee connoisseur and weekend brunch lover.',
        favoriteCategory: 'Cafe & Bakery',
      ),
    );
  }

  AppUser _buildMerchantDemo() {
    return AppUser(
      id: 'merchant-1',
      email: 'merchant@serbuin.com',
      name: 'Kopi Kenangan Artisan',
      role: UserRole.merchant,
      phone: '+62 811-9876-5432',
      avatarUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=150',
      isProfileComplete: true,
      merchantProfile: MerchantProfile(
        businessName: 'Kopi Kenangan Artisan Cafe',
        category: 'Cafe & Bakery',
        address: 'Jl. Senopati No. 42, Kebayoran Baru, Jakarta Selatan',
        phone: '+62 811-9876-5432',
        operatingHours: '07:00 AM - 10:00 PM Daily',
        description:
            'Handcrafted specialty coffee, artisanal pastries, and cozy modern aesthetic.',
      ),
    );
  }

  Future<void> _saveUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(
        'serbuin_current_user',
        jsonEncode(_currentUser!.toMap()),
      );
    } else {
      await prefs.remove('serbuin_current_user');
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    if (role == UserRole.merchant) {
      _currentUser = _buildMerchantDemo().copyWith(
        email: email.trim().isEmpty ? 'merchant@serbuin.com' : email.trim(),
      );
    } else {
      _currentUser = _buildCustomerDemo().copyWith(
        email: email.trim().isEmpty ? 'alex@serbuin.com' : email.trim(),
      );
    }

    await _saveUser();
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    // Simple registration - minimal data, profile completion can be done later
    _currentUser = AppUser(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'New User' : name.trim(),
      email: email.trim(),
      role: role,
      isProfileComplete: false,
    );

    await _saveUser();
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> switchDemoRole(UserRole role) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 200));
    if (role == UserRole.merchant) {
      _currentUser = _buildMerchantDemo();
    } else {
      _currentUser = _buildCustomerDemo();
    }

    await _saveUser();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateCustomerProfile({
    required String name,
    required String phone,
    required String birthDate,
    required String bio,
    required String favoriteCategory,
  }) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      name: name,
      phone: phone,
      isProfileComplete: true,
      customerProfile: CustomerProfile(
        phone: phone,
        birthDate: birthDate,
        bio: bio,
        favoriteCategory: favoriteCategory,
      ),
    );

    await _saveUser();
    notifyListeners();
  }

  Future<void> updateMerchantProfile({
    required String businessName,
    required String category,
    required String address,
    required String phone,
    required String operatingHours,
    required String description,
  }) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      name: businessName,
      phone: phone,
      isProfileComplete: true,
      merchantProfile: MerchantProfile(
        businessName: businessName,
        category: category,
        address: address,
        phone: phone,
        operatingHours: operatingHours,
        description: description,
      ),
    );

    await _saveUser();
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    await _saveUser();
    notifyListeners();
  }
}
