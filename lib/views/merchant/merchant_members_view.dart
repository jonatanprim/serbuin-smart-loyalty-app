import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';

class MerchantMembersView extends StatefulWidget {
  final String merchantId;

  const MerchantMembersView({super.key, required this.merchantId});

  @override
  State<MerchantMembersView> createState() => _MerchantMembersViewState();
}

class _MerchantMembersViewState extends State<MerchantMembersView> {
  String _selectedProgramFilter = 'All';
  String _selectedStatusFilter = 'All';
  bool _isAiScanning = false;
  String? _lastScanTimestamp;

  Future<void> _runAiChurnScan() async {
    setState(() => _isAiScanning = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      _isAiScanning = false;
      _lastScanTimestamp = 'Just now';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ AI Churn Risk Scan complete! Retention vouchers recommended for at-risk members.'),
          backgroundColor: AppColors.accentPurple,
        ),
      );
    }
  }

  void _showAiMemberDetail(MemberRecord member) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemberAiDetailModal(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();

    var filteredMembers = db.members.where((m) => m.merchantId == widget.merchantId).toList();

    if (_selectedProgramFilter != 'All') {
      filteredMembers = filteredMembers.where((m) => m.programId == _selectedProgramFilter).toList();
    }

    if (_selectedStatusFilter != 'All') {
      filteredMembers = filteredMembers.where((m) => m.status.toLowerCase() == _selectedStatusFilter.toLowerCase()).toList();
    }

    final highRiskCount = filteredMembers.where((m) => m.riskLevel == 'high').length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Member Directory',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        _lastScanTimestamp != null
                            ? '${filteredMembers.length} members • AI scanned $_lastScanTimestamp'
                            : '${filteredMembers.length} members enrolled',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isAiScanning ? null : _runAiChurnScan,
                    icon: _isAiScanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(_isAiScanning ? 'Scanning...' : 'AI Scan', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // AI Risk Summary Alert
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceCard,
                      highRiskCount > 0
                          ? AppColors.accentRose.withValues(alpha: 0.1)
                          : AppColors.accentEmerald.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: highRiskCount > 0
                        ? AppColors.accentRose.withValues(alpha: 0.4)
                        : AppColors.accentEmerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: highRiskCount > 0
                            ? AppColors.accentRose.withValues(alpha: 0.2)
                            : AppColors.accentEmerald.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        highRiskCount > 0 ? Icons.warning_rounded : Icons.verified_user_rounded,
                        color: highRiskCount > 0 ? AppColors.accentRose : AppColors.accentEmerald,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            highRiskCount > 0
                                ? '$highRiskCount At-Risk Member${highRiskCount > 1 ? "s" : ""} Detected'
                                : 'All Members Healthy & Retained',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          Text(
                            highRiskCount > 0
                                ? 'AI generated personalized comeback vouchers to re-engage them.'
                                : 'Visit cadences are consistent with loyalty milestones.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Filter 1: By Loyalty Program
              const Text(
                'Filter by Program',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Programs',
                      isSelected: _selectedProgramFilter == 'All',
                      onTap: () => setState(() => _selectedProgramFilter = 'All'),
                    ),
                    ...merchantProgs.map((p) {
                      return _FilterChip(
                        label: p.title,
                        isSelected: _selectedProgramFilter == p.id,
                        onTap: () => setState(() => _selectedProgramFilter = p.id),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Filter 2: By Member Status
              const Text(
                'Filter by Status',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedStatusFilter == 'All',
                    onTap: () => setState(() => _selectedStatusFilter = 'All'),
                  ),
                  _FilterChip(
                    label: 'Active',
                    isSelected: _selectedStatusFilter == 'Active',
                    onTap: () => setState(() => _selectedStatusFilter = 'Active'),
                  ),
                  _FilterChip(
                    label: 'Completed',
                    isSelected: _selectedStatusFilter == 'Completed',
                    onTap: () => setState(() => _selectedStatusFilter = 'Completed'),
                  ),
                  _FilterChip(
                    label: 'Expired',
                    isSelected: _selectedStatusFilter == 'Expired',
                    onTap: () => setState(() => _selectedStatusFilter = 'Expired'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Member List
              if (filteredMembers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text('No members match the selected filters.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                ...filteredMembers.map((member) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MemberCard(
                      member: member,
                      onTap: () => _showAiMemberDetail(member),
                    ),
                  );
                }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final MemberRecord member;
  final VoidCallback onTap;

  const _MemberCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final daysInactive = DateTime.now().difference(member.lastStampDate).inDays;
    final isHighRisk = member.riskLevel == 'high';
    final isMediumRisk = member.riskLevel == 'medium';

    Color riskColor = AppColors.accentEmerald;
    String riskLabel = 'Low Churn Risk';
    if (isHighRisk) {
      riskColor = AppColors.accentRose;
      riskLabel = 'High Churn Risk';
    } else if (isMediumRisk) {
      riskColor = AppColors.accentAmber;
      riskLabel = 'Medium Risk';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHighRisk ? AppColors.accentRose.withValues(alpha: 0.3) : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar with initials
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceLight,
                  child: Text(
                    member.customerName.isNotEmpty ? member.customerName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryLight),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.customerName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.programTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Stamp counter badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${member.stampsCollected} / ${member.totalStampsRequired} Stamps',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),

            // AI Retention Strip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      riskLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: riskColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $daysInactive days ago',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text('AI Voucher', style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primaryLight),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberAiDetailModal extends StatefulWidget {
  final MemberRecord member;

  const _MemberAiDetailModal({required this.member});

  @override
  State<_MemberAiDetailModal> createState() => _MemberAiDetailModalState();
}

class _MemberAiDetailModalState extends State<_MemberAiDetailModal> {
  bool _isSending = false;

  Future<void> _sendRetentionVoucher() async {
    setState(() => _isSending = true);
    final db = context.read<MockDatabaseService>();
    await db.sendAiRetentionVoucher(
      memberId: widget.member.id,
      title: widget.member.recommendedVoucher,
      description: 'AI Generated Retention Offer valid for 7 days.',
    );
    setState(() => _isSending = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voucher sent to ${widget.member.customerName}!'),
          backgroundColor: AppColors.accentEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final isHigh = member.riskLevel == 'high';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHigh ? AppColors.accentRose.withValues(alpha: 0.15) : AppColors.accentEmerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHigh ? Icons.warning_rounded : Icons.person_rounded,
                  color: isHigh ? AppColors.accentRose : AppColors.accentEmerald,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.customerName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(
                      '${member.stampsCollected} / ${member.totalStampsRequired} Stamps • ${member.programTitle}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // AI Diagnosis Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'AI CHURN SCANNER DIAGNOSIS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryLight,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  member.riskReason,
                  style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI Insight: ${member.aiInsight}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recommended Voucher Offer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.accentPurple.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RECOMMENDED RETENTION VOUCHER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryLight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  member.recommendedVoucher,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Triggers an urgent incentive notification to restart customer store visits.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendRetentionVoucher,
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_isSending ? 'Sending Voucher...' : 'Send AI Voucher to Customer'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
