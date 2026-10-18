import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/gemini_ai_service.dart';
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
  String _selectedRiskFilter = 'All'; // 'All', 'High Risk', 'Medium Risk', 'Low Risk'
  String _selectedSortBy = 'churn_desc'; // 'churn_desc', 'churn_asc', 'stamps_desc', 'inactive_desc'
  bool _isAutoScanning = false;
  String? _lastScanTimestamp;

  @override
  void initState() {
    super.initState();
    _triggerAutoChurnScan();
  }

  Future<void> _triggerAutoChurnScan() async {
    setState(() => _isAutoScanning = true);
    // Simulate real-time background AI churn scan on view open
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() {
        _isAutoScanning = false;
        _lastScanTimestamp = 'Live Scanned';
      });
    }
  }

  void _showAiMemberDetail(MemberRecord member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemberAiDetailModal(member: member),
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedProgramFilter != 'All') count++;
    if (_selectedStatusFilter != 'All') count++;
    if (_selectedRiskFilter != 'All') count++;
    if (_selectedSortBy != 'churn_desc') count++;
    return count;
  }

  String _getSortLabel(String sort) {
    switch (sort) {
      case 'churn_asc':
        return 'Churn: Low to High';
      case 'stamps_desc':
        return 'Stamps: High to Low';
      case 'inactive_desc':
        return 'Most Inactive';
      case 'churn_desc':
      default:
        return 'Churn: High to Low';
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedProgramFilter = 'All';
      _selectedStatusFilter = 'All';
      _selectedRiskFilter = 'All';
      _selectedSortBy = 'churn_desc';
    });
  }

  void _showFilterBottomSheet(List<LoyaltyProgram> merchantProgs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemberFilterModal(
        selectedProgramFilter: _selectedProgramFilter,
        selectedStatusFilter: _selectedStatusFilter,
        selectedRiskFilter: _selectedRiskFilter,
        selectedSortBy: _selectedSortBy,
        programs: merchantProgs,
        onApply: (prog, status, risk, sort) {
          setState(() {
            _selectedProgramFilter = prog;
            _selectedStatusFilter = status;
            _selectedRiskFilter = risk;
            _selectedSortBy = sort;
          });
        },
        onReset: _clearAllFilters,
      ),
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

    if (_selectedRiskFilter != 'All') {
      if (_selectedRiskFilter == 'High Risk') {
        filteredMembers = filteredMembers.where((m) => m.riskLevel == 'high').toList();
      } else if (_selectedRiskFilter == 'Medium Risk') {
        filteredMembers = filteredMembers.where((m) => m.riskLevel == 'medium').toList();
      } else if (_selectedRiskFilter == 'Low Risk') {
        filteredMembers = filteredMembers.where((m) => m.riskLevel == 'low').toList();
      }
    }

    // Sort according to _selectedSortBy (e.g. churn rate low to high or high to low)
    filteredMembers.sort((a, b) {
      if (_selectedSortBy == 'churn_desc') {
        return b.churnScore.compareTo(a.churnScore); // High to Low churn rate
      } else if (_selectedSortBy == 'churn_asc') {
        return a.churnScore.compareTo(b.churnScore); // Low to High churn rate
      } else if (_selectedSortBy == 'stamps_desc') {
        return b.stampsCollected.compareTo(a.stampsCollected);
      } else {
        // Most days inactive first
        return a.lastStampDate.compareTo(b.lastStampDate);
      }
    });

    final highRiskCount = filteredMembers.where((m) => m.riskLevel == 'high').length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header without manual scan button (Automatic scanning active)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Member Directory',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${filteredMembers.length} enrolled members • ${_lastScanTimestamp ?? "AI Churn Rate auto-scanned"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAutoScanning)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentPurple),
                          )
                        else
                          const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accentPurple),
                        const SizedBox(width: 5),
                        Text(
                          _isAutoScanning ? 'Auto-Scanning...' : 'Live Risk Scan',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentPurple),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // AI Risk Summary Alert Banner
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
                                ? '$highRiskCount High Churn Risk Member${highRiskCount > 1 ? "s" : ""} Detected'
                                : 'All Members Healthy & Actively Retained',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          Text(
                            highRiskCount > 0
                                ? 'AI analyzed customer order history & age to craft targeted retention vouchers.'
                                : 'Visit cadences align with healthy customer retention benchmarks.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),              const SizedBox(height: 18),

              // Filter & Sort Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredMembers.length} Members Enrolled',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  InkWell(
                    onTap: () => _showFilterBottomSheet(merchantProgs),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeFilterCount > 0
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _activeFilterCount > 0 ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 15,
                            color: _activeFilterCount > 0 ? AppColors.primaryLight : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _activeFilterCount > 0 ? 'Filter & Sort ($_activeFilterCount)' : 'Filter & Sort',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _activeFilterCount > 0 ? AppColors.primaryLight : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Active filter tags (if any active filters applied)
              if (_activeFilterCount > 0) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedRiskFilter != 'All')
                        _ActiveFilterBadge(
                          label: 'Risk: $_selectedRiskFilter',
                          onRemove: () => setState(() => _selectedRiskFilter = 'All'),
                        ),
                      if (_selectedProgramFilter != 'All')
                        _ActiveFilterBadge(
                          label: 'Program: ${merchantProgs.firstWhere((p) => p.id == _selectedProgramFilter, orElse: () => merchantProgs.first).title}',
                          onRemove: () => setState(() => _selectedProgramFilter = 'All'),
                        ),
                      if (_selectedStatusFilter != 'All')
                        _ActiveFilterBadge(
                          label: 'Status: $_selectedStatusFilter',
                          onRemove: () => setState(() => _selectedStatusFilter = 'All'),
                        ),
                      if (_selectedSortBy != 'churn_desc')
                        _ActiveFilterBadge(
                          label: 'Sort: ${_getSortLabel(_selectedSortBy)}',
                          onRemove: () => setState(() => _selectedSortBy = 'churn_desc'),
                        ),
                      InkWell(
                        onTap: _clearAllFilters,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'Clear All',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentRose),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

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

