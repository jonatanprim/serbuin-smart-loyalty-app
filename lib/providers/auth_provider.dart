import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

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

    // In real data mode: user must register or sign in.
    _currentUser = null;
    notifyListeners();
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

  Future<void> _saveToUserRegistry(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final registryJson = prefs.getString('serbuin_registered_users') ?? '[]';
      final List list = jsonDecode(registryJson);
      final index = list.indexWhere((u) => u['email'] == user.email && u['role'] == user.role.name);
      if (index != -1) {
        list[index] = user.toMap();
      } else {
        list.add(user.toMap());
      }
      await prefs.setString('serbuin_registered_users', jsonEncode(list));

      // Also sync user to Firestore
      FirestoreService().syncMember(MemberRecord(
        id: user.id,
        programId: '',
        programTitle: 'Account Registry',
        merchantId: user.role == UserRole.merchant ? user.id : '',
        customerId: user.id,
        customerName: user.name,
        customerEmail: user.email,
        customerPhone: user.phone ?? '',
        stampsCollected: 0,
        totalStampsRequired: 0,
        status: 'active',
        lastStampDate: DateTime.now(),
        joinedDate: user.createdAt,
        riskLevel: 'low',
        riskReason: 'Active account',
        recommendedVoucher: '',
        aiInsight: 'Registered ${user.role.name}',
      ));
    } catch (e) {
      debugPrint('Registry save note: $e');
    }
  }

  Future<AppUser?> _findInUserRegistry(String email, UserRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final registryJson = prefs.getString('serbuin_registered_users');
      if (registryJson != null) {
        final List list = jsonDecode(registryJson);
        final match = list.firstWhere(
          (u) => u['email']?.toString().toLowerCase() == email.toLowerCase() && u['role'] == role.name,
          orElse: () => null,
        );
        if (match != null) {
          return AppUser.fromMap(Map<String, dynamic>.from(match));
        }
      }
    } catch (e) {
      debugPrint('Registry lookup note: $e');
    }
    return null;
  }

  Future<bool> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    final cleanEmail = email.trim().toLowerCase();
    final existingUser = await _findInUserRegistry(cleanEmail, role);

    if (existingUser != null) {
      _currentUser = existingUser;
    } else {
      // Create user session with their real entered credentials
      final emailPrefix = cleanEmail.split('@').first;
      final displayName = emailPrefix.isNotEmpty
          ? emailPrefix[0].toUpperCase() + emailPrefix.substring(1)
          : (role == UserRole.merchant ? 'Merchant Store' : 'Customer Member');

      final id = '${role == UserRole.merchant ? 'merchant' : 'cust'}-${DateTime.now().millisecondsSinceEpoch}';
      _currentUser = AppUser(
        id: id,
        name: displayName,
        email: cleanEmail,
        role: role,
        isProfileComplete: true,
        merchantProfile: role == UserRole.merchant
            ? MerchantProfile(
                businessName: displayName,
                category: 'Cafe & Retail',
                address: '',
                phone: '',
                operatingHours: '08:00 AM - 10:00 PM',
                description: 'Welcome to $displayName!',
              )
            : null,
        customerProfile: role == UserRole.customer
            ? CustomerProfile(
                phone: '',
                birthDate: '',
                bio: '',
                favoriteCategory: 'General',
              )
            : null,
      );
      await _saveToUserRegistry(_currentUser!);
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
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    final id = '${role == UserRole.merchant ? 'merchant' : 'cust'}-${DateTime.now().millisecondsSinceEpoch}';
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'User';

    final newUser = AppUser(
      id: id,
      name: cleanName,
      email: cleanEmail,
      role: role,
      phone: phone ?? '',
      isProfileComplete: true,
      merchantProfile: role == UserRole.merchant
          ? MerchantProfile(
              businessName: cleanName,
              category: 'Cafe & Retail',
              address: '',
              phone: phone ?? '',
              operatingHours: '08:00 AM - 10:00 PM',
              description: 'Welcome to $cleanName!',
            )
          : null,
      customerProfile: role == UserRole.customer
          ? CustomerProfile(
              phone: phone ?? '',
              birthDate: '',
              bio: '',
              favoriteCategory: 'General',
            )
          : null,
    );

    _currentUser = newUser;
    await _saveUser();
    await _saveToUserRegistry(newUser);

    _isLoading = false;
    notifyListeners();
    return true;
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
    await _saveToUserRegistry(_currentUser!);
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
    await _saveToUserRegistry(_currentUser!);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('serbuin_current_user');
    notifyListeners();
  }
}
