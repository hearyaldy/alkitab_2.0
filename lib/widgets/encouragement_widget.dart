// lib/widgets/encouragement_widget.dart

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/encouragement_service.dart';

class EncouragementWidget extends StatefulWidget {
  const EncouragementWidget({super.key});

  @override
  State<EncouragementWidget> createState() => _EncouragementWidgetState();
}

class _EncouragementWidgetState extends State<EncouragementWidget> {
  final EncouragementService _encouragementService = EncouragementService();
  EncouragementMessage? _currentMessage;
  bool _showFeelingSelector = false;
  bool _isExpanded = false;
  Map<Feeling, int> _feelingCounts = {};
  List<MapEntry<Feeling, int>> _top3Feelings = [];

  @override
  void initState() {
    super.initState();
    _loadDailyEncouragement();
    _loadFeelingCounts();
  }

  void _loadDailyEncouragement() {
    setState(() {
      _currentMessage = _encouragementService.getDailyEncouragement();
      _showFeelingSelector = false;
    });
  }

  Future<void> _loadFeelingCounts() async {
    final counts = await _encouragementService.getAllFeelingCounts();
    final top3 = await _encouragementService.getTop3Feelings();
    setState(() {
      _feelingCounts = counts;
      _top3Feelings = top3;
    });
  }

  Future<void> _showFeelingBasedEncouragement(Feeling feeling) async {
    // Record the feeling selection
    await _encouragementService.recordFeelingSelection(feeling);

    final message = _encouragementService.getRandomEncouragementForFeeling(feeling);
    if (message != null) {
      setState(() {
        _currentMessage = message;
        _showFeelingSelector = false;
      });

      // Reload counts to show updated numbers
      await _loadFeelingCounts();
    }
  }

  void _shareEncouragement() {
    if (_currentMessage != null) {
      final content = '''
🙏 ${_currentMessage!.title}

"${_currentMessage!.verse}"
- ${_currentMessage!.reference}

${_currentMessage!.message}

Dikongsi dari Alkitab 2.0
''';
      SharePlus.instance.share(ShareParams(text: content));
    }
  }

  Future<void> _showResetConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Perasaan'),
        content: const Text('Adakah anda pasti mahu reset semua kiraan perasaan? Tindakan ini tidak boleh dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _encouragementService.resetAllFeelingCounts();
      await _loadFeelingCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua kiraan perasaan telah direset'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMessage == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade50,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Galakan Harian',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.indigo.shade600,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  ),
                ],
              ),

              // Content
              if (_isExpanded) ...[
                const SizedBox(height: 12),

                // Title
                Text(
                  _currentMessage!.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 12),

                // Bible Verse
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"${_currentMessage!.verse}"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '- ${_currentMessage!.reference}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Encouragement Message
                Text(
                  _currentMessage!.message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Top 3 Feelings Section
                if (_top3Feelings.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Perasaan Anda Yang Paling Kerap:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showResetConfirmation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      size: 14,
                                      color: Colors.red.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _top3Feelings.map((entry) {
                            final feeling = entry.key;
                            final count = entry.value;
                            final label = _encouragementService.feelingLabels[feeling]!;
                            final emoji = _encouragementService.getFeelingEmoji(feeling);

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _showFeelingBasedEncouragement(feeling),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.indigo.shade300),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(emoji, style: const TextStyle(fontSize: 20)),
                                      const SizedBox(height: 4),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.indigo.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.indigo.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showFeelingSelector = !_showFeelingSelector;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade100,
                          foregroundColor: Colors.indigo.shade700,
                          elevation: 0,
                        ),
                        child: const Text('Bagaimana perasaan anda?'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _shareEncouragement,
                      icon: const Icon(Icons.share),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.indigo.shade100,
                        foregroundColor: Colors.indigo.shade700,
                      ),
                    ),
                    IconButton(
                      onPressed: _loadDailyEncouragement,
                      icon: const Icon(Icons.refresh),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.indigo.shade100,
                        foregroundColor: Colors.indigo.shade700,
                      ),
                    ),
                  ],
                ),

                // Feeling Selector
                if (_showFeelingSelector) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bagaimana perasaan anda hari ini?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _encouragementService.allFeelings.map((feeling) {
                            final label = _encouragementService.feelingLabels[feeling]!;
                            final emoji = _encouragementService.getFeelingEmoji(feeling);
                            final count = _feelingCounts[feeling] ?? 0;

                            return GestureDetector(
                              onTap: () => _showFeelingBasedEncouragement(feeling),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.indigo.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(emoji, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$label $count',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.indigo.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Collapsed view
                const SizedBox(height: 8),
                Text(
                  _currentMessage!.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentMessage!.reference,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}