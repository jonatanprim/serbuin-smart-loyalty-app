import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore? _firestore;
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  void init() {
    try {
      _firestore = FirebaseFirestore.instance;
      _isAvailable = true;
      debugPrint('Cloud Firestore initialized successfully.');
    } catch (e) {
      _isAvailable = false;
      debugPrint('Cloud Firestore offline / fallback mode: $e');
    }
  }

  // --- Loyalty Programs ---
  Future<void> syncProgram(LoyaltyProgram program) async {
    if (!_isAvailable || _firestore == null) return;
    try {
      await _firestore!
          .collection('programs')
          .doc(program.id)
          .set(program.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncProgram note: $e');
    }
  }

  Future<void> deleteProgram(String programId) async {
    if (!_isAvailable || _firestore == null) return;
    try {
      await _firestore!.collection('programs').doc(programId).delete();
    } catch (e) {
      debugPrint('Firestore deleteProgram note: $e');
    }
  }

  // --- Members ---
  Future<void> syncMember(MemberRecord member) async {
    if (!_isAvailable || _firestore == null) return;
    try {
      await _firestore!
          .collection('members')
          .doc(member.id)
          .set(member.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncMember note: $e');
    }
  }

  // --- Vouchers ---
  Future<void> syncVoucher(Voucher voucher) async {
    if (!_isAvailable || _firestore == null) return;
    try {
      await _firestore!
          .collection('vouchers')
          .doc(voucher.id)
          .set(voucher.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncVoucher note: $e');
    }
  }

  // --- Activities ---
  Future<void> logActivity(ActivityLog activity) async {
    if (!_isAvailable || _firestore == null) return;
    try {
      await _firestore!
          .collection('activities')
          .doc(activity.id)
          .set(activity.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore logActivity note: $e');
    }
  }
}
