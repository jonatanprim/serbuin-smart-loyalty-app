import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class StackedCardWallet extends StatefulWidget {
  final List<LoyaltyProgram> cards;
  final void Function(LoyaltyProgram card)? onCardTap;

  const StackedCardWallet({
    super.key,
    required this.cards,
    this.onCardTap,
  });

  @override
  State<StackedCardWallet> createState() => _StackedCardWalletState();
}

class _StackedCardWalletState extends State<StackedCardWallet>
    with SingleTickerProviderStateMixin {
  late List<LoyaltyProgram> _cards;

  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;

  double _dragOffset = 0.0;
  bool _isShuffling = false;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.cards);

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
      List<LoyaltyProgram> oldList, List<LoyaltyProgram> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].id != newList[i].id ||
          oldList[i].totalStamps != newList[i].totalStamps ||
          oldList[i].isActive != newList[i].isActive ||
          oldList[i].memberCount != newList[i].memberCount ||
          oldList[i].title != newList[i].title ||
          oldList[i].rewardTitle != newList[i].rewardTitle) {
        return true;
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant StackedCardWallet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cardsOrderOrStampsChanged(oldWidget.cards, widget.cards)) {
      setState(() {
        _cards = List.from(widget.cards);
        _dragOffset = 0.0;
      });
      _swipeController.reset();
    } else {
      // Sync any updated card metadata in-place without resetting swipe position
      final updatedMap = {for (final c in widget.cards) c.id: c};
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

              // Wrap StampCardWidget to ignore taps on background cards
              Widget cardWidget = IgnorePointer(
                ignoring: !isTopCard,
                child: StampCardWidget(
                  card: card,
                  onTap: isTopCard && widget.onCardTap != null
                      ? () => widget.onCardTap!(card)
                      : null,
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
                        onTap: widget.onCardTap != null
                            ? () => widget.onCardTap!(card)
                            : null,
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

class StampCardWidget extends StatelessWidget {
  final LoyaltyProgram card;
  final VoidCallback? onTap;

  const StampCardWidget({
    super.key,
    required this.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.gradientFromHex(card.gradientColors);
    final primaryColor = AppColors.colorFromHex(card.gradientColors.first);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Category Pill & Active Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        card.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: card.isActive
                        ? AppColors.accentEmerald.withValues(alpha: 0.25)
                        : Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: card.isActive ? AppColors.accentEmerald : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: card.isActive ? AppColors.accentEmerald : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        card.isActive ? 'ACTIVE' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: card.isActive ? AppColors.accentEmerald : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Program Title
            Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),

            // Subtitle
            Text(
              '${card.totalStamps} Stamps Required • ${card.memberCount} Members joined',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 14),

            // Visual Stamp Grid Preview (shows up to 8 slots or all)
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: List.generate(
                      card.totalStamps > 8 ? 8 : card.totalStamps,
                      (idx) {
                        final isGift = idx == (card.totalStamps > 8 ? 7 : card.totalStamps - 1);
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 5),
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: isGift
                                  ? const Icon(
                                      Icons.card_giftcard_rounded,
                                      color: Colors.amberAccent,
                                      size: 14,
                                    )
                                  : Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Reward Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.amberAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reward: ${card.rewardTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
