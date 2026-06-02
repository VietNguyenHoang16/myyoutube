import 'package:flutter/material.dart';

class SkipButtons extends StatelessWidget {
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final bool disabled;

  const SkipButtons({
    super.key,
    required this.onSkipBack,
    required this.onSkipForward,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 16,
          bottom: 80,
          child: _buildButton(
            icon: Icons.replay_5,
            label: '1s',
            onTap: disabled ? null : onSkipBack,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 80,
          child: _buildButton(
            icon: Icons.forward_5,
            label: '1s',
            onTap: disabled ? null : onSkipForward,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? Colors.white : Colors.white38, size: 22),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
