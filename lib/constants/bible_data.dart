// constants/bible_data.dart
const List<Map<String, dynamic>> bibleBooks = [
  {"id": "GEN", "name": "Genesis", "chapters": 50, "testament": "OT"},
  {"id": "EXO", "name": "Exodus", "chapters": 40, "testament": "OT"},
  {"id": "LEV", "name": "Leviticus", "chapters": 27, "testament": "OT"},
  {"id": "NUM", "name": "Numbers", "chapters": 36, "testament": "OT"},
  {"id": "DEU", "name": "Deuteronomy", "chapters": 34, "testament": "OT"},
  {"id": "JOS", "name": "Joshua", "chapters": 24, "testament": "OT"},
  {"id": "JDG", "name": "Judges", "chapters": 21, "testament": "OT"},
  {"id": "RUT", "name": "Ruth", "chapters": 4, "testament": "OT"},
  {"id": "1SA", "name": "1 Samuel", "chapters": 31, "testament": "OT"},
  {"id": "2SA", "name": "2 Samuel", "chapters": 24, "testament": "OT"},
  {"id": "1KI", "name": "1 Kings", "chapters": 22, "testament": "OT"},
  {"id": "2KI", "name": "2 Kings", "chapters": 25, "testament": "OT"},
  {"id": "1CH", "name": "1 Chronicles", "chapters": 29, "testament": "OT"},
  {"id": "2CH", "name": "2 Chronicles", "chapters": 36, "testament": "OT"},
  {"id": "EZR", "name": "Ezra", "chapters": 10, "testament": "OT"},
  {"id": "NEH", "name": "Nehemiah", "chapters": 13, "testament": "OT"},
  {"id": "EST", "name": "Esther", "chapters": 10, "testament": "OT"},
  {"id": "JOB", "name": "Job", "chapters": 42, "testament": "OT"},
  {"id": "PSA", "name": "Psalms", "chapters": 150, "testament": "OT"},
  {"id": "PRO", "name": "Proverbs", "chapters": 31, "testament": "OT"},
  {"id": "ECC", "name": "Ecclesiastes", "chapters": 12, "testament": "OT"},
  {"id": "SNG", "name": "Song of Solomon", "chapters": 8, "testament": "OT"},
  {"id": "ISA", "name": "Isaiah", "chapters": 66, "testament": "OT"},
  {"id": "JER", "name": "Jeremiah", "chapters": 52, "testament": "OT"},
  {"id": "LAM", "name": "Lamentations", "chapters": 5, "testament": "OT"},
  {"id": "EZK", "name": "Ezekiel", "chapters": 48, "testament": "OT"},
  {"id": "DAN", "name": "Daniel", "chapters": 12, "testament": "OT"},
  {"id": "HOS", "name": "Hosea", "chapters": 14, "testament": "OT"},
  {"id": "JOL", "name": "Joel", "chapters": 3, "testament": "OT"},
  {"id": "AMO", "name": "Amos", "chapters": 9, "testament": "OT"},
  {"id": "OBA", "name": "Obadiah", "chapters": 1, "testament": "OT"},
  {"id": "JON", "name": "Jonah", "chapters": 4, "testament": "OT"},
  {"id": "MIC", "name": "Micah", "chapters": 7, "testament": "OT"},
  {"id": "NAM", "name": "Nahum", "chapters": 3, "testament": "OT"},
  {"id": "HAB", "name": "Habakkuk", "chapters": 3, "testament": "OT"},
  {"id": "ZEP", "name": "Zephaniah", "chapters": 3, "testament": "OT"},
  {"id": "HAG", "name": "Haggai", "chapters": 2, "testament": "OT"},
  {"id": "ZEC", "name": "Zechariah", "chapters": 14, "testament": "OT"},
  {"id": "MAL", "name": "Malachi", "chapters": 4, "testament": "OT"},
  {"id": "MAT", "name": "Matthew", "chapters": 28, "testament": "NT"},
  {"id": "MRK", "name": "Mark", "chapters": 16, "testament": "NT"},
  {"id": "LUK", "name": "Luke", "chapters": 24, "testament": "NT"},
  {"id": "JHN", "name": "John", "chapters": 21, "testament": "NT"},
  {"id": "ACT", "name": "Acts", "chapters": 28, "testament": "NT"},
  {"id": "ROM", "name": "Romans", "chapters": 16, "testament": "NT"},
  {"id": "1CO", "name": "1 Corinthians", "chapters": 16, "testament": "NT"},
  {"id": "2CO", "name": "2 Corinthians", "chapters": 13, "testament": "NT"},
  {"id": "GAL", "name": "Galatians", "chapters": 6, "testament": "NT"},
  {"id": "EPH", "name": "Ephesians", "chapters": 6, "testament": "NT"},
  {"id": "PHP", "name": "Philippians", "chapters": 4, "testament": "NT"},
  {"id": "COL", "name": "Colossians", "chapters": 4, "testament": "NT"},
  {"id": "1TH", "name": "1 Thessalonians", "chapters": 5, "testament": "NT"},
  {"id": "2TH", "name": "2 Thessalonians", "chapters": 3, "testament": "NT"},
  {"id": "1TI", "name": "1 Timothy", "chapters": 6, "testament": "NT"},
  {"id": "2TI", "name": "2 Timothy", "chapters": 4, "testament": "NT"},
  {"id": "TIT", "name": "Titus", "chapters": 3, "testament": "NT"},
  {"id": "PHM", "name": "Philemon", "chapters": 1, "testament": "NT"},
  {"id": "HEB", "name": "Hebrews", "chapters": 13, "testament": "NT"},
  {"id": "JAS", "name": "James", "chapters": 5, "testament": "NT"},
  {"id": "1PE", "name": "1 Peter", "chapters": 5, "testament": "NT"},
  {"id": "2PE", "name": "2 Peter", "chapters": 3, "testament": "NT"},
  {"id": "1JN", "name": "1 John", "chapters": 5, "testament": "NT"},
  {"id": "2JN", "name": "2 John", "chapters": 1, "testament": "NT"},
  {"id": "3JN", "name": "3 John", "chapters": 1, "testament": "NT"},
  {"id": "JUD", "name": "Jude", "chapters": 1, "testament": "NT"},
  {"id": "REV", "name": "Revelation", "chapters": 22, "testament": "NT"},
];

// Helper function to get book name by ID
String getBookNameById(String bookId) {
  final book = bibleBooks.firstWhere(
    (book) => book['id'] == bookId,
    orElse: () => {'name': bookId},
  );
  return book['name'] as String;
}

// Helper function to get book by ID
Map<String, dynamic>? getBookById(String bookId) {
  try {
    return bibleBooks.firstWhere((book) => book['id'] == bookId);
  } catch (e) {
    return null;
  }
}

// Get Old Testament books
List<Map<String, dynamic>> getOldTestamentBooks() {
  return bibleBooks.where((book) => book['testament'] == 'OT').toList();
}

// Get New Testament books
List<Map<String, dynamic>> getNewTestamentBooks() {
  return bibleBooks.where((book) => book['testament'] == 'NT').toList();
}

// Color options for verse highlighting
const List<Map<String, dynamic>> highlightColors = [
  {'name': 'Yellow', 'hex': '#FFEB3B'},
  {'name': 'Green', 'hex': '#4CAF50'},
  {'name': 'Blue', 'hex': '#2196F3'},
  {'name': 'Red', 'hex': '#F44336'},
  {'name': 'Purple', 'hex': '#9C27B0'},
];