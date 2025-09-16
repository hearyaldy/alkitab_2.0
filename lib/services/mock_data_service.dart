import '../models/bible_model.dart';
import '../models/devotional_model.dart';

class MockDataService {
  static List<BibleVersion> _versions = [];
  static List<BibleBook> _books = [];
  static List<BibleVerse> _verses = [];
  static List<DevotionalModel> _devotionals = [];
  static List<Map<String, dynamic>> _recentReadings = [];

  static Future<void> initialize() async {
    // Create mock Bible versions
    _versions = [
      BibleVersion(
        id: 'tb',
        name: 'Terjemahan Baru',
        code: 'TB',
        description: 'Indonesian Translation',
      ),
      BibleVersion(
        id: 'tm',
        name: 'Terjemahan Malay',
        code: 'TM',
        description: 'Malay Translation',
      ),
    ];

    // Create mock Bible books
    _books = [
      // Old Testament
      BibleBook(
        id: '1',
        name: 'Kejadian',
        abbreviation: 'Kej',
        order: 1,
        testament: 'OT',
        chapters: 50,
      ),
      BibleBook(
        id: '2',
        name: 'Keluaran',
        abbreviation: 'Kel',
        order: 2,
        testament: 'OT',
        chapters: 40,
      ),
      BibleBook(
        id: '3',
        name: 'Imamat',
        abbreviation: 'Im',
        order: 3,
        testament: 'OT',
        chapters: 27,
      ),
      BibleBook(
        id: '4',
        name: 'Bilangan',
        abbreviation: 'Bil',
        order: 4,
        testament: 'OT',
        chapters: 36,
      ),
      BibleBook(
        id: '5',
        name: 'Ulangan',
        abbreviation: 'Ul',
        order: 5,
        testament: 'OT',
        chapters: 34,
      ),

      // New Testament
      BibleBook(
        id: '40',
        name: 'Matius',
        abbreviation: 'Mat',
        order: 40,
        testament: 'NT',
        chapters: 28,
      ),
      BibleBook(
        id: '41',
        name: 'Markus',
        abbreviation: 'Mrk',
        order: 41,
        testament: 'NT',
        chapters: 16,
      ),
      BibleBook(
        id: '42',
        name: 'Lukas',
        abbreviation: 'Luk',
        order: 42,
        testament: 'NT',
        chapters: 24,
      ),
      BibleBook(
        id: '43',
        name: 'Yohanes',
        abbreviation: 'Yoh',
        order: 43,
        testament: 'NT',
        chapters: 21,
      ),
      BibleBook(
        id: '44',
        name: 'Kisah Para Rasul',
        abbreviation: 'Kis',
        order: 44,
        testament: 'NT',
        chapters: 28,
      ),
    ];

    // Create mock verses for first chapter of Genesis and Matthew
    _verses = [
      // Genesis 1
      BibleVerse(
        id: 1,
        bookId: '1',
        chapterId: 1,
        verseNumber: 1,
        text: 'Pada mulanya Allah menciptakan langit dan bumi.',
      ),
      BibleVerse(
        id: 2,
        bookId: '1',
        chapterId: 1,
        verseNumber: 2,
        text: 'Bumi belum berbentuk dan kosong; gelap gulita menutupi samudera raya, dan Roh Allah melayang-layang di atas permukaan air.',
      ),
      BibleVerse(
        id: 3,
        bookId: '1',
        chapterId: 1,
        verseNumber: 3,
        text: 'Berfirmanlah Allah: "Jadilah terang." Lalu terang itu jadi.',
      ),

      // Matthew 1
      BibleVerse(
        id: 4,
        bookId: '40',
        chapterId: 1,
        verseNumber: 1,
        text: 'Inilah silsilah Yesus Kristus, anak Daud, anak Abraham.',
      ),
      BibleVerse(
        id: 5,
        bookId: '40',
        chapterId: 1,
        verseNumber: 2,
        text: 'Abraham memperanakkan Ishak, Ishak memperanakkan Yakub, Yakub memperanakkan Yehuda dan saudara-saudaranya,',
      ),
    ];

    // Create sample devotional data
    final now = DateTime.now();
    _devotionals = [
      DevotionalModel(
        id: '1',
        title: 'Kasih Yang Tak Bersyarat',
        verseReference: 'Yohanes 3:16',
        verseText: 'Karena begitu besar kasih Allah akan dunia ini, sehingga Ia telah mengaruniakan Anak-Nya yang tunggal, supaya setiap orang yang percaya kepada-Nya tidak binasa, melainkan beroleh hidup yang kekal.',
        content: 'Kasih Allah bukanlah kasih yang bergantung pada perbuatan kita. Kasih-Nya adalah kasih yang murni, yang diberikan tanpa syarat kepada setiap orang. Ketika kita merasa tidak layak atau telah berbuat kesalahan, ingatlah bahwa kasih Allah tidak pernah berubah. Dia mengasihi kita bukan karena kita sempurna, tetapi karena Dia adalah kasih itu sendiri. Hari ini, biarkan kasih yang luar biasa ini mengisi hati kita dan mengalir kepada orang-orang di sekitar kita.',
        reflectionQuestions: [
          'Bagaimana saya dapat menunjukkan kasih tanpa syarat kepada orang lain hari ini?',
          'Apakah ada seseorang yang perlu saya maafkan dengan kasih Allah?'
        ],
        prayer: 'Ya Tuhan, terima kasih untuk kasih-Mu yang tak terbatas. Bantulah saya untuk mengasihi seperti Engkau mengasihi, tanpa syarat dan tanpa batas. Jadikanlah saya saluran kasih-Mu bagi dunia. Amen.',
        date: now,
        author: 'Tim Alkitab 2.0',
      ),
      DevotionalModel(
        id: '2',
        title: 'Kekuatan Dalam Kelemahan',
        verseReference: '2 Korintus 12:9',
        verseText: 'Tetapi jawab Tuhan kepadaku: "Cukuplah kasih karunia-Ku bagimu, sebab justru dalam kelemahanlah kuasa-Ku menjadi sempurna." Sebab itu terlebih suka aku bermegah atas kelemahanku, supaya kuasa Kristus turun menaungi aku.',
        content: 'Seringkali kita merasa malu dengan kelemahan kita dan berusaha menyembunyikannya. Namun, Paulus mengajarkan kita bahwa justru dalam kelemahan kita, kuasa Allah menjadi sempurna. Allah tidak mencari orang yang sempurna, tetapi orang yang bergantung kepada-Nya. Ketika kita mengakui kelemahan kita dan menyerahkannya kepada Tuhan, maka kuasa-Nya bekerja melalui kita dengan cara yang menakjubkan. Hari ini, jangan takut untuk bergantung kepada Tuhan dalam kelemahan kita.',
        reflectionQuestions: [
          'Kelemahan apa yang saya miliki yang dapat diserahkan kepada Tuhan?',
          'Bagaimana Tuhan telah menggunakan kelemahan saya untuk kemuliaan-Nya?'
        ],
        prayer: 'Tuhan Yesus, saya mengakui kelemahan saya di hadapan-Mu. Saya tidak sempurna dan saya membutuhkan kekuatan-Mu setiap hari. Pakailah kelemahan saya untuk menunjukkan kuasa-Mu yang sempurna. Amen.',
        date: now.subtract(const Duration(days: 1)),
        author: 'Tim Alkitab 2.0',
      ),
      DevotionalModel(
        id: '3',
        title: 'Berkat Dalam Kesabaran',
        verseReference: 'Yakobus 5:11',
        verseText: 'Sesungguhnya kami menyebut mereka berbahagia, yaitu mereka yang telah bertekun; kamu telah mendengar tentang ketekunan Ayub dan kamu telah tahu apa yang pada akhirnya disediakan Tuhan baginya, karena Tuhan maha penyayang dan penuh belas kasihan.',
        content: 'Kesabaran dan ketekunan adalah sifat yang tidak mudah dipraktikkan, terutama ketika kita menghadapi tantangan yang berat. Ayub adalah contoh yang luar biasa tentang bagaimana seseorang dapat tetap beriman meskipun mengalami penderitaan yang hebat. Tuhan melihat ketekunan kita dan Dia memiliki rencana yang baik bagi hidup kita. Setiap ujian yang kita hadapi adalah kesempatan untuk bertumbuh dalam iman dan karakter. Bersabarlah, karena Tuhan sedang menyiapkan berkat yang indah untuk hidup kita.',
        reflectionQuestions: [
          'Dalam situasi apa saat ini saya perlu menunjukkan kesabaran?',
          'Bagaimana saya dapat belajar dari teladan kesabaran Ayub?'
        ],
        prayer: 'Ya Allah, berikanlah saya kekuatan untuk bersabar dalam menghadapi setiap tantangan hidup. Bantulah saya untuk percaya bahwa Engkau sedang bekerja dalam setiap situasi untuk kebaikan saya. Amen.',
        date: now.subtract(const Duration(days: 2)),
        author: 'Tim Alkitab 2.0',
      ),
      DevotionalModel(
        id: '4',
        title: 'Jalan Menuju Kedamaian',
        verseReference: 'Filipi 4:6-7',
        verseText: 'Janganlah hendaknya kamu kuatir tentang apa pun juga, tetapi nyatakanlah dalam segala hal keinginanmu kepada Allah dalam doa dan permohonan dengan ucapan syukur. Damai sejahtera Allah, yang melampaui segala akal, akan memelihara hati dan pikiranmu dalam Kristus Yesus.',
        content: 'Di tengah hiruk-pikuk kehidupan modern, kekhawatiran sering kali menguasai pikiran kita. Namun, Paulus memberikan resep yang jitu untuk mengalami kedamaian: jangan khawatir, tetapi berdoalah dengan penuh syukur. Ketika kita menyerahkan segala kekhawatiran kepada Tuhan dan mengucap syukur atas berkat-Nya, maka damai sejahtera-Nya akan memenuhi hati kita. Kedamaian dari Tuhan ini bukan sekedar tidak adanya masalah, tetapi ketenangan hati yang mendalam meskipun badai kehidupan sedang mengamuk.',
        reflectionQuestions: [
          'Apa yang saat ini membuat saya khawatir dan perlu diserahkan kepada Tuhan?',
          'Bagaimana saya dapat lebih banyak bersyukur dalam situasi sulit?'
        ],
        prayer: 'Bapa Yang Mahakasih, saya menyerahkan segala kekhawatiran saya kepada-Mu. Gantilah kekuatiran saya dengan damai sejahtera-Mu yang melampaui segala akal. Ajarlah saya untuk selalu bersyukur dalam segala keadaan. Amen.',
        date: now.subtract(const Duration(days: 3)),
        author: 'Tim Alkitab 2.0',
      ),
      DevotionalModel(
        id: '5',
        title: 'Terang Bagi Dunia',
        verseReference: 'Matius 5:14-16',
        verseText: 'Kamu adalah terang dunia. Kota yang terletak di atas gunung tidak mungkin tersembunyi. Lagipula orang tidak menyalakan pelita lalu meletakkannya di bawah gantang, melainkan di atas kaki dian sehingga menerangi semua orang di dalam rumah itu. Demikianlah hendaknya terangmu bercahaya di depan orang, supaya mereka melihat perbuatanmu yang baik dan memuliakan Bapamu yang di surga.',
        content: 'Yesus memanggil kita untuk menjadi terang dunia. Ini bukan sekedar metafora yang indah, tetapi panggilan hidup yang nyata. Setiap orang percaya memiliki tanggung jawab untuk membawa terang Kristus ke dalam lingkungannya. Terang ini tidak harus berupa tindakan yang spektakuler, tetapi bisa dimulai dari hal-hal sederhana: kebaikan, kejujuran, kasih, dan pelayanan kepada sesama. Ketika kita hidup sebagai terang, orang lain akan melihat perbedaan dalam hidup kita dan memuliakan Allah.',
        reflectionQuestions: [
          'Bagaimana saya dapat menjadi terang di tempat kerja atau sekolah saya?',
          'Perbuatan baik apa yang dapat saya lakukan hari ini untuk memuliakan Allah?'
        ],
        prayer: 'Tuhan Yesus, Engkau adalah terang dunia. Jadikanlah saya pantulan terang-Mu di mana pun saya berada. Bantulah saya untuk hidup sedemikian rupa sehingga orang lain dapat melihat kemuliaan-Mu melalui hidup saya. Amen.',
        date: now.subtract(const Duration(days: 4)),
        author: 'Tim Alkitab 2.0',
      ),
    ];

    // Create sample recent reading history
    _recentReadings = [
      {
        'bookId': 'GEN',
        'chapterId': 1,
        'bookName': 'Kejadian',
        'progress': 0.8,
        'lastRead': DateTime.now().subtract(const Duration(hours: 2)),
        'versePosition': 25,
        'totalVerses': 31,
      },
      {
        'bookId': 'MAT',
        'chapterId': 5,
        'bookName': 'Matius',
        'progress': 0.6,
        'lastRead': DateTime.now().subtract(const Duration(days: 1)),
        'versePosition': 28,
        'totalVerses': 48,
      },
      {
        'bookId': 'PSA',
        'chapterId': 23,
        'bookName': 'Mazmur',
        'progress': 1.0,
        'lastRead': DateTime.now().subtract(const Duration(days: 2)),
        'versePosition': 6,
        'totalVerses': 6,
      },
      {
        'bookId': 'JHN',
        'chapterId': 3,
        'bookName': 'Yohanes',
        'progress': 0.4,
        'lastRead': DateTime.now().subtract(const Duration(days: 3)),
        'versePosition': 15,
        'totalVerses': 36,
      },
    ];
  }

