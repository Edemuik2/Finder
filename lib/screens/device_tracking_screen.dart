import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bluetooth_device_model.dart';
import '../services/bluetooth_service.dart';

class DeviceTrackingScreen extends StatefulWidget {
  final BluetoothDeviceModel device;

  const DeviceTrackingScreen({
    super.key,
    required this.device,
  });

  @override
  State<DeviceTrackingScreen> createState() => _DeviceTrackingScreenState();
}

class _DeviceTrackingScreenState extends State<DeviceTrackingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _rssiSubscription;
  double _distance = 0.0;
  int _currentRssi = 0;
  bool _isTracking = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentRssi = widget.device.rssi;
    _distance = _calculateDistance(_currentRssi);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _startTracking();
  }

  @override
  void dispose() {
    _rssiSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTracking() {
    final service = context.read<BluetoothService>();

    _rssiSubscription =
        service.getRssiStream(widget.device.device).listen((rssi) {
      if (_isTracking && mounted) {
        setState(() {
          _currentRssi = rssi;
          _distance = _calculateDistance(rssi);
        });
      }
    });
  }

  double _calculateDistance(int rssi) {
    const measuredPower = -59.0;

    if (rssi == 0) {
      return -1.0;
    }

    final ratio = rssi / measuredPower;

    if (ratio < 1.0) {
      return math.pow(ratio, 10).toDouble();
    } else {
      return (0.89976) * math.pow(ratio, 7.7095) + 0.111;
    }
  }

  String _getDistanceText() {
    if (_distance < 0) return '?';
    if (_distance < 1.0) {
      final cm = (_distance * 100).round();
      return '$cm';
    }
    return _distance.toStringAsFixed(1);
  }

  String _getDistanceUnit() {
    if (_distance < 0) return '';
    if (_distance < 1.0) return 'см';
    return 'м';
  }

  String? _getProximityLabel() {
    if (_distance < 0) return null;
    if (_distance < 0.5) return 'HERE';
    if (_distance < 1.0) return 'NEARBY';
    return null;
  }

  Color _getDistanceColor() {
    if (_distance < 0) return Colors.grey;
    if (_distance < 0.5) return Colors.green;
    if (_distance < 1.0) return Colors.yellow;
    if (_distance < 3.0) return Colors.orange;
    return Colors.red;
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
    });
    _rssiSubscription?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackground(),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildTrackingContent(),
                ),
                _buildFoundButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: RadarPainter(
            animation: _pulseController.value,
            distance: _distance,
            color: _getDistanceColor(),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.device.deviceType.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            widget.device.deviceType.icon,
            style: const TextStyle(fontSize: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getDistanceColor().withOpacity(0.15),
                border: Border.all(
                  color: _getDistanceColor().withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _getDistanceText(),
                        key: ValueKey(_getDistanceText()),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: _getDistanceColor(),
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _getDistanceUnit(),
                        key: ValueKey(_getDistanceUnit()),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _getDistanceColor().withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: _getProximityLabel() != null
                ? Container(
                    key: ValueKey(_getProximityLabel()),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _getDistanceColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getDistanceColor().withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _getProximityLabel()!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getDistanceColor(),
                        letterSpacing: 2,
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('empty'),
                    height: 44,
                  ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.radar,
                  color: _getDistanceColor(),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Сигнал: $_currentRssi dBm',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundButton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _stopTracking,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Я нашел',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double animation;
  final double distance;
  final Color color;

  RadarPainter({
    required this.animation,
    required this.distance,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.4;

    for (int i = 0; i < 3; i++) {
      final progress = (animation + i / 3) % 1.0;
      final radius = maxRadius * progress;
      final opacity = (1.0 - progress) * 0.3;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.distance != distance ||
        oldDelegate.color != color;
  }
}
