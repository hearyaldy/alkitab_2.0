// lib/services/encouragement_service.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Feeling {
  gembira,    // Happy
  sedih,      // Sad
  cemas,      // Anxious
  marah,      // Angry
  keliru,     // Confused
  bersyukur,  // Grateful
  damai,      // Peaceful
  harapan,    // Hopeful
  letih,      // Tired
  tertekan,   // Overwhelmed
  putusAsa,  // Discouraged
  kesepian,   // Lonely
}

class EncouragementMessage {
  final String title;
  final String verse;
  final String reference;
  final String message;
  final List<Feeling> feelings;

  const EncouragementMessage({
    required this.title,
    required this.verse,
    required this.reference,
    required this.message,
    required this.feelings,
  });
}

class EncouragementService {
  static final EncouragementService _instance = EncouragementService._internal();
  factory EncouragementService() => _instance;
  EncouragementService._internal();

  // Pre-formatted encouragement messages with feeling mappings (in Malay)
  static const List<EncouragementMessage> _encouragements = [
    EncouragementMessage(
      title: "Keamanan Tuhan",
      verse: "Damai sejahtera Kutinggalkan bagimu. Damai sejahtera-Ku Kuberikan kepadamu, dan apa yang Kuberikan tidak seperti yang diberikan oleh dunia. Janganlah gelisah dan gentar hatimu.",
      reference: "Yohanes 14:27",
      message: "Apabila kecemasan memenuhi hati, ingatlah bahawa keamanan Tuhan melampaui segala pengertian. Dia bersama anda setiap saat.",
      feelings: [Feeling.cemas],
    ),
    EncouragementMessage(
      title: "Penghiburan dalam Kesedihan",
      verse: "TUHAN dekat kepada orang-orang yang patah hati dan menyelamatkan orang-orang yang remuk jiwanya.",
      reference: "Mazmur 34:18",
      message: "Air mata anda tidak luput dari perhatian Tuhan. Dia mendekat kepada anda dalam kesedihan dan menawarkan penghiburan-Nya.",
      feelings: [Feeling.sedih],
    ),
    EncouragementMessage(
      title: "Kasih Tuhan",
      verse: "Lihatlah, betapa besarnya kasih yang dikaruniakan Bapa kepada kita, sehingga kita disebut anak-anak Allah, dan memang kita adalah anak-anak Allah.",
      reference: "1 Yohanes 3:1",
      message: "Anda sangat dikasihi oleh Pencipta alam semesta. Biarkan kebenaran ini memenuhi hati anda dengan sukacita.",
      feelings: [Feeling.gembira],
    ),
    EncouragementMessage(
      title: "Sukacita di Pagi Hari",
      verse: "Menangis boleh berlangsung sampai petang, tetapi sukacita datang di pagi hari.",
      reference: "Mazmur 30:5",
      message: "Musim yang gelap tidak akan berlangsung selamanya. Tuhan menjanjikan bahawa sukacita akan kembali dalam hidup anda.",
      feelings: [Feeling.sedih, Feeling.gembira, Feeling.putusAsa],
    ),
    EncouragementMessage(
      title: "Lemparkan Bebanmu",
      verse: "Serahkanlah segala kekuatiranmu kepada-Nya, sebab Ia yang memelihara kamu.",
      reference: "1 Petrus 5:7",
      message: "Kerisauan anda tidak perlu membebankan. Tuhan mengundang anda untuk memberikan beban kepada-Nya kerana Dia mengasihi anda.",
      feelings: [Feeling.cemas, Feeling.tertekan, Feeling.letih],
    ),
    EncouragementMessage(
      title: "Rancangan Tuhan",
      verse: "Sebab Aku ini mengetahui rancangan-rancangan apa yang ada pada-Ku mengenai kamu, demikianlah firman TUHAN, yaitu rancangan damai sejahtera dan bukan rancangan kecelakaan, untuk memberikan kepadamu hari depan yang penuh harapan.",
      reference: "Yeremia 29:11",
      message: "Walaupun hidup terasa tidak pasti, Tuhan mempunyai rancangan yang baik untuk masa depan anda. Percayalah pada timing-Nya yang sempurna.",
      feelings: [Feeling.keliru, Feeling.cemas, Feeling.harapan],
    ),
    EncouragementMessage(
      title: "Tidak Pernah Sendirian",
      verse: "Bukankah telah Kuperintahkan kepadamu: kuatkanlah dan teguhkanlah hatimu? Janganlah kecut dan tawar hati, sebab TUHAN, Allahmu, menyertai engkau, ke manapun engkau pergi.",
      reference: "Yosua 1:9",
      message: "Walaupun anda berasa terpencil, Tuhan adalah teman setia anda. Anda tidak pernah benar-benar sendirian.",
      feelings: [Feeling.kesepian, Feeling.putusAsa, Feeling.cemas],
    ),
    EncouragementMessage(
      title: "Kekuatan dalam Kelemahan",
      verse: "Tetapi jawab-Nya kepadaku: Cukuplah kasih karunia-Ku bagimu, sebab justru dalam kelemahanlah kuasa-Ku menjadi sempurna.",
      reference: "2 Korintus 12:9",
      message: "Apabila anda berasa letih dan lemah, ingatlah bahawa kekuatan Tuhan bersinar paling terang melalui kerentanan anda.",
      feelings: [Feeling.letih, Feeling.tertekan, Feeling.putusAsa],
    ),
    EncouragementMessage(
      title: "Kelembutan dalam Kemarahan",
      verse: "Apabila kamu marah, janganlah berbuat dosa: janganlah matahari terbenam, sedang kamu masih marah.",
      reference: "Efesus 4:26",
      message: "Tidak mengapa berasa marah, tetapi jangan biarkan ia mengawal anda. Bawa perasaan anda kepada Tuhan dan dapatkan kedamaian-Nya.",
      feelings: [Feeling.marah, Feeling.tertekan],
    ),
    EncouragementMessage(
      title: "Kesetiaan Tuhan",
      verse: "Kasih setia TUHAN tidak berkesudahan, rahmat-Nya tidak habis-habis, bahkan baru setiap pagi; besar kesetiaan-Mu!",
      reference: "Ratapan 3:22-23",
      message: "Setiap hari baru membawa belas kasihan segar dari Tuhan. Kasih-Nya untuk anda adalah berterusan dan tidak pernah gagal.",
      feelings: [Feeling.gembira],
    ),
    EncouragementMessage(
      title: "Diam dan Tahu",
      verse: "Diamlah dan ketahuilah, bahwa Akulah Allah! Aku akan ditinggikan di antara bangsa-bangsa, Aku akan ditinggikan di bumi!",
      reference: "Mazmur 46:10",
      message: "Dalam kekacauan hidup, carilah saat-saat ketenangan untuk mengingat kedaulatan dan keamanan Tuhan.",
      feelings: [Feeling.cemas],
    ),
    EncouragementMessage(
      title: "Bersyukur",
      verse: "Mengucap syukurlah dalam segala hal, sebab itulah yang dikehendaki Allah di dalam Kristus Yesus bagi kamu.",
      reference: "1 Tesalonika 5:18",
      message: "Rasa syukur mengubah perspektif kita. Walaupun dalam masa sukar, ada sebab untuk bersyukur kepada Tuhan.",
      feelings: [Feeling.gembira],
    ),
  ];

