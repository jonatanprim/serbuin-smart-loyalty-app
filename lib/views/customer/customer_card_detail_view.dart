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
      final otherMerchantPrograms = db.programs
          .where((p) => p.merchantId == widget.program.merchantId && p.id != widget.program.id && p.isActive)
          .toList();
      final otherToJoin = otherMerchantPrograms.where((p) => !db.members.any((m) => m.programId == p.id && m.customerId == widget.member.customerId && m.status == 'active')).firstOrNull;

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
                'Your card is now marked as Completed! The "${widget.program.rewardTitle}" voucher is ready in your wallet with a dynamic QR code.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              if (otherToJoin != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Other Program at ${widget.program.merchantName}:',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${otherToJoin.title} • Reward: ${otherToJoin.rewardTitle}',
                        style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
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
              if (otherToJoin != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final newMem = await db.joinProgram(
                        customerId: widget.member.customerId,
                        programId: otherToJoin.id,
                        customerName: widget.member.customerName,
                        customerPhone: widget.member.customerPhone,
                        customerEmail: widget.member.customerEmail,
                      );
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerCardDetailView(member: newMem, program: otherToJoin),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: Text('Join ${otherToJoin.title}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentEmerald,
                      side: const BorderSide(color: AppColors.accentEmerald),
                    ),
                  ),
                ),
              ],
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

    final isCompleted = currentMember.status == 'completed';
    final canClaim = !isCompleted && currentMember.stampsCollected >= currentProg.totalStamps;
    final remainingStamps = currentProg.totalStamps - currentMember.stampsCollected;
    final otherMerchantPrograms = db.programs
        .where((p) => p.merchantId == currentProg.merchantId && p.id != currentProg.id && p.isActive)
        .toList();

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
                        Row(
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
                            if (isCompleted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'COMPLETED',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
                  color: isCompleted
                      ? AppColors.accentEmerald.withValues(alpha: 0.15)
                      : canClaim
                          ? AppColors.accentEmerald.withValues(alpha: 0.15)
                          : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isCompleted || canClaim) ? AppColors.accentEmerald : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.verified_rounded
                          : canClaim
                              ? Icons.stars_rounded
                              : Icons.info_outline_rounded,
                      color: (isCompleted || canClaim) ? AppColors.accentEmerald : AppColors.primaryLight,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isCompleted
                            ? '🎉 Program Completed! You have collected all ${currentProg.totalStamps} stamps and claimed your reward voucher.'
                            : canClaim
                                ? '🎉 Congratulations! You have collected all ${currentProg.totalStamps} stamps and unlocked your reward!'
                                : 'Collect $remainingStamps more stamp${remainingStamps > 1 ? "s" : ""} on your next visits to claim.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (isCompleted || canClaim) ? Colors.white : AppColors.textSecondary,
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
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.gavel_rounded, size: 15, color: AppColors.accentPurple),
                        SizedBox(width: 6),
                        Text(
                          'Terms & Conditions (T&C):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        currentProg.termsAndConditions,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Main Action Button (Claim or View Claimed Voucher)
              SizedBox(
                width: double.infinity,
                child: isCompleted
                    ? ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerVouchersView(customerId: currentMember.customerId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.confirmation_number_rounded, size: 20),
                        label: const Text('View Claimed Voucher in Wallet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      )
                    : ElevatedButton.icon(
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

              // Other Programs from this Merchant Section
              if (otherMerchantPrograms.isNotEmpty) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: AppColors.accentPurple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Other Programs from ${currentProg.merchantName}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...otherMerchantPrograms.map((otherProg) {
                  final otherMember = db.members.where((m) =>
                      m.programId == otherProg.id &&
                      (m.customerId == currentMember.customerId || (currentMember.customerPhone.isNotEmpty && m.customerPhone == currentMember.customerPhone)) &&
                      m.status == 'active').firstOrNull;
                  final isAlreadyMember = otherMember != null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientFromHex(otherProg.gradientColors),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.loyalty_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                otherProg.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reward: ${otherProg.rewardTitle}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (isAlreadyMember) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerCardDetailView(member: otherMember, program: otherProg),
                                ),
                              );
                            } else {
                              final newMem = await db.joinProgram(
                                customerId: currentMember.customerId,
                                programId: otherProg.id,
                                customerName: currentMember.customerName,
                                customerPhone: currentMember.customerPhone,
                                customerEmail: currentMember.customerEmail,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Joined ${otherProg.title}! Card added to your wallet.'),
                                    backgroundColor: AppColors.accentEmerald,
                                  ),
                                );
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerCardDetailView(member: newMem, program: otherProg),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAlreadyMember ? AppColors.surfaceLight : AppColors.accentEmerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isAlreadyMember ? 'View Card' : 'Join Program',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else if (isCompleted) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final newMem = await db.joinProgram(
                        customerId: currentMember.customerId,
                        programId: currentProg.id,
                        customerName: currentMember.customerName,
                        customerPhone: currentMember.customerPhone,
                        customerEmail: currentMember.customerEmail,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Started a new card for ${currentProg.title}!'),
                            backgroundColor: AppColors.accentEmerald,
                          ),
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerCardDetailView(member: newMem, program: currentProg),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Start a New Card on this Program'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: const BorderSide(color: AppColors.primaryLight),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
