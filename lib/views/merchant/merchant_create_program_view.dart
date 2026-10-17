import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/gemini_ai_service.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';

class MerchantCreateProgramView extends StatefulWidget {
  final String merchantId;
  final String merchantName;

  const MerchantCreateProgramView({
    super.key,
    required this.merchantId,
    required this.merchantName,
  });

  @override
  State<MerchantCreateProgramView> createState() => _MerchantCreateProgramViewState();
}

class _MerchantCreateProgramViewState extends State<MerchantCreateProgramView> {
  final _aiPromptController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _rewardTitleController = TextEditingController();
  final _rewardDescController = TextEditingController();

  int _totalStamps = 6;
  String _selectedCategory = 'Cafe & Bakery';
  String _selectedIcon = 'coffee';
  List<String> _gradientColors = ['#6366F1', '#A855F7'];
  String? _aiReasoning;

  bool _isGenerating = false;
  bool _isPublishing = false;

  final _categories = [
    'Cafe & Bakery',
    'Restaurant & Bar',
    'Salon & Barbershop',
    'Retail & Fashion',
    'Fitness & Wellness',
    'Entertainment',
  ];

  final _presetColorGradients = [
    ['#6366F1', '#A855F7'], // Indigo / Purple
    ['#EC4899', '#FB7185'], // Pink / Rose
    ['#059669', '#10B981'], // Emerald / Mint
    ['#EA580C', '#F59E0B'], // Orange / Amber
    ['#0284C7', '#06B6D4'], // Ocean Blue / Cyan
    ['#0F172A', '#334155'], // Obsidian Slate
  ];

  @override
  void initState() {
    super.initState();
    _aiPromptController.text = '';
  }

  @override
  void dispose() {
    _aiPromptController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _rewardTitleController.dispose();
    _rewardDescController.dispose();
    super.dispose();
  }

  Future<void> _generateWithAi() async {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _isGenerating = true);
    final gemini = GeminiAiService();
    final template = await gemini.generateProgramTemplate(
      businessPrompt: prompt,
      businessCategory: _selectedCategory,
      businessName: widget.merchantName,
    );

