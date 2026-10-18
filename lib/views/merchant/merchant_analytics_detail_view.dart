import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';
import 'merchant_members_view.dart';

class MerchantAnalyticsDetailView extends StatefulWidget {
  final String merchantId;

  const MerchantAnalyticsDetailView({super.key, required this.merchantId});

  @override
  State<MerchantAnalyticsDetailView> createState() => _MerchantAnalyticsDetailViewState();
}

class _MerchantAnalyticsDetailViewState extends State<MerchantAnalyticsDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();
    final merchantMembers = db.members.where((m) => m.merchantId == widget.merchantId).toList();
    final merchantVouchers = db.vouchers.where((v) => v.merchantId == widget.merchantId).toList();

    // Store footfall & visit computations
    final totalVisits = merchantMembers.fold<int>(0, (sum, m) => sum + m.stampsCollected);
    final completedCards = merchantMembers.where((m) => m.status == 'completed').length;
    final activeMembers = merchantMembers.where((m) => m.status == 'active').length;
    final totalMembers = merchantMembers.length;

    final overallRetentionRate = totalMembers > 0
        ? ((merchantMembers.where((m) => m.riskLevel != 'high').length / totalMembers) * 100).toStringAsFixed(1)
        : '0.0';

    final highRiskMembers = merchantMembers.where((m) => m.riskLevel == 'high').toList();
    final mediumRiskMembers = merchantMembers.where((m) => m.riskLevel == 'medium').toList();
    final lowRiskMembers = merchantMembers.where((m) => m.riskLevel == 'low').toList();

    // AI Voucher metrics
    final redeemedVouchers = merchantVouchers.where((v) => v.isRedeemed).length;
    final voucherRecoveryRate = merchantVouchers.isNotEmpty
        ? ((redeemedVouchers / merchantVouchers.length) * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detailed Analytics & Retention',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Footfall Impact'),
            Tab(text: 'Retention Health'),
            Tab(text: 'AI Churn Engine'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Footfall Impact (How programs drive customer visits)
          _buildFootfallImpactTab(
            programs: merchantProgs,
            members: merchantMembers,
            totalVisits: totalVisits,
            completedCards: completedCards,
            activeMembers: activeMembers,
          ),

          // TAB 2: Program Retention Effectiveness (How effective programs are at sustaining retention)
          _buildRetentionEffectivenessTab(
            programs: merchantProgs,
            members: merchantMembers,
            highRiskCount: highRiskMembers.length,
            mediumRiskCount: mediumRiskMembers.length,
            lowRiskCount: lowRiskMembers.length,
            retentionRate: overallRetentionRate,
          ),

          // TAB 3: AI Churn Prevention & Voucher Recovery Mechanics
          _buildAiChurnEngineTab(
            vouchers: merchantVouchers,
            highRiskMembers: highRiskMembers,
            redeemedCount: redeemedVouchers,
            recoveryRate: voucherRecoveryRate,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: PROGRAM FOOTFALL & VISIT IMPACT
  // ==========================================
  Widget _buildFootfallImpactTab({
    required List<LoyaltyProgram> programs,
    required List<MemberRecord> members,
    required int totalVisits,
    required int completedCards,
    required int activeMembers,
  }) {
    final avgVisitsPerMember = members.isNotEmpty ? (totalVisits / members.length).toStringAsFixed(1) : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Highlight Metrics Grid
          Row(
            children: [
              Expanded(
                child: _MetricHighlightCard(
                  title: 'Visits Driven',
                  value: '$totalVisits',
                  subtitle: 'Stamp scans',
                  icon: Icons.storefront_rounded,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricHighlightCard(
                  title: 'Active Members',
                  value: '$activeMembers',
                  subtitle: 'Collecting now',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.accentEmerald,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricHighlightCard(
                  title: 'Avg. Cadence',
                  value: avgVisitsPerMember,
                  subtitle: 'Visits/member',
                  icon: Icons.repeat_rounded,
                  color: AppColors.accentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.accentPurple.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.stars_rounded, color: AppColors.accentAmber, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VERIFIED STAMP VISITS & CARDS COMPLETED',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryLight, letterSpacing: 0.7),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalVisits Stamps Awarded • $completedCards Completed Cards',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Direct customer in-store visits and card milestones tracked purely from verified stamp scans.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section Title
          const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 18, color: AppColors.primaryLight),
              SizedBox(width: 8),
              Text(
                'Footfall Contribution by Program',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'See how much customer traffic and repeat footfall each individual stamp program produces for your store.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          if (programs.isEmpty)
            _buildEmptyState('No active programs yet. Create a loyalty program to begin tracking customer footfall!')
          else
            ...programs.map((prog) {
              final progMembers = members.where((m) => m.programId == prog.id).toList();
              final progVisits = progMembers.fold<int>(0, (sum, m) => sum + m.stampsCollected);
              final progCompleted = progMembers.where((m) => m.status == 'completed').length;
              final trafficShare = totalVisits > 0 ? ((progVisits / totalVisits) * 100).round() : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientFromHex(prog.gradientColors),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prog.title,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              Text(
                                '${prog.category} • ${progMembers.length} enrolled members',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$trafficShare% Share',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryLight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Traffic progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: trafficShare / 100,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          prog.gradientColors.isNotEmpty ? AppColors.colorFromHex(prog.gradientColors.first) : AppColors.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Metrics Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ProgramMetricItem(
                          label: 'Visits Driven',
                          value: '$progVisits',
                          icon: Icons.storefront_rounded,
                        ),
                        _ProgramMetricItem(
                          label: 'Cards Completed',
                          value: '$progCompleted',
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        _ProgramMetricItem(
                          label: 'Completion Rate',
                          value: '${progMembers.isNotEmpty ? ((progCompleted / progMembers.length) * 100).round() : 0}%',
                          icon: Icons.stars_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PROGRAM RETENTION EFFECTIVENESS
  // ==========================================
  Widget _buildRetentionEffectivenessTab({
    required List<LoyaltyProgram> programs,
    required List<MemberRecord> members,
    required int highRiskCount,
    required int mediumRiskCount,
    required int lowRiskCount,
    required String retentionRate,
  }) {
    final activeRateNum = double.tryParse(retentionRate) ?? 0.0;
    final isHealthy = activeRateNum >= 70.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Retention Health Overview Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceCard,
                  isHealthy ? AppColors.accentEmerald.withValues(alpha: 0.15) : AppColors.accentAmber.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHealthy ? AppColors.accentEmerald.withValues(alpha: 0.4) : AppColors.accentAmber.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OVERALL STORE RETENTION HEALTH',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryLight, letterSpacing: 0.7),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$retentionRate%',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isHealthy ? AppColors.accentEmerald.withValues(alpha: 0.2) : AppColors.accentAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isHealthy ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 16,
                            color: isHealthy ? AppColors.accentEmerald : AppColors.accentAmber,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isHealthy ? 'Healthy Engagement' : 'Needs Intervention',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isHealthy ? AppColors.accentEmerald : AppColors.accentAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Retention measures customer returning cadence within safe visit thresholds. Members with consistent stamps maintain regular store habits and eliminate competitor churn.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                // Breakdown bar
                Row(
                  children: [
                    Expanded(
                      flex: lowRiskCount > 0 ? lowRiskCount : 1,
                      child: Container(
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accentEmerald,
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: mediumRiskCount > 0 ? mediumRiskCount : 1,
                      child: Container(height: 8, color: AppColors.accentAmber),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: highRiskCount > 0 ? highRiskCount : 1,
                      child: Container(
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accentRose,
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RiskLegendItem(color: AppColors.accentEmerald, label: 'Low Risk ($lowRiskCount)'),
                    _RiskLegendItem(color: AppColors.accentAmber, label: 'Medium Risk ($mediumRiskCount)'),
                    _RiskLegendItem(color: AppColors.accentRose, label: 'High Churn ($highRiskCount)'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Retention Effectiveness per Program
          const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: AppColors.accentAmber),
              SizedBox(width: 8),
              Text(
                'Program Retention Effectiveness',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Analysis of how successfully each program keeps customers coming back before dropping off.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          if (programs.isEmpty)
            _buildEmptyState('No programs to compare yet.')
          else
            ...programs.map((prog) {
              final progMembers = members.where((m) => m.programId == prog.id).toList();
              final progHighRisk = progMembers.where((m) => m.riskLevel == 'high').length;
              final progRetained = progMembers.length - progHighRisk;
              final progRetentionPct = progMembers.isNotEmpty
                  ? ((progRetained / progMembers.length) * 100).round()
                  : 100;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            prog.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: progRetentionPct >= 75
                                ? AppColors.accentEmerald.withValues(alpha: 0.15)
                                : AppColors.accentAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$progRetentionPct% Retained',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: progRetentionPct >= 75 ? AppColors.accentEmerald : AppColors.accentAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Funnel / Progress
                    Text(
                      '${progMembers.length} members enrolled • $progRetained actively visiting • $progHighRisk dormant churn risk',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progRetentionPct / 100,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progRetentionPct >= 75 ? AppColors.accentEmerald : AppColors.accentAmber,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Strategic Evaluation
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.psychology_rounded, size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              prog.termsAndConditions.isNotEmpty
                                  ? 'T&C Rule: "${prog.termsAndConditions}" keeps repeat orders moving at optimal basket size.'
                                  : 'Target of ${prog.totalStamps} stamps provides ideal customer velocity without reward fatigue.',
                              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ======================================================================
  // TAB 3: HOW AI CHURN ENGINE & VOUCHERS BRING CUSTOMERS BACK
  // ======================================================================
  Widget _buildAiChurnEngineTab({
    required List<Voucher> vouchers,
    required List<MemberRecord> highRiskMembers,
    required int redeemedCount,
    required String recoveryRate,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mechanics Title Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1065), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'HOW AI CHURN PREVENTION WORKS',
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
                const Text(
                  'How Targeted AI Retention Vouchers Bring At-Risk Customers Back:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Rather than issuing wasteful storewide discounts, Serbuin AI diagnoses individual customer visit decay and triggers high-converting psychological motivators to restore footfall.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5-Step Visual Win-Back Journey
          _buildJourneyStep(
            stepNumber: '1',
            title: 'Real-Time Inactivity & Sunk Investment Detection',
            description:
                'AI scans customer stamp cards continuously. When a customer with progress (e.g., 4/6 stamps) stops visiting for 10-20+ days, they enter the churn danger zone.',
            icon: Icons.access_time_rounded,
            iconColor: AppColors.accentAmber,
          ),
          _buildJourneyStep(
            stepNumber: '2',
            title: 'Personalized Offer Calibration (High-Converting Target)',
            description:
                'Instead of generic mass discounts, AI generates an offer tailored to their card progress or favorite menu category (e.g. comeback treat or bonus stamp booster).',
            icon: Icons.tune_rounded,
            iconColor: AppColors.primaryLight,
          ),
          _buildJourneyStep(
            stepNumber: '3',
            title: '7-Day Scarcity Window (Urgency Trigger)',
            description:
                'The retention voucher has a strict 7-day expiration. Scarcity triggers prompt action, preventing procrastination and compelling a visit this week.',
            icon: Icons.timer_outlined,
            iconColor: AppColors.accentRose,
          ),
          _buildJourneyStep(
            stepNumber: '4',
            title: 'Sunk-Cost Effect Reignites Commitment',
            description:
                'Customers realize they only need 1-2 more stamps to complete their loyalty card. This brings them back into your store to avoid wasting previous progress.',
            icon: Icons.stars_rounded,
            iconColor: Colors.amberAccent,
          ),
          _buildJourneyStep(
            stepNumber: '5',
            title: 'Physical In-Store Habit Restored',
            description:
                'Once the customer visits and scans their voucher at the cash register, their physical habit loop is reset. Repeat orders resume naturally.',
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.accentEmerald,
            isLast: true,
          ),

          const SizedBox(height: 24),

          // Live Churn Win-Back Performance
          const Row(
            children: [
              Icon(Icons.analytics_rounded, size: 18, color: AppColors.primaryLight),
              SizedBox(width: 8),
              Text(
                'Live Churn Prevention Performance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _MetricHighlightCard(
                  title: 'Retention Vouchers',
                  value: '${vouchers.length}',
                  subtitle: 'Targeted win-backs issued',
                  icon: Icons.confirmation_number_outlined,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricHighlightCard(
                  title: 'In-Store Redeemed',
                  value: '$redeemedCount',
                  subtitle: 'Returned to store',
                  icon: Icons.store_rounded,
                  color: AppColors.accentEmerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricHighlightCard(
                  title: 'Win-Back Rate',
                  value: '$recoveryRate%',
                  subtitle: 'Customer recovery efficiency',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.accentCyan,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action Link: Intervene Now
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentRose.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_outline_rounded, color: AppColors.accentRose, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${highRiskMembers.length} High-Risk Members Detected',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Open the Member Directory to review diagnostics and send personalized AI vouchers.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MerchantMembersView(merchantId: widget.merchantId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildJourneyStep({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Center(
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'STEP $stepNumber',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: iconColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _MetricHighlightCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricHighlightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProgramMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProgramMetricItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ],
    );
  }
}

class _RiskLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _RiskLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
