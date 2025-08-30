import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/maintenance_service.dart';

class MaintenancePage extends StatefulWidget {
  final MaintenanceInfo maintenanceInfo;
  
  const MaintenancePage({
    super.key,
    required this.maintenanceInfo,
  });

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _gearController;

  @override
  void initState() {
    super.initState();
    
    // Gear rotation animation only
    _gearController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    // Set system UI overlay style based on theme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      );
    });
  }

  @override
  void dispose() {
    _gearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          // Background pattern
          CustomPaint(
            painter: _MaintenancePatternPainter(
              color: theme.colorScheme.primary.withOpacity(0.05),
            ),
            child: Container(),
          ),
          
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated maintenance icon
                    _buildMaintenanceIcon(theme),
                    
                    const SizedBox(height: 32),
                    
                    // Title with iOS-style font
                    Text(
                      widget.maintenanceInfo.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Message
                    Container(
                      constraints: BoxConstraints(maxWidth: size.width * 0.8),
                      child: Text(
                        widget.maintenanceInfo.message,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                          height: 1.5,
                          fontWeight: FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Estimated time if available
                    if (widget.maintenanceInfo.estimatedEndTime != null) ...[
                      const SizedBox(height: 24),
                      _buildEstimatedTime(theme),
                    ],
                    
                    // Contact email if available
                    if (widget.maintenanceInfo.contactEmail != null) ...[
                      const SizedBox(height: 32),
                      _buildContactSection(theme),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceIcon(ThemeData theme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer circle
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),
        
        // Rotating gear
        RotationTransition(
          turns: _gearController,
          child: Icon(
            CupertinoIcons.gear_solid,
            size: 60,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
        ),
        
        // Center icon (no scaling animation)
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withOpacity(0.15),
          ),
          child: Icon(
            CupertinoIcons.wrench_fill,
            size: 40,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildEstimatedTime(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 18,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            'Estimated completion: ${widget.maintenanceInfo.estimatedEndTime}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Need help?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: widget.maintenanceInfo.contactEmail!),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Email copied to clipboard',
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark 
                        ? Colors.white 
                        : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(
                  bottom: 80,
                  left: 20,
                  right: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.mail,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.maintenanceInfo.contactEmail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for background pattern
class _MaintenancePatternPainter extends CustomPainter {
  final Color color;

  _MaintenancePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 30.0;
    const radius = 2.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MaintenancePatternPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}