import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';
import 'reward_confirm_bottom_sheet.dart';

class MerchantScanView extends StatefulWidget {
  final String merchantId;

  const MerchantScanView({super.key, required this.merchantId});

  @override
  State<MerchantScanView> createState() => _MerchantScanViewState();
}

class _MerchantScanViewState extends State<MerchantScanView> with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;
  String? _selectedProgramId;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;
  bool _isCameraPermissionDenied = false;
  bool _isStartingCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
      'https://unpkg.com/@zxing/library@0.21.3/umd/index.min.js',
    );
    _scannerController = MobileScannerController(
      autoStart: false,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [BarcodeFormat.qrCode],
      returnImage: false,
    );

    _scannerController.addListener(() {
      final v = _scannerController.value;
      debugPrint(
        'scanner: init=${v.isInitialized} running=${v.isRunning} '
        'starting=${v.isStarting} error=${v.error?.errorCode} ${v.error?.errorDetails?.message}',
      );
    });

    final db = context.read<MockDatabaseService>();
    final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();
    if (merchantProgs.isNotEmpty) {
      _selectedProgramId = merchantProgs.first.id;
    }

    _startScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    if (state == AppLifecycleState.resumed) {
      // Re-check and resume camera if returning from iOS permission modal dialog
      final v = _scannerController.value;
      if (!v.isRunning && !v.isStarting) {
        _startScanner();
      }
    }
  }

  Future<void> _startScanner() async {
    if (!mounted || _isStartingCamera) return;
    _isStartingCamera = true;

    try {
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            setState(() {
              _isCameraPermissionDenied = true;
              _isStartingCamera = false;
            });
          }
          return;
        }
      }

      if (_scannerController.value.isRunning) {
        _isStartingCamera = false;
        return;
      }

      await _scannerController.start();
      if (mounted) {
        setState(() {
          _isCameraPermissionDenied = false;
          _isStartingCamera = false;
        });
      }
    } catch (e) {
      debugPrint('Error starting scanner: $e');
      if (mounted) {
        setState(() => _isStartingCamera = false);
      }
    }
  }

  Future<void> _restartScanner() async {
    if (!mounted) return;
    try {
      if (_scannerController.value.isRunning) {
        await _scannerController.stop();
      }
    } catch (_) {}

    try {
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) setState(() => _isCameraPermissionDenied = true);
          return;
        }
      }
      await _scannerController.start();
      if (mounted) {
        setState(() => _isCameraPermissionDenied = false);
      }
    } catch (e) {
      debugPrint('Failed to restart scanner: $e');
    }
  }

  void _showInputManualSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InputManualBottomSheet(),
    );

    if (result != null && result['phone'] != null && result['phone']!.isNotEmpty) {
      _lastScannedCode = null;
      _handleScanOrInput(result['phone']!);
    }
  }

  /// Handles incoming scan code or manual input: checks for Voucher first, else member stamp lookup
  void _handleScanOrInput(String query, {String? providedName}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final db = context.read<MockDatabaseService>();
      final merchantProgs = db.programs.where((p) => p.merchantId == widget.merchantId).toList();
      final programId = _selectedProgramId ?? (merchantProgs.isNotEmpty ? merchantProgs.first.id : '');

      if (programId.isEmpty) {
        if (mounted) setState(() => _isProcessing = false);
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

      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      // 1. Check if the code represents a Reward Voucher
      final isVoucherQuery = !cleanQuery.contains('|') && (
          cleanQuery.toUpperCase().startsWith('SRB-') ||
          cleanQuery.toUpperCase().startsWith('RET-') ||
          cleanQuery.toUpperCase().startsWith('VOUCHER|') ||
          db.vouchers.any((v) =>
              v.code.toUpperCase() == cleanQuery.toUpperCase() ||
              v.id.toUpperCase() == cleanQuery.toUpperCase()));

      if (isVoucherQuery) {
        final voucher = await db.findVoucher(cleanQuery);
        if (voucher != null) {
          // Cross-merchant validation: ensure voucher belongs to this merchant
          if (voucher.merchantId != widget.merchantId) {
            if (mounted) {
              setState(() {
                _isProcessing = false;
                _lastScannedCode = null;
              });
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Invalid Voucher',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                            ),
                            Text(
                              'Voucher is not from this merchant. This voucher belongs to ${voucher.merchantName}.',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.accentRose,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }

          if (mounted) {
            _showVoucherApprovalSheet(voucher);
          }
          return;
        } else {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _lastScannedCode = null;
            });
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Voucher not found. Please verify the code or check if it was redeemed.',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.accentRose,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            );
          }
          return;
        }
      }

      // 2. Otherwise treat as Member Lookup for stamp awarding or enrollment
      // Parse potential QR payload: "cust-id|Customer Name|phone" or "cust-id" or phone
      String customerId = cleanQuery;
      String customerName = 'Member';
      String customerPhone = cleanQuery;

      if (cleanQuery.contains('|')) {
        final parts = cleanQuery.split('|');
        customerId = parts[0].trim();
        if (parts.length > 1 && parts[1].trim().isNotEmpty) customerName = parts[1].trim();
        if (parts.length > 2 && parts[2].trim().isNotEmpty) customerPhone = parts[2].trim();
      }

      // Check if customer is already an active member of THIS program
      MemberRecord? existingMember = db.findActiveMemberInProgram(
        query: customerId,
        programId: programId,
      );
      if (existingMember == null && customerPhone.isNotEmpty && customerPhone != customerId) {
        existingMember = db.findActiveMemberInProgram(
          query: customerPhone,
          programId: programId,
        );
      }

      if (existingMember != null) {
        // Customer is ALREADY a member -> Show bottomsheet to add stamps for customer
        if (mounted) {
          _showCustomerAwardBottomSheet(
            customerId: existingMember.customerId,
            customerName: existingMember.customerName,
            customerPhone: existingMember.customerPhone,
            currentStamps: existingMember.stampsCollected,
            targetProgram: targetProgram,
          );
        }
        return;
      }

      // Customer is NOT yet a member -> Resolve customer details
      final regUser = await db.findRegisteredCustomer(
        customerPhone.isNotEmpty ? customerPhone : (customerId.isNotEmpty ? customerId : cleanQuery),
      );

      if (regUser != null) {
        customerId = regUser['id']!;
        customerName = regUser['name']!;
        customerPhone = regUser['phone']!;
      } else if (providedName != null && providedName.trim().isNotEmpty) {
        customerName = providedName.trim();
      } else if (customerId.startsWith('cust-') && !customerId.contains(RegExp(r'^[0-9]+$'))) {
        final cleanId = customerId.replaceAll('cust-', '');
        customerName = cleanId.isNotEmpty ? cleanId[0].toUpperCase() + cleanId.substring(1) : 'Customer';
      } else if (customerName == 'Member' && customerPhone.isNotEmpty) {
        customerName = 'Customer';
      }

      if (mounted) {
        _showAddNewMemberBottomSheet(
          customerId: customerId,
          customerName: customerName,
          customerPhone: customerPhone,
          targetProgram: targetProgram,
        );
      }
    } catch (e) {
      debugPrint('Error in _handleScanOrInput: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    }
  }

  /// Shows the Voucher Approval BottomSheet with last customer transaction date
  void _showVoucherApprovalSheet(Voucher voucher) async {
    final db = context.read<MockDatabaseService>();

    // Resolve customer details
    final regUser = await db.findRegisteredCustomer(voucher.customerId);
    String custName = regUser?['name'] ?? '';
    String custPhone = regUser?['phone'] ?? '';

    if (custName.isEmpty) {
      final member = db.members.where((m) => m.customerId == voucher.customerId).firstOrNull;
      if (member != null) {
        custName = member.customerName;
        custPhone = member.customerPhone;
      }
    }
    if (custName.isEmpty) {
      custName = 'Member (${voucher.customerId})';
    }

    final txInfo = db.getLastCustomerTransaction(voucher.customerId, merchantId: widget.merchantId);
    final lastDate = txInfo['date'] as DateTime? ?? voucher.claimedAt;
    final lastNote = txInfo['description'] as String?;

    if (!mounted) return;

    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RewardConfirmBottomSheet(
        voucher: voucher,
        merchantId: widget.merchantId,
        customerName: custName,
        customerPhone: custPhone,
        lastTransactionDate: lastDate,
        lastTransactionNote: lastNote,
      ),
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }

    if (approved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Voucher Successfully Approved!',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                    ),
                    Text(
                      '${voucher.title} has been redeemed. The customer has received a notification.',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.accentEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.of(context).pop(); // Return to merchant home
    }
  }

  /// Bottom Sheet shown when scanned customer is NOT YET a member of this program
  void _showAddNewMemberBottomSheet({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required LoyaltyProgram targetProgram,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        bool addOneStamp = true; // default checked as requested: "add button check to add one stamp"
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: AppColors.primaryLight, width: 2),
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

                    // Header Icon & Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: AppColors.primaryLight,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enroll New Member',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Customer is not yet enrolled in this program',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'NEW MEMBER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Prompt question container: "Are you sure add [customerName] to member?"
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
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
                                decoration: const BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    customerName.isNotEmpty ? customerName[0].toUpperCase() : 'M',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      customerPhone.isNotEmpty ? customerPhone : 'ID: $customerId',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                              children: [
                                const TextSpan(text: 'Are you sure you want to add '),
                                TextSpan(
                                  text: customerName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryLight),
                                ),
                                const TextSpan(text: ' to loyalty program '),
                                TextSpan(
                                  text: targetProgram.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentEmerald),
                                ),
                                const TextSpan(text: '?'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Interactive check button to add one stamp
                    InkWell(
                      onTap: () => setSheetState(() => addOneStamp = !addOneStamp),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: addOneStamp
                              ? AppColors.accentEmerald.withValues(alpha: 0.12)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: addOneStamp
                                ? AppColors.accentEmerald.withValues(alpha: 0.5)
                                : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: addOneStamp ? AppColors.accentEmerald : Colors.transparent,
                                border: Border.all(
                                  color: addOneStamp ? AppColors.accentEmerald : AppColors.textMuted,
                                  width: 2,
                                ),
                              ),
                              child: addOneStamp
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Award +1 First Stamp Immediately',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentEmerald.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          '+1 STAMP',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.accentEmerald,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addOneStamp
                                        ? 'Customer immediately receives their first stamp (1/${targetProgram.totalStamps} stamps)'
                                        : 'Customer enrolled with 0 stamps',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: addOneStamp ? AppColors.accentEmerald : AppColors.textMuted,
                                      fontWeight: addOneStamp ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Confirm Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setSheetState(() => isSubmitting = true);
                                final db = context.read<MockDatabaseService>();
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);
                                final count = addOneStamp ? 1 : 0;

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
                                              count > 0
                                                  ? 'Successfully enrolled $customerName as a new member with +1 stamp!'
                                                  : 'Successfully enrolled $customerName as a new member!',
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
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.how_to_reg_rounded, size: 20),
                        label: Text(
                          isSubmitting
                              ? 'Enrolling Member...'
                              : (addOneStamp ? 'Yes, Enroll & Award 1 Stamp' : 'Yes, Enroll as Member'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentEmerald,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(bottomSheetCtx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Cancel'),
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

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  void _showCustomerAwardBottomSheet({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required int currentStamps,
    required LoyaltyProgram targetProgram,
  }) async {
    await showModalBottomSheet(
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

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
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
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (_isProcessing) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  if (_lastScannedCode == code &&
                      _lastScannedTime != null &&
                      DateTime.now().difference(_lastScannedTime!).inSeconds < 2) {
                    return;
                  }
                  _lastScannedCode = code;
                  _lastScannedTime = DateTime.now();
                  _handleScanOrInput(code);
                }
              }
            },
            placeholderBuilder: (context) => ColoredBox(
              color: Colors.black,
              child: Center(
                child: SizedBox(
                  width: 260,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Starting Camera...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Allow camera access if prompted by iOS or browser',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _restartScanner,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryLight),
                        label: const Text(
                          'Tap to restart camera',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            errorBuilder: (context, error) {
              final isDenied = error.errorCode == MobileScannerErrorCode.permissionDenied || _isCameraPermissionDenied;
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
                          isDenied ? 'Camera permission required' : 'Camera unavailable',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isDenied
                              ? 'Please enable camera access for Serbuin in iOS Settings or browser settings, then tap Retry.'
                              : (error.errorDetails?.message ?? error.errorCode.name),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _restartScanner,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry Camera'),
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

                      // Camera reload & Torch toggle buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              tooltip: 'Restart Camera',
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 19),
                              onPressed: _restartScanner,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              tooltip: 'Flash',
                              icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                              onPressed: () => _scannerController.toggleTorch(),
                            ),
                          ),
                        ],
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

/// Bottom Sheet for Manual Phone or Voucher Input
class _InputManualBottomSheet extends StatefulWidget {
  const _InputManualBottomSheet();

  @override
  State<_InputManualBottomSheet> createState() => _InputManualBottomSheetState();
}

class _InputManualBottomSheetState extends State<_InputManualBottomSheet> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    Navigator.of(context).pop({'phone': phone});
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
            'Enter customer phone number to look up their membership card, or enter voucher code (e.g. SRB-XXXXX).',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.text,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Phone Number or Voucher Code',
              hintText: 'e.g. 081234567890 or SRB-XXXXX',
              prefixIcon: Icon(Icons.dialpad_rounded, color: AppColors.primaryLight, size: 20),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search & Continue', style: TextStyle(fontWeight: FontWeight.w700)),
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
