import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/gemini_ai_service.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';
import '../auth/role_selection_view.dart';

class MerchantProfileView extends StatefulWidget {
  final AppUser user;

  const MerchantProfileView({super.key, required this.user});

  @override
  State<MerchantProfileView> createState() => _MerchantProfileViewState();
}

class _MerchantProfileViewState extends State<MerchantProfileView> {
  late TextEditingController _businessNameController;
  late TextEditingController _categoryController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _hoursController;
  late TextEditingController _descController;
  final _geminiKeyController = TextEditingController();

  bool _isSaving = false;
  String? _selectedProgramIdForMock;
  bool _isGeneratingMock = false;
  bool _isClearingMock = false;

  @override
  void initState() {
    super.initState();
    final p = widget.user.merchantProfile;
    _businessNameController = TextEditingController(text: p?.businessName ?? widget.user.name);
    _categoryController = TextEditingController(text: p?.category ?? 'Cafe & Bakery');
    _addressController = TextEditingController(text: p?.address ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? widget.user.phone ?? '');
    _hoursController = TextEditingController(text: p?.operatingHours ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    _descController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();

    await auth.updateMerchantProfile(
      businessName: _businessNameController.text.trim(),
      category: _categoryController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      operatingHours: _hoursController.text.trim(),
      description: _descController.text.trim(),
    );

    if (_geminiKeyController.text.trim().isNotEmpty) {
      GeminiAiService().setApiKey(_geminiKeyController.text.trim());
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merchant profile updated successfully!'),
          backgroundColor: AppColors.accentEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final db = context.watch<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.user.id).toList();
    if (_selectedProgramIdForMock == null && merchantProgs.isNotEmpty) {
      _selectedProgramIdForMock = merchantProgs.first.id;
    }
    final currentProgramMockCount = _selectedProgramIdForMock != null
        ? db.members.where((m) => m.programId == _selectedProgramIdForMock && m.customerId.startsWith('cust-mock-')).length
        : 0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Merchant Profile & Settings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage your store details and explore merchant guidelines',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 20),

              // Store identity card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: AppColors.warmGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _businessNameController.text,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.user.email,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'VERIFIED MERCHANT',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.accentEmerald),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Complete Profile Form
              const Text(
                'Store Information',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 12),

              const Text('Business Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _businessNameController, decoration: const InputDecoration()),
              const SizedBox(height: 12),

              const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _categoryController, decoration: const InputDecoration(hintText: 'e.g. Cafe & Bakery, Retail, Barbershop')),
              const SizedBox(height: 12),

              const Text('Physical Store Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _addressController, decoration: const InputDecoration(hintText: 'e.g. Jl. Senopati No. 42, Jakarta Selatan')),
              const SizedBox(height: 12),

              const Text('Business Phone / WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'e.g. 081234567890')),
              const SizedBox(height: 12),

              const Text('Operating Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _hoursController, decoration: const InputDecoration(hintText: 'e.g. 08:00 AM - 10:00 PM Daily')),
              const SizedBox(height: 12),

              const Text('Store Bio & Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _descController, maxLines: 2, decoration: const InputDecoration(hintText: 'Share a brief description of your store & specialty')),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Merchant Profile'),
                ),
              ),

              const SizedBox(height: 28),

              // "How to Use Serbuin" Expandable Guide (Default: Collapsed)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: AppColors.primaryLight, size: 20),
                    ),
                    title: const Text(
                      'How to Use Serbuin App',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Tap to view step-by-step cashier & loyalty guide',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    iconColor: AppColors.primaryLight,
                    collapsedIconColor: AppColors.textMuted,
                    children: const [
                      SizedBox(height: 8),
                      _GuideStepCard(
                        stepNumber: '1',
                        title: 'Create AI Loyalty Cards',
                        description: 'Tap "Create" on Home. Use Gemini AI to auto-generate reward rules, stamps, and gradients. Max 3 active cards.',
                        icon: Icons.auto_awesome_rounded,
                        accentColor: AppColors.primaryLight,
                      ),
                      SizedBox(height: 10),
                      _GuideStepCard(
                        stepNumber: '2',
                        title: 'Scan Customer QR for Stamps',
                        description: 'When a customer orders, tap the center round Scan button in the bottom navigation to scan their Profile QR and award stamps.',
                        icon: Icons.qr_code_scanner_rounded,
                        accentColor: AppColors.accentCyan,
                      ),
                      SizedBox(height: 10),
                      _GuideStepCard(
                        stepNumber: '3',
                        title: 'Redeem Customer Vouchers',
                        description: 'Customers show dynamic 2-minute expiring QR vouchers. Point your scanner at the voucher QR to redeem instantly.',
                        icon: Icons.confirmation_num_rounded,
                        accentColor: AppColors.accentEmerald,
                      ),
                      SizedBox(height: 10),
                      _GuideStepCard(
                        stepNumber: '4',
                        title: 'Re-engage At-Risk Members',
                        description: 'Open the Members tab. The AI Churn Scanner flags customers at risk of not returning and recommends 1-click win-back vouchers.',
                        icon: Icons.insights_rounded,
                        accentColor: AppColors.accentAmber,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Gemini AI Settings
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.key_rounded, size: 18, color: AppColors.primaryLight),
                        SizedBox(width: 8),
                        Text(
                          'Custom Gemini API Key (Optional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Leave empty to use Serbuin’s built-in intelligent engine, or provide your Google Gemini API key.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _geminiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: 'AIzaSy...'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Mock Customer Data & Churn Simulation
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.science_rounded, size: 20, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mock Customer Data & Churn Simulation',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Seed test members to experience live churn risk & AI retention vouchers',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),

                    if (merchantProgs.isEmpty)
                      const Text(
                        'Please create at least one loyalty program first before generating mock customer members.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      )
                    else ...[
                      const Text(
                        'TARGET LOYALTY PROGRAM',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryLight, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: merchantProgs.any((p) => p.id == _selectedProgramIdForMock)
                                ? _selectedProgramIdForMock
                                : merchantProgs.first.id,
                            isExpanded: true,
                            dropdownColor: AppColors.surfaceCard,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                            items: merchantProgs.map((p) {
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  '${p.title} (${p.category})',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedProgramIdForMock = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              currentProgramMockCount > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 18,
                              color: currentProgramMockCount > 0 ? AppColors.accentEmerald : AppColors.primaryLight,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentProgramMockCount > 0
                                    ? '$currentProgramMockCount mock members active in this program with varied churn risks (High, Med, Low).'
                                    : 'No mock members generated yet for this program.',
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isGeneratingMock || _selectedProgramIdForMock == null
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setState(() => _isGeneratingMock = true);
                                  final count = await db.generateMockCustomerData(
                                    merchantId: widget.user.id,
                                    programId: _selectedProgramIdForMock!,
                                  );
                                  setState(() => _isGeneratingMock = false);

                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Generated $count mock customers with High, Medium & Low churn risk! Open Members tab to test AI Vouchers.',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: AppColors.accentEmerald,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                },
                          icon: _isGeneratingMock
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: Text(
                            _isGeneratingMock
                                ? 'Generating Mock Members...'
                                : 'Generate 10 Mock Members & History',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentEmerald,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      if (currentProgramMockCount > 0) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isClearingMock
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    setState(() => _isClearingMock = true);
                                    final cleared = await db.clearMockCustomerData(
                                      programId: _selectedProgramIdForMock!,
                                    );
                                    setState(() => _isClearingMock = false);

                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Cleared $cleared mock members.'),
                                          backgroundColor: AppColors.surfaceLight,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                      );
                                    }
                                  },
                            icon: _isClearingMock
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: Text(
                              _isClearingMock ? 'Clearing...' : 'Clear Mock Members from Program',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentRose,
                              side: BorderSide(color: AppColors.accentRose.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Logout Button -> Directs to Role Selection
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surfaceCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        title: const Text('Confirm Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        content: const Text('Are you sure you want to log out of your merchant account? Local session will be cleaned.', style: TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRose),
                            child: const Text('Log Out'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true && context.mounted) {
                      final navigator = Navigator.of(context);
                      await auth.logout();
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const RoleSelectionView()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: AppColors.accentRose, size: 18),
                  label: const Text('Log Out (Switch Role)', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.accentRose.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

class _GuideStepCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _GuideStepCard({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(fontWeight: FontWeight.w800, color: accentColor, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
