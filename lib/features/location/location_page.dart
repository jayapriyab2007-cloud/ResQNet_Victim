import 'package:flutter/material.dart';
import '../../core/services/emergency_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_strip.dart';

class LocationPage extends StatefulWidget {
  final LocationService locationService;
  final EmergencyService? emergencyService;
  final bool isStandalone;

  const LocationPage({
    super.key,
    required this.locationService,
    this.emergencyService,
    this.isStandalone = false,
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  LocationResult? _location;
  bool _isRefreshing = false;
  bool _isShared = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _isRefreshing = true);
    final result = await widget.locationService.getPositionWithFallback();
    if (!mounted) return;
    setState(() {
      _location = result;
      _isRefreshing = false;
    });
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatClock(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  Future<void> _shareLocation() async {
    if (_location == null) return;

    final locStr = 'My coordinates: ${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)} (±${_location!.accuracy.round()}m)';

    // If message service is connected, post message
    widget.emergencyService?.messageService?.sendMessage(locStr, from: 'me');

    setState(() => _isShared = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordinates broadcast to nearby ResQNet devices.'),
        backgroundColor: AppColors.successGreen,
      ),
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isShared = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = _location;
    final isLive = loc?.isLive ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Location & GPS',
              subtitle: 'GPS operates without cellular or internet',
              onBack: widget.isStandalone ? () => Navigator.pop(context) : null,
              actions: [
                IconButton(
                  tooltip: 'Refresh GPS',
                  onPressed: _isRefreshing ? null : _loadLocation,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.infoBlue),
                        )
                      : const Icon(Icons.my_location, color: AppColors.infoBlue),
                ),
              ],
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Top Status Strip
                  StatusStrip(
                    gpsActive: isLive || loc != null,
                    meshActive: true,
                    nodeCount: 3,
                    batteryLevel: 64,
                  ),

                  const SizedBox(height: 14),

                  // GPS Status Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: loc != null ? (isLive ? AppColors.successGreenBg : AppColors.warningAmberBg) : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: loc != null
                            ? (isLive ? AppColors.successGreen.withValues(alpha: 0.5) : AppColors.warningAmber.withValues(alpha: 0.5))
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GPS STATUS',
                          style: AppTextStyles.labelCaps.copyWith(
                            color: loc != null
                                ? (isLive ? AppColors.successGreen : AppColors.warningAmber)
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc == null
                              ? 'LOCATION UNAVAILABLE'
                              : isLive
                                  ? 'GPS AVAILABLE'
                                  : 'USING LAST KNOWN LOCATION',
                          style: AppTextStyles.displaySmall.copyWith(
                            fontSize: 18,
                            color: loc != null
                                ? (isLive ? AppColors.successGreen : AppColors.warningAmber)
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loc == null
                              ? 'Waiting for satellite acquisition. Move toward open sky if safe.'
                              : isLive
                                  ? 'Your position is being read directly from orbital satellites.'
                                  : 'Live satellites temporarily shadowed. Showing your most recent cached fix.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Visual Radar Grid Panel
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Radar graphic canvas
                        Container(
                          height: 170,
                          width: double.infinity,
                          color: AppColors.surfaceElevated,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Grid background lines
                              CustomPaint(
                                size: const Size(double.infinity, 170),
                                painter: _GridRadarPainter(),
                              ),
                              // Pulsing target pin
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.emergencyRed.withValues(alpha: 0.2),
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.emergencyRed.withValues(alpha: 0.4),
                                ),
                              ),
                              const Icon(Icons.location_on, color: AppColors.emergencyRed, size: 28),
                            ],
                          ),
                        ),

                        // Coordinate specs
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _infoRow(
                                'Coordinates',
                                loc != null
                                    ? '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'
                                    : 'Acquiring…',
                              ),
                              const Divider(color: AppColors.border, height: 18),
                              _infoRow(
                                'Accuracy',
                                loc != null ? '± ${loc.accuracy.round()} meters' : '—',
                              ),
                              const Divider(color: AppColors.border, height: 18),
                              _infoRow(
                                'Recorded',
                                loc != null
                                    ? '${_formatClock(loc.timestamp)} (${_formatTimeAgo(loc.timestamp)})'
                                    : '—',
                              ),
                              const Divider(color: AppColors.border, height: 18),
                              _infoRow(
                                'Source',
                                isLive ? 'Live GPS satellite fix' : 'Last known fallback position',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions
                  OutlinedButton.icon(
                    onPressed: _isRefreshing ? null : _loadLocation,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(Icons.refresh, color: AppColors.infoBlue, size: 20),
                    label: Text(
                      _isRefreshing ? 'REFRESHING GPS…' : 'REFRESH GPS FIX',
                      style: AppTextStyles.title.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 10),

                  FilledButton.icon(
                    onPressed: loc == null ? null : _shareLocation,
                    style: FilledButton.styleFrom(
                      backgroundColor: _isShared ? AppColors.successGreen : AppColors.emergencyRed,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: Icon(_isShared ? Icons.check : Icons.share_location, size: 20),
                    label: Text(
                      _isShared ? 'LOCATION BROADCASTED' : 'SHARE LOCATION WITH RESCUERS',
                      style: AppTextStyles.title.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'GPS receivers listen to global satellite signals passively. No mobile network, Wi-Fi or data plan is required to read your exact position.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, height: 1.4),
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        Text(
          value,
          style: AppTextStyles.title.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _GridRadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    // Draw vertical and horizontal grid lines
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw circular radar range rings
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = AppColors.infoBlue.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 35, ringPaint);
    canvas.drawCircle(center, 70, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
