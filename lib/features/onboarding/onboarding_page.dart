import 'package:flutter/material.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class OnboardingPage extends StatefulWidget {
  final LocalStore store;
  final VoidCallback onFinished;

  const OnboardingPage({
    super.key,
    required this.store,
    required this.onFinished,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentIndex = 0;

  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      icon: Icons.wifi_off_rounded,
      title: 'Works with no network',
      body:
          'ResQNet operates when cellular towers fail, Wi-Fi is down, and Internet is cut off. Your phone communicates directly via local mesh.',
    ),
    _OnboardingStep(
      icon: Icons.hub_rounded,
      title: 'Nearby devices relay you',
      body:
          'Every ResQNet device near you securely relays your emergency alert. Each hop carries your distress signal closer to the rescue perimeter.',
    ),
    _OnboardingStep(
      icon: Icons.shield_rounded,
      title: 'Rescuers get your alert',
      body:
          'Once your packet reaches a gateway or command center, rescue teams receive your GPS coordinates, emergency type, and medical priority.',
    ),
  ];

  Future<void> _complete() async {
    await widget.store.setOnboarded(true);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.emergencyRed,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.emergency, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RESQNET',
                        style: AppTextStyles.labelCaps.copyWith(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _complete,
                    child: Text(
                      'Skip',
                      style: AppTextStyles.title.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Center Visual
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(step.icon, color: AppColors.infoBlue, size: 36),
              ),

              const SizedBox(height: 24),

              Text(
                step.title,
                style: AppTextStyles.displayLarge.copyWith(fontSize: 26, height: 1.2),
              ),

              const SizedBox(height: 12),

              Text(
                step.body,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 32),

              // Interactive Multi-Hop Relay Diagram
              _RelayDiagram(activeStep: _currentIndex),

              const Spacer(),

              // Step Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (idx) {
                  final active = idx == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 28 : 8,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? AppColors.emergencyRed : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Action Button
              FilledButton(
                onPressed: () {
                  if (_currentIndex == _steps.length - 1) {
                    _complete();
                  } else {
                    setState(() => _currentIndex++);
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppColors.emergencyRed,
                ),
                child: Text(
                  _currentIndex == _steps.length - 1 ? 'START USING RESQNET' : 'NEXT',
                  style: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String body;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _RelayDiagram extends StatelessWidget {
  final int activeStep;

  const _RelayDiagram({required this.activeStep});

  @override
  Widget build(BuildContext context) {
    const nodes = [
      (label: 'You', isSource: true),
      (label: 'Node 1', isSource: false),
      (label: 'Node 2', isSource: false),
      (label: 'Rescuer', isSource: false),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < nodes.length; i++) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0
                        ? AppColors.emergencyRedBg
                        : i == 3 && activeStep >= 2
                            ? AppColors.successGreenBg
                            : activeStep >= 1 && i <= 2
                                ? AppColors.infoBlueBg
                                : AppColors.surfaceElevated,
                    border: Border.all(
                      color: i == 0
                          ? AppColors.emergencyRed
                          : i == 3 && activeStep >= 2
                              ? AppColors.successGreen
                              : activeStep >= 1 && i <= 2
                                  ? AppColors.infoBlue
                                  : AppColors.border,
                      width: 1.8,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      i == 0
                          ? Icons.person
                          : i == 3
                              ? Icons.shield
                              : Icons.hub,
                      size: 18,
                      color: i == 0
                          ? AppColors.emergencyRed
                          : i == 3 && activeStep >= 2
                              ? AppColors.successGreen
                              : activeStep >= 1 && i <= 2
                                  ? AppColors.infoBlue
                                  : AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nodes[i].label,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (i < nodes.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
                  color: activeStep >= i ? AppColors.infoBlue : AppColors.border,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
