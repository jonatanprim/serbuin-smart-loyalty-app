import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';

class CustomerVouchersView extends StatelessWidget {
  final String customerId;

  const CustomerVouchersView({super.key, required this.customerId});

  void _showVoucherDetail(BuildContext context, Voucher voucher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoucherDetailWithTimerSheet(voucher: voucher),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<MockDatabaseService>();
    final vouchers = db.vouchers.where((v) => v.customerId == customerId).toList();
    final activeVouchers = vouchers.where((v) => !v.isRedeemed && DateTime.now().isBefore(v.expiresAt)).toList();
    final redeemedVouchers = vouchers.where((v) => v.isRedeemed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reward Vouchers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.accentEmerald.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, color: AppColors.primaryLight, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap any active voucher to open its dynamic QR code with a secure 2-minute auto-refresh timer.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Active Vouchers Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Vouchers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${activeVouchers.length} Ready',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentEmerald),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (activeVouchers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No active vouchers yet. Collect stamps to claim rewards!',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...activeVouchers.map((voucher) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _VoucherCardItem(
                      voucher: voucher,
                      onTap: () => _showVoucherDetail(context, voucher),
                    ),
                  );
                }),

              const SizedBox(height: 26),

              // Redeemed / Past Vouchers
              if (redeemedVouchers.isNotEmpty) ...[
                const Text(
                  'Past & Redeemed',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ...redeemedVouchers.map((voucher) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VoucherCardItem(
                      voucher: voucher,
                      isPast: true,
                      onTap: () => _showVoucherDetail(context, voucher),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoucherCardItem extends StatelessWidget {
  final Voucher voucher;
  final VoidCallback onTap;
  final bool isPast;

  const _VoucherCardItem({
    required this.voucher,
    required this.onTap,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isPast ? AppColors.surfaceCard.withValues(alpha: 0.5) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPast ? AppColors.border.withValues(alpha: 0.5) : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isPast ? AppColors.darkCardGradient : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      voucher.discountType == 'free_item' ? Icons.card_giftcard_rounded : Icons.local_offer_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voucher.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isPast ? AppColors.textSecondary : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          voucher.merchantName,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPast
                          ? Colors.grey.withValues(alpha: 0.15)
                          : AppColors.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isPast ? 'REDEEMED' : voucher.discountValue,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isPast ? Colors.grey : AppColors.accentEmerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expires: ${dateFormat.format(voucher.expiresAt)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  Row(
                    children: [
                      Text(
                        isPast ? 'View Details' : 'Show QR Code',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPast ? AppColors.textMuted : AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.qr_code_rounded,
                        size: 14,
                        color: isPast ? AppColors.textMuted : AppColors.primaryLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherDetailWithTimerSheet extends StatefulWidget {
  final Voucher voucher;

  const _VoucherDetailWithTimerSheet({required this.voucher});

  @override
  State<_VoucherDetailWithTimerSheet> createState() => _VoucherDetailWithTimerSheetState();
}

class _VoucherDetailWithTimerSheetState extends State<_VoucherDetailWithTimerSheet> {
  Timer? _timer;
  int _secondsRemaining = 120; // 2 minutes auto refresh timer
  int _refreshCounter = 1;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 120;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        // Auto refresh QR code
        setState(() {
          _secondsRemaining = 120;
          _refreshCounter++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimer(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final voucher = widget.voucher;
    final dynamicQrPayload = '${voucher.code}-REF$_refreshCounter';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),

          // Title & Merchant
          Text(
            voucher.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            voucher.merchantName,
            style: const TextStyle(fontSize: 13, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            voucher.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Dynamic QR Code Container
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: QrImageView(
              data: dynamicQrPayload,
              version: QrVersions.auto,
              size: 190.0,
              gapless: false,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2-Minute Countdown Auto Refresh Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    value: _secondsRemaining / 120.0,
                    strokeWidth: 2,
                    color: AppColors.accentEmerald,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Auto-refresh in: ${_formatTimer(_secondsRemaining)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentEmerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Code: ${voucher.code}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5),
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
