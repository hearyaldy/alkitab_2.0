import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/devotional_model.dart';
import '../services/sharing_service.dart';

class EnhancedDevotionalCard extends StatefulWidget {
  final DevotionalModel devotional;
  final VoidCallback? onBookmark;
  final bool isBookmarked;
  final TextEditingController notesController;
  final Function(String) onNoteChanged;

  const EnhancedDevotionalCard({
    super.key,
    required this.devotional,
    this.onBookmark,
    required this.isBookmarked,
    required this.notesController,
    required this.onNoteChanged,
  });

  @override
  State<EnhancedDevotionalCard> createState() => _EnhancedDevotionalCardState();
}

class _EnhancedDevotionalCardState extends State<EnhancedDevotionalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isExpanded = false;
  double _fontSize = 16.0;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
  }

  void _adjustFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(12.0, 24.0);
    });
    HapticFeedback.selectionClick();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateString = '${now.day}/${now.month}/${now.year}';
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isDarkMode
                  ? [
                      const Color(0xFF1E293B),
                      const Color(0xFF334155),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF8FAFC),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: (_isDarkMode ? Colors.black : Colors.grey).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with gradient background
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isDarkMode
                          ? [
                              const Color(0xFF3B82F6),
                              const Color(0xFF1E40AF),
                            ]
                          : [
                              const Color(0xFF60A5FA),
                              const Color(0xFF3B82F6),
                            ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              dateString,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _adjustFontSize(-1),
                                icon: const Icon(Icons.text_decrease, color: Colors.white),
                                tooltip: 'Decrease font size',
                              ),
                              IconButton(
                                onPressed: () => _adjustFontSize(1),
                                icon: const Icon(Icons.text_increase, color: Colors.white),
                                tooltip: 'Increase font size',
                              ),
                              IconButton(
                                onPressed: _toggleExpanded,
                                icon: Icon(
                                  _isExpanded ? Icons.compress : Icons.expand,
                                  color: Colors.white,
                                ),
                                tooltip: _isExpanded ? 'Collapse' : 'Expand',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.devotional.title,
                        style: TextStyle(
                          fontSize: _fontSize + 6,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verse section with enhanced styling
                      if (widget.devotional.verseText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.primaryColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.format_quote,
                                    color: theme.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Scripture',
                                    style: TextStyle(
                                      fontSize: _fontSize - 2,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '"${widget.devotional.verseText!}"',
                                style: TextStyle(
                                  fontSize: _fontSize + 1,
                                  fontStyle: FontStyle.italic,
                                  height: 1.6,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              if (widget.devotional.verseReference != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '— ${widget.devotional.verseReference!}',
                                    style: TextStyle(
                                      fontSize: _fontSize - 1,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Content section
                      Text(
                        'Reflection',
                        style: TextStyle(
                          fontSize: _fontSize + 2,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.headlineSmall?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.devotional.content,
                        style: TextStyle(
                          fontSize: _fontSize,
                          height: 1.7,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),

                      // Reflection questions
                      if (widget.devotional.reflectionQuestions.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildSection(
                          'Reflection Questions',
                          Icons.quiz_outlined,
                          theme,
                          widget.devotional.reflectionQuestions
                              .map((q) => '• $q')
                              .join('\n\n'),
                        ),
                      ],

                      // Prayer section
                      const SizedBox(height: 32),
                      _buildSection(
                        'Prayer',
                        Icons.favorite_outline,
                        theme,
                        widget.devotional.prayer,
                      ),

                      // Notes section
                      const SizedBox(height: 32),
                      _buildNotesSection(theme),

                      // Action buttons
                      const SizedBox(height: 24),
                      _buildActionButtons(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, ThemeData theme, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: _fontSize + 1,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.headlineSmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.6,
              fontStyle: title == 'Prayer' ? FontStyle.italic : FontStyle.normal,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'My Notes',
                style: TextStyle(
                  fontSize: _fontSize + 1,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.headlineSmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.notesController,
            maxLines: _isExpanded ? 6 : 3,
            onChanged: widget.onNoteChanged,
            style: TextStyle(fontSize: _fontSize),
            decoration: InputDecoration(
              hintText: 'Write your thoughts, prayers, or reflections here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.onBookmark,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isBookmarked ? Colors.orange : theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
            ),
            label: Text(
              widget.isBookmarked ? 'Bookmarked' : 'Bookmark',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await SharingService.shareDevotional(widget.devotional);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: theme.primaryColor),
            ),
            icon: const Icon(Icons.share, size: 20),
            label: const Text(
              'Share',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}