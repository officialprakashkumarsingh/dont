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
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + (_animationController.value * 0.2),
              child: Opacity(
                opacity: _animationController.value,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'AhamAI',
                        style: GoogleFonts.amaranth(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}