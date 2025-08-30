import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../theme/providers/theme_provider.dart';
import '../../../core/services/model_service.dart';
import '../../../core/services/maintenance_service.dart';
import '../../auth/pages/auth_gate.dart';
import '../../maintenance/pages/maintenance_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000), // User requested 1 second
      vsync: this,
    );
    
    _animationController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load models in the background
    ModelService.instance.loadModels();
    
    // Check maintenance status
    final maintenanceInfo = await MaintenanceService.checkMaintenanceStatus();
    
    // Wait for animation and minimum splash duration
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      // Check if maintenance mode is active
      if (maintenanceInfo != null && maintenanceInfo.isMaintenanceMode) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => MaintenancePage(
              maintenanceInfo: maintenanceInfo,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        // No maintenance, proceed normally
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Theme.of(context) to ensure the splash screen respects the MaterialApp's theme.
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Stack(
        children: [
          // Dotted pattern background
          CustomPaint(
            painter: DottedPatternPainter(
              dotColor: colorScheme.onSurface.withOpacity(0.05),
              spacing: 20,
              dotRadius: 1.5,
            ),
            child: Container(),
          ),
          
          // Animated Triangle Logo
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(100, 100),
                      painter: TrianglePainter(
                        animation: _animationController.value,
                        color: colorScheme.primary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // AhamAI Logo Text
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _animationController.value,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'AhamAI',
                              style: GoogleFonts.roboto(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final double animation;
  final Color color;

  TrianglePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a more stylish triangle with gradient and shadow
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Add a subtle shadow for depth
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    final shadowPath = Path();

    // Define the three points of the triangle (more aesthetically pleasing proportions)
    final p1 = Offset(size.width / 2, size.height * 0.1); // Top point slightly lower
    final p2 = Offset(size.width * 0.85, size.height * 0.9); // Bottom-right
    final p3 = Offset(size.width * 0.15, size.height * 0.9); // Bottom-left

    // Calculate the total length of the triangle perimeter
    final l1 = (p2 - p1).distance; // top to bottom-right
    final l2 = (p3 - p2).distance; // bottom-right to bottom-left
    final l3 = (p1 - p3).distance; // bottom-left to top

    final totalLength = l1 + l2 + l3;

    // Determine how much of the path to draw based on animation
    final animatedLength = animation * totalLength;

    // Build the animated path
    // Draw first side (p1 to p2)
    if (animatedLength > 0) {
      final progress = (animatedLength.clamp(0, l1) / l1);
      final endPoint = p1 + (p2 - p1) * progress;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(endPoint.dx, endPoint.dy);
      
      // Shadow path
      shadowPath.moveTo(p1.dx, p1.dy);
      shadowPath.lineTo(endPoint.dx, endPoint.dy);
    }

    // Draw second side (p2 to p3)
    if (animatedLength > l1) {
      final lengthOnSide2 = (animatedLength - l1).clamp(0, l2);
      final progress = lengthOnSide2 / l2;
      final endPoint = p2 + (p3 - p2) * progress;
      path.moveTo(p2.dx, p2.dy);
      path.lineTo(endPoint.dx, endPoint.dy);
      
      // Shadow path
      shadowPath.moveTo(p2.dx, p2.dy);
      shadowPath.lineTo(endPoint.dx, endPoint.dy);
    }

    // Draw third side (p3 to p1)
    if (animatedLength > l1 + l2) {
      final lengthOnSide3 = (animatedLength - l1 - l2).clamp(0, l3);
      final progress = lengthOnSide3 / l3;
      final endPoint = p3 + (p1 - p3) * progress;
      path.moveTo(p3.dx, p3.dy);
      path.lineTo(endPoint.dx, endPoint.dy);
      
      // Shadow path
      shadowPath.moveTo(p3.dx, p3.dy);
      shadowPath.lineTo(endPoint.dx, endPoint.dy);
    }

    // Draw shadow first (behind the main triangle)
    canvas.drawPath(shadowPath, shadowPaint);
    
    // Create gradient effect for the main triangle
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color,
        color.withOpacity(0.7),
      ],
    );
    
    paint.shader = gradient.createShader(rect);
    
    // Draw the main triangle
    canvas.drawPath(path, paint);
    
    // Add a subtle inner glow effect when animation is complete
    if (animation > 0.95) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.1)
        ..style = PaintingStyle.fill;
      
      // Create a complete triangle path for the glow
      final glowPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      
      canvas.drawPath(glowPath, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TrianglePainter oldDelegate) {
    return animation != oldDelegate.animation || color != oldDelegate.color;
  }
}

// Custom painter for dotted pattern background
class DottedPatternPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double dotRadius;

  DottedPatternPainter({
    required this.dotColor,
    required this.spacing,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DottedPatternPainter oldDelegate) {
    return dotColor != oldDelegate.dotColor ||
        spacing != oldDelegate.spacing ||
        dotRadius != oldDelegate.dotRadius;
  }
}