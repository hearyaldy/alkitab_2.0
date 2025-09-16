import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_models.dart';
import 'firebase_service.dart';

class FirebaseDataService {
  static final FirebaseDataService _instance = FirebaseDataService._internal();
  factory FirebaseDataService() => _instance;
  FirebaseDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _auth = FirebaseService();

  // Collections
  CollectionReference get _users => _firestore.collection('users');
  CollectionReference get _devotionals => _firestore.collection('devotionals');
  CollectionReference get _bibleMarks => _firestore.collection('bible_marks');

  // Sync user preferences
  Future<void> syncUserPreferences(UserPreferences prefs) async {
    if (_auth.currentUser == null) return;

    await _users.doc(_auth.currentUser!.uid).set({
      'preferences': prefs.toJson(),
      'lastSynced': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get user preferences
  Future<UserPreferences?> getUserPreferences() async {
    if (_auth.currentUser == null) return null;

    final doc = await _users.doc(_auth.currentUser!.uid).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    return UserPreferences.fromJson(data['preferences']);
  }

  // Sync bible marks (bookmarks, highlights, favorites)
  Future<void> syncBibleMark(UserBibleMark mark) async {
    if (_auth.currentUser == null) return;

    await _bibleMarks.doc(mark.id).set(
          mark.toJson(),
          SetOptions(merge: true),
        );
  }

  // Get all bible marks for user
  Future<List<UserBibleMark>> getBibleMarks() async {
    if (_auth.currentUser == null) return [];

    final snapshot = await _bibleMarks
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .get();

    return snapshot.docs
        .map(
            (doc) => UserBibleMark.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Get devotionals with pagination and caching
  Future<List<Devotional>> getDevotionals({
    DateTime? startDate,
    int limit = 10,
  }) async {
    // Try to get from cache first
    final prefs = await SharedPreferences.getInstance();
    final cacheKey =
        'devotionals_${startDate?.toIso8601String() ?? 'latest'}_$limit';
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null) {
      // Return cached data if it's less than 24 hours old
      final cacheTimestamp = prefs.getInt('${cacheKey}_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cacheTimestamp < 24 * 60 * 60 * 1000) {
        return (cachedData as List)
            .map((item) => Devotional.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    // Get from Firestore
    Query query = _devotionals.orderBy('date', descending: true);

    if (startDate != null) {
      query = query.where('date', isLessThanOrEqualTo: startDate);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    final devotionals = snapshot.docs
        .map((doc) => Devotional.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    // Cache the results
    await prefs.setString(
        cacheKey, devotionals.map((d) => d.toJson()).toList().toString());
    await prefs.setInt(
        '${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);

    return devotionals;
  }

  // Delete user data (for account deletion)
  Future<void> deleteUserData() async {
    if (_auth.currentUser == null) return;

    final userId = _auth.currentUser!.uid;

    // Delete bible marks
    final marksSnapshot =
        await _bibleMarks.where('userId', isEqualTo: userId).get();

    for (var doc in marksSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete user preferences
    await _users.doc(userId).delete();
  }
}
