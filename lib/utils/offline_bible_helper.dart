import '../services/connectivity_service.dart';
import '../utils/bible_content_cache_manager.dart';

class OfflineBibleHelper {
  final ConnectivityService _connectivityService;

  OfflineBibleHelper(this._connectivityService);

  Future<bool> shouldFetchFromNetwork({
    required String version,
    required String bookId,
    required int chapterId,
  }) async {
    // If online, always try to fetch fresh content
    if (_connectivityService.isOnline) return true;

    // Check if content is cached when offline
    return !(await BibleContentCacheManager.isVersesCached(
      version: version,
      bookId: bookId,
      chapterId: chapterId,
    ));
  }
}
