import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/mock_database_service.dart';
import '../../theme/app_theme.dart';
import 'customer_card_detail_view.dart';
import 'customer_profile_view.dart';
import 'customer_qr_bottomsheet.dart';
import 'customer_vouchers_view.dart';

class CustomerHomeView extends StatefulWidget {
  final AppUser user;

  const CustomerHomeView({super.key, required this.user});

  @override
  State<CustomerHomeView> createState() => _CustomerHomeViewState();
}

class _CustomerHomeViewState extends State<CustomerHomeView> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  final Map<String, int> _previousCardStamps = {};
  String? _lastStampedCardId;
  final Set<String> _previouslyRedeemedVouchers = {};
  bool _isFirstVoucherCheck = true;
  final bool _showJoinMorePrograms = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openQrBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerQrBottomSheet(user: widget.user),
    );
  }

  void _openVouchersView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerVouchersView(customerId: widget.user.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<MockDatabaseService>();

    // Vouchers counter badge
    final customerVouchers = db.vouchers
        .where((v) => v.customerId == widget.user.id && !v.isRedeemed && DateTime.now().isBefore(v.expiresAt))
        .toList();
    final voucherCount = customerVouchers.length;

    // Detect voucher redeemed in real-time
    final allUserVouchers = db.vouchers.where((v) => v.customerId == widget.user.id).toList();
    final redeemedUserVouchers = allUserVouchers.where((v) => v.isRedeemed).toList();
    final currentRedeemedVoucherIds = redeemedUserVouchers.map((v) => v.id).toSet();

    if (!_isFirstVoucherCheck) {
      for (final v in redeemedUserVouchers) {
        if (!_previouslyRedeemedVouchers.contains(v.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                            'Voucher Successfully Redeemed',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                          ),
                          Text(
                            '${v.title} has been successfully redeemed.',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
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
          });
          break;
        }
      }
    }
    _previouslyRedeemedVouchers.clear();
    _previouslyRedeemedVouchers.addAll(currentRedeemedVoucherIds);
    _isFirstVoucherCheck = false;

    // Member records for this customer (matched by customerId, phone, email, or name)
    final cleanUserPhone = normalizePhoneNumber(widget.user.phone);
    final cleanUserEmail = widget.user.email.trim().toLowerCase();
    final cleanUserName = widget.user.name.trim().toLowerCase();

    var memberRecords = db.members.where((m) {
      if (m.customerId == widget.user.id) return true;
      if (cleanUserEmail.isNotEmpty && m.customerEmail.trim().toLowerCase() == cleanUserEmail) return true;
      if (cleanUserPhone.length >= 6) {
        final cleanMemberPhone = normalizePhoneNumber(m.customerPhone);
        if (cleanMemberPhone.isNotEmpty &&
            (cleanMemberPhone.endsWith(cleanUserPhone) || cleanUserPhone.endsWith(cleanMemberPhone))) {
          return true;
        }
      }
      if (cleanUserName.isNotEmpty && m.customerName.trim().toLowerCase() == cleanUserName) return true;
      return false;
    }).toList();

    // Detect any new stamps and record the stamped card
    for (final card in memberRecords) {
      final prev = _previousCardStamps[card.id];
      if (prev != null && card.stampsCollected > prev) {
        final diff = card.stampsCollected - prev;
        _lastStampedCardId = card.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.accentAmber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '+$diff Stamp${diff > 1 ? 's' : ''} Received!',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          '${card.stampsCollected}/${card.totalStampsRequired} stamps on ${card.programTitle}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        });
      } else if (prev == null && _previousCardStamps.isNotEmpty) {
        _lastStampedCardId = card.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.card_membership_rounded, color: AppColors.accentEmerald, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Loyalty Card Added!',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          '${card.programTitle} • ${card.stampsCollected}/${card.totalStampsRequired} stamps',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.accentEmerald, width: 1.5),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        });
      }
      _previousCardStamps[card.id] = card.stampsCollected;
    }

    // Sort cards so the card that last received a stamp is always on top (index 0)
    memberRecords.sort((a, b) {
      if (a.id == _lastStampedCardId) return -1;
      if (b.id == _lastStampedCardId) return 1;
      return b.lastStampDate.compareTo(a.lastStampDate);
    });

    // Search filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      memberRecords = memberRecords.where((m) {
        return m.programTitle.toLowerCase().contains(query);
      }).toList();
    }

    // Status filter
    if (_selectedStatus != 'All') {
      memberRecords = memberRecords.where((m) {
        return m.status.toLowerCase() == _selectedStatus.toLowerCase();
      }).toList();
    }

    // Customer activities (matched by userId or matched program activities)
    final customerActivities = db.activities.where((a) {
      return a.userId == widget.user.id ||
          memberRecords.any((m) => a.subtitle.contains(m.programTitle));
    }).toList();

    // Programs available to join (no active card for customer)
    final activeProgramIds = memberRecords
        .where((m) => m.status == 'active')
        .map((m) => m.programId)
        .toSet();
    final customerMerchantIds = memberRecords.map((m) => m.merchantId).toSet();

    var joinablePrograms = db.programs.where((p) => p.isActive && !activeProgramIds.contains(p.id)).toList();
    joinablePrograms.sort((a, b) {
      final aHas = customerMerchantIds.contains(a.merchantId) ? 1 : 0;
      final bHas = customerMerchantIds.contains(b.merchantId) ? 1 : 0;
      return bHas.compareTo(aHas);
    });

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await db.init();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Greeting & Action Buttons (QR & Voucher with badge)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()},',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // QR Button (opens profile QR)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 22),
                      tooltip: 'Show Member QR Code',
                      onPressed: _openQrBottomSheet,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Voucher Button with Notification Badge Counter
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.confirmation_num_rounded, color: AppColors.primaryLight, size: 22),
                          tooltip: 'My Vouchers',
                          onPressed: _openVouchersView,
                        ),
                      ),
                      if (voucherCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: AppColors.accentRose,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            child: Center(
                              child: Text(
                                '$voucherCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Profile Completion Reminder Banner
              if (!widget.user.isProfileComplete || widget.user.customerProfile == null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.secondary.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded, color: AppColors.primaryLight, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Complete Your Profile',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Unlock membership perks across top merchants!',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerProfileView(user: widget.user),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Complete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Search Field
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                  hintText: 'Search loyalty card or merchant...',
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 14),

              // Filter by Status Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Active', 'Completed', 'Expired'].map((status) {
                    final isSelected = _selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedStatus = status),
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
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 22),

              // Stacked List Loyalty Cards Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Loyalty Cards',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Sorted by Recent Activity',
                    style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stacked Cards Widget
              if (memberRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text('No loyalty cards found.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                _StackedCardsContainer(
                  memberRecords: memberRecords,
                  programs: db.programs,
                  onCardTap: (member, program) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerCardDetailView(member: member, program: program),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),

              // Available Programs to Join Section (Hidden for now as requested)
              if (_showJoinMorePrograms && joinablePrograms.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Join More Programs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${joinablePrograms.length} available',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: joinablePrograms.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final prog = joinablePrograms[index];
                      final isFromMyMerchant = customerMerchantIds.contains(prog.merchantId);
                      return Container(
                        width: 260,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isFromMyMerchant ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradientFromHex(prog.gradientColors),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.loyalty_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prog.title,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        prog.merchantName,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '🎁 ${prog.rewardTitle}',
                                    style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final newMem = await db.joinProgram(
                                      customerId: widget.user.id,
                                      programId: prog.id,
                                      customerName: widget.user.name,
                                      customerPhone: widget.user.phone,
                                      customerEmail: widget.user.email,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('🎉 Joined ${prog.title}! Added to your wallet.'),
                                          backgroundColor: AppColors.accentEmerald,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CustomerCardDetailView(member: newMem, program: prog),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentEmerald,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Join', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Recent Activities Section
              const Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              if (customerActivities.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('No recent activity yet.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                )
              else
                ...customerActivities.take(5).map((act) {
                  return _CustomerActivityTile(activity: act);
                }),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _StackedCardsContainer extends StatefulWidget {
  final List<MemberRecord> memberRecords;
  final List<LoyaltyProgram> programs;
  final void Function(MemberRecord member, LoyaltyProgram program) onCardTap;

  const _StackedCardsContainer({
    required this.memberRecords,
    required this.programs,
    required this.onCardTap,
  });

  @override
  State<_StackedCardsContainer> createState() => _StackedCardsContainerState();
}

class _StackedCardsContainerState extends State<_StackedCardsContainer>
    with SingleTickerProviderStateMixin {
  late List<MemberRecord> _cards;

  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;

  double _dragOffset = 0.0;
  bool _isShuffling = false;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.memberRecords);

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _swipeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_isShuffling && mounted) {
          setState(() {
            final topCard = _cards.removeAt(0);
            _cards.add(topCard);
            _dragOffset = 0.0;
            _isShuffling = false;
          });
          _swipeController.reset();
        }
      }
    });
  }

  bool _cardsOrderOrStampsChanged(
      List<MemberRecord> oldList, List<MemberRecord> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].id != newList[i].id ||
          oldList[i].stampsCollected != newList[i].stampsCollected ||
          oldList[i].status != newList[i].status) {
        return true;
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant _StackedCardsContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cardsOrderOrStampsChanged(oldWidget.memberRecords, widget.memberRecords)) {
      setState(() {
        _cards = List.from(widget.memberRecords);
        _dragOffset = 0.0;
      });
      _swipeController.reset();
    } else {
      // Sync any updated card metadata in-place without resetting swipe position
      final updatedMap = {for (final c in widget.memberRecords) c.id: c};
      setState(() {
        _cards = _cards.map((c) => updatedMap[c.id] ?? c).toList();
      });
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    // If dragged more than 40% of the screen width, trigger shuffle
    if (_cards.length > 1 && _dragOffset.abs() > screenWidth * 0.4) {
      _isShuffling = true;
      final direction = _dragOffset > 0 ? 1.0 : -1.0;
      _swipeAnimation =
          Tween<Offset>(
            begin: Offset(_dragOffset, 0),
            end: Offset(screenWidth * direction, 0),
          ).animate(
            CurvedAnimation(parent: _swipeController, curve: Curves.easeOut),
          );
      _swipeController.forward(from: 0);
    } else {
      _isShuffling = false;
      // Snap back
      _swipeAnimation =
          Tween<Offset>(
            begin: Offset(_dragOffset, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _swipeController,
              curve: Curves.easeOutBack,
            ),
          );
      _swipeController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _dragOffset = 0.0;
          });
        }
      });
    }
  }

  LoyaltyProgram _getProgramForCard(MemberRecord card) {
    return widget.programs.firstWhere(
      (p) => p.id == card.programId,
      orElse: () => LoyaltyProgram(
        id: card.programId,
        merchantId: card.merchantId,
        merchantName: 'Partner Merchant',
        title: card.programTitle,
        description: 'Digital Loyalty Program',
        category: 'Cafe',
        totalStamps: card.totalStampsRequired,
        rewardTitle: 'Reward Voucher',
        rewardDescription: 'Exclusive perk',
        gradientColors: ['#6366F1', '#A855F7'],
        iconName: 'coffee',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 310, // Reduced height to fix large gap below cards
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: List.generate(_cards.length, (index) {
              // Render from back to front
              final reverseIndex = _cards.length - 1 - index;
              final card = _cards[reverseIndex];
              final prog = _getProgramForCard(card);

              // Only show top 3 cards to prevent rendering issues and overlap
              if (reverseIndex > 2 && reverseIndex != _cards.length - 1) {
                return const SizedBox.shrink();
              }

              final isTopCard = reverseIndex == 0;

              // Calculate scale and offset based on reverseIndex
              final scale = 1.0 - (reverseIndex * 0.05);

              // To make background cards stick out from the TOP,
              // the front card (reverseIndex 0) should be pushed down the most.
              // If we show 3 cards, reverseIndex goes 0, 1, 2.
              final displayIndex = reverseIndex > 2 ? 2 : reverseIndex;
              final verticalOffset = (2 - displayIndex) * 16.0;

              // Wrap card widget to ignore taps on background cards
              Widget cardWidget = IgnorePointer(
                ignoring: !isTopCard,
                child: _StackedLoyaltyCardItem(
                  member: card,
                  program: prog,
                  isFront: isTopCard,
                  onTap: () => widget.onCardTap(card, prog),
                ),
              );

              if (isTopCard) {
                return AnimatedBuilder(
                  animation: _swipeController,
                  builder: (context, child) {
                    final currentOffset = _swipeController.isAnimating
                        ? _swipeAnimation.value.dx
                        : _dragOffset;

                    final rotation = currentOffset / 800; // Slight rotation

                    return Positioned(
                      top: verticalOffset,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: _onPanUpdate,
                        onHorizontalDragEnd: _onPanEnd,
                        onTap: () => widget.onCardTap(card, prog),
                        child: Transform.translate(
                          offset: Offset(currentOffset, 0),
                          child: Transform.rotate(angle: rotation, child: child),
                        ),
                      ),
                    );
                  },
                  child: cardWidget,
                );
              } else {
                // Background cards
                return Positioned(
                  top: verticalOffset,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    transform: Matrix4.diagonal3Values(scale, scale, 1.0),
                    transformAlignment: Alignment.topCenter,
                    child: cardWidget,
                  ),
                );
              }
            }),
          ),
        ),
        if (_cards.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.swipe_rounded, size: 14, color: AppColors.primaryLight),
              const SizedBox(width: 6),
              Text(
                'Swipe card horizontally to shuffle (${_cards.length} cards)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StackedLoyaltyCardItem extends StatelessWidget {
  final MemberRecord member;
  final LoyaltyProgram program;
  final bool isFront;
  final VoidCallback onTap;

  const _StackedLoyaltyCardItem({
    required this.member,
    required this.program,
    required this.isFront,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM');
    final isCompleted = member.status == 'completed';
    final isReadyToClaim = !isCompleted && member.stampsCollected >= member.totalStampsRequired;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.gradientFromHex(program.gradientColors),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.colorFromHex(program.gradientColors.first).withValues(alpha: isFront ? 0.4 : 0.2),
              blurRadius: isFront ? 22 : 12,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        program.category,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentEmerald,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 2),
                            Text('COMPLETED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                    ] else if (isFront) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 12, color: Colors.amberAccent),
                            SizedBox(width: 2),
                            Text('LATEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Last stamp: ${dateFormat.format(member.lastStampDate)}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              program.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              program.merchantName,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 18),

            // Visual Stamps Row
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: List.generate(program.totalStamps, (idx) {
                      final isEarned = idx < member.stampsCollected;
                      final isGiftSlot = idx == program.totalStamps - 1;

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          height: 32,
                          decoration: BoxDecoration(
                            color: isEarned ? Colors.white : Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isEarned ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Center(
                            child: isEarned
                                ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 16)
                                : isGiftSlot
                                    ? const Icon(Icons.card_giftcard_rounded, color: Colors.amberAccent, size: 15)
                                    : Text(
                                        '${idx + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reward Strip or Ready to Claim Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.accentEmerald.withValues(alpha: 0.35)
                    : isReadyToClaim
                        ? AppColors.accentEmerald.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: (isCompleted || isReadyToClaim) ? Border.all(color: Colors.white, width: 1.5) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.verified_rounded
                        : isReadyToClaim
                            ? Icons.celebration_rounded
                            : Icons.star_rounded,
                    color: isCompleted ? Colors.lightGreenAccent : Colors.amberAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCompleted
                          ? '✅ Completed: ${program.rewardTitle} Claimed'
                          : isReadyToClaim
                              ? '🎉 Ready to Claim: ${program.rewardTitle}!'
                              : 'Reward: ${program.rewardTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white),
                ],
              ),
            ),
            if (program.termsAndConditions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 12, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'T&C: ${program.termsAndConditions}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerActivityTile extends StatelessWidget {
  final ActivityLog activity;

  const _CustomerActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, HH:mm');

    IconData icon = Icons.loyalty_rounded;
    Color iconColor = AppColors.primaryLight;
    if (activity.type == 'voucher_claimed' || activity.type == 'voucher_redeemed') {
      icon = Icons.confirmation_num_rounded;
      iconColor = AppColors.accentEmerald;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  activity.subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            dateFormat.format(activity.timestamp),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
