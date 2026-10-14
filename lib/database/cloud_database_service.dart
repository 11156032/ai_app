import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 雲端資料庫 API 服務
///
/// 統一管理所有對後端 REST API 的 HTTP 呼叫。
/// 使用 JWT Token 進行認證。
///
/// 用法：
/// ```dart
/// final cloud = CloudDatabaseService.instance;
/// await cloud.login('username', 'password');
/// final posts = await cloud.getPosts();
/// ```
class CloudDatabaseService {
  static final CloudDatabaseService instance = CloudDatabaseService._();
  CloudDatabaseService._();

  // ─── 設定 ───
  // 開發階段：API 跑在本機或同一台伺服器上
  // 上線後改為實際的 API URL
  static const String _baseUrl = 'http://140.131.114.242:8000';

  /// 當前登入的 JWT Token
  String? _token;

  /// 是否已登入
  bool get isLoggedIn => _token != null;

  /// 設定 Token（從登入結果或本地快取還原）
  void setToken(String? token) {
    _token = token;
  }

  // ─── 通用 HTTP 方法 ───

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParams);
    try {
      final response = await http.get(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('CloudDB GET $path 失敗: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _post(String path, {Object? body}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('CloudDB POST $path 失敗: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _put(String path, {Object? body}) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('CloudDB PUT $path 失敗: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('CloudDB DELETE $path 失敗: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }
    final detail = body is Map ? body['detail'] ?? '未知錯誤' : '未知錯誤';
    throw CloudApiException(response.statusCode, detail.toString());
  }

  // ═══════════════════════════════════════════════════════════════
  // 認證 API
  // ═══════════════════════════════════════════════════════════════

  /// 註冊新用戶，成功後自動設定 Token
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String displayName = '',
  }) async {
    final result = await _post('/api/auth/register', body: {
      'username': username,
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    _token = result['token'];
    return result;
  }

  /// 登入，成功後自動設定 Token
  Future<Map<String, dynamic>> login(String username, String password) async {
    final result = await _post('/api/auth/login', body: {
      'username': username,
      'password': password,
    });
    _token = result['token'];
    return result;
  }

  /// 取得當前用戶資料
  Future<Map<String, dynamic>> getMe() async {
    return await _get('/api/auth/me');
  }

  /// 更新當前用戶資料
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> updates) async {
    return await _put('/api/auth/me', body: updates);
  }

  /// 登出（清除 Token）
  void logout() {
    _token = null;
  }

  // ═══════════════════════════════════════════════════════════════
  // 社群貼文 API
  // ═══════════════════════════════════════════════════════════════

  /// 取得貼文列表
  Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int limit = 20,
    int? groupId,
    String? userId,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (groupId != null) params['group_id'] = groupId.toString();
    if (userId != null) params['user_id'] = userId;
    return await _get('/api/posts', queryParams: params);
  }

  /// 建立貼文
  Future<Map<String, dynamic>> createPost({
    required String content,
    String type = 'text',
    Map<String, dynamic>? attachedData,
    int? groupId,
  }) async {
    return await _post('/api/posts', body: {
      'content': content,
      'type': type,
      if (attachedData != null) 'attached_data': attachedData,
      if (groupId != null) 'group_id': groupId,
    });
  }

  /// 編輯貼文
  Future<Map<String, dynamic>> updatePost(int postId, String content) async {
    return await _put('/api/posts/$postId', body: {'content': content});
  }

  /// 刪除貼文
  Future<Map<String, dynamic>> deletePost(int postId) async {
    return await _delete('/api/posts/$postId');
  }

  /// 按讚/取消按讚
  Future<Map<String, dynamic>> toggleLike(int postId) async {
    return await _post('/api/posts/$postId/like');
  }

  /// 收藏/取消收藏
  Future<Map<String, dynamic>> toggleBookmark(int postId) async {
    return await _post('/api/posts/$postId/bookmark');
  }

  /// 取得貼文留言
  Future<Map<String, dynamic>> getComments(int postId) async {
    return await _get('/api/posts/$postId/comments');
  }

  /// 新增留言
  Future<Map<String, dynamic>> createComment({
    required int postId,
    required String text,
    int parentId = 0,
  }) async {
    return await _post('/api/posts/$postId/comments', body: {
      'text': text,
      'parent_id': parentId,
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 群組 API
  // ═══════════════════════════════════════════════════════════════

  /// 取得我的群組列表
  Future<Map<String, dynamic>> getMyGroups() async {
    return await _get('/api/groups');
  }

  /// 建立群組
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String description = '',
    String iconEmoji = '📚',
    String type = 'public',
    bool joinRequiresApproval = false,
    List<String> tags = const [],
  }) async {
    return await _post('/api/groups', body: {
      'name': name,
      'description': description,
      'icon_emoji': iconEmoji,
      'type': type,
      'join_requires_approval': joinRequiresApproval,
      'tags': tags,
    });
  }

  /// 探索公開群組
  Future<Map<String, dynamic>> discoverGroups() async {
    return await _get('/api/groups/discover');
  }

  /// 加入群組
  Future<Map<String, dynamic>> joinGroup(int groupId) async {
    return await _post('/api/groups/$groupId/join');
  }

  /// 離開群組
  Future<Map<String, dynamic>> leaveGroup(int groupId) async {
    return await _post('/api/groups/$groupId/leave');
  }

  /// 取得群組成員
  Future<Map<String, dynamic>> getGroupMembers(int groupId) async {
    return await _get('/api/groups/$groupId/members');
  }

  /// 透過邀請 Token 加入群組
  Future<Map<String, dynamic>> joinByToken(String token) async {
    return await _post('/api/groups/join-by-token/$token');
  }

  // ═══════════════════════════════════════════════════════════════
  // 工具方法
  // ═══════════════════════════════════════════════════════════════

  /// 檢查 API 健康狀態
  Future<bool> healthCheck() async {
    try {
      final result = await _get('/health');
      return result['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }
}

/// 雲端 API 例外
class CloudApiException implements Exception {
  final int statusCode;
  final String message;

  CloudApiException(this.statusCode, this.message);

  @override
  String toString() => 'CloudApiException($statusCode): $message';

  /// 是否為認證錯誤（Token 過期或無效）
  bool get isAuthError => statusCode == 401;

  /// 是否為權限不足
  bool get isForbidden => statusCode == 403;

  /// 是否為資源不存在
  bool get isNotFound => statusCode == 404;

  /// 是否為衝突（例如帳號已存在）
  bool get isConflict => statusCode == 409;
}