    setState(() {
      _titleController.text = template.title;
      _descController.text = template.description;
      _rewardTitleController.text = template.rewardTitle;
      _rewardDescController.text = template.rewardDescription;
      _totalStamps = template.totalStamps;
      _selectedCategory = template.category;
      _gradientColors = template.gradientColors;
      _selectedIcon = template.iconName;
      _aiReasoning = template.aiReasoning;
      _isGenerating = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Gemini AI template generated! You can customize before publishing.'),
          backgroundColor: AppColors.accentPurple,
        ),
      );
    }
  }

  Future<void> _publishProgram() async {
    final title = _titleController.text.trim();
    final rewardTitle = _rewardTitleController.text.trim();

    if (title.isEmpty || rewardTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate or enter a program title and reward title.'),
          backgroundColor: AppColors.accentRose,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);
    final db = context.read<MockDatabaseService>();

    final newProgram = LoyaltyProgram(
      id: 'prog-${const Uuid().v4().substring(0, 8)}',
      merchantId: widget.merchantId,
      merchantName: widget.merchantName,
      title: title,
      description: _descController.text.trim().isEmpty
          ? 'Collect stamps on every purchase.'
          : _descController.text.trim(),
      category: _selectedCategory,
      totalStamps: _totalStamps,
      rewardTitle: rewardTitle,
      rewardDescription: _rewardDescController.text.trim().isEmpty
          ? 'Show this to the cashier to claim your reward.'
          : _rewardDescController.text.trim(),
      gradientColors: _gradientColors,
      iconName: _selectedIcon,
      isActive: true,
      createdAt: DateTime.now(),
      memberCount: 0,
    );

    final success = await db.createProgram(newProgram);
    setState(() => _isPublishing = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Program "${newProgram.title}" published successfully!'),
            backgroundColor: AppColors.accentEmerald,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot create: Maximum 3 active loyalty cards per merchant limit reached!'),
            backgroundColor: AppColors.accentRose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<MockDatabaseService>();
    final currentProgramCount = db.getMerchantActiveProgramCount(widget.merchantId);
    final isLimitReached = currentProgramCount >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Loyalty Program', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Max 3 Cards Warning or Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isLimitReached
                      ? AppColors.accentRose.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLimitReached ? AppColors.accentRose : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLimitReached ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      color: isLimitReached ? AppColors.accentRose : AppColors.primaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isLimitReached
                            ? 'Maximum limit reached (3/3 cards). Delete or archive an unused program first.'
                            : 'Active Programs: $currentProgramCount/3 maximum allowed per merchant.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isLimitReached ? AppColors.accentRose : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // AI Prompt Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.accentPurple.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Generate with Gemini AI',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Describe your business offering or loyalty goal. AI will create an optimized stamp mechanic & reward.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _aiPromptController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        hintText: 'e.g. Modern Barber shop 5 haircuts get 6th VIP styling free',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick prompt chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PromptChip(
                            label: '☕ Specialty Cafe',
                            onTap: () => setState(() => _aiPromptController.text =
                                'Specialty coffee shop buy 5 drinks get 6th signature drink free'),
                          ),
                          _PromptChip(
                            label: '💈 Barbershop',
                            onTap: () => setState(() => _aiPromptController.text =
                                'Gentlemen barbershop 5 cuts unlock deluxe hot towel treatment'),
                          ),
                          _PromptChip(
                            label: '🥐 Artisan Bakery',
                            onTap: () => setState(() => _aiPromptController.text =
                                'Pastry bakery collect 8 stamps for free gourmet croissant & latte'),
                          ),
                          _PromptChip(
                            label: '🍜 Ramen Bar',
                            onTap: () => setState(() => _aiPromptController.text =
                                'Japanese noodle bar 6 bowl stamps unlock free Chef Special ramen'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generateWithAi,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.bolt_rounded, size: 18),
                        label: Text(_isGenerating ? 'AI Generating...' : 'Generate Program Template'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_aiReasoning != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: AppColors.accentCyan, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'AI Rationale: $_aiReasoning',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Live Card Preview
              const Text(
                'Live Card Preview',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 10),
              _buildLiveCardPreview(),

              const SizedBox(height: 24),

              // Editable Program Fields
              const Text(
                'Customize Program Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 14),

              const Text('Program Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'e.g. Brew Master Card'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceCard,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Total Stamps Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Stamps Required', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.primaryLight),
                        onPressed: _totalStamps > 4 ? () => setState(() => _totalStamps--) : null,
                      ),
                      Text(
                        '$_totalStamps Stamps',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryLight),
                        onPressed: _totalStamps < 12 ? () => setState(() => _totalStamps++) : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text('Reward Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _rewardTitleController,
                decoration: const InputDecoration(hintText: 'e.g. Free Specialty Pour Over'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              const Text('Reward Description & Terms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _rewardDescController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'e.g. Valid for any hot or cold single-origin coffee.'),
              ),
              const SizedBox(height: 16),

              // Color Palette Picker
              const Text('Card Gradient Style', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: _presetColorGradients.map((grad) {
                  final isSelected = _gradientColors.first == grad.first;
                  return GestureDetector(
                    onTap: () => setState(() => _gradientColors = grad),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientFromHex(grad),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.colorFromHex(grad.first).withValues(alpha: 0.6),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Publish Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isLimitReached || _isPublishing) ? null : _publishProgram,
                  child: _isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isLimitReached ? 'Limit Reached (Max 3)' : 'Publish Loyalty Program'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCardPreview() {
    final title = _titleController.text.trim().isEmpty ? 'Your Program Title' : _titleController.text.trim();
    final reward = _rewardTitleController.text.trim().isEmpty ? 'Claim Reward' : _rewardTitleController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.gradientFromHex(_gradientColors),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.colorFromHex(_gradientColors.first).withValues(alpha: 0.35),
            blurRadius: 20,
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
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedCategory,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            widget.merchantName,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 18),

          // Stamp circles preview
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_totalStamps, (index) {
              final isLast = index == _totalStamps - 1;
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: isLast
                      ? const Icon(Icons.card_giftcard_rounded, size: 16, color: Colors.amberAccent)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Reward strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reward: $reward',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
        backgroundColor: AppColors.surfaceLight,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: onTap,
      ),
    );
  }
}
