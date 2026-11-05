import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/bible_version_provider.dart';
import '../../providers/sync_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  double _fontSize = 16.0;
  bool _notifications = true;
  String _fontFamily = 'Georgia';
  String _colorTheme = 'classic';

  // Audio settings
  String _audioVoice = 'female';
  double _audioSpeed = 0.5;
  double _audioPitch = 1.0;
  double _audioVolume = 1.0;
  List<String> _availableVoices = ['female', 'male'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAudioVoices();
  }

  Future<void> _loadAudioVoices() async {
    try {
      final FlutterTts flutterTts = FlutterTts();
      final voices = await flutterTts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        setState(() {
          _availableVoices = voices
              .map((voice) => voice['name']?.toString() ?? voice.toString())
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading voices: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 16.0;
      _notifications = prefs.getBool('notifications') ?? true;
      _fontFamily = prefs.getString('fontFamily') ?? 'Georgia';
      _colorTheme = prefs.getString('colorTheme') ?? 'classic';

      // Audio settings
      _audioVoice = prefs.getString('audio_voice') ?? 'female';
      _audioSpeed = prefs.getDouble('speech_rate') ?? 0.5;
      _audioPitch = prefs.getDouble('speech_pitch') ?? 1.0;
      _audioVolume = prefs.getDouble('speech_volume') ?? 1.0;
    });

    // Apply settings to providers
    ref.read(themeProvider.notifier).setTheme(
          _darkMode ? ThemeMode.dark : ThemeMode.light,
        );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setBool('notifications', _notifications);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setString('colorTheme', _colorTheme);

    // Audio settings
    await prefs.setString('audio_voice', _audioVoice);
    await prefs.setDouble('speech_rate', _audioSpeed);
    await prefs.setDouble('speech_pitch', _audioPitch);
    await prefs.setDouble('speech_volume', _audioVolume);
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildModernSliderTile(
    BuildContext context,
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                min.toString(),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                max.toString(),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernTile(
    BuildContext context,
    String title,
    String subtitle,
    String value,
    VoidCallback? onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFontDisplayName(String fontFamily) {
    switch (fontFamily) {
      case 'Georgia':
        return 'Georgia';
      case 'Times New Roman':
        return 'Times New Roman';
      case 'Arial':
        return 'Arial';
      default:
        return 'Georgia';
    }
  }

  String _getThemeDisplayName(String theme) {
    switch (theme) {
      case 'classic':
        return 'Classic';
      case 'modern':
        return 'Modern';
      case 'sepia':
        return 'Sepia';
      default:
        return 'Classic';
    }
  }

  Future<void> _showFontSizeDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        double tempFontSize = _fontSize;
        return AlertDialog(
          title: const Text('Font Size'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: tempFontSize,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    label: tempFontSize.round().toString(),
                    onChanged: (value) {
                      setState(() => tempFontSize = value);
                    },
                  ),
                  Text(
                    'Sample Text',
                    style: TextStyle(fontSize: tempFontSize),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _fontSize = tempFontSize);
                _saveSettings();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFontFamilyDialog() async {
    final fonts = ['Georgia', 'Times New Roman', 'Arial'];
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Font'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: fonts
                .map(
                  (font) => ListTile(
                    title: Text(
                      'Sample Text',
                      style: TextStyle(fontFamily: font),
                    ),
                    subtitle: Text(font),
                    onTap: () {
                      setState(() => _fontFamily = font);
                      _saveSettings();
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _showColorThemeDialog() async {
    final themes = ['classic', 'modern', 'sepia'];
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: themes
                .map(
                  (theme) => ListTile(
                    title: Text(_getThemeDisplayName(theme)),
                    onTap: () {
                      setState(() => _colorTheme = theme);
                      _saveSettings();
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _showAudioVoiceDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Choose Voice',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _availableVoices.length,
                      itemBuilder: (context, index) {
                        final voice = _availableVoices[index];
                        return ListTile(
                          title: Text(voice),
                          onTap: () {
                            setState(() => _audioVoice = voice);
                            _saveSettings();
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showVersionSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Bible Version'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Terjemahan Baru'),
                onTap: () {
                  ref.read(bibleVersionProvider.notifier).setVersion('TB');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Alkitab Berita Baik'),
                onTap: () {
                  ref.read(bibleVersionProvider.notifier).setVersion('ABB');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bibleVersion = ref.watch(bibleVersionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSection(
              context,
              'Appearance',
              Icons.palette_outlined,
              Colors.purple,
              [
                _buildModernSwitchTile(
                  context,
                  'Dark Mode',
                  'Use a dark theme for eye comfort',
                  _darkMode,
                  (value) {
                    setState(() => _darkMode = value);
                    ref.read(themeProvider.notifier).setTheme(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                    _saveSettings();
                  },
                ),
                _buildModernTile(
                  context,
                  'Text Size',
                  'Adjust the font size for comfortable reading',
                  '${_fontSize.toInt()}pt',
                  () => _showFontSizeDialog(),
                ),
                _buildModernTile(
                  context,
                  'Font Type',
                  'Choose the font style for Bible text',
                  _getFontDisplayName(_fontFamily),
                  () => _showFontFamilyDialog(),
                ),
                _buildModernTile(
                  context,
                  'Color Theme',
                  'Choose the app color scheme',
                  _getThemeDisplayName(_colorTheme),
                  () => _showColorThemeDialog(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Reading Section
            _buildSection(
              context,
              'Bible',
              Icons.menu_book_outlined,
              Colors.blue,
              [
                _buildModernTile(
                  context,
                  'Default Bible Version',
                  'Choose your preferred Bible translation',
                  bibleVersion == 'ABB'
                      ? 'Alkitab Berita Baik'
                      : 'Terjemahan Baru',
                  () => _showVersionSelectionDialog(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Audio Section
            _buildSection(
              context,
              'Audio Settings',
              Icons.volume_up_outlined,
              Colors.green,
              [
                _buildModernTile(
                  context,
                  'Voice Type',
                  'Choose the voice for audio reading',
                  _audioVoice,
                  () => _showAudioVoiceDialog(),
                ),
                _buildModernSliderTile(
                  context,
                  'Reading Speed',
                  'Adjust the audio reading speed',
                  _audioSpeed,
                  0.1,
                  1.5,
                  (value) {
                    setState(() => _audioSpeed = value);
                    _saveSettings();
                  },
                ),
                _buildModernSliderTile(
                  context,
                  'Voice Pitch',
                  'Adjust the voice pitch',
                  _audioPitch,
                  0.5,
                  2.0,
                  (value) {
                    setState(() => _audioPitch = value);
                    _saveSettings();
                  },
                ),
                _buildModernSliderTile(
                  context,
                  'Volume',
                  'Adjust the audio volume level',
                  _audioVolume,
                  0.1,
                  1.0,
                  (value) {
                    setState(() => _audioVolume = value);
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Notifications Section
            _buildSection(
              context,
              'Notifications',
              Icons.notifications_outlined,
              Colors.orange,
              [
                _buildModernSwitchTile(
                  context,
                  'Verse of the Day',
                  'Receive a daily verse notification every morning',
                  _notifications,
                  (value) {
                    setState(() => _notifications = value);
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // About Section
            _buildSection(
              context,
              'About the App',
              Icons.info_outline,
              Colors.grey[600]!,
              [
                _buildModernTile(
                  context,
                  'App Version',
                  'Alkitab 2.0 - Latest version',
                  '1.1.0',
                  null,
                ),
                _buildModernTile(
                  context,
                  'Terms & Conditions',
                  'Read the app\'s terms of use',
                  '',
                  () {},
                ),
                _buildModernTile(
                  context,
                  'Privacy Policy',
                  'Information about your data privacy',
                  '',
                  () {},
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Account & Sync Section
            _buildSection(
              context,
              'Account & Sync',
              Icons.person_outline,
              Colors.blue,
              [
                Consumer(
                  builder: (context, ref, _) {
                    final authState = ref.watch(authStateProvider);
                    final syncState = ref.watch(syncStateProvider);

                    return authState.when(
                      data: (user) {
                        if (user == null) {
                          return Column(
                            children: [
                              _buildModernTile(
                                context,
                                'Sign In',
                                'Sign in to sync your data',
                                '',
                                () => _showLoginDialog(context, ref),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _buildModernTile(
                              context,
                              'Email',
                              (user).email ?? '',
                              '',
                              null,
                            ),
                            _buildModernTile(
                              context,
                              'Sync',
                              syncState.lastSynced != null
                                  ? 'Last synced: ${_formatDateTime(syncState.lastSynced!)}'
                                  : 'Never synced',
                              '',
                              syncState.isSyncing ? null : () => _sync(ref),
                            ),
                            if (syncState.error != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Error: ${syncState.error}',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            _buildModernTile(
                              context,
                              'Sign Out',
                              'Sign out of your account',
                              '',
                              () => _showLogoutConfirmation(ref),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (_, __) => _buildModernTile(
                        context,
                        'Error',
                        'Failed to load authentication status',
                        '',
                        null,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Version selection dialog is implemented above

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sync(WidgetRef ref) async {
    await ref.read(syncStateProvider.notifier).syncAll();
  }

  void _showLoginDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success =
                    await ref.read(userProvider.notifier).signInWithGoogle();
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to sign in with Google')),
                  );
                }
              },
              child: const Text('Sign in with Google'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/login'); // Implement email login screen
              },
              child: const Text('Sign in with Email'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(userProvider.notifier).signOut();
              Navigator.pop(context);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
