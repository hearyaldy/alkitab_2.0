// lib/providers/note_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../providers/sync_providers.dart';

// Provider for NoteService
final noteServiceProvider = Provider<NoteService>((ref) {
  final syncQueueProcessor = ref.watch(syncQueueProcessorProvider);
  return NoteService(syncQueueProcessor);
});

// Provider for all notes (with loading, error states)
final notesProvider = FutureProvider<List<NoteModel>>((ref) async {
  final noteService = ref.watch(noteServiceProvider);
  return noteService.getUserNotes();
});

// Provider for Bible notes
final bibleNotesProvider = FutureProvider<List<NoteModel>>((ref) async {
  final noteService = ref.watch(noteServiceProvider);
  return noteService.getUserNotes(type: 'bible');
});

// Provider for devotional notes
final devotionalNotesProvider = FutureProvider<List<NoteModel>>((ref) async {
  final noteService = ref.watch(noteServiceProvider);
  return noteService.getUserNotes(type: 'devotional');
});

// Provider for notes on a specific Bible verse
final verseNotesProvider = FutureProvider.family<List<NoteModel>,
    ({String bookId, int chapterId, int verseId})>(
  (ref, params) async {
    final noteService = ref.watch(noteServiceProvider);
    return noteService.getBibleNotes(
      bookId: params.bookId,
      chapterId: params.chapterId,
      verseId: params.verseId,
    );
  },
);

// Provider for notes on a specific Bible chapter
final chapterNotesProvider =
    FutureProvider.family<List<NoteModel>, ({String bookId, int chapterId})>(
  (ref, params) async {
    final noteService = ref.watch(noteServiceProvider);
    return noteService.getBibleNotes(
      bookId: params.bookId,
      chapterId: params.chapterId,
    );
  },
);

// Provider for notes on a specific devotional
final devotionalSpecificNotesProvider =
    FutureProvider.family<List<NoteModel>, String>(
  (ref, devotionalId) async {
    final noteService = ref.watch(noteServiceProvider);
    return noteService.getDevotionalNotes(devotionalId: devotionalId);
  },
);

// A provider for note operations with loading states
class NoteOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final NoteService _noteService;

  NoteOperationsNotifier(this._noteService)
      : super(const AsyncValue.data(null));

  Future<NoteModel?> addNote({
    String? bookId,
    int? chapterId,
    int? verseId,
    required String content,
    String? devotionalId,
    String noteType = 'general',
    String? title,
  }) async {
    state = const AsyncValue.loading();
    try {
      final note = await _noteService.addNote(
        bookId: bookId,
        chapterId: chapterId,
        verseId: verseId,
        content: content,
        devotionalId: devotionalId,
        noteType: noteType,
        title: title,
      );
      state = const AsyncValue.data(null);
      return note;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  Future<void> deleteNote(String noteId) async {
    state = const AsyncValue.loading();
    try {
      await _noteService.deleteNote(noteId);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<NoteModel?> updateNote({
    required String id,
    String? content,
    String? title,
  }) async {
    state = const AsyncValue.loading();
    try {
      final note = await _noteService.updateNote(
        id: id,
        content: content,
        title: title,
      );
      state = const AsyncValue.data(null);
      return note;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  Future<void> refreshNotes() async {
    state = const AsyncValue.loading();
    try {
      await _noteService.processNoteSyncQueue();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// Provider for note operations
final noteOperationsProvider =
    StateNotifierProvider<NoteOperationsNotifier, AsyncValue<void>>((ref) {
  final noteService = ref.watch(noteServiceProvider);
  return NoteOperationsNotifier(noteService);
});

// Helper to check if a verse has notes in current state
final verseHasNotesProvider =
    Provider.family<bool, ({String bookId, int chapterId, int verseId})>(
  (ref, params) {
    final notes = ref.watch(bibleNotesProvider);

    return notes.maybeWhen(
      data: (data) => data.any((note) =>
          note.bookId == params.bookId &&
          note.chapterId == params.chapterId &&
          note.verseId == params.verseId),
      orElse: () => false,
    );
  },
);

// Current editing note provider
final currentEditingNoteProvider = StateProvider<NoteModel?>((ref) => null);
