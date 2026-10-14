import 'dart:async';
import 'dart:io' show Directory, File;
import 'package:flutter/foundation.dart' show kIsWeb;

/// 代表專案中單一 Dart 原始碼檔案的基礎資訊
class DartFileInfo {
  /// 專案相對路徑，例如：`lib/screens/main_screen.dart`
  final String relativePath;

  /// 檔案名稱，例如：`main_screen.dart`
  final String name;

  /// 所屬目錄層級，例如：`screens`, `widgets`, `services`, `database`, `utils`
  final String folder;

  /// 實際總行數
  final int lineCount;

  /// 是否為 Part 分片檔案 (`*.part.dart`)
  final bool isPart;

  const DartFileInfo({
    required this.relativePath,
    required this.name,
    required this.folder,
    required this.lineCount,
    this.isPart = false,
  });

  @override
  String toString() => '$relativePath ($lineCount 行)';
}

/// 專案架構掃描服務
///
/// 負責於開發環境本機安全讀取 `lib/` 原始碼檔案清單與行數統計。
/// 設計為完全非阻塞、保證不崩潰 (Crash-safe)，當環境不支援本機檔案讀取時安全回傳空值。
class ArchitectureScannerService {
  /// 檢查目前執行環境是否具備讀取 `lib/` 檔案之能力
  static bool isAvailable() {
    if (kIsWeb) return false;
    try {
      final libDir = _findLibDirectory();
      return libDir != null && libDir.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// 安全搜尋專案中的 `lib/` 目錄
  static Directory? _findLibDirectory() {
    if (kIsWeb) return null;
    try {
      // 1. 檢查當前工作目錄下的 lib
      final currentLib = Directory('lib');
      if (currentLib.existsSync()) {
        return currentLib;
      }

      // 2. 檢查當前目錄本身是否就是 lib
      final currentDir = Directory.current;
      if (currentDir.path.endsWith('lib') && currentDir.existsSync()) {
        return currentDir;
      }

      // 3. 向上一至兩層尋找 lib（適用於不同終端或測試執行目錄）
      var parent = currentDir.parent;
      for (int i = 0; i < 2; i++) {
        final candidate = Directory('${parent.path}/lib');
        if (candidate.existsSync()) {
          return candidate;
        }
        parent = parent.parent;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// 掃描 `lib/` 目錄下所有的 `.dart` 檔案並統計實際行數
  ///
  /// 若發生任何 I/O 錯誤或處於不支援環境，將安全回傳空列表，絕不拋出例外。
  static Future<List<DartFileInfo>> scanProjectFiles() async {
    if (kIsWeb) return [];

    final results = <DartFileInfo>[];
    try {
      final libDir = _findLibDirectory();
      if (libDir == null || !libDir.existsSync()) {
        return [];
      }

      final entities = libDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.dart')) {
          try {
            // 正規化路徑為斜線格式
            final normalizedPath = entity.path.replaceAll(r'\', '/');
            final libIndex = normalizedPath.indexOf('lib/');
            final relativePath = libIndex != -1
                ? normalizedPath.substring(libIndex)
                : entity.path;

            final name = relativePath.split('/').last;

            // 判斷所屬資料夾類別（例如 screens, widgets, services, database）
            final pathSegments = relativePath.split('/');
            String folder = 'root';
            if (pathSegments.length > 2) {
              folder = pathSegments[1];
            }

            final lines = await entity.readAsLines();
            final isPart = name.contains('.part.dart');

            results.add(DartFileInfo(
              relativePath: relativePath,
              name: name,
              folder: folder,
              lineCount: lines.length,
              isPart: isPart,
            ));
          } catch (_) {
            // 忽略單一檔案讀取異常，繼續處理其他檔案
          }
        }
      }
    } catch (_) {
      return [];
    }

    return results;
  }

  /// 取得依行數由大到小排序之檔案清單（大型檔案排行）
  ///
  /// - [limit] 最多回傳幾筆資料（預設 15 筆，傳入 <= 0 則不限制）
  /// - [minLines] 最低行數門檻（預設 0 行）
  static Future<List<DartFileInfo>> getLargeFiles({
    int limit = 15,
    int minLines = 0,
  }) async {
    final allFiles = await scanProjectFiles();
    if (allFiles.isEmpty) return [];

    final filtered = allFiles.where((f) => f.lineCount >= minLines).toList()
      ..sort((a, b) => b.lineCount.compareTo(a.lineCount));

    if (limit > 0 && filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }

  /// 依資料夾層級將檔案分組（例如 screens, widgets, services, database）
  static Future<Map<String, List<DartFileInfo>>> getFilesByFolder() async {
    final allFiles = await scanProjectFiles();
    final grouped = <String, List<DartFileInfo>>{};

    for (final file in allFiles) {
      grouped.putIfAbsent(file.folder, () => []).add(file);
    }

    // 每個資料夾內的檔案依行數由大到小排序
    for (final folder in grouped.keys) {
      grouped[folder]!.sort((a, b) => b.lineCount.compareTo(a.lineCount));
    }

    return grouped;
  }
}
