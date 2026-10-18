import 'package:flutter_test/flutter_test.dart';
import 'package:serbuin_app/models/models.dart';
import 'package:serbuin_app/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voucher & Database Service Tests', () {
    test('cleanVoucherCode strips dynamic suffix and prefixes', () {
      expect(MockDatabaseService.cleanVoucherCode('SRB-12345678-REF1'), 'SRB-12345678');
      expect(MockDatabaseService.cleanVoucherCode('SRB-12345678-REF42'), 'SRB-12345678');
      expect(MockDatabaseService.cleanVoucherCode('VOUCHER|SRB-12345678'), 'SRB-12345678');
      expect(MockDatabaseService.cleanVoucherCode('  RET-ABCDEF-REF3  '), 'RET-ABCDEF');
      expect(MockDatabaseService.cleanVoucherCode('PLAIN-CODE'), 'PLAIN-CODE');
    });

    test('redeemVoucher successfully approves and marks as redeemed', () async {
      final db = MockDatabaseService();
      final testVoucher = Voucher(
        id: 'test-v-1',
        code: 'SRB-TESTVOUCHER',
        programId: 'prog-1',
        merchantId: 'merchant-1',
        merchantName: 'Kopi Kenangan',
        customerId: 'cust-1',
        title: 'Free Latte',
        description: 'Tukarkan dengan 1 Hot/Iced Latte',
        discountType: 'free_item',
        discountValue: 'Free Item',
        claimedAt: DateTime.now().subtract(const Duration(days: 1)),
        expiresAt: DateTime.now().add(const Duration(days: 14)),
        isRedeemed: false,
      );

      final result = await db.redeemVoucher(testVoucher);
      expect(result['success'], isTrue);
      expect((result['voucher'] as Voucher).isRedeemed, isTrue);
      expect((result['voucher'] as Voucher).redeemedAt, isNotNull);

      // Attempting to redeem again should fail
      final secondAttempt = await db.redeemVoucher(result['voucher'] as Voucher);
      expect(secondAttempt['success'], isFalse);
      expect(secondAttempt['message'], contains('already redeemed'));

      // Attempting to redeem by wrong merchant should fail
      final wrongMerchantAttempt = await db.redeemVoucher(testVoucher, merchantId: 'wrong-merchant');
      expect(wrongMerchantAttempt['success'], isFalse);
      expect(wrongMerchantAttempt['message'], contains('not from this merchant'));
    });

    test('getLastCustomerTransaction retrieves correct latest transaction info', () {
      final db = MockDatabaseService();
      final txInfo = db.getLastCustomerTransaction('cust-nonexistent');
      expect(txInfo, isNotNull);
      expect(txInfo.containsKey('date'), isTrue);
      expect(txInfo.containsKey('description'), isTrue);
    });

    test('findActiveMemberInProgram returns null for non-member and finds existing member', () {
      final db = MockDatabaseService();
      final nonMember = db.findActiveMemberInProgram(
        query: 'nonexistent-cust-id',
        programId: 'prog-1',
      );
      expect(nonMember, isNull);
    });
  });
}
