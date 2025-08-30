import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/chat_history_service.dart';
import '../../../core/services/auth_service.dart';

class ChatSidebar extends StatefulWidget {
  final Function(String sessionId) onSessionSelected;
  final VoidCallback onNewChat;
  
  const ChatSidebar({
    super.key,
    required this.onSessionSelected,
    required this.onNewChat,
  });

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> with SingleTickerProviderStateMixin {
  final _historyService = ChatHistoryService.instance;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isLoadingMessages = false;
  
  // Animation controller for staggered list
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _historyService.addListener(_onHistoryChanged);
    _loadHistory();
    _searchController.addListener(_onSearchChanged);

    // Start the animation when the widget is built
    _listAnimationController.forward();
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _historyService.removeListener(_onHistoryChanged);
    _listAnimationController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    final newQuery = _searchController.text.toLowerCase();
    
    // Only update state if query actually changed
    if (_searchQuery != newQuery) {
      setState(() {
        _searchQuery = newQuery;
      });
      
      // Load all messages for deep search if query is not empty
      if (_searchQuery.isNotEmpty && !_isLoadingMessages) {
        _loadAllMessages();
      }
    }
  }
  
  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }
  
  Future<void> _loadHistory() async {
    await _historyService.loadSessions();
  }
  
  Future<void> _loadAllMessages() async {
    if (_isLoadingMessages) return;
    
    // Don't update state if not needed to prevent focus loss
    if (!mounted) return;
    
    // Update loading state without rebuilding if possible
    _isLoadingMessages = true;
    
    await _historyService.loadAllSessionMessages();
    
    if (mounted) {
      setState(() {
        _isLoadingMessages = false;
      });
      
      // Keep focus on search field
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && !_searchFocusNode.hasFocus) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
  
  String _truncateTitle(String title) {
    if (title.length <= 30) return title;
    return '${title.substring(0, 27)}...';
  }
  
  void _showSessionOptions(BuildContext context, ChatSession session) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Session title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                session.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            
            // Options
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: theme.colorScheme.onSurface,
              ),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, session);
              },
            ),
            ListTile(
              leading: Icon(
                session.isPinned ?? false
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                color: theme.colorScheme.onSurface,
              ),
              title: Text(session.isPinned ?? false ? 'Unpin' : 'Pin'),
              onTap: () async {
                Navigator.pop(context);
                await _historyService.togglePinSession(session.id);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Colors.red.withOpacity(0.7),
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Colors.red.withOpacity(0.7)),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Chat'),
                    content: const Text(
                      'Are you sure you want to delete this conversation?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await _historyService.deleteSession(session.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showRenameDialog(BuildContext context, ChatSession session) {
    final controller = TextEditingController(text: session.title);
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter new name',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
            ),
            maxLength: 50,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != session.title) {
                await _historyService.renameSession(session.id, newTitle);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;
    final allSessions = _historyService.sessions;
    final currentSessionId = _historyService.currentSessionId;
    
    // Filter sessions based on search query
    final sessions = _searchQuery.isEmpty
        ? allSessions
        : allSessions.where((session) {
            // Search in title
            if (session.title.toLowerCase().contains(_searchQuery)) {
              return true;
            }
            
            // Search in message content if available
            if (session.messages != null) {
              for (var message in session.messages!) {
                if (message.content.toLowerCase().contains(_searchQuery)) {
                  return true;
                }
              }
            }
            
            return false;
          }).toList();
    
    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with safe area padding
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12, // Add safe area + extra padding
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            child: Column(
              children: [
                // User info
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'User',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user?.email ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // New chat button - stylish gradient design
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          widget.onNewChat();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(25),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 20,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'New Chat',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Search bar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      _isLoadingMessages
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary.withOpacity(0.6),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.search,
                              size: 18,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                      const SizedBox(width: 8),
                                              Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: theme.textTheme.bodyMedium,
                            autofocus: false,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search chats and messages...',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onTap: () {
                              if (!_isSearching) {
                                setState(() {
                                  _isSearching = true;
                                });
                              }
                            },
                            onChanged: (value) {
                              // Search is handled by the listener
                            },
                          ),
                        ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 18,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _isSearching = false;
                            });
                          },
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Chat sessions list
          Expanded(
            child: _historyService.isLoading
                ? _SidebarShimmerList()
                : sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty 
                                  ? Icons.search_off 
                                  : Icons.chat_bubble_outline,
                              size: 48,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No chats found'
                                  : 'No conversations yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Start a new chat to begin',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isSelected = session.id == currentSessionId;
                          
                          // Staggered animation for each item
                          final animation = Tween<double>(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(
                            CurvedAnimation(
                              parent: _listAnimationController,
                              curve: Interval(
                                (1 / sessions.length) * index * 0.2, // Make stagger more subtle
                                1.0,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                          );

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.2, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: Dismissible(
                                key: Key(session.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red.withOpacity(0.1),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.withOpacity(0.7),
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Chat'),
                                      content: const Text(
                                        'Are you sure you want to delete this conversation?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (direction) {
                                  _historyService.deleteSession(session.id);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  child: Material(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                                                child: InkWell(
                                  onTap: () {
                                    widget.onSessionSelected(session.id);
                                    Navigator.pop(context);
                                  },
                                  onLongPress: () {
                                    _showSessionOptions(context, session);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (session.isPinned ?? false) ...[
                                              Icon(
                                                Icons.push_pin,
                                                size: 14,
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.7),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                _truncateTitle(session.title),
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? theme.colorScheme.primary
                                                      : theme.colorScheme.onSurface,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const SizedBox(width: 24),
                                                Text(
                                                  _formatDate(session.updatedAt),
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: theme.colorScheme.onSurface
                                                        .withOpacity(0.5),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                if (session.messageCount > 0) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '• ${session.messageCount} messages',
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      color: theme.colorScheme.onSurface
                                                          .withOpacity(0.5),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear History'),
                    content: const Text(
                      'Are you sure you want to delete all conversations? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await _historyService.clearAllSessions();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              icon: Icon(
                Icons.delete_sweep_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              label: Text(
                'Clear History',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 10, // Show a decent number of shimmer items
      itemBuilder: (context, index) {
        return const _ShimmerItem();
      },
    );
  }
}

class _ShimmerItem extends StatelessWidget {
  const _ShimmerItem();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerColor = theme.colorScheme.surfaceVariant.withOpacity(0.5);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 100,
            height: 12,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}