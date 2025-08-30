import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedRobot extends StatefulWidget {
  final double size;
  final Color? color;
  
  const AnimatedRobot({
    super.key,
    this.size = 50,
    this.color,
  });

  @override
  State<AnimatedRobot> createState() => _AnimatedRobotState();
}

class _AnimatedRobotState extends State<AnimatedRobot>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _blinkController;
  late AnimationController _rotateController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _blinkAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    
    // Bounce animation
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));
    
    // Blink animation
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _blinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));
    
    // Rotate animation for antenna
    _rotateController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _rotateAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _bounceController.repeat(reverse: true);
    _rotateController.repeat(reverse: true);
    _startBlinking();
  }
  
  void _startBlinking() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 2 + math.Random().nextInt(3)));
      if (mounted) {
        await _blinkController.forward();
        await _blinkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _blinkController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? Theme.of(context).colorScheme.primary;
    final backgroundColor = primaryColor.withOpacity(0.1);
    
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bounceAnimation,
        _blinkAnimation,
        _rotateAnimation,
      ]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: RobotPainter(
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
              blinkValue: _blinkAnimation.value,
              antennaRotation: _rotateAnimation.value,
            ),
          ),
        );
      },
    );
  }
}

class RobotPainter extends CustomPainter {
  final Color primaryColor;
  final Color backgroundColor;
  final double blinkValue;
  final double antennaRotation;

  RobotPainter({
    required this.primaryColor,
    required this.backgroundColor,
    required this.blinkValue,
    required this.antennaRotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final headRadius = size.width * 0.35;
    
    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, size.width / 2, bgPaint);
    
    // Robot head (rounded rectangle with gradient effect)
    final headPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: headRadius * 1.6,
        height: headRadius * 1.8,
      ),
      Radius.circular(headRadius * 0.3),
    );
    canvas.drawRRect(headRect, headPaint);
    
    // Add subtle gradient overlay for depth
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.transparent,
          Colors.black.withOpacity(0.1),
        ],
      ).createShader(headRect.outerRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(headRect, gradientPaint);
    
    // Antenna
    canvas.save();
    canvas.translate(center.dx, center.dy - headRadius * 0.9);
    canvas.rotate(antennaRotation);
    
    final antennaPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, -headRadius * 0.3),
      antennaPaint,
    );
    
    // Antenna ball
    canvas.drawCircle(
      Offset(0, -headRadius * 0.3),
      3,
      Paint()..color = primaryColor,
    );
    
    canvas.restore();
    
    // Eyes with more detail
    final eyeRadius = headRadius * 0.18;
    final eyeY = center.dy - headRadius * 0.2;
    
    // Eye whites
    final eyeWhitePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    
    // Left eye white
    canvas.drawCircle(
      Offset(center.dx - headRadius * 0.35, eyeY),
      eyeRadius,
      eyeWhitePaint,
    );
    
    // Right eye white
    canvas.drawCircle(
      Offset(center.dx + headRadius * 0.35, eyeY),
      eyeRadius,
      eyeWhitePaint,
    );
    
    // Eye pupils (affected by blink)
    final pupilPaint = Paint()
      ..color = primaryColor.withOpacity(blinkValue)
      ..style = PaintingStyle.fill;
    
    final pupilRadius = eyeRadius * 0.5;
    
    // Left pupil
    canvas.drawCircle(
      Offset(center.dx - headRadius * 0.35, eyeY),
      pupilRadius,
      pupilPaint,
    );
    
    // Right pupil
    canvas.drawCircle(
      Offset(center.dx + headRadius * 0.35, eyeY),
      pupilRadius,
      pupilPaint,
    );
    
    // Eye sparkles
    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(0.8 * blinkValue)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(center.dx - headRadius * 0.35 + pupilRadius * 0.3, eyeY - pupilRadius * 0.3),
      2,
      sparklePaint,
    );
    
    canvas.drawCircle(
      Offset(center.dx + headRadius * 0.35 + pupilRadius * 0.3, eyeY - pupilRadius * 0.3),
      2,
      sparklePaint,
    );
    
    // Nose (more prominent and stylized)
    final nosePaint = Paint()
      ..color = primaryColor.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    final noseOutlinePaint = Paint()
      ..color = primaryColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    final noseY = center.dy + headRadius * 0.05;
    final nosePath = Path();
    nosePath.moveTo(center.dx, noseY - headRadius * 0.1);
    nosePath.lineTo(center.dx - headRadius * 0.1, noseY + headRadius * 0.06);
    nosePath.quadraticBezierTo(
      center.dx,
      noseY + headRadius * 0.1,
      center.dx + headRadius * 0.1,
      noseY + headRadius * 0.06,
    );
    nosePath.close();
    
    canvas.drawPath(nosePath, nosePaint);
    canvas.drawPath(nosePath, noseOutlinePaint);
    
    // Mouth (more expressive smile)
    final mouthPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    final mouthStrokePaint = Paint()
      ..color = primaryColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    final mouthY = center.dy + headRadius * 0.35;
    final mouthPath = Path();
    mouthPath.moveTo(center.dx - headRadius * 0.35, mouthY);
    mouthPath.quadraticBezierTo(
      center.dx,
      mouthY + headRadius * 0.25,
      center.dx + headRadius * 0.35,
      mouthY,
    );
    
    // Draw mouth outline (smile)
    canvas.drawPath(mouthPath, mouthStrokePaint);
    
    // Add teeth/tongue effect
    final teethPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    // Draw small teeth
    for (int i = -1; i <= 1; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx + i * headRadius * 0.15, mouthY + headRadius * 0.05),
            width: headRadius * 0.08,
            height: headRadius * 0.06,
          ),
          Radius.circular(2),
        ),
        teethPaint,
      );
    }
    
    // Body indicator dots
    final dotPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(
          center.dx - headRadius * 0.3 + (i * headRadius * 0.3),
          center.dy + headRadius * 0.7,
        ),
        2,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(RobotPainter oldDelegate) {
    return blinkValue != oldDelegate.blinkValue ||
        antennaRotation != oldDelegate.antennaRotation ||
        primaryColor != oldDelegate.primaryColor;
  }
}