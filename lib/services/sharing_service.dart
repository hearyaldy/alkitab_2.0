import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/devotional_model.dart';

class SharingService {
  static const String appName = 'Alkitab 2.0';
  static const String appWebsite = 'https://alkitab20.app'; // Replace with actual website

  // General sharing method for devotionals
  static Future<void> shareDevotional(
    DevotionalModel devotional, {
    SharingPlatform? platform,
    String? additionalMessage,
  }) async {
    final content = _formatDevotionalContent(devotional, additionalMessage);

    if (platform == null) {
      await SharePlus.instance.share(ShareParams(
        text: content,
        subject: devotional.title,
      ));
    } else {
      await _shareToSpecificPlatform(content, devotional.title, platform);
    }
  }

  // Share Bible verse
  static Future<void> shareBibleVerse(
    String verseText,
    String verseReference, {
    SharingPlatform? platform,
    String? additionalMessage,
  }) async {
    final content = _formatBibleVerseContent(verseText, verseReference, additionalMessage);

    if (platform == null) {
      await SharePlus.instance.share(ShareParams(
        text: content,
        subject: 'Bible Verse - $verseReference',
      ));
    } else {
      await _shareToSpecificPlatform(content, 'Bible Verse - $verseReference', platform);
    }
  }

  // Share encouragement message
  static Future<void> shareEncouragement(
    String message, {
    SharingPlatform? platform,
    String? additionalMessage,
  }) async {
    final content = _formatEncouragementContent(message, additionalMessage);

    if (platform == null) {
      await SharePlus.instance.share(ShareParams(text: content));
    } else {
      await _shareToSpecificPlatform(content, 'Daily Encouragement', platform);
    }
  }

  // Show sharing options modal
  static Future<void> showSharingOptions(
    BuildContext context, {
    required String content,
    required String title,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SharingOptionsSheet(
        content: content,
        title: title,
      ),
    );
  }

  // Format devotional content for sharing
  static String _formatDevotionalContent(DevotionalModel devotional, String? additionalMessage) {
    final buffer = StringBuffer();

    buffer.writeln('📖 ${devotional.title}');
    buffer.writeln();

    if (devotional.verseReference != null) {
      buffer.writeln('📜 ${devotional.verseReference}');
      buffer.writeln();
    }

    if (devotional.verseText != null) {
      buffer.writeln('"${devotional.verseText}"');
      buffer.writeln();
    }

    // Add first 200 characters of content with ellipsis
    final content = devotional.content;
    if (content.length > 200) {
      buffer.writeln('${content.substring(0, 200)}...');
    } else {
      buffer.writeln(content);
    }
    buffer.writeln();

    buffer.writeln('🙏 ${devotional.prayer}');
    buffer.writeln();

    if (additionalMessage != null) {
      buffer.writeln(additionalMessage);
      buffer.writeln();
    }

    buffer.writeln('Shared from $appName');
    buffer.writeln(appWebsite);

    return buffer.toString();
  }

  // Format Bible verse content for sharing
  static String _formatBibleVerseContent(String verseText, String verseReference, String? additionalMessage) {
    final buffer = StringBuffer();

    buffer.writeln('📜 $verseReference');
    buffer.writeln();
    buffer.writeln('"$verseText"');
    buffer.writeln();

    if (additionalMessage != null) {
      buffer.writeln(additionalMessage);
      buffer.writeln();
    }

    buffer.writeln('Shared from $appName');
    buffer.writeln(appWebsite);

    return buffer.toString();
  }

  // Format encouragement content for sharing
  static String _formatEncouragementContent(String message, String? additionalMessage) {
    final buffer = StringBuffer();

    buffer.writeln('💝 Daily Encouragement');
    buffer.writeln();
    buffer.writeln(message);
    buffer.writeln();

    if (additionalMessage != null) {
      buffer.writeln(additionalMessage);
      buffer.writeln();
    }

    buffer.writeln('Shared from $appName');
    buffer.writeln(appWebsite);

    return buffer.toString();
  }

  // Share to specific platform
  static Future<void> _shareToSpecificPlatform(
    String content,
    String title,
    SharingPlatform platform,
  ) async {
    final encodedContent = Uri.encodeComponent(content);
    final encodedTitle = Uri.encodeComponent(title);

    String url;

    switch (platform) {
      case SharingPlatform.whatsapp:
        url = 'whatsapp://send?text=$encodedContent';
        break;
      case SharingPlatform.telegram:
        url = 'https://t.me/share/url?text=$encodedContent';
        break;
      case SharingPlatform.facebook:
        url = 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(appWebsite)}&quote=$encodedContent';
        break;
      case SharingPlatform.twitter:
        url = 'https://twitter.com/intent/tweet?text=$encodedContent';
        break;
      case SharingPlatform.instagram:
        // Instagram doesn't support direct text sharing via URL scheme
        // Fall back to general sharing
        await SharePlus.instance.share(ShareParams(text: content, subject: title));
        return;
      case SharingPlatform.email:
        url = 'mailto:?subject=$encodedTitle&body=$encodedContent';
        break;
      case SharingPlatform.sms:
        url = 'sms:?body=$encodedContent';
        break;
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      // Fall back to general sharing
      await SharePlus.instance.share(ShareParams(text: content, subject: title));
    }
  }
}

enum SharingPlatform {
  whatsapp,
  telegram,
  facebook,
  twitter,
  instagram,
  email,
  sms,
}

class SharingOptionsSheet extends StatelessWidget {
  final String content;
  final String title;

  const SharingOptionsSheet({
    super.key,
    required this.content,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Share via',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildSharingOption(
                context,
                SharingPlatform.whatsapp,
                'WhatsApp',
                Icons.message,
                Colors.green,
              ),
              _buildSharingOption(
                context,
                SharingPlatform.telegram,
                'Telegram',
                Icons.send,
                Colors.blue,
              ),
              _buildSharingOption(
                context,
                SharingPlatform.facebook,
                'Facebook',
                Icons.facebook,
                Colors.blue[800]!,
              ),
              _buildSharingOption(
                context,
                SharingPlatform.twitter,
                'Twitter',
                Icons.alternate_email,
                Colors.lightBlue,
              ),
              _buildSharingOption(
                context,
                SharingPlatform.instagram,
                'Instagram',
                Icons.camera_alt,
                Colors.purple,
              ),
              _buildSharingOption(
                context,
                SharingPlatform.email,
                'Email',
                Icons.email,
                Colors.red,
              ),
              _buildSharingOption(
                context,
                SharingPlatform.sms,
                'SMS',
                Icons.sms,
                Colors.orange,
              ),
              _buildSharingOption(
                context,
                null,
                'More',
                Icons.more_horiz,
                Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSharingOption(
    BuildContext context,
    SharingPlatform? platform,
    String label,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        if (platform == null) {
          // Generic share
          await SharePlus.instance.share(ShareParams(text: content, subject: title));
        } else {
          await SharingService._shareToSpecificPlatform(content, title, platform);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}