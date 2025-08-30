import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_history_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../chat/pages/chat_page.dart';
import '../../chat/pages/new_chat_page.dart';
import '../../chat/widgets/model_selector_sheet.dart';
import '../../chat/widgets/chat_sidebar.dart';
import '../../profile/pages/profile_page.dart';
import '../../../shared/widgets/smooth_app_bar.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isForceUpdateRequired = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    
    // Initialize chat history
    ChatHistoryService.instance.initialize();
    
    // Check for app updates
    _checkForAppUpdate();
  }
  
  Future<void> _checkForAppUpdate() async {
    // Wait a bit before checking for updates to let the UI settle
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    try {
      final updateInfo = await AppUpdateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        if (updateInfo.isForceUpdate) {
          setState(() {
            _isForceUpdateRequired = true;
          });
        }
        AppUpdateService.showUpdateDialog(context, updateInfo);
      }
    } catch (e) {
      print('Error checking for app update: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;
    
    // If force update is required, show a blocking screen
    if (_isForceUpdateRequired) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.system_update,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Update Required',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please update the app to continue',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: ChatSidebar(
        onSessionSelected: (sessionId) async {
          // Switch to selected session - the ChatPage will listen for changes
          await ChatHistoryService.instance.switchToSession(sessionId);
        },
        onNewChat: () async {
          // Create new chat session - the ChatPage will listen for changes
          await ChatHistoryService.instance.createNewSession();
        },
      ),
      appBar: SmoothAppBar(
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: Icon(
            Icons.menu,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        title: Center(
          child: GestureDetector(
            onTap: () => _showModelSelector(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'अहम्',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: 'AI',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _showProfile(),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user?.name.isNotEmpty == true 
                      ? user!.name[0].toUpperCase() 
                      : 'U',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: const ChatPage(),
      ),
    );
  }

  void _showModelSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ModelSelectorBottomSheet(),
    );
  }

  void _showProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfilePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _startNewChat() async {
    // Create a new chat session
    await ChatHistoryService.instance.createNewSession();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New chat started'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 100, // Above input area
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}