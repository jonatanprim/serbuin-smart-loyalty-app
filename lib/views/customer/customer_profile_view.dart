import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/role_selection_view.dart';

class CustomerProfileView extends StatefulWidget {
  final AppUser user;

  const CustomerProfileView({super.key, required this.user});

  @override
  State<CustomerProfileView> createState() => _CustomerProfileViewState();
}

class _CustomerProfileViewState extends State<CustomerProfileView> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _birthDateController;
  late TextEditingController _bioController;
  late String _favoriteCategory;
  bool _isSaving = false;

  final _categories = [
    'Cafe & Bakery',
    'Restaurant & Bar',
    'Salon & Barbershop',
    'Retail & Fashion',
    'Fitness & Wellness',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.user.customerProfile;
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: p?.phone ?? widget.user.phone ?? '');
    _birthDateController = TextEditingController(text: p?.birthDate ?? '');
    _bioController = TextEditingController(text: p?.bio ?? '');
    _favoriteCategory = (p?.favoriteCategory != null && p!.favoriteCategory.isNotEmpty)
        ? p.favoriteCategory
        : 'Cafe & Bakery';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();

    await auth.updateCustomerProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      birthDate: _birthDateController.text.trim(),
      bio: _bioController.text.trim(),
      favoriteCategory: _favoriteCategory,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully! Membership status upgraded.'),
          backgroundColor: AppColors.accentEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'A',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.user.email,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'VIP LOYALTY MEMBER',
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

              // Edit / Complete Profile Form
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 12),

              const Text('Full Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Enter your full name')),
              const SizedBox(height: 12),

              const Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'e.g. 081234567890')),
              const SizedBox(height: 12),

              const Text('Date of Birth (For Birthday Perks)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _birthDateController, decoration: const InputDecoration(hintText: 'e.g. 1998-05-14')),
              const SizedBox(height: 12),

              const Text('Favorite Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _favoriteCategory,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceCard,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _favoriteCategory = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Bio / Preferences', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _bioController, maxLines: 2, decoration: const InputDecoration(hintText: 'Share a bit about yourself')),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Profile Details'),
                ),
              ),

              const SizedBox(height: 28),

              // Membership Benefits Checklist
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Serbuin Perks',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    _PerkRow(icon: Icons.check_circle_rounded, text: 'Unlimited digital stamps across partner merchants'),
                    SizedBox(height: 6),
                    _PerkRow(icon: Icons.check_circle_rounded, text: 'Dynamic QR vouchers with 2-minute fraud protection'),
                    SizedBox(height: 6),
                    _PerkRow(icon: Icons.check_circle_rounded, text: 'Exclusive AI personalized win-back & loyalty offers'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Logout Button -> Directs to Role Selection
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await auth.logout();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const RoleSelectionView()),
                      (route) => false,
                    );
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

class _PerkRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PerkRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentEmerald, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
