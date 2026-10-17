import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/gemini_ai_service.dart';
import '../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    final p = widget.user.merchantProfile;
    _businessNameController = TextEditingController(text: p?.businessName ?? widget.user.name);
    _categoryController = TextEditingController(text: p?.category ?? 'Cafe & Bakery');
    _addressController = TextEditingController(text: p?.address ?? 'Jl. Senopati No. 42, Jakarta');
    _phoneController = TextEditingController(text: p?.phone ?? widget.user.phone ?? '+62 811-9876-5432');
    _hoursController = TextEditingController(text: p?.operatingHours ?? '07:00 AM - 10:00 PM Daily');
    _descController = TextEditingController(text: p?.description ?? 'Artisan specialty coffee & cozy aesthetic.');
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
              TextField(controller: _categoryController, decoration: const InputDecoration()),
              const SizedBox(height: 12),

              const Text('Physical Store Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _addressController, decoration: const InputDecoration()),
              const SizedBox(height: 12),

              const Text('Business Phone / WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _phoneController, decoration: const InputDecoration()),
              const SizedBox(height: 12),

              const Text('Operating Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _hoursController, decoration: const InputDecoration()),
              const SizedBox(height: 12),

              const Text('Store Bio & Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _descController, maxLines: 2, decoration: const InputDecoration()),
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

              // "How to Use Serbuin" Interactive Guide
              const Text(
                'How to Use Serbuin Merchant',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 12),
              _GuideStepCard(
                stepNumber: '1',
                title: 'Create AI Loyalty Cards',
                description: 'Tap "Create" on Home. Use Gemini AI to auto-generate reward rules, stamps, and gradients. Max 3 active cards.',
                icon: Icons.auto_awesome_rounded,
                accentColor: AppColors.primaryLight,
              ),
              const SizedBox(height: 10),
              _GuideStepCard(
                stepNumber: '2',
                title: 'Scan Customer QR for Stamps',
                description: 'When a customer orders, tap the center round Scan button in the bottom navigation to scan their Profile QR and award stamps.',
                icon: Icons.qr_code_scanner_rounded,
                accentColor: AppColors.accentCyan,
              ),
              const SizedBox(height: 10),
              _GuideStepCard(
                stepNumber: '3',
                title: 'Redeem Customer Vouchers',
                description: 'Customers show dynamic 2-minute expiring QR vouchers. Point your scanner at the voucher QR to redeem instantly.',
                icon: Icons.confirmation_num_rounded,
                accentColor: AppColors.accentEmerald,
              ),
              const SizedBox(height: 10),
              _GuideStepCard(
                stepNumber: '4',
                title: 'Re-engage At-Risk Members',
                description: 'Open the Members tab. The AI Churn Scanner flags customers at risk of not returning and recommends 1-click win-back vouchers.',
                icon: Icons.insights_rounded,
                accentColor: AppColors.accentAmber,
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

              const SizedBox(height: 28),

              // Logout Button -> Directs to Role Selection
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.logout();
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