  // Get feeling labels for UI (in Malay)
  Map<Feeling, String> get feelingLabels => {
    Feeling.gembira: "Gembira",
    Feeling.sedih: "Sedih",
    Feeling.cemas: "Cemas",
    Feeling.marah: "Marah",
    Feeling.keliru: "Keliru",
    Feeling.bersyukur: "Bersyukur",
    Feeling.damai: "Damai",
    Feeling.harapan: "Harapan",
    Feeling.letih: "Letih",
    Feeling.tertekan: "Tertekan",
    Feeling.putusAsa: "Putus Asa",
    Feeling.kesepian: "Kesepian",
  };

  // Get random daily encouragement
  EncouragementMessage getDailyEncouragement() {
    // Use date as seed for consistent daily message
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final random = Random(seed);

    return _encouragements[random.nextInt(_encouragements.length)];
  }

  // Get encouragement based on feeling
  List<EncouragementMessage> getEncouragementByFeeling(Feeling feeling) {
    return _encouragements
        .where((encouragement) => encouragement.feelings.contains(feeling))
        .toList();
  }

  // Get random encouragement for specific feeling
  EncouragementMessage? getRandomEncouragementForFeeling(Feeling feeling) {
    final matches = getEncouragementByFeeling(feeling);
    if (matches.isEmpty) return null;

    final random = Random();
    return matches[random.nextInt(matches.length)];
  }

  // Get all feelings as list for UI
  List<Feeling> get allFeelings => Feeling.values;

  // Get feeling emoji (optional visual enhancement)
  String getFeelingEmoji(Feeling feeling) {
    switch (feeling) {
      case Feeling.gembira: return "😊";
      case Feeling.sedih: return "😢";
      case Feeling.cemas: return "😰";
      case Feeling.marah: return "😠";
      case Feeling.keliru: return "😕";
      case Feeling.bersyukur: return "🙏";
      case Feeling.damai: return "😌";
      case Feeling.harapan: return "🌟";
      case Feeling.letih: return "😴";
      case Feeling.tertekan: return "🤯";
      case Feeling.putusAsa: return "😞";
      case Feeling.kesepian: return "😔";
    }
  }

  // Add feeling tracking with SharedPreferences
  Future<void> recordFeelingSelection(Feeling feeling) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'feeling_count_${feeling.name}';
      final currentCount = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, currentCount + 1);
    } catch (e) {
      debugPrint('Error recording feeling: $e');
    }
  }

  // Get feeling count
  Future<int> getFeelingCount(Feeling feeling) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'feeling_count_${feeling.name}';
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      debugPrint('Error getting feeling count: $e');
      return 0;
    }
  }

  // Get all feeling counts
  Future<Map<Feeling, int>> getAllFeelingCounts() async {
    final Map<Feeling, int> counts = {};
    for (final feeling in allFeelings) {
      counts[feeling] = await getFeelingCount(feeling);
    }
    return counts;
  }

  // Get top 3 most selected feelings
  Future<List<MapEntry<Feeling, int>>> getTop3Feelings() async {
    final counts = await getAllFeelingCounts();
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedEntries.take(3).toList();
  }

  // Reset all feeling counts
  Future<void> resetAllFeelingCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final feeling in allFeelings) {
        final key = 'feeling_count_${feeling.name}';
        await prefs.remove(key);
      }
      debugPrint('All feeling counts have been reset');
    } catch (e) {
      debugPrint('Error resetting feeling counts: $e');
    }
  }
}