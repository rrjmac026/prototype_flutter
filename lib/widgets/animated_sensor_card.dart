import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedSensorCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool isOnline;
  final String type;
  final double percentage;

  const AnimatedSensorCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.isOnline,
    required this.type,
    required this.percentage,
  }) : super(key: key);

  @override
  State<AnimatedSensorCard> createState() => _AnimatedSensorCardState();
}

class _AnimatedSensorCardState extends State<AnimatedSensorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(8), // Reduced padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.color.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            // Background animation layer
            if (widget.isOnline) 
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildAnimation(),
                ),
              ),
            
            // Content layer with flexible layout
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with flexible sizing
                Flexible(
                  flex: 2,
                  child: Icon(
                    widget.icon, 
                    size: 24, // Reduced size
                    color: widget.isOnline ? widget.color : Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 4), // Reduced spacing
                
                // Title with flexible text handling
                Flexible(
                  flex: 2,
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 10, // Reduced font size
                      fontWeight: FontWeight.w600,
                      color: widget.isOnline 
                        ? Theme.of(context).textTheme.bodyMedium?.color
                        : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                const SizedBox(height: 2), // Reduced spacing
                
                // Value with flexible sizing
                Flexible(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.value,
                      style: TextStyle(
                        fontSize: 16, // Reduced font size
                        fontWeight: FontWeight.bold,
                        color: widget.isOnline ? widget.color : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Offline overlay
            if (!widget.isOnline)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          color: Colors.white,
                          size: 20, // Reduced size
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'OFFLINE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10, // Reduced font size
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    switch (widget.type) {
      case 'moisture':
        return _buildWaterAnimation();
      case 'temperature':
        return _buildTemperatureAnimation();
      case 'humidity':
        return _buildHumidityAnimation();
      case 'status':
        return _buildStatusAnimation();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWaterAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: WaterPainter(
            animation: _controller,
            fillPercent: (widget.percentage / 100).clamp(0.0, 1.0),
            color: widget.color,
          ),
        );
      },
    );
  }

  Widget _buildTemperatureAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: TemperaturePainter(
            animation: _controller,
            fillPercent: (widget.percentage / 100).clamp(0.0, 1.0),
            color: widget.color,
          ),
        );
      },
    );
  }

  Widget _buildHumidityAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: HumidityPainter(
            animation: _controller,
            fillPercent: (widget.percentage / 100).clamp(0.0, 1.0),
            color: widget.color,
          ),
        );
      },
    );
  }

  Widget _buildStatusAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: StatusPainter(
            animation: _controller,
            fillPercent: (widget.percentage / 100).clamp(0.0, 1.0),
            color: widget.color,
          ),
        );
      },
    );
  }
}

class WaterPainter extends CustomPainter {
  final Animation<double> animation;
  final double fillPercent;
  final Color color;