class _ActiveFilterBadge extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterBadge({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(width: 5),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MemberFilterModal extends StatefulWidget {
  final String selectedProgramFilter;
  final String selectedStatusFilter;
  final String selectedRiskFilter;
  final String selectedSortBy;
  final List<LoyaltyProgram> programs;
  final void Function(String prog, String status, String risk, String sort) onApply;
  final VoidCallback onReset;

  const _MemberFilterModal({
    required this.selectedProgramFilter,
    required this.selectedStatusFilter,
    required this.selectedRiskFilter,
    required this.selectedSortBy,
    required this.programs,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_MemberFilterModal> createState() => _MemberFilterModalState();
}

class _MemberFilterModalState extends State<_MemberFilterModal> {
  late String _tempProgram;
  late String _tempStatus;
  late String _tempRisk;
  late String _tempSort;

  @override
  void initState() {
    super.initState();
    _tempProgram = widget.selectedProgramFilter;
    _tempStatus = widget.selectedStatusFilter;
    _tempRisk = widget.selectedRiskFilter;
    _tempSort = widget.selectedSortBy;
  }

  void _resetLocal() {
    setState(() {
      _tempProgram = 'All';
      _tempStatus = 'All';
      _tempRisk = 'All';
      _tempSort = 'churn_desc';
    });
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: AppColors.primaryLight),
                    SizedBox(width: 8),
                    Text(
                      'Filter & Sort Members',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _resetLocal,
                  child: const Text('Reset All', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Sort by
                    const Text(
                      'SORT DIRECTORY BY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryLight, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: '🚨 Churn: High to Low',
                          isSelected: _tempSort == 'churn_desc',
                          onTap: () => setState(() => _tempSort = 'churn_desc'),
                        ),
                        _FilterChip(
                          label: '✅ Churn: Low to High',
                          isSelected: _tempSort == 'churn_asc',
                          onTap: () => setState(() => _tempSort = 'churn_asc'),
                        ),
                        _FilterChip(
                          label: '⭐ Stamps: High to Low',
                          isSelected: _tempSort == 'stamps_desc',
                          onTap: () => setState(() => _tempSort = 'stamps_desc'),
                        ),
                        _FilterChip(
                          label: '⏳ Most Inactive First',
                          isSelected: _tempSort == 'inactive_desc',
                          onTap: () => setState(() => _tempSort = 'inactive_desc'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Churn Risk Level
                    const Text(
                      'FILTER BY CHURN RISK LEVEL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryLight, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All Risks',
                          isSelected: _tempRisk == 'All',
                          onTap: () => setState(() => _tempRisk = 'All'),
                        ),
                        _FilterChip(
                          label: '🚨 High Risk (75-96%)',
                          isSelected: _tempRisk == 'High Risk',
                          onTap: () => setState(() => _tempRisk = 'High Risk'),
                        ),
                        _FilterChip(
                          label: '⚠️ Medium Risk (40-70%)',
                          isSelected: _tempRisk == 'Medium Risk',
                          onTap: () => setState(() => _tempRisk = 'Medium Risk'),
                        ),
                        _FilterChip(
                          label: '✅ Low Risk (<30%)',
                          isSelected: _tempRisk == 'Low Risk',
                          onTap: () => setState(() => _tempRisk = 'Low Risk'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Filter by Program
                    const Text(
                      'FILTER BY LOYALTY PROGRAM',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryLight, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All Programs',
                          isSelected: _tempProgram == 'All',
                          onTap: () => setState(() => _tempProgram = 'All'),
                        ),
                        ...widget.programs.map((p) {
                          return _FilterChip(
                            label: p.title,
                            isSelected: _tempProgram == p.id,
                            onTap: () => setState(() => _tempProgram = p.id),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 4: Membership Status
                    const Text(
                      'FILTER BY MEMBERSHIP STATUS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryLight, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All Statuses',
                          isSelected: _tempStatus == 'All',
                          onTap: () => setState(() => _tempStatus = 'All'),
                        ),
                        _FilterChip(
                          label: 'Active',
                          isSelected: _tempStatus == 'Active',
                          onTap: () => setState(() => _tempStatus = 'Active'),
                        ),
                        _FilterChip(
                          label: 'Completed',
                          isSelected: _tempStatus == 'Completed',
                          onTap: () => setState(() => _tempStatus = 'Completed'),
                        ),
                        _FilterChip(
                          label: 'Expired',
                          isSelected: _tempStatus == 'Expired',
                          onTap: () => setState(() => _tempStatus = 'Expired'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_tempProgram, _tempStatus, _tempRisk, _tempSort);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Apply Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
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
    String riskLabel = 'Low Risk';
    if (isHighRisk) {
      riskColor = AppColors.accentRose;
      riskLabel = 'High Churn';
    } else if (isMediumRisk) {
      riskColor = AppColors.accentAmber;
      riskLabel = 'Medium Risk';
    }

    String displayName = member.customerName.trim();
    if (displayName.isEmpty ||
        displayName.startsWith('Member (+') ||
        displayName.startsWith('Member (0') ||
        displayName.startsWith('Member (')) {
      if (member.customerEmail.isNotEmpty && !member.customerEmail.contains('@serbuin.com')) {
        final prefix = member.customerEmail.split('@').first;
        displayName = prefix.isNotEmpty ? prefix[0].toUpperCase() + prefix.substring(1) : 'Customer Member';
      } else if (member.customerId.startsWith('cust-') && !member.customerId.contains(RegExp(r'^[0-9]+$'))) {
        final cleanId = member.customerId.replaceAll('cust-', '');
        displayName = cleanId.isNotEmpty ? cleanId[0].toUpperCase() + cleanId.substring(1) : 'Customer';
      } else {
        displayName = 'Loyalty Member';
      }
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
            color: isHighRisk ? AppColors.accentRose.withValues(alpha: 0.35) : AppColors.border,
            width: isHighRisk ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceLight,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryLight),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.customerPhone.isNotEmpty
                            ? '${member.programTitle} • ${member.customerPhone}'
                            : member.programTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
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

            // AI Retention & Churn Rate Strip
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
                      '${member.churnScore}% $riskLabel',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: riskColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $daysInactive days inactive',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                // Only display AI Voucher badge if member is High Risk!
                if (isHighRisk)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentRose.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.accentRose),
                        SizedBox(width: 4),
                        Text('AI Voucher', style: TextStyle(fontSize: 10, color: AppColors.accentRose, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                else
                  const Row(
                    children: [
                      Text('Details', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textMuted),
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
  late ChurnAnalysisResult _analysis;
  int? _resolvedAge;
  String? _resolvedFavorite;
  int? _resolvedVisits;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _resolvedAge = m.customerAge;
    _resolvedFavorite = m.favoriteItem;
    _resolvedVisits = m.totalVisits ?? (m.stampsCollected > 0 ? m.stampsCollected : null);

    // Initial analysis strictly using real verified visit and preference data (no transaction amount data)
    _analysis = GeminiAiService().generateLocalChurnAnalysis(
      customerName: m.customerName,
      stampsCollected: m.stampsCollected,
      totalStamps: m.totalStampsRequired,
      daysInactive: DateTime.now().difference(m.lastStampDate).inDays,
      programTitle: m.programTitle,
      customerAge: _resolvedAge,
      favoriteItem: _resolvedFavorite,
      totalVisits: _resolvedVisits,
    );

    // Asynchronously resolve registered customer profile (birthDate / favoriteCategory) if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lookupRealProfile();
    });
  }

  Future<void> _lookupRealProfile() async {
    final db = context.read<MockDatabaseService>();
    final m = widget.member;

    // Count real visits from db activities if available
    final realActivitiesCount = db.activities.where((a) => a.userId == m.customerId).length;
    final realVisits = realActivitiesCount > 0 ? realActivitiesCount : (m.stampsCollected > 0 ? m.stampsCollected : null);

    final userData = await db.getCustomerProfileData(m.customerId, m.customerPhone);
    if (!mounted) return;

    int? computedAge = m.customerAge;
    String? favCategory = m.favoriteItem;

    if (userData != null) {
      final profileMap = userData['customerProfile'] is Map ? userData['customerProfile'] as Map : null;
      final birthDateStr = profileMap?['birthDate'] ?? userData['birthDate'];
      if (birthDateStr is String && birthDateStr.isNotEmpty) {
        final bDate = DateTime.tryParse(birthDateStr);
        if (bDate != null) {
          final now = DateTime.now();
          int age = now.year - bDate.year;
          if (now.month < bDate.month || (now.month == bDate.month && now.day < bDate.day)) {
            age--;
          }
          if (age > 0 && age < 120) {
            computedAge = age;
          }
        }
      }

      final favStr = profileMap?['favoriteCategory'] ?? userData['favoriteCategory'];
      if (favStr is String && favStr.trim().isNotEmpty) {
        favCategory = favStr.trim();
      }
    }

    if (computedAge != _resolvedAge || favCategory != _resolvedFavorite || realVisits != _resolvedVisits) {
      setState(() {
        _resolvedAge = computedAge;
        _resolvedFavorite = favCategory;
        _resolvedVisits = realVisits;
        _analysis = GeminiAiService().generateLocalChurnAnalysis(
          customerName: m.customerName,
          stampsCollected: m.stampsCollected,
          totalStamps: m.totalStampsRequired,
          daysInactive: DateTime.now().difference(m.lastStampDate).inDays,
          programTitle: m.programTitle,
          customerAge: _resolvedAge,
          favoriteItem: _resolvedFavorite,
          totalVisits: _resolvedVisits,
        );
      });
    }
  }

  Future<void> _sendRetentionVoucher() async {
    setState(() => _isSending = true);
    final db = context.read<MockDatabaseService>();
    final customerFirstName = widget.member.customerName.split(' ').first;

    await db.sendAiRetentionVoucher(
      memberId: widget.member.id,
      title: _analysis.recommendedVoucherTitle,
      description: 'Hey $customerFirstName! We miss seeing you. Here is an exclusive treat for your next visit (valid for 7 days).',
    );
    setState(() => _isSending = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Personalized retention voucher successfully delivered to ${widget.member.customerName}!'),
          backgroundColor: AppColors.accentEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final isHigh = member.riskLevel == 'high';
    final daysInactive = DateTime.now().difference(member.lastStampDate).inDays;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHigh ? AppColors.accentRose.withValues(alpha: 0.2) : AppColors.accentEmerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_analysis.riskScore}% ${member.riskLevel.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isHigh ? AppColors.accentRose : AppColors.accentEmerald,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Customer Profile & Order History Demographics Card (Real Data Only)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 13, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        Text(
                          (_resolvedAge != null || _resolvedFavorite != null)
                              ? 'VERIFIED CUSTOMER PROFILE & HISTORY'
                              : 'VERIFIED LOYALTY CARD ACTIVITY',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryLight,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_resolvedAge != null)
                          _DemographicPill(icon: Icons.cake_rounded, label: 'Age: $_resolvedAge yrs'),
                        if (_resolvedVisits != null)
                          _DemographicPill(
                            icon: Icons.repeat_rounded,
                            label: '$_resolvedVisits visit${_resolvedVisits! > 1 ? 's' : ''}',
                          ),
                        _DemographicPill(
                           icon: Icons.schedule_rounded,
                          label: daysInactive == 0 ? 'Active today' : '$daysInactive days absent',
                        ),
                        _DemographicPill(
                          icon: Icons.stars_rounded,
                          label: '${member.stampsCollected}/${member.totalStampsRequired} stamps',
                        ),
                      ],
                    ),
                    if (_resolvedFavorite != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, size: 14, color: AppColors.accentRose),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Favorite: $_resolvedFavorite',
                              style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'Enrolled in ${member.programTitle} • No extra demographic survey recorded. AI retention strategy is calibrated strictly on verified visit activity and stamp progress.',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // AI Churn Diagnosis Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isHigh ? AppColors.accentRose.withValues(alpha: 0.3) : AppColors.border),
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
                      _analysis.diagnosis,
                      style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // If NOT High Risk, hide voucher button and show healthy notice!
              if (!isHigh) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentEmerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Customer is currently active with a low ${_analysis.riskScore}% churn rate. AI retention vouchers are reserved for high-risk members to preserve profit margins.',
                          style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                // High Risk Member: Show personalized AI Voucher & Merchant Strategy
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
                        'PERSONALIZED RETENTION VOUCHER FOR THIS CUSTOMER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryLight,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _analysis.recommendedVoucherTitle,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _analysis.recommendedVoucherDescription,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 10),

                      // Why this voucher is better to give to this customer:
                      const Row(
                        children: [
                          Icon(Icons.psychology_rounded, size: 14, color: Colors.amberAccent),
                          SizedBox(width: 6),
                          Text(
                            'Why this voucher is optimal for this customer:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amberAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _analysis.whyRecommendedForMerchant,
                        style: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action Button (Only present for High Risk)
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
                    label: Text(_isSending ? 'Delivering Voucher...' : 'Send Personalized AI Voucher to Customer'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DemographicPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DemographicPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primaryLight),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
