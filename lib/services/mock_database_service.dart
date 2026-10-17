import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'cloud_run_service.dart';
import 'firestore_service.dart';

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

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final programsJson = prefs.getString('serbuin_programs');
    final membersJson = prefs.getString('serbuin_members');
    final vouchersJson = prefs.getString('serbuin_vouchers');
    final activitiesJson = prefs.getString('serbuin_activities');

    if (programsJson != null && membersJson != null) {
      try {
        _programs = (jsonDecode(programsJson) as List)
            .map((e) => LoyaltyProgram.fromMap(e))
            .toList();
        _members = (jsonDecode(membersJson) as List)
            .map((e) => MemberRecord.fromMap(e))
            .toList();
        _vouchers = (jsonDecode(vouchersJson ?? '[]') as List)
            .map((e) => Voucher.fromMap(e))
            .toList();
        _activities = (jsonDecode(activitiesJson ?? '[]') as List)
            .map((e) => ActivityLog.fromMap(e))
            .toList();
        _isInitialized = true;
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Failed to parse cached data, falling back to seed: $e');
      }
    }

    _seedData();
    await _saveToStorage();
    _isInitialized = true;
    notifyListeners();
  }

  void _seedData() {
    final now = DateTime.now();

    // Seed 2 programs for merchant (limit max 3)
    _programs = [
      LoyaltyProgram(
        id: 'prog-kopi-1',
        merchantId: 'merchant-1',
        merchantName: 'Kopi Kenangan Artisan',
        title: 'Brew Master 6-Stamps Card',
        description: 'Earn 1 stamp for every specialty drink ordered. Collect 6 stamps to claim your complimentary single-origin beverage!',
        category: 'Cafe & Bakery',
        totalStamps: 6,
        rewardTitle: 'Free Single-Origin Pour Over & Pastry',
        rewardDescription: 'Valid for any signature single-origin brew with choice of freshly baked butter croissant.',
        gradientColors: ['#6366F1', '#A855F7'],
        iconName: 'coffee',
        isActive: true,
        createdAt: now.subtract(const Duration(days: 45)),
        memberCount: 24,
      ),
      LoyaltyProgram(
        id: 'prog-kopi-2',
        merchantId: 'merchant-1',
        merchantName: 'Kopi Kenangan Artisan',
        title: 'Pastry & Brunch Elite Club',
        description: 'Indulge in our brunch items and handcrafted pastries. Collect 8 stamps to unlock an entire brunch set on the house!',
        category: 'Cafe & Bakery',
        totalStamps: 8,
        rewardTitle: 'Free Gourmet Truffle Croissant & Latte',
        rewardDescription: 'Enjoy our top-selling savory truffle croissant paired with any regular sized hot latte.',
        gradientColors: ['#EC4899', '#FB7185'],
        iconName: 'restaurant',
        isActive: true,
        createdAt: now.subtract(const Duration(days: 20)),
        memberCount: 18,
      ),
    ];

    // Seed merchant members with diverse risk and stamps
    _members = [
      MemberRecord(
        id: 'mem-1',
        programId: 'prog-kopi-1',
        programTitle: 'Brew Master 6-Stamps Card',
        merchantId: 'merchant-1',
        customerId: 'cust-alex',
        customerName: 'Alex Morgan',
        customerEmail: 'alex@serbuin.com',
        customerPhone: '+62 812-3456-7890',
        stampsCollected: 5,
        totalStampsRequired: 6,
        status: 'active',
        lastStampDate: now.subtract(const Duration(days: 2)),
        joinedDate: now.subtract(const Duration(days: 30)),
        riskLevel: 'low',
        riskReason: 'Regular customer with visits every 2-3 days.',
        recommendedVoucher: 'Instant 10% Off add-on snack',
        aiInsight: 'Almost completed card (5/6 stamps). High engagement expected.',
      ),
      MemberRecord(
        id: 'mem-2',
        programId: 'prog-kopi-1',
        programTitle: 'Brew Master 6-Stamps Card',
        merchantId: 'merchant-1',
        customerId: 'cust-sarah',
        customerName: 'Sarah Jenkins',
        customerEmail: 'sarah.j@example.com',
        customerPhone: '+62 812-9876-5432',
        stampsCollected: 4,
        totalStampsRequired: 6,
        status: 'active',
        lastStampDate: now.subtract(const Duration(days: 26)),
        joinedDate: now.subtract(const Duration(days: 60)),
        riskLevel: 'high',
        riskReason: '26 days since last visit despite being 2 stamps away from reward.',
        recommendedVoucher: 'Comeback Special: 40% Off Any Beverage',
        aiInsight: 'At severe churn risk. A targeted 40% voucher can stimulate return within 72 hours.',
      ),
      MemberRecord(
        id: 'mem-3',
        programId: 'prog-kopi-1',
        programTitle: 'Brew Master 6-Stamps Card',
        merchantId: 'merchant-1',
        customerId: 'cust-david',
        customerName: 'David Chen',
        customerEmail: 'david.chen@example.com',
        customerPhone: '+62 813-1122-3344',
        stampsCollected: 6,
        totalStampsRequired: 6,
        status: 'completed',
        lastStampDate: now.subtract(const Duration(days: 5)),
        joinedDate: now.subtract(const Duration(days: 40)),
        riskLevel: 'low',
        riskReason: 'Fully completed program reward and ready for renewal.',
        recommendedVoucher: 'Reward Claim Reminder & Double Stamp Renewal',
        aiInsight: 'Loyal advocate. Ready to start new loyalty card.',
      ),
      MemberRecord(
        id: 'mem-4',
        programId: 'prog-kopi-2',
        programTitle: 'Pastry & Brunch Elite Club',
        merchantId: 'merchant-1',
        customerId: 'cust-jessica',
        customerName: 'Jessica Lee',
        customerEmail: 'jess.lee@example.com',
        customerPhone: '+62 815-5566-7788',
        stampsCollected: 3,
        totalStampsRequired: 8,
        status: 'active',
        lastStampDate: now.subtract(const Duration(days: 14)),
        joinedDate: now.subtract(const Duration(days: 35)),
        riskLevel: 'medium',
        riskReason: '14 days without visit; previous cadence was weekly.',
        recommendedVoucher: 'Free Cinnamon Roll on Next Brunch',
        aiInsight: 'Moderate lapse. Sweet incentive recommendation fits weekend dining pattern.',
      ),
      MemberRecord(
        id: 'mem-5',
        programId: 'prog-kopi-2',
        programTitle: 'Pastry & Brunch Elite Club',
        merchantId: 'merchant-1',
        customerId: 'cust-michael',
        customerName: 'Michael Taylor',
        customerEmail: 'mtaylor@example.com',
        customerPhone: '+62 818-9988-7766',
        stampsCollected: 1,
        totalStampsRequired: 8,
        status: 'expired',
        lastStampDate: now.subtract(const Duration(days: 75)),
        joinedDate: now.subtract(const Duration(days: 90)),
        riskLevel: 'high',
        riskReason: '75 days inactive after initial stamp.',
        recommendedVoucher: 'Win-Back Exclusive: Buy 1 Get 1 Free Pastry',
        aiInsight: 'Needs strong reactivation offer to re-ignite habit.',
      ),
      MemberRecord(
        id: 'mem-6',
        programId: 'prog-kopi-1',
        programTitle: 'Brew Master 6-Stamps Card',
        merchantId: 'merchant-1',
        customerId: 'cust-emily',
        customerName: 'Emily Watson',
        customerEmail: 'emily.w@example.com',
        customerPhone: '+62 817-0011-2233',
        stampsCollected: 2,
        totalStampsRequired: 6,
        status: 'active',
        lastStampDate: now.subtract(const Duration(days: 3)),
        joinedDate: now.subtract(const Duration(days: 10)),
        riskLevel: 'low',
        riskReason: 'New enthusiastic member, 2 stamps in 10 days.',
        recommendedVoucher: 'Welcome Perks + Bonus Stamp',
        aiInsight: 'High retention potential. On track to complete in 3 weeks.',
      ),
    ];

    // Seed customer vouchers (for Alex)
    _vouchers = [
      Voucher(
        id: 'vouch-1',
        code: 'SERBUIN-LATTE-8821',
        programId: 'prog-kopi-1',
        merchantId: 'merchant-1',
        merchantName: 'Kopi Kenangan Artisan',
        customerId: 'cust-alex',
        title: 'Free Single-Origin Pour Over',
        description: 'Enjoy your claimed loyalty reward! Valid for hot or iced single-origin brew.',
        discountType: 'free_item',
        discountValue: 'Free Specialty Brew',
        claimedAt: now.subtract(const Duration(hours: 4)),
        expiresAt: now.add(const Duration(days: 25)),
        isRedeemed: false,
      ),
      Voucher(
        id: 'vouch-2',
        code: 'SERBUIN-BRUNCH-4419',
        programId: 'prog-kopi-2',
        merchantId: 'merchant-1',
        merchantName: 'Kopi Kenangan Artisan',
        customerId: 'cust-alex',
        title: '25% Off Weekend Brunch Platter',
        description: 'Special member courtesy voucher for weekend dining.',
        discountType: 'percentage',
        discountValue: '25% OFF',
        claimedAt: now.subtract(const Duration(days: 3)),
        expiresAt: now.add(const Duration(days: 14)),
        isRedeemed: false,
      ),
    ];

    // Seed activities
    _activities = [
      ActivityLog(
        id: 'act-1',
        userId: 'cust-alex',
        type: 'stamp_earned',
        title: 'Earned +1 Stamp',
        subtitle: 'Reached 5/6 stamps on Brew Master Card',
        merchantName: 'Kopi Kenangan Artisan',
        timestamp: now.subtract(const Duration(days: 2, hours: 3)),
        stampsCount: 1,
      ),
      ActivityLog(
        id: 'act-2',
        userId: 'cust-alex',
        type: 'voucher_claimed',
        title: 'Claimed Reward Voucher',
        subtitle: 'Free Single-Origin Pour Over ready to use',
        merchantName: 'Kopi Kenangan Artisan',
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
      ActivityLog(
        id: 'act-3',
        userId: 'cust-alex',
        type: 'stamp_earned',
        title: 'Earned +1 Stamp',
        subtitle: 'Signature Cold Brew ordered',
        merchantName: 'Kopi Kenangan Artisan',
        timestamp: now.subtract(const Duration(days: 7)),
        stampsCount: 1,
      ),
      ActivityLog(
        id: 'act-4',
        userId: 'merchant-1',
        type: 'program_created',
        title: 'New Program Published',
        subtitle: 'Brew Master 6-Stamps Card is now live',
        merchantName: 'Kopi Kenangan Artisan',
        timestamp: now.subtract(const Duration(days: 45)),
      ),
    ];
  }

  Future<void> _saveToStorage() async {
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

    _programs.insert(0, newProgram);

    _activities.insert(
      0,
      ActivityLog(
        id: _uuid.v4(),
        userId: newProgram.merchantId,
        type: 'program_created',
        title: 'Program Published: ${newProgram.title}',
        subtitle: 'Max stamps: ${newProgram.totalStamps} • ${newProgram.rewardTitle}',
        merchantName: newProgram.merchantName,
        timestamp: DateTime.now(),
      ),
    );

    await _saveToStorage();
    notifyListeners();

    // Sync to Cloud Firestore
    FirestoreService().syncProgram(newProgram);
    return true;
  }

  /// Update program
  Future<void> updateProgram(LoyaltyProgram updatedProgram) async {
    final index = _programs.indexWhere((p) => p.id == updatedProgram.id);
    if (index != -1) {
      _programs[index] = updatedProgram;
      await _saveToStorage();
      notifyListeners();

      // Sync to Cloud Firestore
      FirestoreService().syncProgram(updatedProgram);
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

    // Delete from Cloud Firestore
    FirestoreService().deleteProgram(programId);
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
      );
      _members[memberIndex] = member;
    } else {
      member = MemberRecord(
        id: _uuid.v4(),
        programId: programId,
        programTitle: program.title,
        merchantId: merchantId,
        customerId: customerId,
        customerName: customerName ?? 'Serbuin Member',
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
    _activities.insert(
      0,
      ActivityLog(
        id: _uuid.v4(),
        userId: customerId,
        type: 'stamp_earned',
        title: 'Earned +$count Stamp${count > 1 ? 's' : ''}',
        subtitle: '${member.stampsCollected}/${member.totalStampsRequired} stamps on ${program.title}',
        merchantName: program.merchantName,
        timestamp: DateTime.now(),
        stampsCount: count,
      ),
    );

    await _saveToStorage();
    notifyListeners();

    // Sync to Cloud Firestore
    FirestoreService().syncMember(member);

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

    _activities.insert(
      0,
      ActivityLog(
        id: _uuid.v4(),
        userId: voucher.customerId,
        type: 'voucher_redeemed',
        title: 'Voucher Redeemed!',
        subtitle: '${voucher.title} • ${voucher.discountValue}',
        merchantName: voucher.merchantName,
        timestamp: DateTime.now(),
      ),
    );

    await _saveToStorage();
    notifyListeners();

    // Sync to Cloud Firestore
    FirestoreService().syncVoucher(updated);

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

    final newVoucher = Voucher(
      id: _uuid.v4(),
      code: 'RET-${_uuid.v4().substring(0, 6).toUpperCase()}',
      programId: member.programId,
      merchantId: member.merchantId,
      merchantName: 'Kopi Kenangan Artisan',
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

    _activities.insert(
      0,
      ActivityLog(
        id: _uuid.v4(),
        userId: member.customerId,
        type: 'voucher_claimed',
        title: 'AI Retention Voucher Sent: $title',
        subtitle: 'Sent to ${member.customerName}',
        merchantName: 'Kopi Kenangan Artisan',
        timestamp: DateTime.now(),
      ),
    );

    // Update member record with improved risk level
    _members[memberIndex] = member.copyWith(
      riskLevel: 'medium',
      riskReason: 'Retention voucher delivered. Monitoring revisit.',
    );

    await _saveToStorage();
    notifyListeners();

    // Sync to Cloud Firestore
    FirestoreService().syncVoucher(newVoucher);
    FirestoreService().syncMember(_members[memberIndex]);

    // Trigger Cloud Run FCM push notification to customer
    CloudRunService().sendFcmNotification(
      customerId: member.customerId,
      title: '🎁 Exclusive Retention Perk!',
      body: '$title has been sent to your wallet by Kopi Kenangan Artisan.',
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
    _members[memberIndex] = member.copyWith(
      stampsCollected: 0,
      status: 'active',
      lastStampDate: DateTime.now(),
    );

    _activities.insert(
      0,
      ActivityLog(
        id: _uuid.v4(),
        userId: customerId,
        type: 'voucher_claimed',
        title: 'Reward Voucher Claimed!',
        subtitle: prog.rewardTitle,
        merchantName: prog.merchantName,
        timestamp: DateTime.now(),
      ),
    );

    await _saveToStorage();
    notifyListeners();

    // Sync to Cloud Firestore
    FirestoreService().syncVoucher(voucher);
    FirestoreService().syncMember(_members[memberIndex]);

    return voucher;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
