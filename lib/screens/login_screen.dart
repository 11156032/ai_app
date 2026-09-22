import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../widgets/common_widgets.dart';
import 'login/widgets/login_brand_logo.dart';
import 'login/widgets/login_flow_background.dart';
import 'login/widgets/login_success_overlay.dart';
import 'login/widgets/google_sign_in_modal.dart';

// ── 別名相容定義 ─────────────────────────────────────────────────────────────
typedef _BrandMark = LoginBrandMark;
typedef _LoginSuccessOverlay = LoginSuccessOverlay;
typedef _GlassCard = LoginGlassCard;
typedef _AmbientFlowBackground = LoginAmbientFlowBackground;
typedef _FocusedGlowField = LoginFocusedGlowField;
typedef _GoogleSignInModal = GoogleSignInModal;
Widget _exquisiteFadeIn({
  required Widget child,
  required int delayMs,
  double from = 40,
}) =>
    exquisiteFadeIn(child: child, delayMs: delayMs, from: from);

// ── 主體 ─────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool _isSuccess = false; // 用於登入成功後隱藏表單，避免閃現登入畫面
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false; // 註冊時必須勾選吀意服務條款與隱私權政策

  // ── 登入成功動畫 ────────────────────────────────────────────────────────
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = '@gmail.com';
    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        if (_emailCtrl.text == '@gmail.com') {
          _emailCtrl.selection = const TextSelection.collapsed(offset: 0);
        }
      }
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _emailCtrl.dispose();
    _emailFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _showSuccessOverlay(Map<String, dynamic> userMap) {
    setState(() => _isSuccess = true);
    final displayName =
        (userMap['display_name'] ?? userMap['username'] ?? '您').toString();
    _overlayEntry = OverlayEntry(
      builder: (_) => Material(
        color: Colors.transparent,
        child: _LoginSuccessOverlay(
          displayName: displayName,
          onComplete: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
            widget.onLogin(userMap);
          },
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  // ── 樣式常數 ──────────────────────────────────────────────────────────────
  static final _primaryColor = Color(0xFF8D6E63);
  static const _bgColor = Color(0xFFF7F3F0);

  InputDecoration _inputDeco(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Color(0xFF8D6E63), fontSize: 13.5),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: Colors.white.withValues(alpha: 0.45), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: Color(0xFF8D6E63).withValues(alpha: 0.7), width: 1.8),
      ),
      suffixIcon: suffix,
    );
  }

  Future<void> _forgotPassword() async {
    final TextEditingController emailResetCtrl = TextEditingController();
    if (_emailCtrl.text.isNotEmpty && _emailCtrl.text != '@gmail.com') {
      emailResetCtrl.text = _emailCtrl.text;
    }

    final bool? emailExists = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('忘記密碼'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('請輸入您註冊時使用的電子信箱，以進行密碼重設。'),
            const SizedBox(height: 14),
            TextField(
              controller: emailResetCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco('電子信箱',
                  suffix: const Icon(Icons.email_outlined,
                      color: Color(0xFFBCAAA4))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final email = emailResetCtrl.text.trim();
              if (email.isEmpty || email == '@gmail.com') {
                ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                  SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('請輸入有效的信箱')),
                );
                return;
              }

              try {
                final db = await DatabaseHelper.instance.database;
                final res = await db
                    .query('users', where: 'email = ?', whereArgs: [email]);
                if (res.isEmpty) {
                  if (!ctx.mounted) return;
                  showDialog(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title: const Text('提示'),
                      content: const Text('找不到此信箱對應的帳號，請確認信箱是否輸入正確。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('確定'),
                        ),
                      ],
                    ),
                  );
                } else {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                }
              } catch (e) {
                debugPrint('查詢帳號失敗: $e');
              }
            },
            child: const Text('下一步'),
          ),
        ],
      ),
    );

    if (emailExists == true) {
      final targetEmail = emailResetCtrl.text.trim();
      if (!mounted) return;

      final TextEditingController newPasswordCtrl = TextEditingController();
      final TextEditingController confirmPasswordCtrl = TextEditingController();
      bool obscureNew = true;
      bool obscureConfirm = true;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('重設新密碼'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('帳號驗證成功！請輸入您的新密碼。'),
                const SizedBox(height: 14),
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: obscureNew,
                  decoration: _inputDeco(
                    '新密碼',
                    suffix: IconButton(
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFBCAAA4),
                      ),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordCtrl,
                  obscureText: obscureConfirm,
                  decoration: _inputDeco(
                    '確認新密碼',
                    suffix: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFBCAAA4),
                      ),
                      onPressed: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newPass = newPasswordCtrl.text;
                  final confPass = confirmPasswordCtrl.text;

                  if (newPass.isEmpty || confPass.isEmpty) {
                    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                      SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('欄位不可為空')),
                    );
                    return;
                  }
                  if (newPass != confPass) {
                    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                      SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('兩次輸入密碼不同')),
                    );
                    return;
                  }

                  try {
                    final db = await DatabaseHelper.instance.database;
                    await db.update(
                      'users',
                      <String, Object?>{'hashed_password': newPass},
                      where: 'email = ?',
                      whereArgs: [targetEmail],
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);

                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('重設成功'),
                        content: const Text('您的密碼已成功更新！請使用新密碼進行登入。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('確定'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    debugPrint('更新密碼失敗: $e');
                  }
                },
                child: const Text('完成重設'),
              ),
            ],
          );
        }),
      );
    }
  }

  // 登入頁內嵌條款/隱私彈窗（服務條款與隱私權政策的精簡版本）
  void _showInlineDialog({
    required BuildContext context,
    required String title,
    required IconData icon,
  }) {
    final isTerms = title == '服務條款';
    final themeColor =
        isTerms ? const Color(0xFFD97706) : const Color(0xFF0D9488);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isTerms ? Icons.gavel_rounded : Icons.security_rounded,
                color: themeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2022),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v1.8.0',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTerms ? '法定權益與平台使用規範' : '本機優先加密與個資保護承諾',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: isTerms
                  ? [
                      _buildInlineSection(
                        '1. 接受條款與服務範疇',
                        '您使用「YeBang 家教」即代表您已閱讀並同意受本條款約束。本服務提供題庫測驗、AI 步驟詳解、AI 語音速記（5 大整理風格）、互動心智圖、學科能力診斷、弱項補強教材、智慧筆記（Markdown與 AI 摘要）、智慧行事曆排程與 24H 線上客服等多元功能。',
                        themeColor,
                      ),
                      _buildInlineSection(
                        '2. 帳號責任與資安保護',
                        '您有責任妥善保管帳號憑證（Email、密碼或 Google 授權），並對帳號下發生的所有活動負完全責任。禁止共用或轉讓帳號；如發現遭未經授權使用，請立即通知我們。',
                        themeColor,
                      ),
                      _buildInlineSection(
                        '3. 行為規範與智慧財產權',
                        '嚴禁散佈違法、侵權、騷擾或不當內容；嚴禁傳播惡意程式碼、爬蟲抓取或以自動化工具濫用系統與 AI 資源。本軟體所有設計、程式碼與題庫資料庫均受著作權法保護；個人筆記著作權歸屬本人。',
                        themeColor,
                      ),
                      _buildInlineSection(
                        '4. AI 生成內容與語音輔助聲明',
                        'AI 智慧特助、語音辨識、詳解與診斷由尖端模型（含 Gemini、Groq、Speech-to-Text 等）提供支援，其回覆內容為「學習輔助參考資料」，不構成考試唯一標準或專業法律保證。',
                        themeColor,
                      ),
                      _buildInlineSection(
                        '5. 免責聲明與管轄法院',
                        '本服務依現狀提供。條款依中華民國法律為準據法，並以台灣台北地方法院為第一審管轄法院。版本：v1.8.0（修訂發布：2026 年 9 月 23 日）。',
                        themeColor,
                      ),
                    ]
                  : [
                      _buildInlineSection(
                        '1. 蒐集的資料類型（最小化原則）',
                        '帳號資訊（姓名、Email、頭像）、學習歷程（測驗紀錄、正確率、錯題本、文字筆記、心智圖、行事曆待辦）、即時語音輸入串流（僅主動點擊錄音時轉換，不持久保存錄音）及系統偏好（深淺色、主題色、語系）。',
                        themeColor,
                      ),
                      _buildInlineSection(
                        '2. 資料使用目的與【絕不出售承諾】',
                        '僅用於提供功能、運算能力掌握度矩陣並生成客製化學習建議。【嚴格承諾絕不販售、出租或出借個人資料給任何第三方】。',
                        themeColor,
                      ),
                      _buildInlineSection(
                        '3. 本機優先儲存與傳輸安全',
                        '學習歷程與筆記主要加密儲存於本機 SQLite 資料庫中；雲端功能傳輸全面採用標準 HTTPS / TLS 1.3 傳輸層加密。',
                        themeColor,
                      ),
                      _buildInlineSection(
                        '4. 使用者完整個資自主權利',
                        '您可隨時查詢、修改個人資料，或申請註銷刪除帳號（或訪客一鍵清除本機暫存），徹底清除關聯資料。',
                        themeColor,
                      ),
                      _buildInlineSection(
                        '5. 第三方服務安全規範',
                        '整合 Google 登入、Google Gemini AI、Groq AI、Speech-to-Text 及 Cloudflare 中繼站等服務，資料僅供當次推理使用。版本：v1.8.0（修訂發布：2026 年 9 月 23 日）。',
                        themeColor,
                      ),
                    ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '我已完整閱讀並了解',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineSection(String title, String content, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4A4A4A),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final inputEmail = _emailCtrl.text.trim();
    final inputPassword = _passwordCtrl.text.trim();
    final inputUsername = _usernameCtrl.text.trim();
    final inputConfirm = _confirmPasswordCtrl.text.trim();

    if (isLogin) {
      if (inputEmail.isEmpty ||
          inputEmail == '@gmail.com' ||
          inputPassword.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('信箱與密碼不得為空')));
        return;
      }
    } else {
      if (inputUsername.isEmpty ||
          inputEmail.isEmpty ||
          inputEmail == '@gmail.com' ||
          inputPassword.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('所有欄位皆不得為空')));
        return;
      }
      if (inputPassword != inputConfirm) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('提示'),
                  content: const Text('兩次輸入的密碼不相同，請重新確認！'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('確定'))
                  ],
                ));
        return;
      }
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1500), 
            content: Text('請先閱讀並勾選同意「服務條款」與「隱私權政策」才能完成註冊。'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    try {
      final db = await DatabaseHelper.instance.database;

      if (isLogin) {
        final res = await db.query('users',
            where: 'LOWER(email) = LOWER(?) AND hashed_password = ?',
            whereArgs: [inputEmail, inputPassword]);
        if (!mounted) return;
        if (res.isNotEmpty) {
          final userMap = Map<String, dynamic>.from(res.first);

          // 處理刪除復原邏輯 (自動刪除由系統背景或啟動時處理)
          if (userMap['deleted_at'] != null) {
            if (!mounted) return;
            final shouldRestore = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('帳號復原提示'),
                content: const Text('您的帳號已排程刪除。是否要取消刪除並復原帳號？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('確認復原')),
                ],
              ),
            );
            if (shouldRestore == true) {
              await db.update('users', <String, Object?>{'deleted_at': null},
                  where: 'id = ?', whereArgs: [userMap['id']]);
              userMap['deleted_at'] = null;
            } else {
              return; // 放棄登入
            }
          }

          userMap['session_post_ids'] = <int>{};
          userMap['session_comment_ids'] = <int>{};
          _showSuccessOverlay(userMap);
        } else {
          final userCheck = await db.query('users',
              where: 'LOWER(email) = LOWER(?)', whereArgs: [inputEmail]);
          if (!mounted) return;
          if (userCheck.isNotEmpty) {
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text('密碼錯誤'),
                      content: const Text('您輸入的密碼不正確，請重新輸入。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('確定'))
                      ],
                    ));
          } else {
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text('找不到帳號'),
                      content: const Text('此信箱尚未註冊，請先建立新帳號再登入。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('確定'))
                      ],
                    ));
          }
        }
      } else {
        // 註冊
        try {
          // 在註冊前，先明確以「不區分大小寫」的方式檢查是否已有相同的信箱或使用者名稱
          final checkRes = await db.query('users',
              where: 'LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?)',
              whereArgs: [inputUsername, inputEmail]);

          if (checkRes.isNotEmpty) {
            if (!mounted) return;
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text('註冊失敗'),
                      content: const Text('此帳號名稱或信箱已被使用，請換一個試試。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('確定'))
                      ],
                    ));
            return;
          }

          String newId = 'u_${DateTime.now().millisecondsSinceEpoch}';
          await db.insert('users', <String, Object?>{
            'id': newId,
            'username': inputUsername,
            'email': inputEmail,
            'hashed_password': inputPassword,
            'display_name': inputUsername,
          });
          _passwordCtrl.clear();
          _confirmPasswordCtrl.clear();
          if (!mounted) return;
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('註冊成功'),
                    content: const Text('帳號建立完成！請使用帳號密碼登入。'),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => isLogin = true);
                          },
                          child: const Text('前往登入'))
                    ],
                  ));
        } catch (e) {
          if (!mounted) return;
          String errorMsg = '發生未知的錯誤，請稍後再試。';
          if (!e.toString().contains('UNIQUE constraint failed')) {
            errorMsg += '\n錯誤詳情：$e';
          }

          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('註冊失敗'),
                    content: Text(errorMsg),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('確定'))
                    ],
                  ));
        }
      }
    } catch (e) {
      debugPrint('資料庫連線失敗: $e');
    }
  }

  // ── Google 登入邏輯 ────────────────────────────────────────────────────────
  void _showGoogleSignInDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Google Sign In',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value) * 0.12 + 0.88,
          child: Opacity(
            opacity: anim1.value,
            child: _GoogleSignInModal(
              onAccountSelected: (email, name) async {
                Navigator.pop(ctx);
                await _handleGoogleLogin(email, name);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleGoogleLogin(String email, String displayName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res =
          await db.query('users', where: 'email = ?', whereArgs: [email]);
      if (!mounted) return;

      Map<String, dynamic> userMap;
      if (res.isNotEmpty) {
        userMap = Map<String, dynamic>.from(res.first);
        // 如果存在但尚未標記為 google 登入，則更新為 google 登入
        if (userMap['is_google'] != 1) {
          await db.update('users', <String, Object?>{'is_google': 1},
              where: 'id = ?', whereArgs: [userMap['id']]);
          userMap['is_google'] = 1;
        }

        // 處理刪除復原邏輯
        if (userMap['deleted_at'] != null) {
          if (!mounted) return;
          final shouldRestore = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('帳號復原提示'),
              content: const Text('您的帳號已排程刪除。是否要取消刪除並復原帳號？'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('確認復原')),
              ],
            ),
          );
          if (shouldRestore == true) {
            await db.update('users', <String, Object?>{'deleted_at': null},
                where: 'id = ?', whereArgs: [userMap['id']]);
            userMap['deleted_at'] = null;
          } else {
            return; // 放棄登入
          }
        }
      } else {
        // 註冊新的 Google 帳號
        String baseUsername = displayName.trim().isNotEmpty
            ? displayName.trim()
            : (email.contains('@') ? email.split('@')[0] : 'google_user');

        String uniqueUsername = baseUsername;
        int counter = 1;
        while (true) {
          final existing = await db.query('users',
              where: 'username = ?', whereArgs: [uniqueUsername]);
          if (existing.isEmpty) break;
          uniqueUsername = '${baseUsername}_$counter';
          counter++;
        }

        String newId = 'g_${DateTime.now().millisecondsSinceEpoch}';
        final newUserData = {
          'id': newId,
          'username': uniqueUsername,
          'email': email,
          'hashed_password': 'google_oauth_bypass',
          'display_name':
              displayName.trim().isNotEmpty ? displayName : uniqueUsername,
          'is_google': 1,
          'is_email_verified': 1,
        };
        await db.insert('users', newUserData);
        userMap = newUserData;
      }

      userMap['session_post_ids'] = <int>{};
      userMap['session_comment_ids'] = <int>{};
      _showSuccessOverlay(userMap);
    } catch (e) {
      debugPrint('Google 登入失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('Google 登入失敗：$e')),
        );
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return const Scaffold(backgroundColor: _bgColor);
    }
    // 每次切換 isLogin 時，key 重建讓動畫重播
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // 動態流光背景
          const Positioned.fill(
            child: _AmbientFlowBackground(),
          ),

          // 主體內容
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 品牌圖示
                  _exquisiteFadeIn(
                    child: const _BrandMark(),
                    delayMs: 0,
                    from: 25,
                  ),
                  const SizedBox(height: 24),

                  // 毛玻璃登入卡片
                  _exquisiteFadeIn(
                    delayMs: 400,
                    from: 35,
                    child: _GlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 標題
                          Text(
                            isLogin ? 'YeBang 家教' : '建立新帳號',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4E342E),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isLogin ? '請輸入您的信箱與密碼' : '填寫資料以完成註冊',
                            style: TextStyle(
                                fontSize: 13.5, color: Color(0xFF8D6E63)),
                          ),
                          const SizedBox(height: 28),

                          // 欄位組
                          // Gmail 欄
                          _FocusedGlowField(
                            focusNode: _emailFocusNode,
                            child: TextField(
                              controller: _emailCtrl,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              onTap: () {
                                if (_emailCtrl.text == '@gmail.com') {
                                  _emailCtrl.selection =
                                      const TextSelection.collapsed(offset: 0);
                                }
                              },
                              decoration: _inputDeco('信箱',
                                  suffix: const Icon(Icons.email_outlined,
                                      color: Color(0xFFBCAAA4))),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 帳號名稱欄（僅註冊）
                          if (!isLogin) ...[
                            _FocusedGlowField(
                              focusNode: _usernameFocusNode,
                              child: TextField(
                                controller: _usernameCtrl,
                                focusNode: _usernameFocusNode,
                                decoration: _inputDeco('帳號名稱',
                                    suffix: const Icon(
                                        Icons.person_outline_rounded,
                                        color: Color(0xFFBCAAA4))),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 密碼欄
                          _FocusedGlowField(
                            focusNode: _passwordFocusNode,
                            child: TextField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocusNode,
                              obscureText: _obscurePassword,
                              decoration: _inputDeco('密碼',
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFFBCAAA4),
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  )),
                            ),
                          ),
                          if (isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  '忘記密碼？',
                                  style: TextStyle(
                                    color: Color(0xFF8D6E63),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ] else ...[
                            const SizedBox(height: 14),
                          ],

                          // 確認密碼（僅註冊）
                          if (!isLogin) ...[
                            _FocusedGlowField(
                              focusNode: _confirmPasswordFocusNode,
                              child: TextField(
                                controller: _confirmPasswordCtrl,
                                focusNode: _confirmPasswordFocusNode,
                                obscureText: _obscureConfirm,
                                decoration: _inputDeco('確認密碼',
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFFBCAAA4),
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    )),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 查閱與同意服務條款（僅註冊模式）
                          if (!isLogin) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _agreedToTerms,
                                      onChanged: (v) => setState(
                                          () => _agreedToTerms = v ?? false),
                                      activeColor: Color(0xFF8D6E63),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      side: BorderSide(
                                          color: Color(0xFF8D6E63), width: 1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text('我已閱讀並同意本應用程式的 ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600)),
                                        GestureDetector(
                                          onTap: () => _showInlineDialog(
                                              context: context,
                                              title: '服務條款',
                                              icon: Icons.gavel_outlined),
                                          child: Text('服務條款',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8D6E63),
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration
                                                      .underline)),
                                        ),
                                        Text(' 與 ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600)),
                                        GestureDetector(
                                          onTap: () => _showInlineDialog(
                                              context: context,
                                              title: '隱私權政策',
                                              icon: Icons.privacy_tip_outlined),
                                          child: Text('隱私權政策',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8D6E63),
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration
                                                      .underline)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 主按鈕（登入 / 註冊）
                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF8D6E63),
                                  Color(0xFFA1887F),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Color(0xFF8D6E63).withValues(alpha: 0.32),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _submit,
                              child: Text(
                                isLogin ? '登入' : '註冊',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 切換登入 / 註冊
                          TextButton(
                            onPressed: () => setState(() {
                              isLogin = !isLogin;
                              _passwordCtrl.clear();
                              _confirmPasswordCtrl.clear();
                              if (_emailCtrl.text.isEmpty) {
                                _emailCtrl.text = '@gmail.com';
                              }
                            }),
                            child: Text(
                              isLogin ? '還沒有帳號？點此註冊' : '已有帳號？點此登入',
                              style: TextStyle(
                                  color: Color(0xFF8D6E63),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Google 登入按鈕
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.55),
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 1.2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: _showGoogleSignInDialog,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const GoogleLogo(size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    isLogin
                                        ? '使用 Google 帳號登入'
                                        : '使用 Google 帳號註冊',
                                    style: const TextStyle(
                                      color: Color(0xFF3C4043),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 分隔線
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(
                                  child: Divider(color: Color(0xFFE5DCD3))),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('或',
                                    style: TextStyle(
                                        color: Color(0xFFBCAAA4),
                                        fontSize: 12)),
                              ),
                              Expanded(
                                  child: Divider(color: Color(0xFFE5DCD3))),
                            ]),
                          ),
                          const SizedBox(height: 12),

                          // 訪客登入
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.35),
                                side: BorderSide(
                                    color: Color(0xFF8D6E63)
                                        .withValues(alpha: 0.4),
                                    width: 1.2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.person_outline_rounded,
                                  color: Color(0xFF8D6E63), size: 20),
                              label: const Text(
                                '以訪客身份直接登入',
                                style: TextStyle(
                                    color: Color(0xFF8D6E63),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5),
                              ),
                              onPressed: () async {
                                try {
                                  final db =
                                      await DatabaseHelper.instance.database;
                                  final res = await db.query('users',
                                      where: 'username = ?', whereArgs: ['訪客']);
                                  if (!mounted) return;
                                  if (res.isNotEmpty) {
                                    final userMap =
                                        Map<String, dynamic>.from(res.first);
                                    userMap['session_post_ids'] = <int>{};
                                    userMap['session_comment_ids'] = <int>{};
                                    _showSuccessOverlay(userMap);
                                  } else {
                                    _showSuccessOverlay({
                                      'id': 'u4',
                                      'username': '訪客',
                                      'display_name': '訪客',
                                      'session_post_ids': <int>{},
                                      'session_comment_ids': <int>{},
                                    });
                                  }
                                } catch (e) {
                                  debugPrint('訪客登入失敗: $e');
                                  if (!mounted) return;
                                  _showSuccessOverlay({
                                    'id': 'u4',
                                    'username': '訪客',
                                    'display_name': '訪客',
                                    'session_post_ids': <int>{},
                                    'session_comment_ids': <int>{},
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


