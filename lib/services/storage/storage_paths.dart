import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Centralized filesystem layout for Portfolio Manager.
///
/// Everything the app writes on the user device is namespaced under a
/// single root directory named `PortfolioManager`. The tree is:
///
/// ```
/// [ApplicationDocumentsDirectory]/
///   PortfolioManager/
///     data/         Hive databases (portfolios, goals, settings)
///     cache/
///       market/     Downloaded market snapshots (top_movers, prices_index)
///     imports/      Optional local copy of CSV/PDF files imported by the user
///     exports/      User-triggered JSON/PDF backups
/// ```
///
/// API keys are NOT stored here: they live in `flutter_secure_storage`
/// (platform-backed keystore) and never touch the visible filesystem.
///
/// On web, Flutter IO is not available and Hive uses IndexedDB. All
/// getters return a stable sentinel (`/portfolio_manager_web`) that is
/// not used as a real filesystem path.
class StoragePaths {
  StoragePaths._();

  static const String rootDirName = 'PortfolioManager';
  static const String dataDirName = 'data';
  static const String cacheDirName = 'cache';
  static const String marketCacheDirName = 'market';
  static const String importsDirName = 'imports';
  static const String exportsDirName = 'exports';

  static const String _webSentinel = '/portfolio_manager_web';

  static String? _root;
  static String? _data;
  static String? _cache;
  static String? _marketCache;
  static String? _imports;
  static String? _exports;

  /// Resolve and create (if needed) the full directory tree.
  ///
  /// Must be called before any consumer that relies on [dataDir],
  /// [marketCacheDir] and friends -- in particular before Hive
  /// initialization in [LocalStorageService.init].
  static Future<void> init() async {
    if (kIsWeb) {
      _root = _webSentinel;
      _data = '$_webSentinel/$dataDirName';
      _cache = '$_webSentinel/$cacheDirName';
      _marketCache = '$_webSentinel/$cacheDirName/$marketCacheDirName';
      _imports = '$_webSentinel/$importsDirName';
      _exports = '$_webSentinel/$exportsDirName';
      return;
    }

    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}${Platform.pathSeparator}$rootDirName');
    await _ensureDir(root);

    final data =
        Directory('${root.path}${Platform.pathSeparator}$dataDirName');
    final cache =
        Directory('${root.path}${Platform.pathSeparator}$cacheDirName');
    final marketCache = Directory(
        '${cache.path}${Platform.pathSeparator}$marketCacheDirName');
    final imports =
        Directory('${root.path}${Platform.pathSeparator}$importsDirName');
    final exports =
        Directory('${root.path}${Platform.pathSeparator}$exportsDirName');

    // marketCache is a child of cache, so creating it with recursive:true
    // covers the parent. We skip the explicit cache create to keep the
    // intent clear (no "who wins if these race" question).
    await Future.wait<void>([
      _ensureDir(data),
      _ensureDir(marketCache),
      _ensureDir(imports),
      _ensureDir(exports),
    ]);

    _root = root.path;
    _data = data.path;
    _cache = cache.path;
    _marketCache = marketCache.path;
    _imports = imports.path;
    _exports = exports.path;
  }

  static Future<void> _ensureDir(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Root app directory (e.g. .../Documents/PortfolioManager).
  static String get rootDir => _orThrow(_root, 'rootDir');

  /// Hive databases live here.
  static String get dataDir => _orThrow(_data, 'dataDir');

  /// General cache dir -- safe to delete, regenerated on demand.
  static String get cacheDir => _orThrow(_cache, 'cacheDir');

  /// Market snapshots downloaded from the public pipeline.
  static String get marketCacheDir =>
      _orThrow(_marketCache, 'marketCacheDir');

  /// Optional local copy of broker import files (CSV/PDF) retained for
  /// re-processing.
  static String get importsDir => _orThrow(_imports, 'importsDir');

  /// User-triggered backups (JSON portfolio + goals).
  static String get exportsDir => _orThrow(_exports, 'exportsDir');

  static String _orThrow(String? value, String name) {
    if (value == null) {
      throw StateError(
        'StoragePaths.$name accessed before StoragePaths.init() completed',
      );
    }
    return value;
  }

  /// True once [init] has populated the paths.
  static bool get isReady => _root != null;
}
