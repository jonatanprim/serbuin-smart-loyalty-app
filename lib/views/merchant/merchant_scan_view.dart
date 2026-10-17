import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

class _MerchantScanViewState extends State<MerchantScanView> {
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;
  String? _selectedProgramId;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  @override
  void initState() {
    super.initState();
    MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl('zxing.min.js');
    _scannerController = MobileScannerController();

    final db = context.read<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();
    if (merchantProgs.isNotEmpty) {
      _selectedProgramId = merchantProgs.first.id;
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _showInputManualSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InputManualBottomSheet(),
    );

    if (result != null && result['phone'] != null && result['phone']!.isNotEmpty) {
      _handleCustomerLookup(result['phone']!, providedName: result['name']);
    }
  }

  void _handleCustomerLookup(String query, {String? providedName}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final db = context.read<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();
    final programId = _selectedProgramId ?? (merchantProgs.isNotEmpty ? merchantProgs.first.id : '');

    if (programId.isEmpty) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create or select an active loyalty program first.'),
          backgroundColor: AppColors.accentRose,
        ),
      );
      return;
    }

    final targetProgram = merchantProgs.firstWhere(
      (p) => p.id == programId,
      orElse: () => merchantProgs.first,
    );

    // Parse potential QR payload: "cust-id|Customer Name|phone" or "cust-id" or phone
    String customerId = query;
    String customerName = 'Member';
    String customerPhone = query;

    if (query.contains('|')) {
      final parts = query.split('|');
      customerId = parts[0];
      if (parts.length > 1 && parts[1].isNotEmpty) customerName = parts[1];
      if (parts.length > 2 && parts[2].isNotEmpty) customerPhone = parts[2];
    }

    // 1. Try finding in program members
    final existingMember = db.findMemberByPhoneOrIdentifier(
      query: customerId.isNotEmpty ? customerId : query,
      programId: programId,
    );

    int currentStamps = 0;
    if (existingMember != null) {
      customerId = existingMember.customerId;
      customerName = existingMember.customerName;
      customerPhone = existingMember.customerPhone;
      currentStamps = existingMember.stampsCollected;
    } else {
      // 2. Try looking up in registered user accounts
      final regUser = await db.findRegisteredCustomer(customerPhone.isNotEmpty ? customerPhone : (customerId.isNotEmpty ? customerId : query));
      if (regUser != null) {
        customerId = regUser['id']!;
        customerName = regUser['name']!;
        customerPhone = regUser['phone']!;
      } else if (providedName != null && providedName.trim().isNotEmpty) {
        customerName = providedName.trim();
      } else if (customerId.startsWith('cust-') && !customerId.contains(RegExp(r'^[0-9]+$'))) {
        final cleanId = customerId.replaceAll('cust-', '');
        customerName = cleanId.isNotEmpty ? cleanId[0].toUpperCase() + cleanId.substring(1) : 'Customer';
      } else {
        customerName = 'Member';
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);

      _showCustomerAwardBottomSheet(
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        currentStamps: currentStamps,
        targetProgram: targetProgram,
      );
    }
  }

  void _showCustomerAwardBottomSheet({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required int currentStamps,
    required LoyaltyProgram targetProgram,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        int stampsToAdd = 1;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final newTotalStamps = (currentStamps + stampsToAdd).clamp(0, targetProgram.totalStamps);
            final willReachReward = newTotalStamps >= targetProgram.totalStamps;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header: Customer Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                customerName.isNotEmpty ? customerName[0].toUpperCase() : 'M',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        customerName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentEmerald.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'VERIFIED',
                                        style: TextStyle(
                                          color: AppColors.accentEmerald,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_rounded, size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      customerPhone.isNotEmpty ? customerPhone : 'ID: ',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Program Title & Current Stamp Progress
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'LOYALTY PROGRAM',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      targetProgram.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$currentStamps / ${targetProgram.totalStamps} Stamps',
                                  style: const TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Visual stamp dots preview
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(targetProgram.totalStamps, (index) {
                              final isExisting = index < currentStamps;
                              final isNewAward = index >= currentStamps && index < newTotalStamps;

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isExisting
                                      ? AppColors.primary
                                      : isNewAward
                                          ? AppColors.accentEmerald
                                          : AppColors.surfaceLight,
                                  border: Border.all(
                                    color: isNewAward
                                        ? AppColors.accentEmerald
                                        : isExisting
                                            ? AppColors.primaryLight
                                            : AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  isExisting
                                      ? Icons.check_rounded
                                      : isNewAward
                                          ? Icons.add_rounded
                                          : Icons.circle_outlined,
                                  color: isExisting || isNewAward ? Colors.white : AppColors.textMuted,
                                  size: 14,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Counter to add stamps
                    const Text(
                      'HOW MANY STAMPS TO AWARD?',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Decrement button
                        InkWell(
                          onTap: stampsToAdd > 1
                              ? () => setSheetState(() => stampsToAdd--)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              color: stampsToAdd > 1 ? Colors.white : AppColors.textMuted,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Current stamps to add display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '+$stampsToAdd',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Increment button
                        InkWell(
                          onTap: (currentStamps + stampsToAdd < targetProgram.totalStamps)
                              ? () => setSheetState(() => stampsToAdd++)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: (currentStamps + stampsToAdd < targetProgram.totalStamps)
                                  ? Colors.white
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Text(
                      willReachReward
                          ? '🎉 Member will complete card and unlock reward!'
                          : 'Resulting in $newTotalStamps / ${targetProgram.totalStamps} stamps',
                      style: TextStyle(
                        color: willReachReward ? AppColors.accentAmber : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: willReachReward ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Confirm Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final db = context.read<MockDatabaseService>();
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          final count = stampsToAdd;

                          await db.awardStampToCustomer(
                            merchantId: widget.merchantId,
                            customerId: customerId,
                            customerName: customerName,
                            customerPhone: customerPhone,
                            programId: targetProgram.id,
                            count: count,
                          );

                          if (bottomSheetCtx.mounted) {
                            Navigator.pop(bottomSheetCtx);
                          }

                          if (mounted) {
                            navigator.pop(); // Close scanner and return to Home

                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Success add $count stamp${count > 1 ? 's' : ''} to member $customerName!',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          'Confirm & Award +$stampsToAdd Stamp${stampsToAdd > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentEmerald,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen Camera Scanner Feed
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_isProcessing) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  if (_lastScannedCode == code &&
                      _lastScannedTime != null &&
                      DateTime.now().difference(_lastScannedTime!).inSeconds < 3) {
                    return;
                  }
                  _lastScannedCode = code;
                  _lastScannedTime = DateTime.now();
                  _handleCustomerLookup(code);
                }
              }
            },
            placeholderBuilder: (context) => ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primaryLight),
                      const SizedBox(height: 16),
                      const Text(
                        'Starting camera...\nAllow camera access if your browser asks.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _showInputManualSheet,
                        icon: const Icon(Icons.dialpad_rounded, size: 18),
                        label: const Text('Input Phone Number Manually'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            errorBuilder: (context, error) {
              final isDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_rounded, color: AppColors.accentRose, size: 44),
                        const SizedBox(height: 12),
                        Text(
                          isDenied ? 'Camera permission denied' : 'Camera unavailable',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isDenied
                              ? 'Enable camera access for this site (lock icon in the address bar), then tap Retry.'
                              : (error.errorDetails?.message ?? error.errorCode.name),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                await _scannerController.stop();
                                await _scannerController.start();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _showInputManualSheet,
                              icon: const Icon(Icons.dialpad_rounded, size: 18),
                              label: const Text('Manual Input'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. Translucent Vignette Mask & Scanning Frame Overlay
          const QRScannerOverlay(scanAreaSize: 260),

          // 3. Top Floating Navigation Bar & Loyalty Program Selector
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close / Back button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      const Text(
                        'Scan Customer QR',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),

                      // Torch toggle button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                          onPressed: () => _scannerController.toggleTorch(),
                        ),
                      ),
                    ],
                  ),

                  // Target program picker chip
                  if (merchantProgs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedProgramId ?? merchantProgs.first.id,
                          dropdownColor: AppColors.surfaceCard,
                          isDense: true,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          items: merchantProgs.map((p) {
                            return DropdownMenuItem(
                              value: p.id,
                              child: Text('Awarding to: ${p.title} (${p.totalStamps} stamps)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedProgramId = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Bottom Controls Overlay: Guidance & Manual Input Button
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Point camera at customer\'s QR code',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Manual Input Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _showInputManualSheet,
                    icon: const Icon(Icons.dialpad_rounded, size: 18),
                    label: const Text(
                      'Input Phone Number Manually',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
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

/// Bottom Sheet for Manual Phone Input
class _InputManualBottomSheet extends StatefulWidget {
  const _InputManualBottomSheet();

  @override
  State<_InputManualBottomSheet> createState() => _InputManualBottomSheetState();
}

class _InputManualBottomSheetState extends State<_InputManualBottomSheet> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  List<Map<String, String>> _registeredCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final db = context.read<MockDatabaseService>();
    final customers = await db.getAllRegisteredCustomers();
    if (mounted) {
      setState(() {
        _registeredCustomers = customers;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    if (phone.isEmpty) return;
    Navigator.of(context).pop({'phone': phone, 'name': name});
  }

  void _selectCustomer(Map<String, String> cust) {
    Navigator.of(context).pop({
      'phone': cust['phone']?.isNotEmpty == true ? cust['phone']! : cust['id']!,
      'name': cust['name'] ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Manual Member Input',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter customer phone number to look up their membership card and award stamps.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Customer Phone Number',
              hintText: 'e.g. 081234567890 or +62812...',
              prefixIcon: Icon(Icons.phone_rounded, color: AppColors.primaryLight, size: 20),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Customer Name (Optional)',
              hintText: 'e.g. Budi Santoso, Siti Rahma',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primaryLight, size: 20),
            ),
            onSubmitted: (_) => _submit(),
          ),

          // Registered Customers Quick Select (if available)
          if (_registeredCustomers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'OR TAP REGISTERED CUSTOMER:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _registeredCustomers.map((cust) {
                  final name = cust['name'] ?? 'Customer';
                  final phone = cust['phone'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.person_rounded, size: 16, color: AppColors.primaryLight),
                      label: Text(
                        phone.isNotEmpty ? '$name ($phone)' : name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      backgroundColor: AppColors.surfaceLight,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () => _selectCustomer(cust),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Continue to Stamp Awarding', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent Vignette Overlay with Centered Cutout and Animated Laser
class QRScannerOverlay extends StatefulWidget {
  final Color overlayColor;
  final double scanAreaSize;

  const QRScannerOverlay({
    super.key,
    this.overlayColor = const Color(0x99000000),
    this.scanAreaSize = 260.0,
  });

  @override
  State<QRScannerOverlay> createState() => _QRScannerOverlayState();
}

class _QRScannerOverlayState extends State<QRScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: widget.scanAreaSize).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(widget.overlayColor, BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
              Center(
                child: Container(
                  width: widget.scanAreaSize,
                  height: widget.scanAreaSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: SizedBox(
            width: widget.scanAreaSize,
            height: widget.scanAreaSize,
            child: Stack(
              children: [
                // Corner Brackets
                CustomPaint(
                  size: Size(widget.scanAreaSize, widget.scanAreaSize),
                  painter: _ScannerFramePainter(color: AppColors.primaryLight),
                ),
                // Animated Scanning Laser Line
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Positioned(
                      top: _animation.value,
                      left: 4,
                      right: 4,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.accentCyan,
                              AppColors.primaryLight,
                              Colors.transparent,
                            ],
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  final Color color;
  static const double strokeWidth = 4.0;
  static const double cornerLength = 32.0;
  static const double cornerRadius = 20.0;

  _ScannerFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Top Left
    path.moveTo(0, cornerLength);
    path.lineTo(0, cornerRadius);
    path.arcToPoint(const Offset(cornerRadius, 0), radius: const Radius.circular(cornerRadius));
    path.lineTo(cornerLength, 0);

    // Top Right
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(Offset(size.width, cornerRadius), radius: const Radius.circular(cornerRadius));
    path.lineTo(size.width, cornerLength);

    // Bottom Right
    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height - cornerRadius);
    path.arcToPoint(Offset(size.width - cornerRadius, size.height), radius: const Radius.circular(cornerRadius));
    path.lineTo(size.width - cornerLength, size.height);

    // Bottom Left
    path.moveTo(cornerLength, size.height);
    path.lineTo(cornerRadius, size.height);
    path.arcToPoint(Offset(0, size.height - cornerRadius), radius: const Radius.circular(cornerRadius));
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
