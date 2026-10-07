import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../widgets/common_widgets.dart';
import 'login/widgets/login_brand_logo.dart';
import 'login/widgets/login_flow_background.dart';
import 'login/widgets/login_success_overlay.dart';
import 'login/widgets/google_sign_in_modal.dart';
import '../services/app_locale_service.dart';

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
        (userMap['display_name'] ?? userMap['username'] ?? tr('ana_you')).toString();
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
        title: Text(tr('login_forgot_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('login_forgot_desc')),
            const SizedBox(height: 14),
            TextField(
              controller: emailResetCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco(tr('login_email'),
                  suffix: const Icon(Icons.email_outlined,
                      color: Color(0xFFBCAAA4))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('btn_cancel'), style: TextStyle(color: Colors.grey)),
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
                  SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('login_invalid_email'))),
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
                      title: Text(tr('login_hint')),
                      content: Text(tr('login_email_not_found')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: Text(tr('confirm')),
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
            child: Text(tr('login_next')),
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
            title: Text(tr('login_reset_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('login_reset_desc')),
                const SizedBox(height: 14),
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: obscureNew,
                  decoration: _inputDeco(
                    tr('pwd_new_label'),
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
                    tr('pwd_confirm_new'),
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
                child: Text(tr('btn_cancel'), style: TextStyle(color: Colors.grey)),
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
                      SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('login_field_empty'))),
                    );
                    return;
                  }
                  if (newPass != confPass) {
                    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                      SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('login_pwd_mismatch'))),
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
                        title: Text(tr('login_reset_ok_title')),
                        content: Text(tr('login_reset_ok')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(tr('confirm')),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    debugPrint('更新密碼失敗: $e');
                  }
                },
                child: Text(tr('login_reset_done')),
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
    final isTerms = title == tr('terms_label');
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
                          'v1.8.5',
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
                    isTerms ? tr('login_terms_sub') : tr('login_privacy_sub'),
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
                        tr('lt_t1'),
                        tr('lt_c1'),
                        themeColor,
                      ),
                      _buildInlineSection(
                        tr('lt_t2'),
                        tr('lt_c2'),
                        themeColor,
                      ),
                      _buildInlineSection(
                        tr('lt_t3'),
                        tr('lt_c3'),
                        themeColor,
                      ),
                      _buildInlineSection(
                        tr('lt_t4'),
                        tr('lt_c4'),
                        themeColor,
                      ),
                      _buildInlineSection(
                        tr('lt_t5'),
                        tr('lt_c5'),
                        themeColor,
                      ),
                    ]
                  : [
                      _buildInlineSection(
                        tr('lp_t1'),
                        tr('lp_c1'),
                        themeColor,
                      ),
                      _buildInlineSection(
                        tr('lp_t2'),
                        tr('lp_c2'),
                        themeColor,
                      ),
                      _buildInlineSection(
                        tr('lp_t3'),
                        tr('lp_c3'),
                        themeColor,
                      ),
                      _buildInlineSection(
                        tr('lp_t4'),
                        tr('lp_c4'),
                        themeColor,
                      ),
                      _buildInlineSection(
                        tr('lp_t5'),
                        tr('lp_c5'),
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
            child: Text(
              tr('login_read_ack'),
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
            .showSnackBar(SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('login_need_email_pwd'))));
        return;
      }
    } else {
      if (inputUsername.isEmpty ||
          inputEmail.isEmpty ||
          inputEmail == '@gmail.com' ||
          inputPassword.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('login_need_all'))));
        return;
      }
      if (inputPassword != inputConfirm) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: Text(tr('login_hint')),
                  content: Text(tr('login_pwd_mismatch2')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(tr('confirm')))
                  ],
                ));
        return;
      }
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1500), 
            content: Text(tr('login_need_agree')),
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
                title: Text(tr('login_restore_title')),
                content: Text(tr('login_restore_msg')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(tr('btn_cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(tr('login_restore_confirm'))),
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
                      title: Text(tr('login_wrong_pwd_title')),
                      content: Text(tr('login_wrong_pwd')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(tr('confirm')))
                      ],
                    ));
          } else {
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: Text(tr('login_no_account_title')),
                      content: Text(tr('login_no_account')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(tr('confirm')))
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
                      title: Text(tr('login_signup_failed')),
                      content: Text(tr('login_taken')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(tr('confirm')))
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
            'language': AppLocaleService.currentLanguage,
          });
          _passwordCtrl.clear();
          _confirmPasswordCtrl.clear();
          if (!mounted) return;
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: Text(tr('login_signup_ok_title')),
                    content: Text(tr('login_signup_ok')),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => isLogin = true);
                          },
                          child: Text(tr('login_go_login')))
                    ],
                  ));
        } catch (e) {
          if (!mounted) return;
          String errorMsg = tr('login_unknown_err');
          if (!e.toString().contains('UNIQUE constraint failed')) {
            errorMsg += tr('login_err_detail', [e.toString()]);
          }

          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: Text(tr('login_signup_failed')),
                    content: Text(errorMsg),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(tr('confirm')))
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
              title: Text(tr('login_restore_title')),
              content: Text(tr('login_restore_msg')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(tr('btn_cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(tr('login_restore_confirm'))),
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
          'language': AppLocaleService.currentLanguage,
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
          SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('login_google_failed', [e.toString()]))),
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
            child: RepaintBoundary(
              child: _AmbientFlowBackground(),
            ),
          ),

          // 主體內容
          Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const ClampingScrollPhysics(),
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
                            isLogin ? 'YeBang 家教' : tr('login_create_account'),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4E342E),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isLogin ? tr('login_enter_cred') : tr('login_fill_signup'),
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
                              decoration: _inputDeco(tr('login_email_short'),
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
                                decoration: _inputDeco(tr('login_username'),
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
                              decoration: _inputDeco(tr('login_password'),
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
                                  tr('login_forgot_link'),
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
                                decoration: _inputDeco(tr('login_confirm_pwd'),
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
                                        Text(tr('login_agree_prefix'),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600)),
                                        GestureDetector(
                                          onTap: () => _showInlineDialog(
                                              context: context,
                                              title: tr('terms_label'),
                                              icon: Icons.gavel_outlined),
                                          child: Text(tr('terms_label'),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8D6E63),
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration
                                                      .underline)),
                                        ),
                                        Text(tr('login_and'),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600)),
                                        GestureDetector(
                                          onTap: () => _showInlineDialog(
                                              context: context,
                                              title: tr('privacy_label'),
                                              icon: Icons.privacy_tip_outlined),
                                          child: Text(tr('privacy_label'),
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
                                isLogin ? tr('btn_login') : tr('btn_signup'),
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
                              isLogin ? tr('login_to_signup') : tr('login_to_login'),
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
                                        ? tr('login_google_signin')
                                        : tr('login_google_signup'),
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
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(
                                  child: Divider(color: Color(0xFFE5DCD3))),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(tr('login_or'),
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
                              label: Text(
                                tr('login_guest'),
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


