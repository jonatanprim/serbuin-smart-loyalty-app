import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final _phoneController = TextEditingController();
  late AnimationController _laserController;
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  String? _selectedProgramId;
  bool _isTorchOn = false;
  bool _isRequestingCamera = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
      torchEnabled: false,
    );

    final db = context.read<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();
    if (merchantProgs.isNotEmpty) {
      _selectedProgramId = merchantProgs.first.id;
    }

    // Attempt camera start on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestCameraPermission();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _laserController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    if (_isRequestingCamera) return;
    setState(() => _isRequestingCamera = true);

    try {
      // Explicitly request camera permission using permission_handler
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission permanently denied. Tap Settings to enable it.'),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
            backgroundColor: AppColors.accentRose,
            duration: const Duration(seconds: 6),
          ),
        );
      }

      if (_scannerController.value.isRunning) {
        await _scannerController.stop();
      }
      await _scannerController.start();
    } catch (e) {
      debugPrint('Primary camera start attempt: $e');
      // If back camera is unavailable (e.g. desktop/laptop webcam), try front camera
      try {
        await _scannerController.switchCamera();
        await _scannerController.start();
      } catch (e2) {
        debugPrint('Fallback camera start attempt: $e2');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Camera access: Tap the camera/lock icon in your browser address bar to allow camera permission ($e2)'),
              backgroundColor: AppColors.accentRose,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingCamera = false);
      }
    }
  }

  void _onQrDetected(String rawCode) {
    if (_isProcessing) return;
    final code = rawCode.trim();
    if (code.isEmpty) return;

    _handleCustomerLookup(code);
  }

  void _handlePhoneSubmit() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number.'),
          backgroundColor: AppColors.accentRose,
        ),
      );
      return;
    }
    _handleCustomerLookup(phone);
  }

  void _handleCustomerLookup(String query) {
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

    // Parse potential QR payload: "cust-alex|Alex Morgan" or "cust-alex" or phone
    String customerId = query;
    String customerName = 'Alex Morgan';
    String customerPhone = query;

    if (query.contains('|')) {
      final parts = query.split('|');
      customerId = parts[0];
      if (parts.length > 1) customerName = parts[1];
      if (parts.length > 2) customerPhone = parts[2];
    }

    // Try finding in database
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
      // Clean phone or ID
      if (customerId.startsWith('cust-')) {
        customerName = customerId.replaceAll('cust-', '').toUpperCase();
      } else {
        customerName = 'Member ($customerPhone)';
      }
    }

    setState(() => _isProcessing = false);

    _showCustomerAwardBottomSheet(
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      currentStamps: currentStamps,
      targetProgram: targetProgram,
    );
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
                                      customerPhone.isNotEmpty ? customerPhone : '+62 812-3456-7890',
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
                                    width: isNewAward ? 2 : 1,
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

                    const SizedBox(height: 20),

                    // Counter Section: How much stamp to give
                    const Text(
                      'How many stamps to award?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Minus button
                        InkWell(
                          onTap: stampsToAdd > 1
                              ? () => setSheetState(() => stampsToAdd--)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: stampsToAdd > 1 ? AppColors.surfaceLight : AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: stampsToAdd > 1 ? AppColors.border : AppColors.border.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              color: stampsToAdd > 1 ? Colors.white : AppColors.textMuted,
                              size: 24,
                            ),
                          ),
                        ),

                        // Stamp Counter Display
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.25),
                                AppColors.accentEmerald.withValues(alpha: 0.25),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded, color: AppColors.accentEmerald, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                '+$stampsToAdd',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Plus button
                        InkWell(
                          onTap: (currentStamps + stampsToAdd < targetProgram.totalStamps)
                              ? () => setSheetState(() => stampsToAdd++)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: (currentStamps + stampsToAdd < targetProgram.totalStamps)
                                  ? AppColors.surfaceLight
                                  : AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (currentStamps + stampsToAdd < targetProgram.totalStamps)
                                    ? AppColors.border
                                    : AppColors.border.withValues(alpha: 0.3),
                              ),
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
                            Navigator.pop(bottomSheetCtx); // Close bottomsheet
                          }

                          if (mounted) {
                            navigator.pop(); // Close MerchantScanView & navigate to Home

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Scan Customer QR',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Request / Restart Camera',
            onPressed: _requestCameraPermission,
          ),
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColors.accentAmber : Colors.white70,
            ),
            onPressed: () {
              setState(() => _isTorchOn = !_isTorchOn);
              _scannerController.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Target Program Selector
              if (merchantProgs.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                                child: Text('Target: ${p.title} (${p.totalStamps} stamps)'),
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
                const SizedBox(height: 16),
              ],

              // Live Camera Scanner Viewport with Overlay
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(
                      children: [
                        // Live Camera feed
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              final String? val = barcode.rawValue;
                              if (val != null && val.isNotEmpty) {
                                _onQrDetected(val);
                                break;
                              }
                            }
                          },
                          placeholderBuilder: (context) {
                            return Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight, size: 36),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isRequestingCamera ? 'Requesting Camera...' : 'Camera Scanner',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isRequestingCamera
                                          ? 'Please click "Allow" on the browser prompt'
                                          : 'Tap below to activate camera & allow permission',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      height: 38,
                                      child: ElevatedButton.icon(
                                        onPressed: _isRequestingCamera ? null : _requestCameraPermission,
                                        icon: _isRequestingCamera
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.videocam_rounded, size: 16),
                                        label: Text(
                                          _isRequestingCamera ? 'Requesting...' : 'Activate Camera',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error) {
                            return Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentRose.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.videocam_off_rounded, color: AppColors.accentRose, size: 36),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Camera Access Needed',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Click below to grant camera permission:',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 38,
                                      child: ElevatedButton.icon(
                                        onPressed: _isRequestingCamera ? null : _requestCameraPermission,
                                        icon: const Icon(Icons.camera_alt_rounded, size: 14),
                                        label: const Text('Request Permission', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Or enter customer phone number below',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Corner targeting markers
                        ..._buildCornerMarkers(),

                        // Animated scanning laser (only while running)
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _scannerController,
                          builder: (context, state, _) {
                            if (!state.isRunning) return const SizedBox.shrink();
                            return AnimatedBuilder(
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
                            );
                          },
                        ),

                        // Bottom scanner hint
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _isProcessing ? 'Processing QR...' : 'Point camera at customer QR',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Manual Phone Number Input Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.dialpad_rounded, size: 16, color: AppColors.primaryLight),
                        SizedBox(width: 8),
                        Text(
                          'Or Award Stamps by Phone Number',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter customer phone number to look up their stamp count:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Phone Number Input and Submit
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                hintText: 'Enter phone number (e.g. 081234567890)',
                                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                prefixIcon: Icon(Icons.phone_rounded, color: AppColors.textMuted, size: 18),
                              ),
                              onSubmitted: (_) => _handlePhoneSubmit(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _handlePhoneSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Submit',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
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
