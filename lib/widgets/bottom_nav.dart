import 'package:flutter/material.dart';
import '../theme/kratos_theme.dart';

/// Bottom navigation bar matching the Stitch design
class KratosBottomNav extends StatelessWidget {
  final int currentIndex;

  const KratosBottomNav({
    super.key,
    this.currentIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: KratosColors.surface,
        border: Border(
          top: BorderSide(
            color: KratosColors.surfaceContainerHighest,
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
            filled: true,
          ),
          // Logs
          _NavItem(
            icon: Icons.add_circle_outline,
            label: 'LOGS',
            isActive: currentIndex == 1,
          ),
          // Center FAB
          _buildFAB(),
          // Library
          _NavItem(
            icon: Icons.fitness_center,
            label: 'LIBRARY',
            isActive: currentIndex == 3,
          ),
          // Profile
          _NavItem(
            icon: Icons.account_circle_outlined,
            label: 'PROFILE',
            isActive: currentIndex == 4,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: KratosColors.primaryContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: KratosColors.surface,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: KratosColors.primaryContainer.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: KratosColors.background,
          size: 30,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool filled;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? KratosColors.primaryContainer
        : KratosColors.onSecondaryContainer;

    return Column(
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
                    color: KratosColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