  WaterPainter({
    required this.animation,
    required this.fillPercent,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 6.0;
    final waveFrequency = 2.0;
    final y = size.height * (1 - fillPercent * 0.8) + size.height * 0.1;

    path.moveTo(0, size.height);
    
    for (var i = 0.0; i <= size.width; i += 2) {
      final normalizedX = i / size.width;
      final waveY = y + math.sin((normalizedX * waveFrequency + animation.value) * math.pi * 2) * waveHeight * fillPercent;
      path.lineTo(i, waveY.clamp(0.0, size.height));
    }
    
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Add subtle wave lines
    final wavePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final wavePath = Path();
    for (var i = 0.0; i <= size.width; i += 2) {
      final normalizedX = i / size.width;
      final waveY = y + math.sin((normalizedX * waveFrequency + animation.value) * math.pi * 2) * waveHeight * fillPercent;
      if (i == 0) {
        wavePath.moveTo(i, waveY.clamp(0.0, size.height));
      } else {
        wavePath.lineTo(i, waveY.clamp(0.0, size.height));
      }
    }
    
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TemperaturePainter extends CustomPainter {
  final Animation<double> animation;
  final double fillPercent;
  final Color color;

  TemperaturePainter({
    required this.animation,
    required this.fillPercent,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final center = Offset(size.width / 2, size.height * 0.8);
    final flameHeight = size.height * 0.7 * fillPercent;
    
    // Draw multiple flame layers for realistic fire effect
    _drawFlameLayer(canvas, size, center, flameHeight, Colors.red.withOpacity(0.3), 1.0, 0.8);
    _drawFlameLayer(canvas, size, center, flameHeight * 0.8, Colors.orange.withOpacity(0.4), 1.2, 0.6);
    _drawFlameLayer(canvas, size, center, flameHeight * 0.6, Colors.yellow.withOpacity(0.5), 1.5, 0.4);
    
    // Add sparks/embers
    _drawSparks(canvas, size, center, flameHeight);
  }
  
  void _drawFlameLayer(Canvas canvas, Size size, Offset center, double height, Color flameColor, double frequency, double amplitude) {
    final paint = Paint()
      ..color = flameColor
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final baseWidth = size.width * 0.3;
    
    // Start from the base of the flame
    path.moveTo(center.dx - baseWidth / 2, center.dy);
    
    // Draw flame shape with animated flickering
    for (var i = 0; i <= 20; i++) {
      final t = i / 20.0;
      final y = center.dy - height * t;
      
      // Create flame width that narrows towards the tip
      final flameWidth = baseWidth * (1 - t * 0.8);
      
      // Add flickering effect with multiple sine waves
      final flicker1 = math.sin((animation.value * frequency + t * 3) * math.pi * 2) * amplitude * flameWidth * 0.1;
      final flicker2 = math.sin((animation.value * frequency * 1.7 + t * 2) * math.pi * 2) * amplitude * flameWidth * 0.05;
      final totalFlicker = flicker1 + flicker2;
      
      if (i == 0) {
        path.lineTo(center.dx - flameWidth / 2, y);
      } else {
        path.lineTo(center.dx - flameWidth / 2 + totalFlicker, y);
      }
    }
    
    // Draw the tip of the flame
    path.lineTo(center.dx, center.dy - height);
    
    // Draw the right side of the flame
    for (var i = 20; i >= 0; i--) {
      final t = i / 20.0;
      final y = center.dy - height * t;
      final flameWidth = baseWidth * (1 - t * 0.8);
      
      final flicker1 = math.sin((animation.value * frequency + t * 3) * math.pi * 2) * amplitude * flameWidth * 0.1;
      final flicker2 = math.sin((animation.value * frequency * 1.7 + t * 2) * math.pi * 2) * amplitude * flameWidth * 0.05;
      final totalFlicker = flicker1 + flicker2;
      
      path.lineTo(center.dx + flameWidth / 2 + totalFlicker, y);
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }
  
  void _drawSparks(Canvas canvas, Size size, Offset center, double flameHeight) {
    final sparkPaint = Paint()
      ..color = Colors.orange.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    // Draw animated sparks
    for (var i = 0; i < 6; i++) {
      final sparkProgress = (animation.value + i * 0.3) % 1.0;
      final sparkX = center.dx + (math.sin(i * 0.7) * size.width * 0.2);
      final sparkY = center.dy - flameHeight * (0.3 + sparkProgress * 0.7);
      final sparkSize = (1 - sparkProgress) * 3 * fillPercent;
      
      if (sparkSize > 0.5) {
        canvas.drawCircle(Offset(sparkX, sparkY), sparkSize, sparkPaint);
      }
    }
    
    // Add smaller ember particles
    final emberPaint = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    for (var i = 0; i < 4; i++) {
      final emberProgress = (animation.value * 0.7 + i * 0.25) % 1.0;
      final emberX = center.dx + (math.cos(i * 1.2 + animation.value) * size.width * 0.15);
      final emberY = center.dy - flameHeight * (0.1 + emberProgress * 0.5);
      final emberSize = (1 - emberProgress) * 2 * fillPercent;
      
      if (emberSize > 0.3) {
        canvas.drawCircle(Offset(emberX, emberY), emberSize, emberPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HumidityPainter extends CustomPainter {
  final Animation<double> animation;
  final double fillPercent;
  final Color color;

  HumidityPainter({
    required this.animation,
    required this.fillPercent,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw animated water droplets
    for (var i = 0; i < 5; i++) {
      final progress = (animation.value + i * 0.2) % 1.0;
      final x = size.width * 0.2 + (size.width * 0.6) * (i / 4);
      final y = size.height * 0.2 + progress * size.height * 0.6;
      final dropSize = 4 + fillPercent * 6;
      
      final dropOpacity = math.sin(progress * math.pi) * 0.6;
      paint.color = color.withOpacity(dropOpacity);
      
      // Draw teardrop shape
      final dropPath = Path();
      dropPath.addOval(Rect.fromCenter(
        center: Offset(x, y),
        width: dropSize,
        height: dropSize * 1.2,
      ));
      
      canvas.drawPath(dropPath, paint);
    }
    
    // Add mist effect at bottom
    final mistPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    final mistHeight = size.height * 0.3 * fillPercent;
    final mistRect = Rect.fromLTWH(0, size.height - mistHeight, size.width, mistHeight);
    canvas.drawRect(mistRect, mistPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StatusPainter extends CustomPainter {
  final Animation<double> animation;
  final double fillPercent;
  final Color color;

  StatusPainter({
    required this.animation,
    required this.fillPercent,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.35;
    
    // Draw pulsing rings
    for (var i = 0; i < 3; i++) {
      final progress = (animation.value + i * 0.33) % 1.0;
      final radius = maxRadius * progress * fillPercent;
      final strokeWidth = 2.0 * (1 - progress);
      final opacity = (1 - progress) * 0.5;
      
      if (strokeWidth > 0.1) {
        final paint = Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
        
        canvas.drawCircle(center, radius, paint);
      }
    }
    
    // Draw center indicator
    final centerPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}