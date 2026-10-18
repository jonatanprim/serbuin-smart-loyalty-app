import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'cloud_run_service.dart';

class MockDatabaseService extends ChangeNotifier {
  static final MockDatabaseService _instance = MockDatabaseService._internal();
  factory MockDatabaseService() => _instance;
  MockDatabaseService._internal();

  final _uuid = const Uuid();

  List<LoyaltyProgram> _programs = [];
  List<MemberRecord> _members = [];
  List<Voucher> _vouchers = [];
  List<ActivityLog> _activities = [];

  List<LoyaltyProgram> get programs => List.unmodifiable(_programs);
  List<MemberRecord> get members => List.unmodifiable(_members);
  List<Voucher> get vouchers => List.unmodifiable(_vouchers);
  List<ActivityLog> get activities => List.unmodifiable(_activities);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  StreamSubscription? _programsSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _vouchersSub;
  StreamSubscription? _activitiesSub;

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Purge ANY old legacy dummy / seed data from local storage
    bool purgeLegacy(String? str) {
      if (str == null) return false;
      return str.contains('prog-kopi-1') ||
          str.contains('Alex Morgan') ||
          str.contains('cust-alex') ||
          str.contains('mem-1') ||
          str.contains('+62 812-3456-7890');
    }

    if (purgeLegacy(prefs.getString('serbuin_programs')) ||
        purgeLegacy(prefs.getString('serbuin_members')) ||
        purgeLegacy(prefs.getString('serbuin_vouchers')) ||
        purgeLegacy(prefs.getString('serbuin_activities'))) {
      await prefs.remove('serbuin_programs');
      await prefs.remove('serbuin_members');
      await prefs.remove('serbuin_vouchers');
      await prefs.remove('serbuin_activities');
    } else {
      // Load offline cache if present
      final programsJson = prefs.getString('serbuin_programs');
      final membersJson = prefs.getString('serbuin_members');
      final vouchersJson = prefs.getString('serbuin_vouchers');
      final activitiesJson = prefs.getString('serbuin_activities');

      if (programsJson != null) {
        try {
          _programs = (jsonDecode(programsJson) as List)
              .map((e) => LoyaltyProgram.fromMap(e))
              .toList();
        } catch (_) {}
      }
      if (membersJson != null) {
        try {
          _members = (jsonDecode(membersJson) as List)
              .map((e) => MemberRecord.fromMap(e))
              .toList();
        } catch (_) {}
      }
      if (vouchersJson != null) {
        try {
          _vouchers = (jsonDecode(vouchersJson) as List)
              .map((e) => Voucher.fromMap(e))
              .toList();
        } catch (_) {}
      }
      if (activitiesJson != null) {
        try {
          _activities = (jsonDecode(activitiesJson) as List)
              .map((e) => ActivityLog.fromMap(e))
              .toList();
        } catch (_) {}
      }
    }

    _isInitialized = true;
    notifyListeners();

