import 'dart:async';
import 'package:flutter/foundation.dart';
import 'voice_note_service.dart';
import 'push_notification_service.dart';
import '../screens/notes_screen.dart';
import 'app_locale_service.dart';

/// 語音筆記背景整理任務資訊
class VoiceNoteBackgroundTask {
  final String id;
  final String transcript;
  final VoiceNoteStyle style;
  final VoiceNoteDetailLevel detailLevel;
  final String userId;
  final DateTime startTime;
  final void Function(
    String title,
    String category,
    String markdownContent,
    Map<String, dynamic>? mindmapJson,
    List<ActionItem>? actionItems,
  )? onNoteReady;

  VoiceNoteBackgroundTask({
    required this.id,
    required this.transcript,
    required this.style,
    this.detailLevel = VoiceNoteDetailLevel.detailed,
    required this.userId,
    required this.startTime,
    this.onNoteReady,
  });
}

/// 全域 AI 語音筆記背景整理管理器 (Singleton / ChangeNotifier)
/// 允許使用者在 AI 整理期間隨時退出或切換視窗，完成後自動發送系統推播並於 App 內顯示橫幅
class VoiceNoteBackgroundManager extends ChangeNotifier {
  VoiceNoteBackgroundManager._internal();
  static final VoiceNoteBackgroundManager instance =
      VoiceNoteBackgroundManager._internal();

  VoiceNoteBackgroundTask? _currentTask;
  bool _isGenerating = false;
  double _progress = 0.0;
  String? _stageText;
  VoiceNoteResult? _lastCompletedResult;
  Note? _lastCreatedNote;
  String? _lastErrorMessage;
  DateTime? _completedTime;

  VoiceNoteBackgroundTask? get currentTask => _currentTask;
  bool get isGenerating => _isGenerating;
  double get progress => _progress;
  String? get stageText => _stageText;
  VoiceNoteResult? get lastCompletedResult => _lastCompletedResult;
  Note? get lastCreatedNote => _lastCreatedNote;
  String? get lastErrorMessage => _lastErrorMessage;
  DateTime? get completedTime => _completedTime;

  /// 啟動 AI 背景整理任務
  Future<void> startBackgroundTask({
    required String transcript,
    required VoiceNoteStyle style,
    VoiceNoteDetailLevel detailLevel = VoiceNoteDetailLevel.detailed,
    required String userId,
    void Function(
      String title,
      String category,
      String markdownContent,
      Map<String, dynamic>? mindmapJson,
      List<ActionItem>? actionItems,
    )? onNoteReady,
  }) async {
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    _currentTask = VoiceNoteBackgroundTask(
      id: taskId,
      transcript: transcript,
      style: style,
      detailLevel: detailLevel,
      userId: userId,
      startTime: DateTime.now(),
      onNoteReady: onNoteReady,
    );
    _isGenerating = true;
    _progress = 0.1;
    _stageText = tr('vb_stage');
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final result = await VoiceNoteService.instance.organizeTranscript(
        transcript: transcript,
        style: style,
        detailLevel: detailLevel,
        userId: userId,
      );

      _isGenerating = false;
      _progress = 1.0;
      _stageText = tr('vb_done');
      _lastCompletedResult = result;
      _completedTime = DateTime.now();

      // 若外部有自訂回調 (如在特定編輯器中追加內容)
      if (_currentTask?.onNoteReady != null) {
        _currentTask!.onNoteReady!(
          result.title,
          result.category,
          result.markdownContent,
          result.mindmapJson,
          result.actionItems,
        );
      } else {
        // 自動新增筆記至 NotesDatabase
        final effectiveCategory =
            result.category.isNotEmpty ? result.category : style.suggestedCategory;
        if (!NotesDatabase.categories.contains(effectiveCategory)) {
          NotesDatabase.categories.add(effectiveCategory);
        }
        final newNote = Note(
          id: 'note_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          title: result.title.isEmpty ? tr('notes_voice_default_title') : result.title,
          content: result.markdownContent,
          category: effectiveCategory,
          strokes: [],
          updatedAt: DateTime.now(),
          mindmapJson: result.mindmapJson,
          actionItems: result.actionItems,
        );
        NotesDatabase.notes.insert(0, newNote);
        _lastCreatedNote = newNote;
      }

      // 發送系統本地推播通知 (鎖定螢幕/背景時亦會彈出)
      await PushNotificationService().showLocalNotification(
        title: tr('vb_notif_title'),
        body: tr('vb_notif_body', [result.title.toString()]),
        payload: _lastCreatedNote?.id ?? 'voice_note_done',
      );

      _currentTask = null;
      notifyListeners();
    } catch (e) {
      debugPrint('VoiceNoteBackgroundManager error: $e');
      _isGenerating = false;
      _lastErrorMessage = e.toString();
      _currentTask = null;
      notifyListeners();

      await PushNotificationService().showLocalNotification(
        title: tr('vb_fail_title'),
        body: tr('vb_fail_body'),
      );
    }
  }

  /// 清除已完成提示狀態
  void dismissCompletedNotification() {
    _lastCompletedResult = null;
    _lastCreatedNote = null;
    notifyListeners();
  }
}