  static List<BibleVersion> getVersions() {
    return _versions;
  }

  static List<BibleBook> getBooks() {
    return _books;
  }

  static List<BibleVerse> getVerses({
    required String bookId,
    required int chapter,
    String versionId = 'tb',
  }) {
    return _verses
        .where((verse) =>
            verse.bookId == bookId &&
            verse.chapterId == chapter)
        .toList();
  }

  static BibleBook? getBook(String bookId) {
    try {
      return _books.firstWhere((book) => book.id == bookId);
    } catch (e) {
      return null;
    }
  }

  static BibleVersion? getVersion(String versionId) {
    try {
      return _versions.firstWhere((version) => version.id == versionId);
    } catch (e) {
      return null;
    }
  }

  static List<BibleVerse> searchVerses(String query) {
    return _verses
        .where((verse) =>
            verse.text.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Devotional methods
  static List<DevotionalModel> getDevotionals() {
    return _devotionals;
  }

  static DevotionalModel? getTodayDevotional() {
    if (_devotionals.isEmpty) return null;

    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final index = dayOfYear % _devotionals.length;
    return _devotionals[index];
  }

  static List<DevotionalModel> getFeaturedDevotionals({int count = 5}) {
    final sorted = [..._devotionals];
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(count).toList();
  }

  static DevotionalModel? getDevotionalById(String id) {
    try {
      return _devotionals.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  // Recent readings methods
  static List<Map<String, dynamic>> getRecentReadings() {
    return _recentReadings;
  }

  static void addRecentReading(Map<String, dynamic> reading) {
    _recentReadings.removeWhere((r) =>
        r['bookId'] == reading['bookId'] &&
        r['chapterId'] == reading['chapterId']);
    _recentReadings.insert(0, reading);
    if (_recentReadings.length > 5) {
      _recentReadings = _recentReadings.take(5).toList();
    }
  }
}