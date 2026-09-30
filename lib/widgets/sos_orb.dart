import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class SosOrb extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final bool isSosActive;

  const SosOrb({
    super.key,
    required this.onTap,
    this.size = 210,
    this.isSosActive = false,
  });

  @override
  State<SosOrb> createState() => _SosOrbState();
}

class _SosOrbState extends State<SosOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.45).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbSize = widget.size;

    return Center(
      child: SizedBox(
        width: orbSize * 1.45,
        height: orbSize * 1.45,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Pulsing Ring
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: orbSize,
                      height: orbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isSosActive
                            ? AppColors.emergencyRed
                            : AppColors.emergencyRed.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Secondary Glow Shadow
            Container(
              width: orbSize + 16,
              height: orbSize + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emergencyRed.withValues(alpha: 0.35),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),

            // Main Interactive SOS Orb
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: widget.onTap,
                customBorder: const CircleBorder(),
                splashColor: Colors.white24,
                highlightColor: Colors.black26,
                child: Ink(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.sosGradient,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 2),
                        const Text('SOS', style: AppTextStyles.sosText),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.isSosActive ? 'RELAYING' : 'ALERT',
                            style: AppTextStyles.labelCaps.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
