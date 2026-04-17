import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import '../database/database_helper.dart';
import '../main.dart' show googleSignIn;

class LoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // ── 一般帳密登入 / 註冊 ──────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('帳號與密碼不得為空')));
      return;
    }

    if (!isLogin) {
      if (_emailCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('信箱不得為空')));
        return;
      }
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
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
    }

    try {
      final db = await DatabaseHelper.instance.database;

      if (isLogin) {
        final res = await db.query('users',
            where: 'username = ? AND hashed_password = ?',
            whereArgs: [_usernameCtrl.text, _passwordCtrl.text]);
        if (!mounted) return;
        if (res.isNotEmpty) {
          showDialog(
              barrierDismissible: false,
              context: context,
              builder: (ctx) => AlertDialog(
                      title: const Text('登入成功'),
                      content: Text('歡迎回來，${res.first['display_name']}！👋'),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              widget.onLogin(
                                  Map<String, dynamic>.from(res.first));
                            },
                            child: const Text('進入系統'))
                      ]));
        } else {
          final userCheck = await db.query('users',
              where: 'username = ?', whereArgs: [_usernameCtrl.text]);
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
                      content: const Text('此帳號尚未註冊，請先建立新帳號再登入。'),
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
          String newId = 'u_${DateTime.now().millisecondsSinceEpoch}';
          await db.insert('users', {
            'id': newId,
            'username': _usernameCtrl.text,
            'email': _emailCtrl.text,
            'hashed_password': _passwordCtrl.text,
            'display_name': _usernameCtrl.text,
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
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('註冊失敗'),
                    content: Text('帳號或信箱可能已被使用，請換一個試試。\n詳細：$e'),
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

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 60, color: Color(0xFF8D6E63)),
              const SizedBox(height: 20),
              Text(isLogin ? '歡迎回來' : '建立新帳號',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8D6E63))),
              const SizedBox(height: 40),
              // 帳號
              TextField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                      labelText: '帳號',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none))),
              const SizedBox(height: 15),
              // Email（僅註冊）
              if (!isLogin) ...[
                TextField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                        labelText: '電子郵件',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none))),
                const SizedBox(height: 15),
              ],
              // 密碼
              TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '密碼',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  )),
              const SizedBox(height: 15),
              // 確認密碼（僅註冊）
              if (!isLogin) ...[
                TextField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: '確認密碼',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    )),
                const SizedBox(height: 15),
              ],
              const SizedBox(height: 15),
              // 登入 / 註冊按鈕
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6E63),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: _submit,
                child: Text(isLogin ? '登入' : '註冊',
                    style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),
              // 分隔線
              Row(
                children: [
                  Expanded(
                      child:
                          Divider(color: Colors.grey.shade300, thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child:
                        Text('或使用以下方式登入', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(
                      child:
                          Divider(color: Colors.grey.shade300, thickness: 1)),
                ],
              ),
              const SizedBox(height: 20),
              // Google 登入按鈕
              // Web：renderButton（由 Google GIS SDK 渲染，點擊觸發事件由 AuthWrapper 監聽）
              // 非 Web：自定義按鈕，呼叫 authenticate()
              if (kIsWeb)
                SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: (GoogleSignInPlatform.instance
                            as web.GoogleSignInPlugin)
                        .renderButton(
                      configuration: web.GSIButtonConfiguration(
                        type: web.GSIButtonType.standard,
                        theme: web.GSIButtonTheme.outline,
                        size: web.GSIButtonSize.large,
                      ),
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                    height: 24,
                  ),
                  label: const Text('使用 Google 繼續',
                      style: TextStyle(color: Colors.black87, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  // 非 Web 平台：直接呼叫 signIn()
                  // 結果由 AuthWrapper 的 onCurrentUserChanged 監聽器處理
                  onPressed: () async {
                    try {
                      await googleSignIn.signIn();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Google 登入失敗：$e')));
                    }
                  },
                ),
              const SizedBox(height: 20),
              // 切換登入 / 註冊
              TextButton(
                onPressed: () => setState(() {
                  isLogin = !isLogin;
                  _passwordCtrl.clear();
                  _confirmPasswordCtrl.clear();
                }),
                child: Text(isLogin ? '還沒有帳號？點此註冊' : '已有帳號？點此登入',
                    style: const TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 15),
              // 訪客登入
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  try {
                    final db = await DatabaseHelper.instance.database;
                    final res = await db.query('users',
                        where: 'username = ?', whereArgs: ['訪客']);
                    if (!mounted) return;
                    if (res.isNotEmpty) {
                      showDialog(
                          barrierDismissible: false,
                          context: context,
                          builder: (ctx) => AlertDialog(
                                  title: const Text('登入成功'),
                                  content: Text(
                                      '歡迎回來，${res.first['display_name']}！'),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          widget.onLogin(
                                              Map<String, dynamic>.from(
                                                  res.first));
                                        },
                                        child: const Text('進入系統'))
                                  ]));
                    } else {
                      widget.onLogin(
                          {'id': 'u4', 'username': '訪客', 'display_name': '訪客'});
                    }
                  } catch (e) {
                    debugPrint('訪客登入失敗: $e');
                    if (!mounted) return;
                    widget.onLogin(
                        {'id': 'u4', 'username': '訪客', 'display_name': '訪客'});
                  }
                },
                child: const Text('以訪客身份直接登入',
                    style: TextStyle(color: Color(0xFF8D6E63))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
