import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';
import 'customer_vouchers_view.dart';

class CustomerCardDetailView extends StatefulWidget {
  final MemberRecord member;
  final LoyaltyProgram program;

  const CustomerCardDetailView({
    super.key,
    required this.member,
    required this.program,
  });

  @override
  State<CustomerCardDetailView> createState() => _CustomerCardDetailViewState();
}

class _CustomerCardDetailViewState extends State<CustomerCardDetailView> {
  bool _isClaiming = false;

  Future<void> _claimReward() async {
    setState(() => _isClaiming = true);
    final db = context.read<MockDatabaseService>();

    final voucher = await db.claimProgramReward(
      customerId: widget.member.customerId,
      programId: widget.program.id,
    );

    setState(() => _isClaiming = false);

    if (voucher != null && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.accentEmerald, width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentEmerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded, color: AppColors.accentEmerald, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reward Claimed! 🎉',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Your "${widget.program.rewardTitle}" voucher is now ready in your wallet with a dynamic QR code!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerVouchersView(customerId: widget.member.customerId),
                      ),
                    );
                  },
                  child: const Text('View My Vouchers'),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<MockDatabaseService>();
    final currentMember = db.members.firstWhere(
      (m) => m.id == widget.member.id,
      orElse: () => widget.member,
    );
    final currentProg = db.programs.firstWhere(
      (p) => p.id == widget.program.id,
      orElse: () => widget.program,
    );

    final canClaim = currentMember.stampsCollected >= currentProg.totalStamps;
    final remainingStamps = currentProg.totalStamps - currentMember.stampsCollected;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentProg.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientFromHex(currentProg.gradientColors),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.colorFromHex(currentProg.gradientColors.first).withValues(alpha: 0.35),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            currentProg.category,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                        const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      currentProg.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentProg.merchantName,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 20),

                    // Stamp Grid
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(currentProg.totalStamps, (index) {
                        final isEarned = index < currentMember.stampsCollected;
                        final isLastRewardSlot = index == currentProg.totalStamps - 1;

                        return Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isEarned
                                ? Colors.white
                                : Colors.black.withValues(alpha: 0.2),
                            border: Border.all(
                              color: isEarned ? Colors.white : Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: isEarned
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isEarned
                                ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 22)
                                : isLastRewardSlot
                                    ? const Icon(Icons.card_giftcard_rounded, color: Colors.amberAccent, size: 20)
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Progress status message
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: canClaim
                      ? AppColors.accentEmerald.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: canClaim ? AppColors.accentEmerald : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      canClaim ? Icons.stars_rounded : Icons.info_outline_rounded,
                      color: canClaim ? AppColors.accentEmerald : AppColors.primaryLight,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        canClaim
                            ? '🎉 Congratulations! You have collected all ${currentProg.totalStamps} stamps and unlocked your reward!'
                            : 'Collect $remainingStamps more stamp${remainingStamps > 1 ? "s" : ""} on your next visits to claim.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: canClaim ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Reward Voucher Details Card
              const Text(
                'Unlockable Reward Voucher',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentProg.rewardTitle,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentProg.rewardDescription,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 12),
                    const Text(
                      'Redemption Rules:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentProg.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Claim Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canClaim && !_isClaiming ? _claimReward : null,
                  icon: _isClaiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.card_giftcard_rounded, size: 20),
                  label: Text(
                    canClaim
                        ? 'Claim Reward Voucher Now'
                        : 'Collect $remainingStamps More Stamps to Claim',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canClaim ? AppColors.accentEmerald : AppColors.surfaceLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
