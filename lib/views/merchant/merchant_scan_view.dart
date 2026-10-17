import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';

class MerchantScanView extends StatefulWidget {
  final String merchantId;

  const MerchantScanView({super.key, required this.merchantId});

  @override
  State<MerchantScanView> createState() => _MerchantScanViewState();
}

class _MerchantScanViewState extends State<MerchantScanView> with SingleTickerProviderStateMixin {
  final _manualCodeController = TextEditingController();
  late AnimationController _laserController;
  bool _isProcessing = false;
  String? _selectedProgramId;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    final db = context.read<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();
    if (merchantProgs.isNotEmpty) {
      _selectedProgramId = merchantProgs.first.id;
    }
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _processScannedData(String rawData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final db = context.read<MockDatabaseService>();
    final code = rawData.trim();

    // Check if it's a voucher redemption code (starts with SERBUIN- or RET- or SRB-)
    if (code.toUpperCase().startsWith('SERBUIN-') ||
        code.toUpperCase().startsWith('SRB-') ||
        code.toUpperCase().startsWith('RET-')) {
      final res = await db.redeemVoucherByCode(code);
      if (mounted) {
        setState(() => _isProcessing = false);
        _showResultDialog(
          isSuccess: res['success'] ?? false,
          title: res['success'] == true ? 'Voucher Redeemed!' : 'Redemption Failed',
          message: res['message'] ?? '',
          icon: res['success'] == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          accentColor: res['success'] == true ? AppColors.accentEmerald : AppColors.accentRose,
        );
      }
      return;
    }

    // Otherwise treat as Customer Profile QR (awards stamp)
    if (_selectedProgramId == null) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an active program to award stamps.'),
          backgroundColor: AppColors.accentRose,
        ),
      );
      return;
    }

    // Extract customer ID or default to Alex Morgan
    String customerId = code.contains('cust-') ? code : 'cust-alex';
    String customerName = 'Alex Morgan';
    if (code.contains('|')) {
      final parts = code.split('|');
      customerId = parts[0];
      if (parts.length > 1) customerName = parts[1];
    }

    final res = await db.awardStampToCustomer(
      merchantId: widget.merchantId,
      customerId: customerId,
      customerName: customerName,
      programId: _selectedProgramId!,
      count: 1,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      final isCompleted = res['isCompleted'] == true;
      _showResultDialog(
        isSuccess: res['success'] ?? false,
        title: isCompleted ? 'Reward Milestone Reached! 🎉' : 'Stamp Awarded! ☕',
        message: res['message'] ?? '',
        icon: isCompleted ? Icons.celebration_rounded : Icons.add_task_rounded,
        accentColor: isCompleted ? AppColors.accentAmber : AppColors.primaryLight,
        extraInfo: isCompleted
            ? 'Customer has collected all required stamps and can now claim their reward!'
            : null,
      );
    }
  }

  void _showResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
    required IconData icon,
    required Color accentColor,
    String? extraInfo,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (extraInfo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  extraInfo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.primaryLight),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                child: const Text('Continue Scanning'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Scan Customer or Voucher QR',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Target Program Selector
              if (merchantProgs.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded, size: 18, color: AppColors.primaryLight),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedProgramId ?? merchantProgs.first.id,
                            dropdownColor: AppColors.surfaceCard,
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            items: merchantProgs.map((p) {
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text('Program: ${p.title} (${p.totalStamps} stamps)'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedProgramId = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Scanner Viewport with Laser Animation
              Container(
                width: 270,
                height: 270,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Corner targeting brackets
                    ..._buildCornerMarkers(),

                    // Animated scanning laser
                    AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, child) {
                        return Positioned(
                          top: 20 + (_laserController.value * 230),
                          left: 15,
                          right: 15,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.transparent, AppColors.accentCyan, AppColors.primaryLight, Colors.transparent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentCyan.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 54,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isProcessing ? 'Processing...' : 'Align QR inside the frame',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Simulation & Manual Input Header
              const Text(
                'Instant Web Scanner Simulation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Test customer QR scan or voucher code redemption directly:',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Quick Simulation Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _processScannedData('cust-alex|Alex Morgan'),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: const Text('Scan Alex Morgan (Give +1 Stamp)', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _processScannedData('SERBUIN-LATTE-8821'),
                      icon: const Icon(Icons.confirmation_num_rounded, size: 16),
                      label: const Text('Redeem Free Latte Voucher', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentEmerald,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Manual Code Input
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCodeController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter code (e.g. SERBUIN-LATTE-8821)',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () {
                              final text = _manualCodeController.text.trim();
                              if (text.isNotEmpty) _processScannedData(text);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerMarkers() {
    return [
      Positioned(
        top: 10,
        left: 10,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.accentCyan, width: 3),
              left: BorderSide(color: AppColors.accentCyan, width: 3),
            ),
          ),
        ),
      ),
      Positioned(
        top: 10,
        right: 10,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.accentCyan, width: 3),
              right: BorderSide(color: AppColors.accentCyan, width: 3),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 10,
        left: 10,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.accentCyan, width: 3),
              left: BorderSide(color: AppColors.accentCyan, width: 3),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 10,
        right: 10,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.accentCyan, width: 3),
              right: BorderSide(color: AppColors.accentCyan, width: 3),
            ),
          ),
        ),
      ),
    ];
  }
}
