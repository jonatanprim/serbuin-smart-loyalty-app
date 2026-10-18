import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      // 1. Save directly to Cloud Firestore users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Cloud Firestore save user error: $e');
    }

    try {
      // 2. Cache locally
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
    } catch (e) {
      debugPrint('Registry local cache note: $e');
    }
  }

  Future<AppUser?> _findInUserRegistry(String email, UserRole role) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      // 1. Query Cloud Firestore
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .where('role', isEqualTo: role.name)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return AppUser.fromMap(snap.docs.first.data());
      }
    } catch (e) {
      debugPrint('Cloud Firestore user lookup note: $e');
    }

    try {
      // 2. Fallback to local cache
      final prefs = await SharedPreferences.getInstance();
      final registryJson = prefs.getString('serbuin_registered_users');
      if (registryJson != null) {
        final List list = jsonDecode(registryJson);
        final match = list.firstWhere(
          (u) => u['email']?.toString().toLowerCase() == cleanEmail && u['role'] == role.name,
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

  String? _authError;
  String? get authError => _authError;

  Future<bool> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    final cleanEmail = email.trim().toLowerCase();
    final existingUser = await _findInUserRegistry(cleanEmail, role);

    if (existingUser != null) {
      // Check password in Firestore User Registry
      if (existingUser.password != null && existingUser.password!.isNotEmpty) {
        if (existingUser.password != password) {
          _isLoading = false;
          _authError = 'Incorrect password. Please verify your credentials.';
          notifyListeners();
          return false;
        }
        _currentUser = existingUser;
      } else {
        // Pre-seeded or mock account: bind the entered password in the registry
        final updatedUser = existingUser.copyWith(password: password);
        await _saveToUserRegistry(updatedUser);
        _currentUser = updatedUser;
      }
    } else {
      // Create user session with their real entered credentials in the Firestore registry
      final emailPrefix = cleanEmail.split('@').first;
      final displayName = emailPrefix.isNotEmpty
          ? emailPrefix[0].toUpperCase() + emailPrefix.substring(1)
          : (role == UserRole.merchant ? 'Merchant Store' : 'Customer Member');

      final id = '${role == UserRole.merchant ? 'merchant' : 'cust'}-${DateTime.now().millisecondsSinceEpoch}';
      _currentUser = AppUser(
        id: id,
        name: displayName,
        email: cleanEmail,
        password: password,
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
    _authError = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    final id = '${role == UserRole.merchant ? 'merchant' : 'cust'}-${DateTime.now().millisecondsSinceEpoch}';
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'User';

    final newUser = AppUser(
      id: id,
      name: cleanName,
      email: cleanEmail,
      password: password,
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
