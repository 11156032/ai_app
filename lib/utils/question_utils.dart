import 'dart:convert';
import 'package:flutter/material.dart';

/// 題庫共用小工具函式
abstract final class QuestionUtils {
  /// 解析題目選項（支援 List、JSON 字串或逗號分隔字串）
  static List<String> parseOptions(dynamic rawOptions) {
    if (rawOptions == null) return [];
    if (rawOptions is List) {
      return rawOptions.map((item) => item.toString()).toList();
    }
    if (rawOptions is String && rawOptions.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawOptions);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (_) {
        return rawOptions
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  /// 取得正確答案索引（支援 answerIndex, answer 欄位，容錯轉型）
  static int getCorrectAnswerIndex(Map<String, dynamic> question) {
    final raw = question['answerIndex'] ?? question['answer'] ?? 0;
    return int.tryParse(raw.toString()) ?? 0;
  }

  /// 取得題目文字內容（支援 question, text 欄位）
  static String getQuestionText(Map<String, dynamic> question) {
    return (question['question'] ?? question['text'] ?? '').toString();
  }

  /// 取得當前使用者 ID（容錯 'id' 或 'user_id'）
  static String getUserId(dynamic currentUser, {String fallback = 'u1'}) {
    if (currentUser is Map) {
      final id = currentUser['id'] ?? currentUser['user_id'];
      if (id != null && id.toString().trim().isNotEmpty) {
        return id.toString();
      }
    }
    return fallback;
  }

  /// 將不同格式的難度字串標準化為 '易' | '中' | '難' | '無'
  static String normalizeDifficulty(dynamic raw, {String fallback = '無'}) {
    if (raw == null) return fallback;
    final str = raw.toString().trim().toLowerCase();
    if (str.isEmpty || str == 'null' || str == '無' || str == 'none') {
      return fallback;
    }
    if (str == 'easy' || str == '易' || str == '簡單' || str == '基礎') {
      return '易';
    }
    if (str == 'medium' || str == '中' || str == '中等' || str == '一般') {
      return '中';
    }
    if (str == 'hard' || str == '難' || str == '困難' || str == '進階' || str == '高難度') {
      return '難';
    }
    return raw.toString().trim();
  }

  /// 根據難度回傳對應的標籤顏色
  static Color getDifficultyColor(String? diff) {
    final normalized = normalizeDifficulty(diff);
    switch (normalized) {
      case '易':
        return const Color(0xFF10B981);
      case '中':
        return const Color(0xFFF59E0B);
      case '難':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// 格式化相對時間（例如：剛剛、5 分鐘前、2 小時前）
  static String formatRelativeTime(dynamic rawTime) {
    if (rawTime == null) return '';
    try {
      final dt = DateTime.tryParse(rawTime.toString());
      if (dt == null) return rawTime.toString();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '剛剛';
      if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
      if (diff.inHours < 24) return '${diff.inHours} 小時前';
      if (diff.inDays < 7) return '${diff.inDays} 天前';
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
