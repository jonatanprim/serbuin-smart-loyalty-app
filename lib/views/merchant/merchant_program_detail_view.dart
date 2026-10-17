import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';

class MerchantProgramDetailView extends StatefulWidget {
  final LoyaltyProgram program;

  const MerchantProgramDetailView({super.key, required this.program});

  @override
  State<MerchantProgramDetailView> createState() => _MerchantProgramDetailViewState();
}

class _MerchantProgramDetailViewState extends State<MerchantProgramDetailView> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _rewardTitleController;
  late TextEditingController _rewardDescController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.program.title);
    _descController = TextEditingController(text: widget.program.description);
    _rewardTitleController = TextEditingController(text: widget.program.rewardTitle);
    _rewardDescController = TextEditingController(text: widget.program.rewardDescription);
    _isActive = widget.program.isActive;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rewardTitleController.dispose();
    _rewardDescController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final db = context.read<MockDatabaseService>();

    final updated = widget.program.copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      rewardTitle: _rewardTitleController.text.trim(),
      rewardDescription: _rewardDescController.text.trim(),
      isActive: _isActive,
    );

    await db.updateProgram(updated);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Program updated successfully!'),
          backgroundColor: AppColors.accentEmerald,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _handleDelete() async {
    final db = context.read<MockDatabaseService>();
    final membersCount = db.members.where((m) => m.programId == widget.program.id).length;

    if (membersCount > 0 || widget.program.memberCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: AppColors.accentRose, size: 22),
              SizedBox(width: 10),
              Text('Cannot Delete Program', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'This program currently has ${widget.program.memberCount} enrolled members with active digital stamps. To preserve customer rewards, active programs cannot be deleted.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Loyalty Program?'),
        content: const Text(
          'Are you sure you want to delete this program? This action cannot be undone.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRose),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await db.deleteProgram(widget.program.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Program deleted.'),
              backgroundColor: AppColors.accentEmerald,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = widget.program.memberCount == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: canDelete ? AppColors.accentRose : AppColors.textMuted,
            ),
            tooltip: canDelete ? 'Delete Program' : 'Cannot delete (has active members)',
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientFromHex(widget.program.gradientColors),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.colorFromHex(widget.program.gradientColors.first).withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
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
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.program.category,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isActive ? AppColors.accentEmerald.withValues(alpha: 0.3) : Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isActive ? AppColors.accentEmerald : Colors.grey,
                            ),
                          ),
                          child: Text(
                            _isActive ? 'ACTIVE' : 'PAUSED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _isActive ? AppColors.accentEmerald : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.program.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.program.totalStamps} Stamps Required • ${widget.program.memberCount} Members Joined',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Status Switcher
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Program Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('Pause program to stop accepting new cards', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    Switch(
                      value: _isActive,
                      activeColor: AppColors.accentEmerald,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Edit Form Fields
              const Text('Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 14),

              const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 14),

              const Text('Reward Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _rewardTitleController,
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 14),

              const Text('Reward Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _rewardDescController,
                maxLines: 2,
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 28),

              // Save Changes Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 14),

              // Delete Info Pill
              if (!canDelete)
                Center(
                  child: Text(
                    '🔒 Program has ${widget.program.memberCount} members and cannot be deleted.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
