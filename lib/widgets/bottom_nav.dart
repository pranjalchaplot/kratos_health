import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/soma_provider.dart';
import '../theme/soma_theme.dart';
import 'quick_log_modal.dart';

/// Elite Bottom Navigation Bar for SOMA with obsidian glass styling and micro-haptics
class SomaBottomNav extends StatelessWidget {
  const SomaBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final currentIndex = provider.currentTabIndex;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset * 0.5 : 8, top: 8),
      decoration: BoxDecoration(
        color: SomaColors.background.withValues(alpha: 0.88),
        border: const Border(
          top: BorderSide(
            color: SomaColors.cardBorder,
            width: 1,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dashboard Tab
                _NavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'DASHBOARD',
                  isActive: currentIndex == 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    provider.setTab(0);
                  },
                ),
                // Logs Tab
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'LOGS',
                  isActive: currentIndex == 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    provider.setTab(1);
                  },
                ),
                // Center Quick Log Floating Action Button
                _buildFAB(context),
                // Analytics Tab
                _NavItem(
                  icon: Icons.query_stats_rounded,
                  label: 'ANALYTICS',
                  isActive: currentIndex == 3,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    provider.setTab(3);
                  },
                ),
                // Profile Tab
                _NavItem(
                  icon: Icons.account_circle_outlined,
                  label: 'PROFILE',
                  isActive: currentIndex == 4,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    provider.setTab(4);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        QuickLogModal.show(context);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: SomaColors.primaryContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: SomaColors.background,
            width: 2.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: SomaColors.primaryGlow,
              blurRadius: 18,
              spreadRadius: 2,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: SomaColors.onPrimary,
          size: 26,
        ),
      ),
    );
  }
}

// Backwards compatibility alias
typedef KratosBottomNav = SomaBottomNav;

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = SomaColors.primaryContainer;
    final inactiveColor = SomaColors.onSecondaryContainer;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? SomaColors.surfaceContainerHigh.withValues(alpha: 0.6) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: SomaFonts.mono(
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.6,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
