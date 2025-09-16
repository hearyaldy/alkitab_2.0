import '../models/bible_model.dart';

class MockDataService {
  static List<BibleVersion> _versions = [];
  static List<BibleBook> _books = [];
  static List<BibleVerse> _verses = [];

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
}