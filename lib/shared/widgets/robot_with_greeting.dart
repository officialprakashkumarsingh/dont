import 'package:flutter/material.dart';
import 'animated_robot.dart';

class RobotWithGreeting extends StatefulWidget {
  final double size;
  final Color? color;
  
  const RobotWithGreeting({
    super.key,
    this.size = 80,
    this.color,
  });

  @override
  State<RobotWithGreeting> createState() => _RobotWithGreetingState();
}

class _RobotWithGreetingState extends State<RobotWithGreeting>
    with SingleTickerProviderStateMixin {
  late AnimationController _bubbleController;
  late Animation<double> _bubbleAnimation;
  late Animation<double> _fadeAnimation;
  String _greeting = '';
  String _timeOfDay = '';
  
  @override
  void initState() {
    super.initState();
    _setGreeting();
    
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _bubbleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bubbleController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
    
    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _bubbleController.forward();
      }
    });
  }
  
  void _setGreeting() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 12) {
      _timeOfDay = 'morning';
      _greeting = 'Good morning! ☀️';
    } else if (hour >= 12 && hour < 17) {
      _timeOfDay = 'afternoon';
      _greeting = 'Good afternoon! 🌤️';
    } else if (hour >= 17 && hour < 21) {
      _timeOfDay = 'evening';
      _greeting = 'Good evening! 🌅';
    } else {
      _timeOfDay = 'night';
      _greeting = 'Good night! 🌙';
    }
  }
  
  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speech bubble
        AnimatedBuilder(
          animation: _bubbleController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _bubbleAnimation.value,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Bubble tail
                      Positioned(
                        bottom: -5,
                        child: CustomPaint(
                          size: const Size(20, 10),
                          painter: BubbleTailPainter(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          ),
                        ),
                      ),
                      // Bubble body
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _greeting,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ready to start a conversation?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        
        // Robot
        AnimatedRobot(
          size: widget.size,
          color: widget.color ?? Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

class BubbleTailPainter extends CustomPainter {
  final Color color;
  
  BubbleTailPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(BubbleTailPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}