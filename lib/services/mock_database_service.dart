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

    // 1. Purge any old legacy dummy / seed data from local storage
    final programsJson = prefs.getString('serbuin_programs');
    if (programsJson != null && programsJson.contains('prog-kopi-1')) {
      await prefs.remove('serbuin_programs');
      await prefs.remove('serbuin_members');
      await prefs.remove('serbuin_vouchers');
      await prefs.remove('serbuin_activities');
    } else {
      // Load offline cache if present
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
        _programs = snap.docs.map((doc) => LoyaltyProgram.fromMap(doc.data())).toList();
        _saveToStorage();
        notifyListeners();
      }, onError: (e) => debugPrint('Live programs error: $e'));

      _membersSub?.cancel();
      _membersSub = firestore.collection('members').snapshots().listen((snap) {
        _members = snap.docs.map((doc) => MemberRecord.fromMap(doc.data())).toList();
        _saveToStorage();
        notifyListeners();
      }, onError: (e) => debugPrint('Live members error: $e'));

      _vouchersSub?.cancel();
      _vouchersSub = firestore.collection('vouchers').snapshots().listen((snap) {
        _vouchers = snap.docs.map((doc) => Voucher.fromMap(doc.data())).toList();
        _saveToStorage();
        notifyListeners();
      }, onError: (e) => debugPrint('Live vouchers error: $e'));

      _activitiesSub?.cancel();
      _activitiesSub = firestore.collection('activities').snapshots().listen((snap) {
        _activities = snap.docs.map((doc) => ActivityLog.fromMap(doc.data())).toList();
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
    final prog = _programs.firstWhere((p) => p.id == programId, orElse: () => throw Exception('Not found'));
    final membersInProg = _members.where((m) => m.programId == programId).length;
    if (membersInProg > 0 || prog.memberCount > 0) {
      return false; // Can't delete if members exist
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

  /// Find customer/member record by phone number, customer ID, or name
  MemberRecord? findMemberByPhoneOrIdentifier({
    required String query,
    required String programId,
  }) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    final cleanDigits = cleanQuery.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanAlpha = cleanQuery.toLowerCase();

    // 1. Search in the target program members
    for (final m in _members.where((m) => m.programId == programId)) {
      final phoneDigits = m.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
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
      final phoneDigits = m.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
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

  /// Look up registered customer user account by phone number in shared Firestore users collection
  Future<Map<String, String>?> findRegisteredCustomerByPhone(String phone) async {
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.length < 6) return null;

    // 1. Query live Cloud Firestore users collection
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final p = (data['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
        if (p.isNotEmpty && (p.endsWith(cleanDigits) || cleanDigits.endsWith(p))) {
          return {
            'id': data['id']?.toString() ?? doc.id,
            'name': data['name']?.toString() ?? '',
            'phone': data['phone']?.toString() ?? phone,
            'email': data['email']?.toString() ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('Firestore live user query note: $e');
    }

    // 2. Query loaded members
    for (final m in _members) {
      final p = m.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (p.isNotEmpty && (p.endsWith(cleanDigits) || cleanDigits.endsWith(p))) {
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

    // Find or create member record
    final memberIndex = _members.indexWhere(
      (m) => m.customerId == customerId && m.programId == programId,
    );

    MemberRecord member;
    if (memberIndex != -1) {
      final existing = _members[memberIndex];
      final newStamps = (existing.stampsCollected + count).clamp(0, program.totalStamps);
      final isCompleted = newStamps >= program.totalStamps;

      member = existing.copyWith(
        stampsCollected: newStamps,
        status: isCompleted ? 'completed' : 'active',
        lastStampDate: DateTime.now(),
        riskLevel: 'low',
        riskReason: 'Recently active in store.',
        customerPhone: customerPhone ?? existing.customerPhone,
        customerName: customerName ?? existing.customerName,
      );
      _members[memberIndex] = member;
    } else {
      member = MemberRecord(
        id: _uuid.v4(),
        programId: programId,
        programTitle: program.title,
        merchantId: merchantId,
        customerId: customerId,
        customerName: customerName ?? 'Customer Member',
        customerEmail: '$customerId@serbuin.com',
        customerPhone: customerPhone ?? '+62 812-3456-7890',
        stampsCollected: count,
        totalStampsRequired: program.totalStamps,
        status: count >= program.totalStamps ? 'completed' : 'active',
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
      userId: customerId,
      type: 'stamp_earned',
      title: 'Earned +$count Stamp${count > 1 ? 's' : ''}',
      subtitle: '${member.stampsCollected}/${member.totalStampsRequired} stamps on ${program.title}',
      merchantName: program.merchantName,
      timestamp: DateTime.now(),
      stampsCount: count,
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
    CloudRunService().sendFcmNotification(
      customerId: customerId,
      title: member.stampsCollected >= program.totalStamps ? '🎉 Reward Unlocked!' : '☕ +$count Stamp Earned!',
      body: '${member.stampsCollected}/${program.totalStamps} stamps collected on ${program.title}',
    );

    return {
      'success': true,
      'member': member,
      'program': program,
      'isCompleted': member.stampsCollected >= program.totalStamps,
      'message': 'Successfully awarded +$count stamp to ${member.customerName}!',
    };
  }

  /// Redeem voucher by QR scan
  Future<Map<String, dynamic>> redeemVoucherByCode(String code) async {
    final index = _vouchers.indexWhere((v) => v.code.toUpperCase() == code.toUpperCase());
    if (index == -1) {
      return {'success': false, 'message': 'Invalid voucher code.'};
    }

    final voucher = _vouchers[index];
    if (voucher.isRedeemed) {
      return {
        'success': false,
        'message': 'Voucher has already been redeemed on ${_formatDate(voucher.redeemedAt!)}.',
      };
    }

    if (DateTime.now().isAfter(voucher.expiresAt)) {
      return {'success': false, 'message': 'Voucher has expired.'};
    }

    final updated = voucher.copyWith(
      isRedeemed: true,
      redeemedAt: DateTime.now(),
    );
    _vouchers[index] = updated;

    final act = ActivityLog(
      id: _uuid.v4(),
      userId: voucher.customerId,
      type: 'voucher_redeemed',
      title: 'Voucher Redeemed!',
      subtitle: '${voucher.title} • ${voucher.discountValue}',
      merchantName: voucher.merchantName,
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

    return {
      'success': true,
      'voucher': updated,
      'message': 'Voucher successfully redeemed: ${voucher.title}!',
    };
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
      title: 'AI Retention Voucher Sent: $title',
      subtitle: 'Sent to ${member.customerName}',
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

  /// Claim a completed loyalty card reward to generate a voucher
  Future<Voucher?> claimProgramReward({
    required String customerId,
    required String programId,
  }) async {
    final memberIndex = _members.indexWhere(
      (m) => m.customerId == customerId && m.programId == programId,
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
      customerId: customerId,
      title: prog.rewardTitle,
      description: prog.rewardDescription,
      discountType: 'free_item',
      discountValue: 'Reward Unlocked',
      claimedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      isRedeemed: false,
    );

    _vouchers.insert(0, voucher);

    // Reset stamps or mark renewed
    final updatedMember = member.copyWith(
      stampsCollected: 0,
      status: 'active',
      lastStampDate: DateTime.now(),
    );
    _members[memberIndex] = updatedMember;

    final act = ActivityLog(
      id: _uuid.v4(),
      userId: customerId,
      type: 'voucher_claimed',
      title: 'Reward Voucher Claimed!',
      subtitle: prog.rewardTitle,
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

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
