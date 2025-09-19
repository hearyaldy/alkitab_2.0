import 'package:flutter/material.dart';

class LazyLoadingService {
  static final LazyLoadingService _instance = LazyLoadingService._internal();
  factory LazyLoadingService() => _instance;
  LazyLoadingService._internal();

  static const int defaultPageSize = 20;
  static const int defaultThreshold = 5;

  Future<List<T>> loadPage<T>({
    required List<T> fullList,
    required int page,
    int pageSize = defaultPageSize,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));

    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, fullList.length);

    if (startIndex >= fullList.length) {
      return [];
    }

    return fullList.sublist(startIndex, endIndex);
  }

  bool hasMoreData<T>(List<T> fullList, int currentPage, int pageSize) {
    final totalPages = (fullList.length / pageSize).ceil();
    return currentPage < totalPages - 1;
  }

  bool shouldLoadNext(int currentIndex, int loadedCount, int threshold) {
    return currentIndex >= loadedCount - threshold;
  }
}

class LazyListController<T> extends ChangeNotifier {
  final List<T> _fullList;
  final List<T> _loadedItems = [];
  final int pageSize;
  final int threshold;

  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  LazyListController({
    required List<T> fullList,
    this.pageSize = LazyLoadingService.defaultPageSize,
    this.threshold = LazyLoadingService.defaultThreshold,
  }) : _fullList = fullList {
    _loadInitialPage();
  }

  List<T> get items => List.unmodifiable(_loadedItems);
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  bool get hasMoreData => LazyLoadingService().hasMoreData(_fullList, _currentPage, pageSize);
  int get totalCount => _fullList.length;
  int get loadedCount => _loadedItems.length;

  Future<void> _loadInitialPage() async {
    await _loadNextPage();
  }

  Future<void> loadMore() async {
    if (_isLoading || !hasMoreData) return;
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    _setLoading(true);
    _clearError();

    try {
      final newItems = await LazyLoadingService().loadPage<T>(
        fullList: _fullList,
        page: _currentPage,
        pageSize: pageSize,
      );

      _loadedItems.addAll(newItems);
      _currentPage++;

      debugPrint('Loaded page $_currentPage: ${newItems.length} items (Total: ${_loadedItems.length}/${_fullList.length})');
    } catch (e) {
      _setError('Failed to load more items: $e');
      debugPrint('Error loading page: $e');
    } finally {
      _setLoading(false);
    }
  }

  void checkAndLoadMore(int currentIndex) {
    if (LazyLoadingService().shouldLoadNext(currentIndex, _loadedItems.length, threshold)) {
      loadMore();
    }
  }

  void refresh(List<T> newFullList) {
    _fullList.clear();
    _fullList.addAll(newFullList);
    _loadedItems.clear();
    _currentPage = 0;
    _clearError();
    _loadInitialPage();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _hasError = true;
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _hasError = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _loadedItems.clear();
    super.dispose();
  }
}

class ImagePreloadingService {
  static final ImagePreloadingService _instance = ImagePreloadingService._internal();
  factory ImagePreloadingService() => _instance;
  ImagePreloadingService._internal();

  final Set<String> _preloadedImages = {};
  final Set<String> _preloadingImages = {};

  Future<void> preloadImage(String imageUrl, {required BuildContext context}) async {
    if (_preloadedImages.contains(imageUrl) || _preloadingImages.contains(imageUrl)) {
      return;
    }

    _preloadingImages.add(imageUrl);

    try {
      final ImageProvider provider = NetworkImage(imageUrl);
      await precacheImage(provider, context);
      _preloadedImages.add(imageUrl);
      debugPrint('Preloaded image: $imageUrl');
    } catch (e) {
      debugPrint('Failed to preload image $imageUrl: $e');
    } finally {
      _preloadingImages.remove(imageUrl);
    }
  }

  void preloadImagesInRange(
    List<String> imageUrls,
    int currentIndex,
    BuildContext context, {
    int preloadRange = 3,
  }) {
    final startIndex = (currentIndex - preloadRange).clamp(0, imageUrls.length);
    final endIndex = (currentIndex + preloadRange + 1).clamp(0, imageUrls.length);

    for (int i = startIndex; i < endIndex; i++) {
      if (i < imageUrls.length) {
        preloadImage(imageUrls[i], context: context);
      }
    }
  }

  bool isPreloaded(String imageUrl) => _preloadedImages.contains(imageUrl);

  void clearCache() {
    _preloadedImages.clear();
    _preloadingImages.clear();
  }
}

class OptimizedListWidget<T> extends StatefulWidget {
  final LazyListController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? loadingIndicator;
  final Widget? errorWidget;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;

  const OptimizedListWidget({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.loadingIndicator,
    this.errorWidget,
    this.padding,
    this.physics,
  });

  @override
  State<OptimizedListWidget<T>> createState() => _OptimizedListWidgetState<T>();
}

class _OptimizedListWidgetState<T> extends State<OptimizedListWidget<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.hasError) {
      return widget.errorWidget ??
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                widget.controller.errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => widget.controller.loadMore(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      itemCount: widget.controller.items.length + (widget.controller.hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < widget.controller.items.length) {
          widget.controller.checkAndLoadMore(index);
          return widget.itemBuilder(context, widget.controller.items[index], index);
        } else {
          return widget.loadingIndicator ??
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
        }
      },
    );
  }
}