    // 2. Connect to live Cloud Firestore collections for 100% real-time multi-device sync
    _startLiveFirestoreStreams();
  }

  void _startLiveFirestoreStreams() {
    try {
      final firestore = FirebaseFirestore.instance;

      _programsSub?.cancel();
      _programsSub = firestore.collection('programs').snapshots().listen((snap) {
        final list = <LoyaltyProgram>[];
        for (final doc in snap.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = data['id'] ?? doc.id;
            list.add(LoyaltyProgram.fromMap(data));
          } catch (e) {
            debugPrint('Error parsing program ${doc.id}: $e');
          }
        }
        _programs = list;
        _saveToStorage();
        notifyListeners();
      }, onError: (e) => debugPrint('Live programs error: $e'));

      _membersSub?.cancel();
      _membersSub = firestore.collection('members').snapshots().listen((snap) {
        final list = <MemberRecord>[];
        for (final doc in snap.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = data['id'] ?? doc.id;
            list.add(MemberRecord.fromMap(data));
          } catch (e) {
            debugPrint('Error parsing member ${doc.id}: $e');
          }
        }
        _members = list;
        _saveToStorage();
        notifyListeners();
      }, onError: (e) => debugPrint('Live members error: $e'));

      _vouchersSub?.cancel();
      _vouchersSub = firestore.collection('vouchers').snapshots().listen((snap) {
        final list = <Voucher>[];
        for (final doc in snap.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = data['id'] ?? doc.id;
            list.add(Voucher.fromMap(data));
          } catch (e) {
            debugPrint('Error parsing voucher ${doc.id}: $e');
          }
        }
        _vouchers = list;
        _saveToStorage();
        notifyListeners();
      }, onError: (e) => debugPrint('Live vouchers error: $e'));

      _activitiesSub?.cancel();
      _activitiesSub = firestore.collection('activities').snapshots().listen((snap) {
        final list = <ActivityLog>[];
        for (final doc in snap.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = data['id'] ?? doc.id;
            list.add(ActivityLog.fromMap(data));
          } catch (e) {
            debugPrint('Error parsing activity ${doc.id}: $e');
          }
        }
        _activities = list;
        _saveToStorage();
        notifyListeners();
      }, onError: (e) => debugPrint('Live activities error: $e'));
    } catch (e) {
      debugPrint('Firestore real-time listeners initialization note: $e');
    }
  }

  @override
  void dispose() {
    _programsSub?.cancel();
    _membersSub?.cancel();
    _vouchersSub?.cancel();
    _activitiesSub?.cancel();
    super.dispose();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'serbuin_programs',
        jsonEncode(_programs.map((e) => e.toMap()).toList()),
      );
      await prefs.setString(
        'serbuin_members',
        jsonEncode(_members.map((e) => e.toMap()).toList()),
      );
      await prefs.setString(
        'serbuin_vouchers',
        jsonEncode(_vouchers.map((e) => e.toMap()).toList()),
      );
      await prefs.setString(
        'serbuin_activities',
        jsonEncode(_activities.map((e) => e.toMap()).toList()),
      );
    } catch (_) {}
  }

  // --- Merchant Methods ---

  /// Total active programs for a merchant (Max 3)
  int getMerchantActiveProgramCount(String merchantId) {
    return _programs.where((p) => p.merchantId == merchantId && p.isActive).length;
  }

  /// Create new program (Validates max 3)
  Future<bool> createProgram(LoyaltyProgram newProgram) async {
    final currentCount = getMerchantActiveProgramCount(newProgram.merchantId);
    if (currentCount >= 3) {
      return false; // Exceeds limit of 3
    }

    final newActivity = ActivityLog(
      id: _uuid.v4(),
      userId: newProgram.merchantId,
      type: 'program_created',
      title: 'Program Published: ${newProgram.title}',
      subtitle: 'Max stamps: ${newProgram.totalStamps} • ${newProgram.rewardTitle}',
      merchantName: newProgram.merchantName,
      timestamp: DateTime.now(),
    );

    _programs.insert(0, newProgram);
    _activities.insert(0, newActivity);
    await _saveToStorage();
    notifyListeners();

    // Persist to Cloud Firestore (triggers real-time update across all devices)
    try {
      await FirebaseFirestore.instance
          .collection('programs')
          .doc(newProgram.id)
          .set(newProgram.toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(newActivity.id)
          .set(newActivity.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore createProgram error: $e');
    }
    return true;
  }

  /// Update program
  Future<void> updateProgram(LoyaltyProgram updatedProgram) async {
    final index = _programs.indexWhere((p) => p.id == updatedProgram.id);
    if (index != -1) {
      _programs[index] = updatedProgram;
      await _saveToStorage();
      notifyListeners();

      try {
        await FirebaseFirestore.instance
          .collection('programs')
          .doc(updatedProgram.id)
          .set(updatedProgram.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore updateProgram error: $e');
      }
    }
  }

  /// Delete program (Allowed only if memberCount == 0)
  Future<bool> deleteProgram(String programId) async {
    final prog = _programs.firstWhere((p) => p.id == programId, orElse: () => _programs.first);
    if (prog.memberCount > 0) {
      return false; // Cannot delete program with enrolled members
    }

    _programs.removeWhere((p) => p.id == programId);
    await _saveToStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('programs').doc(programId).delete();
    } catch (e) {
      debugPrint('Firestore deleteProgram error: $e');
    }
    return true;
  }

  /// Archive/Deactivate program
  Future<void> archiveProgram(String programId) async {
    final index = _programs.indexWhere((p) => p.id == programId);
    if (index != -1) {
      final updated = _programs[index].copyWith(isActive: false);
      _programs[index] = updated;
      await _saveToStorage();
      notifyListeners();

      try {
        await FirebaseFirestore.instance
          .collection('programs')
          .doc(programId)
          .update({'isActive': false});
      } catch (e) {
        debugPrint('Firestore archiveProgram error: $e');
      }
    }
  }

  /// Find active member record belonging strictly to the specified program
  MemberRecord? findActiveMemberInProgram({
    required String query,
    required String programId,
  }) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    final cleanDigits = normalizePhoneNumber(cleanQuery);
    final cleanAlpha = cleanQuery.toLowerCase();

    for (final m in _members.where((m) => m.programId == programId && m.status == 'active')) {
      final phoneDigits = normalizePhoneNumber(m.customerPhone);
      if (cleanDigits.length >= 6 && phoneDigits.isNotEmpty) {
        if (phoneDigits.endsWith(cleanDigits) || cleanDigits.endsWith(phoneDigits)) {
          return m;
        }
      }
      if (m.customerId.toLowerCase() == cleanAlpha ||
          m.customerName.toLowerCase() == cleanAlpha ||
          (cleanAlpha.length >= 4 && m.customerName.toLowerCase().contains(cleanAlpha))) {
        return m;
      }
    }
    return null;
  }

  /// Find customer/member record by phone number, customer ID, or name
  MemberRecord? findMemberByPhoneOrIdentifier({
    required String query,
    required String programId,
  }) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    final cleanDigits = normalizePhoneNumber(cleanQuery);
    final cleanAlpha = cleanQuery.toLowerCase();

    // 1. Search in the target program members
    for (final m in _members.where((m) => m.programId == programId)) {
      final phoneDigits = normalizePhoneNumber(m.customerPhone);
      if (cleanDigits.length >= 6 && phoneDigits.isNotEmpty) {
        if (phoneDigits.endsWith(cleanDigits) || cleanDigits.endsWith(phoneDigits)) {
          return m;
        }
      }
      if (m.customerId.toLowerCase() == cleanAlpha ||
          m.customerName.toLowerCase() == cleanAlpha ||
          m.customerName.toLowerCase().contains(cleanAlpha)) {
        return m;
      }
    }

    // 2. Search across other programs (to reuse name, phone, customerId)
    for (final m in _members) {
      final phoneDigits = normalizePhoneNumber(m.customerPhone);
      if (cleanDigits.length >= 6 && phoneDigits.isNotEmpty) {
        if (phoneDigits.endsWith(cleanDigits) || cleanDigits.endsWith(phoneDigits)) {
          final prog = _programs.firstWhere((p) => p.id == programId, orElse: () => _programs.first);
          return MemberRecord(
            id: 'mem-${DateTime.now().millisecondsSinceEpoch}',
            programId: programId,
            programTitle: prog.title,
            merchantId: prog.merchantId,
            customerId: m.customerId,
            customerName: m.customerName,
            customerEmail: m.customerEmail,
            customerPhone: m.customerPhone,
            stampsCollected: 0,
            totalStampsRequired: prog.totalStamps,
            status: 'active',
            lastStampDate: DateTime.now(),
            joinedDate: DateTime.now(),
            riskLevel: 'low',
            riskReason: 'Enrolled in new program',
            recommendedVoucher: 'Welcome treat',
            aiInsight: 'Cross-program customer',
          );
        }
      }
      if (m.customerId.toLowerCase() == cleanAlpha ||
          m.customerName.toLowerCase() == cleanAlpha) {
        final prog = _programs.firstWhere((p) => p.id == programId, orElse: () => _programs.first);
        return MemberRecord(
          id: 'mem-${DateTime.now().millisecondsSinceEpoch}',
          programId: programId,
          programTitle: prog.title,
          merchantId: prog.merchantId,
          customerId: m.customerId,
          customerName: m.customerName,
          customerEmail: m.customerEmail,
          customerPhone: m.customerPhone,
          stampsCollected: 0,
          totalStampsRequired: prog.totalStamps,
          status: 'active',
          lastStampDate: DateTime.now(),
          joinedDate: DateTime.now(),
          riskLevel: 'low',
          riskReason: 'Enrolled in new program',
          recommendedVoucher: 'Welcome treat',
          aiInsight: 'Cross-program customer',
        );
      }
    }

    return null;
  }

  /// Look up registered customer user account in shared Firestore users collection or loaded members
  Future<Map<String, String>?> findRegisteredCustomer(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;
    final cleanAlpha = cleanQuery.toLowerCase();
    final cleanDigits = normalizePhoneNumber(cleanQuery);

    // 1. Query live Cloud Firestore users collection
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = (data['id'] ?? doc.id).toString();
        final name = (data['name'] ?? '').toString();
        final phone = (data['phone'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final pDigits = normalizePhoneNumber(phone);

        if (cleanDigits.length >= 6 && pDigits.isNotEmpty) {
          if (pDigits.endsWith(cleanDigits) || cleanDigits.endsWith(pDigits)) {
            return {'id': id, 'name': name, 'phone': phone, 'email': email};
          }
        }
        if (id.toLowerCase() == cleanAlpha ||
            (email.isNotEmpty && email.toLowerCase() == cleanAlpha) ||
            (name.isNotEmpty && name.toLowerCase() == cleanAlpha)) {
          return {'id': id, 'name': name, 'phone': phone, 'email': email};
        }
      }
    } catch (e) {
      debugPrint('Firestore live user query note: $e');
    }

    // 2. Query loaded members
    for (final m in _members) {
      final pDigits = normalizePhoneNumber(m.customerPhone);
      if (cleanDigits.length >= 6 && pDigits.isNotEmpty) {
        if (pDigits.endsWith(cleanDigits) || cleanDigits.endsWith(pDigits)) {
          return {
            'id': m.customerId,
            'name': m.customerName,
            'phone': m.customerPhone,
            'email': m.customerEmail,
          };
        }
      }
      if (m.customerId.toLowerCase() == cleanAlpha ||
          (m.customerEmail.isNotEmpty && m.customerEmail.toLowerCase() == cleanAlpha) ||
          m.customerName.toLowerCase() == cleanAlpha) {
        return {
          'id': m.customerId,
          'name': m.customerName,
          'phone': m.customerPhone,
          'email': m.customerEmail,
        };
      }
    }

    return null;
  }

  /// Alias for backward compatibility
  Future<Map<String, String>?> findRegisteredCustomerByPhone(String phone) =>
      findRegisteredCustomer(phone);

  /// Fetch full customer profile data (birthDate, favoriteCategory, etc.) for real data lookup
  Future<Map<String, dynamic>?> getCustomerProfileData(String customerId, [String? phone]) async {
    final cleanId = customerId.trim().toLowerCase();
    final cleanPhone = phone != null ? normalizePhoneNumber(phone) : '';

    // 1. Try from live Firestore
    try {
      if (cleanId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(customerId).get();
        if (doc.exists && doc.data() != null) {
          return doc.data();
        }
      }
      final querySnap = await FirebaseFirestore.instance.collection('users').get();
      for (final doc in querySnap.docs) {
        final data = doc.data();
        final docId = (data['id'] ?? doc.id).toString().toLowerCase();
        final docPhone = normalizePhoneNumber((data['phone'] ?? '').toString());
        if (cleanId.isNotEmpty && docId == cleanId) return data;
        if (cleanPhone.isNotEmpty && docPhone.isNotEmpty && (docPhone.endsWith(cleanPhone) || cleanPhone.endsWith(docPhone))) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('Firestore customer profile fetch note: $e');
    }

    // 2. Try from local preferences registered users cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final regJson = prefs.getString('serbuin_registered_users');
      if (regJson != null) {
        final List list = jsonDecode(regJson);
        for (final item in list) {
          if (item is Map) {
            final uId = (item['id'] ?? '').toString().toLowerCase();
            final uPhone = normalizePhoneNumber((item['phone'] ?? '').toString());
            if (cleanId.isNotEmpty && uId == cleanId) {
              return Map<String, dynamic>.from(item);
            }
            if (cleanPhone.isNotEmpty && uPhone.isNotEmpty && (uPhone.endsWith(cleanPhone) || cleanPhone.endsWith(uPhone))) {
              return Map<String, dynamic>.from(item);
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fetch all registered customers from Firestore
  Future<List<Map<String, String>>> getAllRegisteredCustomers() async {
    final list = <Map<String, String>>[];
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['role'] == 'customer') {
          list.add({
            'id': (data['id'] ?? doc.id).toString(),
            'name': (data['name'] ?? 'Customer').toString(),
            'phone': (data['phone'] ?? '').toString(),
            'email': (data['email'] ?? '').toString(),
          });
        }
      }
    } catch (e) {
      debugPrint('Get all registered customers note: $e');
    }
    return list;
  }

  /// Award stamp to a member by scanning QR or entering phone
  Future<Map<String, dynamic>> awardStampToCustomer({
    required String merchantId,
    required String customerId,
    required String programId,
    String? customerName,
    String? customerPhone,
    int count = 1,
  }) async {
    final progIndex = _programs.indexWhere((p) => p.id == programId);
    if (progIndex == -1) {
      return {'success': false, 'message': 'Loyalty program not found.'};
    }
    final program = _programs[progIndex];

    final normInputPhone = normalizePhoneNumber(customerPhone?.isNotEmpty == true ? customerPhone : customerId);

    // Look up if user is registered in Firestore
    final regUser = await findRegisteredCustomer(customerId.isNotEmpty ? customerId : (customerPhone ?? ''));

    final actualCustomerId = regUser?['id'] ?? (customerId.isNotEmpty ? customerId : (customerPhone ?? ''));
    final actualCustomerName = (customerName != null && customerName.trim().isNotEmpty && customerName != 'Customer Member')
        ? customerName.trim()
        : (regUser?['name']?.isNotEmpty == true ? regUser!['name']! : 'Member');
    final actualCustomerPhone = (customerPhone != null && customerPhone.trim().isNotEmpty)
        ? customerPhone.trim()
        : (regUser?['phone'] ?? '');
    final actualCustomerEmail = regUser?['email'] ?? '';

    // Find existing active member record in this program (preserve completed cards)
    final memberIndex = _members.indexWhere((m) {
      if (m.programId != programId) return false;
      if (m.status == 'completed') return false;
      if (actualCustomerId.isNotEmpty && (m.customerId == actualCustomerId || m.customerId == customerId)) return true;
      if (normInputPhone.length >= 6) {
        final normMemberPhone = normalizePhoneNumber(m.customerPhone);
        if (normMemberPhone.isNotEmpty &&
            (normMemberPhone.endsWith(normInputPhone) || normInputPhone.endsWith(normMemberPhone))) {
          return true;
        }
      }
      return false;
    });

    MemberRecord member;
    if (memberIndex != -1) {
      final existing = _members[memberIndex];
      final newStamps = (existing.stampsCollected + count).clamp(0, program.totalStamps);

      member = existing.copyWith(
        customerId: actualCustomerId.isNotEmpty ? actualCustomerId : existing.customerId,
        customerName: actualCustomerName.isNotEmpty && actualCustomerName != 'Member'
            ? actualCustomerName
            : existing.customerName,
        customerPhone: actualCustomerPhone.isNotEmpty ? actualCustomerPhone : existing.customerPhone,
        customerEmail: actualCustomerEmail.isNotEmpty ? actualCustomerEmail : existing.customerEmail,
        stampsCollected: newStamps,
        status: 'active',
        lastStampDate: DateTime.now(),
        riskLevel: 'low',
        riskReason: 'Active stamp earned.',
      );
      _members[memberIndex] = member;
    } else {
      member = MemberRecord(
        id: _uuid.v4(),
        programId: programId,
        programTitle: program.title,
        merchantId: merchantId,
        customerId: actualCustomerId,
        customerName: actualCustomerName,
        customerEmail: actualCustomerEmail,
        customerPhone: actualCustomerPhone,
        stampsCollected: count,
        totalStampsRequired: program.totalStamps,
        status: 'active',
        lastStampDate: DateTime.now(),
        joinedDate: DateTime.now(),
        riskLevel: 'low',
        riskReason: 'New member just enrolled!',
        recommendedVoucher: 'Welcome treat',
        aiInsight: 'New customer started their journey.',
      );
      _members.insert(0, member);
      _programs[progIndex] = program.copyWith(memberCount: program.memberCount + 1);
    }

    // Add activity
    final newActivity = ActivityLog(
      id: _uuid.v4(),
      userId: actualCustomerId,
      type: count > 0 ? 'stamp_earned' : 'program_joined',
      title: count > 0 ? 'Earned +$count Stamp${count > 1 ? 's' : ''}' : 'Joined ${program.title}',
      subtitle: '${member.stampsCollected}/${member.totalStampsRequired} stamps on ${program.title}',
      merchantName: program.merchantName,
      timestamp: DateTime.now(),
      stampsCount: count > 0 ? count : null,
    );
    _activities.insert(0, newActivity);

    await _saveToStorage();
    notifyListeners();

    // Persist to Cloud Firestore (Immediately syncs to customer's phone!)
    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(member.id)
          .set(member.toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(newActivity.id)
          .set(newActivity.toMap(), SetOptions(merge: true));

      if (memberIndex == -1) {
        await FirebaseFirestore.instance
            .collection('programs')
            .doc(program.id)
            .update({'memberCount': FieldValue.increment(1)});
      }
    } catch (e) {
      debugPrint('Firestore awardStamp sync error: $e');
    }

    // Trigger Cloud Run FCM push notification
    if (count > 0) {
      CloudRunService().sendFcmNotification(
        customerId: actualCustomerId,
        title: member.stampsCollected >= program.totalStamps ? '🎉 Reward Unlocked!' : '☕ +$count Stamp Earned!',
        body: '${member.stampsCollected}/${program.totalStamps} stamps collected on ${program.title}',
      );
    } else {
      CloudRunService().sendFcmNotification(
        customerId: actualCustomerId,
        title: '🎉 Welcome to ${program.title}!',
        body: 'You are now officially a member of ${program.merchantName}.',
      );
    }

    return {
      'success': true,
      'member': member,
      'program': program,
      'isCompleted': member.stampsCollected >= program.totalStamps,
      'message': count > 0
          ? 'Successfully awarded +$count stamp to ${member.customerName}!'
          : 'Successfully added ${member.customerName} as member!',
    };
  }

  /// Utility to clean and normalize voucher codes from QR payloads or inputs
  static String cleanVoucherCode(String input) {
    var code = input.trim();
    if (code.startsWith('VOUCHER|')) {
      code = code.substring(8);
    }
    // Remove dynamic refresh suffix like -REF1, -REF2, etc.
    code = code.replaceAll(RegExp(r'-REF\d+$', caseSensitive: false), '');
    return code.trim();
  }

  /// Look up voucher by scanned QR payload, voucher code, or ID
  Future<Voucher?> findVoucher(String rawCode) async {
    final clean = cleanVoucherCode(rawCode);
    if (clean.isEmpty) return null;

    final cleanUpper = clean.toUpperCase();
    final rawUpper = rawCode.trim().toUpperCase();

    // 1. Check in loaded vouchers
    for (final v in _vouchers) {
      if (v.code.toUpperCase() == cleanUpper ||
          v.id.toUpperCase() == cleanUpper ||
          v.code.toUpperCase() == rawUpper ||
          v.id.toUpperCase() == rawUpper) {
        return v;
      }
    }

    // 2. Query live Cloud Firestore if not found in memory
    try {
      final firestore = FirebaseFirestore.instance;
      // Search by code
      var snap = await firestore
          .collection('vouchers')
          .where('code', isEqualTo: cleanUpper)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        snap = await firestore
            .collection('vouchers')
            .where('code', isEqualTo: clean)
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) {
        // Try getting by document ID
        final doc = await firestore.collection('vouchers').doc(clean).get();
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = data['id'] ?? doc.id;
          final v = Voucher.fromMap(data);
          final idx = _vouchers.indexWhere((x) => x.id == v.id);
          if (idx == -1) {
            _vouchers.insert(0, v);
          } else {
            _vouchers[idx] = v;
          }
          await _saveToStorage();
          notifyListeners();
          return v;
        }
      } else {
        final doc = snap.docs.first;
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = data['id'] ?? doc.id;
        final v = Voucher.fromMap(data);
        final idx = _vouchers.indexWhere((x) => x.id == v.id);
        if (idx == -1) {
          _vouchers.insert(0, v);
        } else {
          _vouchers[idx] = v;
        }
        await _saveToStorage();
        notifyListeners();
        return v;
      }
    } catch (e) {
      debugPrint('Firestore findVoucher query note: $e');
    }

    return null;
  }

  /// Get the most recent transaction date and activity description for a customer
  Map<String, dynamic> getLastCustomerTransaction(String customerId, {String? merchantId}) {
    DateTime? latestDate;
    String description = 'Loyalty card activity';
    int? stampsCount;

    // 1. Inspect activities
    final userActivities = _activities.where((a) => a.userId == customerId).toList();
    if (merchantId != null && merchantId.isNotEmpty) {
      // Prioritize activities for this merchant if any
      final merchantProgs = _programs.where((p) => p.merchantId == merchantId).map((p) => p.title.toLowerCase()).toSet();
      final merchantActs = userActivities.where((a) =>
          merchantProgs.contains(a.subtitle.toLowerCase()) ||
          a.merchantName.isNotEmpty).toList();
      if (merchantActs.isNotEmpty) {
        merchantActs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        latestDate = merchantActs.first.timestamp;
        description = '${merchantActs.first.title} (${merchantActs.first.subtitle})';
        stampsCount = merchantActs.first.stampsCount;
      }
    }

    if (latestDate == null && userActivities.isNotEmpty) {
      userActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      latestDate = userActivities.first.timestamp;
      description = '${userActivities.first.title} (${userActivities.first.subtitle})';
      stampsCount = userActivities.first.stampsCount;
    }

    // 2. Inspect members lastStampDate
    final userMembers = _members.where((m) => m.customerId == customerId).toList();
    if (userMembers.isNotEmpty) {
      userMembers.sort((a, b) => b.lastStampDate.compareTo(a.lastStampDate));
      final memberLastDate = userMembers.first.lastStampDate;
      if (latestDate == null || memberLastDate.isAfter(latestDate)) {
        latestDate = memberLastDate;
        description = 'Last stamp on ${userMembers.first.programTitle}';
        stampsCount = userMembers.first.stampsCollected;
      }
    }

    return {
      'date': latestDate,
      'description': description,
      'stamps': stampsCount,
    };
  }

  /// Force refresh vouchers list from Firestore
  Future<void> refreshVouchers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('vouchers').get();
      final list = <Voucher>[];
      for (final doc in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = data['id'] ?? doc.id;
          list.add(Voucher.fromMap(data));
        } catch (e) {
          debugPrint('Error parsing voucher ${doc.id}: $e');
        }
      }
      _vouchers = list;
      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshVouchers error: $e');
    }
  }

  /// Approve and redeem voucher object
  Future<Map<String, dynamic>> redeemVoucher(Voucher voucher, {String? merchantId}) async {
    if (merchantId != null && merchantId.isNotEmpty && voucher.merchantId != merchantId) {
      return {
        'success': false,
        'message': 'Voucher is not from this merchant. This voucher belongs to ${voucher.merchantName}.',
      };
    }

    final index = _vouchers.indexWhere((v) => v.id == voucher.id || v.code.toUpperCase() == voucher.code.toUpperCase());
    final currentVoucher = index != -1 ? _vouchers[index] : voucher;

    if (currentVoucher.isRedeemed) {
      final redeemedStr = currentVoucher.redeemedAt != null ? _formatDate(currentVoucher.redeemedAt!) : 'previously';
      return {
        'success': false,
        'message': 'Voucher was already redeemed on $redeemedStr.',
      };
    }

    if (DateTime.now().isAfter(currentVoucher.expiresAt)) {
      return {'success': false, 'message': 'Voucher has expired.'};
    }

    final updated = currentVoucher.copyWith(
      isRedeemed: true,
      redeemedAt: DateTime.now(),
    );

    if (index != -1) {
      _vouchers[index] = updated;
    } else {
      _vouchers.insert(0, updated);
    }

    final act = ActivityLog(
      id: _uuid.v4(),
      userId: updated.customerId,
      type: 'voucher_redeemed',
      title: 'Voucher Redeemed',
      subtitle: '${updated.title} • Redeemed at ${updated.merchantName}',
      merchantName: updated.merchantName,
      timestamp: DateTime.now(),
    );
    _activities.insert(0, act);

    await _saveToStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('vouchers')
          .doc(updated.id)
          .set(updated.toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(act.id)
          .set(act.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore redeem voucher error: $e');
    }

    // Trigger Cloud Run FCM push notification to customer
    CloudRunService().sendFcmNotification(
      customerId: updated.customerId,
      title: 'Voucher Successfully Redeemed',
      body: 'Voucher "${updated.title}" has been successfully redeemed at ${updated.merchantName}.',
    );

    return {
      'success': true,
      'voucher': updated,
      'message': 'Voucher "${updated.title}" successfully approved & redeemed!',
    };
  }

  /// Redeem voucher by QR scan code
  Future<Map<String, dynamic>> redeemVoucherByCode(String code, {String? merchantId}) async {
    final clean = cleanVoucherCode(code);
    var voucher = await findVoucher(clean);
    voucher ??= await findVoucher(code);

    if (voucher == null) {
      return {'success': false, 'message': 'Voucher not found.'};
    }

    return redeemVoucher(voucher, merchantId: merchantId);
  }

  /// Send AI retention voucher to a member
  Future<void> sendAiRetentionVoucher({
    required String memberId,
    required String title,
    required String description,
  }) async {
    final memberIndex = _members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return;
    final member = _members[memberIndex];

    final prog = _programs.firstWhere(
      (p) => p.id == member.programId,
      orElse: () => _programs.first,
    );
    final merchantName = prog.merchantName;

    final newVoucher = Voucher(
      id: _uuid.v4(),
      code: 'RET-${_uuid.v4().substring(0, 6).toUpperCase()}',
      programId: member.programId,
      merchantId: member.merchantId,
      merchantName: merchantName,
      customerId: member.customerId,
      title: title,
      description: description,
      discountType: 'percentage',
      discountValue: 'Exclusive Perk',
      claimedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      isRedeemed: false,
    );

    _vouchers.insert(0, newVoucher);

    final act = ActivityLog(
      id: _uuid.v4(),
      userId: member.customerId,
      type: 'voucher_claimed',
      title: 'Personalized Retention Voucher Sent: $title',
      subtitle: 'Delivered to ${member.customerName}',
      merchantName: merchantName,
      timestamp: DateTime.now(),
    );
    _activities.insert(0, act);

    // Update member record with improved risk level
    _members[memberIndex] = member.copyWith(
      riskLevel: 'medium',
      riskReason: 'Retention voucher delivered. Monitoring revisit.',
    );

    await _saveToStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('vouchers')
          .doc(newVoucher.id)
          .set(newVoucher.toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('members')
          .doc(_members[memberIndex].id)
          .set(_members[memberIndex].toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(act.id)
          .set(act.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore retention voucher error: $e');
    }

    // Trigger Cloud Run FCM push notification to customer
    CloudRunService().sendFcmNotification(
      customerId: member.customerId,
      title: '🎁 Exclusive Retention Perk!',
      body: '$title has been sent to your wallet by $merchantName.',
    );
  }

  // --- Customer Methods ---

  /// Claim a completed loyalty card reward to generate a voucher and mark card as completed
  Future<Voucher?> claimProgramReward({
    required String customerId,
    required String programId,
  }) async {
    final memberIndex = _members.indexWhere(
      (m) =>
          (m.customerId == customerId || m.id == customerId) &&
          m.programId == programId &&
          m.status != 'completed',
    );
    if (memberIndex == -1) return null;
    final member = _members[memberIndex];

    if (member.stampsCollected < member.totalStampsRequired) {
      return null; // Not enough stamps
    }

    final prog = _programs.firstWhere((p) => p.id == programId);

    final voucher = Voucher(
      id: _uuid.v4(),
      code: 'SRB-${_uuid.v4().substring(0, 8).toUpperCase()}',
      programId: programId,
      merchantId: prog.merchantId,
      merchantName: prog.merchantName,
      customerId: member.customerId,
      title: prog.rewardTitle,
      description: prog.rewardDescription,
      discountType: 'free_item',
      discountValue: 'Reward Unlocked',
      claimedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      isRedeemed: false,
    );

    _vouchers.insert(0, voucher);

    // Auto set card to completed and preserve total stamps
    final updatedMember = member.copyWith(
      stampsCollected: member.totalStampsRequired,
      status: 'completed',
      lastStampDate: DateTime.now(),
    );
    _members[memberIndex] = updatedMember;

    final act = ActivityLog(
      id: _uuid.v4(),
      userId: member.customerId,
      type: 'voucher_claimed',
      title: 'Program Completed & Reward Claimed! 🎉',
      subtitle: '${prog.title} • ${prog.rewardTitle}',
      merchantName: prog.merchantName,
      timestamp: DateTime.now(),
    );
    _activities.insert(0, act);

    await _saveToStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('vouchers')
          .doc(voucher.id)
          .set(voucher.toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('members')
          .doc(updatedMember.id)
          .set(updatedMember.toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(act.id)
          .set(act.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore claim reward error: $e');
    }

    return voucher;
  }

  /// Enroll or join customer into another loyalty program of that merchant
  Future<MemberRecord> joinProgram({
    required String customerId,
    required String programId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
  }) async {
    // If the customer already has an active card for this program, return it
    for (final m in _members) {
      if (m.programId == programId && m.customerId == customerId && m.status == 'active') {
        return m;
      }
    }

    final prog = _programs.firstWhere((p) => p.id == programId);

    // Resolve customer details from registered customers or existing memberships
    String finalName = customerName?.trim() ?? '';
    String finalPhone = customerPhone?.trim() ?? '';
    String finalEmail = customerEmail?.trim() ?? '';

    if (finalName.isEmpty || finalPhone.isEmpty) {
      final regUser = await findRegisteredCustomer(customerId);
      if (regUser != null) {
        if (finalName.isEmpty) finalName = regUser['name'] ?? 'Member';
        if (finalPhone.isEmpty) finalPhone = regUser['phone'] ?? '';
        if (finalEmail.isEmpty) finalEmail = regUser['email'] ?? '';
      }
    }

    if (finalName.isEmpty) {
      for (final m in _members) {
        if (m.customerId == customerId) {
          finalName = m.customerName;
          if (finalPhone.isEmpty) finalPhone = m.customerPhone;
          if (finalEmail.isEmpty) finalEmail = m.customerEmail;
          break;
        }
      }
    }

    if (finalName.isEmpty) finalName = 'Member';

    final newMember = MemberRecord(
      id: 'mem-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 4)}',
      programId: programId,
      programTitle: prog.title,
      merchantId: prog.merchantId,
      customerId: customerId,
      customerName: finalName,
      customerEmail: finalEmail,
      customerPhone: finalPhone,
      stampsCollected: 0,
      totalStampsRequired: prog.totalStamps,
      status: 'active',
      lastStampDate: DateTime.now(),
      joinedDate: DateTime.now(),
      riskLevel: 'low',
      riskReason: 'New membership enrolled',
      recommendedVoucher: 'Welcome treat',
      aiInsight: 'Joined ${prog.title}',
    );

    _members.insert(0, newMember);

    // Increment program memberCount
    final progIdx = _programs.indexWhere((p) => p.id == programId);
    if (progIdx != -1) {
      _programs[progIdx] = prog.copyWith(memberCount: prog.memberCount + 1);
    }

    final newActivity = ActivityLog(
      id: _uuid.v4(),
      userId: customerId,
      type: 'program_joined',
      title: 'Joined ${prog.title}',
      subtitle: 'Started new loyalty membership at ${prog.merchantName}',
      merchantName: prog.merchantName,
      timestamp: DateTime.now(),
    );
    _activities.insert(0, newActivity);

    await _saveToStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(newMember.id)
          .set(newMember.toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('programs')
          .doc(prog.id)
          .update({'memberCount': prog.memberCount + 1});
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(newActivity.id)
          .set(newActivity.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore joinProgram error: $e');
    }

    return newMember;
  }

  /// Generate realistic mock customer data for testing live churn risk & AI retention vouchers
  Future<int> generateMockCustomerData({
    required String merchantId,
    required String programId,
  }) async {
    final progIndex = _programs.indexWhere((p) => p.id == programId);
    if (progIndex == -1) return 0;
    final program = _programs[progIndex];

    final mockProfiles = [
      {
        'id': 'cust-mock-01',
        'name': 'Amanda Putri',
        'email': 'amanda.putri@serbuin.com',
        'phone': '081234567801',
        'birthDate': '1998-04-12',
        'bio': 'Coffee enthusiast and remote product designer.',
        'favoriteCategory': 'Signature Beverages',
        'favoriteItem': 'Signature Iced Caramel Macchiato',
        'stamps': (program.totalStamps * 0.7).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 42,
        'riskLevel': 'high',
        'churnScore': 89,
        'riskReason': '42 days without visit despite being close to reward unlocking.',
        'aiInsight': 'High engagement history now at immediate risk of churn.',
        'totalVisits': 7,
      },
      {
        'id': 'cust-mock-02',
        'name': 'Budi Santoso',
        'email': 'budi.santoso@serbuin.com',
        'phone': '081234567802',
        'birthDate': '1993-09-25',
        'bio': 'Architect who loves morning espresso and pastries.',
        'favoriteCategory': 'Bakery & Pastry',
        'favoriteItem': 'Almond Croissant & Double Espresso',
        'stamps': (program.totalStamps * 0.8).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 48,
        'riskLevel': 'high',
        'churnScore': 93,
        'riskReason': 'High risk: 48 days inactive with high stamp progress.',
        'aiInsight': 'Very high lifetime value customer at urgent churn risk.',
        'totalVisits': 8,
      },
      {
        'id': 'cust-mock-03',
        'name': 'Citra Dewi',
        'email': 'citra.dewi@serbuin.com',
        'phone': '081234567803',
        'birthDate': '2001-02-18',
        'bio': 'University student and matcha lover.',
        'favoriteCategory': 'Matcha & Tea',
        'favoriteItem': 'Kyoto Ceremonial Matcha Latte',
        'stamps': (program.totalStamps * 0.5).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 36,
        'riskLevel': 'high',
        'churnScore': 82,
        'riskReason': 'Inactivity exceeded 5 weeks after reaching halfway mark.',
        'aiInsight': 'Responds strongly to student discounts and afternoon treats.',
        'totalVisits': 5,
      },
      {
        'id': 'cust-mock-04',
        'name': 'Dimas Pratama',
        'email': 'dimas.pratama@serbuin.com',
        'phone': '081234567804',
        'birthDate': '1996-07-08',
        'bio': 'Tech consultant & frequent digital nomad.',
        'favoriteCategory': 'Cold Brew',
        'favoriteItem': 'Nitro Vanilla Cold Brew',
        'stamps': (program.totalStamps * 0.4).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 22,
        'riskLevel': 'medium',
        'churnScore': 58,
        'riskReason': 'Visit cadence dropped from weekly to zero visits in 3 weeks.',
        'aiInsight': 'Moderate churn risk. A timely reminder offer will re-engage.',
        'totalVisits': 4,
      },
      {
        'id': 'cust-mock-05',
        'name': 'Eka Wijaya',
        'email': 'eka.wijaya@serbuin.com',
        'phone': '081234567805',
        'birthDate': '1999-11-30',
        'bio': 'Food blogger & dessert aficionado.',
        'favoriteCategory': 'Pastry',
        'favoriteItem': 'Cinnamon Roll & Flat White',
        'stamps': (program.totalStamps * 0.3).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 19,
        'riskLevel': 'medium',
        'churnScore': 51,
        'riskReason': '19 days since last transaction. Approaching high risk threshold.',
        'aiInsight': 'Enjoys sweet pairings with afternoon coffee.',
        'totalVisits': 3,
      },
      {
        'id': 'cust-mock-06',
        'name': 'Faisal Rahman',
        'email': 'faisal.rahman@serbuin.com',
        'phone': '081234567806',
        'birthDate': '1990-03-15',
        'bio': 'Corporate manager who holds team huddles at cafe.',
        'favoriteCategory': 'Artisan Brews',
        'favoriteItem': 'V60 Single Origin Ethiopian',
        'stamps': (program.totalStamps * 0.6).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 25,
        'riskLevel': 'medium',
        'churnScore': 64,
        'riskReason': '25 days inactive after consistent early visits.',
        'aiInsight': 'High ticket size per visit with strong preference for pour-overs.',
        'totalVisits': 6,
      },
      {
        'id': 'cust-mock-07',
        'name': 'Gita Savitri',
        'email': 'gita.savitri@serbuin.com',
        'phone': '081234567807',
        'birthDate': '1997-12-05',
        'bio': 'Creative director & daily morning customer.',
        'favoriteCategory': 'Espresso & Milk',
        'favoriteItem': 'Oat Milk Spanish Latte',
        'stamps': (program.totalStamps * 0.9).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 2,
        'riskLevel': 'low',
        'churnScore': 12,
        'riskReason': 'Highly active champion member. Visited 2 days ago.',
        'aiInsight': 'Very loyal customer close to completing reward.',
        'totalVisits': 9,
      },
      {
        'id': 'cust-mock-08',
        'name': 'Hendra Setiawan',
        'email': 'hendra.setiawan@serbuin.com',
        'phone': '081234567808',
        'birthDate': '1994-08-22',
        'bio': 'Fitness enthusiast & black coffee drinker.',
        'favoriteCategory': 'Americano',
        'favoriteItem': 'Iced Americano Grande',
        'stamps': (program.totalStamps * 0.4).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 3,
        'riskLevel': 'low',
        'churnScore': 15,
        'riskReason': 'Regular healthy visit rhythm.',
        'aiInsight': 'Consistent weekday morning visitor.',
        'totalVisits': 4,
      },
      {
        'id': 'cust-mock-09',
        'name': 'Indah Permata',
        'email': 'indah.permata@serbuin.com',
        'phone': '081234567809',
        'birthDate': '2002-05-19',
        'bio': 'Social media creator & brunch lover.',
        'favoriteCategory': 'Seasonal Specials',
        'favoriteItem': 'Avocado Toast & Matcha Fusion',
        'stamps': 2,
        'daysInactive': 1,
        'riskLevel': 'low',
        'churnScore': 10,
        'riskReason': 'New member with active engagement in the last 24h.',
        'aiInsight': 'Recently enrolled and highly engaged.',
        'totalVisits': 2,
      },
      {
        'id': 'cust-mock-10',
        'name': 'Joko Susilo',
        'email': 'joko.susilo@serbuin.com',
        'phone': '081234567810',
        'birthDate': '1988-10-10',
        'bio': 'Finance analyst working nearby.',
        'favoriteCategory': 'Traditional Brews',
        'favoriteItem': 'Kopi Tubruk & Banana Fritter',
        'stamps': (program.totalStamps * 0.5).round().clamp(1, program.totalStamps - 1),
        'daysInactive': 4,
        'riskLevel': 'low',
        'churnScore': 18,
        'riskReason': 'Reliable frequent visits.',
        'aiInsight': 'Appreciates traditional snack pairings.',
        'totalVisits': 5,
      },
    ];

    int createdCount = 0;

    for (final p in mockProfiles) {
      final daysInactive = p['daysInactive'] as int;
      final totalVisits = p['totalVisits'] as int;
      final lastStampDate = DateTime.now().subtract(Duration(days: daysInactive));
      final joinedDate = lastStampDate.subtract(Duration(days: totalVisits * 5));
      final birthDateStr = p['birthDate'] as String;
      final bDate = DateTime.tryParse(birthDateStr) ?? DateTime(1995, 1, 1);
      final age = DateTime.now().year - bDate.year;

      // 1. Create real AppUser in Firestore & local cache so it can be logged in
      final user = AppUser(
        id: p['id'] as String,
        email: p['email'] as String,
        name: p['name'] as String,
        role: UserRole.customer,
        phone: p['phone'] as String,
        isProfileComplete: true,
        createdAt: joinedDate,
        customerProfile: CustomerProfile(
          phone: p['phone'] as String,
          birthDate: birthDateStr,
          bio: p['bio'] as String,
          favoriteCategory: p['favoriteCategory'] as String,
        ),
      );

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .set(user.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore seed user note: $e');
      }

      // Also cache in local registered users registry
      try {
        final prefs = await SharedPreferences.getInstance();
        final regJson = prefs.getString('serbuin_registered_users') ?? '[]';
        final List list = jsonDecode(regJson);
        final idx = list.indexWhere((u) => u['id'] == user.id || u['email'] == user.email);
        if (idx != -1) {
          list[idx] = user.toMap();
        } else {
          list.add(user.toMap());
        }
        await prefs.setString('serbuin_registered_users', jsonEncode(list));
      } catch (_) {}

      // 2. Create MemberRecord in Firestore & memory
      final memberId = 'mem-${p['id']}-$programId';
      final member = MemberRecord(
        id: memberId,
        programId: programId,
        programTitle: program.title,
        merchantId: merchantId,
        customerId: p['id'] as String,
        customerName: p['name'] as String,
        customerEmail: p['email'] as String,
        customerPhone: p['phone'] as String,
        stampsCollected: p['stamps'] as int,
        totalStampsRequired: program.totalStamps,
        status: 'active',
        lastStampDate: lastStampDate,
        joinedDate: joinedDate,
        riskLevel: p['riskLevel'] as String,
        churnScore: p['churnScore'] as int,
        riskReason: p['riskReason'] as String,
        aiInsight: p['aiInsight'] as String,
        recommendedVoucher: 'AI Retention Reward Voucher',
        customerAge: age,
        favoriteItem: p['favoriteItem'] as String,
        totalSpend: null,
        totalVisits: totalVisits,
        personalizedVoucherReason:
            'AI predicted churn probability of ${p['churnScore']}%. Targeted retention offer based on customer favorite ${p['favoriteItem']}.',
      );

      _members.removeWhere((m) => m.id == member.id || (m.programId == programId && m.customerId == member.customerId));
      _members.insert(0, member);

      try {
        await FirebaseFirestore.instance
            .collection('members')
            .doc(member.id)
            .set(member.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore seed member note: $e');
      }

      // 3. Create Stamp Earned History Activities in Firestore & memory
      for (int v = 0; v < totalVisits; v++) {
        final visitDate = joinedDate.add(Duration(days: (v + 1) * 4));
        final act = ActivityLog(
          id: 'act-${p['id']}-$programId-$v',
          userId: p['id'] as String,
          type: 'stamp_earned',
          title: 'Earned +1 Stamp',
          subtitle: '${v + 1}/${program.totalStamps} stamps on ${program.title}',
          merchantName: program.merchantName,
          timestamp: visitDate,
          stampsCount: 1,
        );

        _activities.removeWhere((a) => a.id == act.id);
        _activities.insert(0, act);

        try {
          await FirebaseFirestore.instance
              .collection('activities')
              .doc(act.id)
              .set(act.toMap(), SetOptions(merge: true));
        } catch (_) {}
      }

      createdCount++;
    }

    // 4. Update program member count
    final activeCount = _members.where((m) => m.programId == programId && m.status == 'active').length;
    _programs[progIndex] = program.copyWith(memberCount: activeCount);

    try {
      await FirebaseFirestore.instance
          .collection('programs')
          .doc(program.id)
          .update({'memberCount': activeCount});
    } catch (_) {}

    await _saveToStorage();
    notifyListeners();

    return createdCount;
  }

  /// Clear mock customer data for a program
  Future<int> clearMockCustomerData({
    required String programId,
  }) async {
    const mockPrefix = 'cust-mock-';
    final toRemove = _members.where((m) => m.programId == programId && m.customerId.startsWith(mockPrefix)).toList();

    for (final m in toRemove) {
      _members.removeWhere((x) => x.id == m.id);
      _activities.removeWhere((a) => a.userId == m.customerId && a.subtitle.contains(m.programTitle));
      try {
        await FirebaseFirestore.instance.collection('members').doc(m.id).delete();
      } catch (_) {}
    }

    final pIdx = _programs.indexWhere((p) => p.id == programId);
    if (pIdx != -1) {
      final activeCount = _members.where((m) => m.programId == programId && m.status == 'active').length;
      _programs[pIdx] = _programs[pIdx].copyWith(memberCount: activeCount);
      try {
        await FirebaseFirestore.instance.collection('programs').doc(programId).update({'memberCount': activeCount});
      } catch (_) {}
    }

    await _saveToStorage();
    notifyListeners();
    return toRemove.length;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
