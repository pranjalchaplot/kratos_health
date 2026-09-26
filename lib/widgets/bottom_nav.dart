import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/soma_provider.dart';
import '../theme/soma_theme.dart';
import 'quick_log_modal.dart';

/// Bottom navigation bar matching the Stitch design
class SomaBottomNav extends StatelessWidget {
  const SomaBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final currentIndex = provider.currentTabIndex;

    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: SomaColors.surface,
        border: Border(
          top: BorderSide(
            color: SomaColors.surfaceContainerHighest,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dashboard
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'DASHBOARD',
            isActive: currentIndex == 0,
            onTap: () => provider.setTab(0),
          ),
          // Logs
          _NavItem(
            icon: Icons.assignment_outlined,
            label: 'LOGS',
            isActive: currentIndex == 1,
            onTap: () => provider.setTab(1),
          ),
          // Center FAB
          _buildFAB(context),
          // Library / Analytics
          _NavItem(
            icon: Icons.analytics_outlined,
            label: 'ANALYTICS',
            isActive: currentIndex == 3,
            onTap: () => provider.setTab(3),
          ),
          // Profile
          _NavItem(
            icon: Icons.account_circle_outlined,
            label: 'PROFILE',
            isActive: currentIndex == 4,
            onTap: () => provider.setTab(4),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: GestureDetector(
        onTap: () => QuickLogModal.show(context),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: SomaColors.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(
              color: SomaColors.surface,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: SomaColors.primaryContainer.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: SomaColors.background,
            size: 30,
          ),
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
    final color = isActive
        ? SomaColors.primaryContainer
        : SomaColors.onSecondaryContainer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
                // Active dot indicator
                if (isActive)
                  Positioned(
                    bottom: -8,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: SomaColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
