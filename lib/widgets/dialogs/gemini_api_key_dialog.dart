import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 顯示自訂 Gemini API Key 設定彈窗
void showGeminiApiKeyDialog({
  required BuildContext context,
  required String initialKey,
  required Color primaryColor,
  required Future<void> Function(String newKey) onSave,
}) {
  showDialog(
    context: context,
    builder: (ctx) => GeminiApiKeyDialog(
      initialKey: initialKey,
      primaryColor: primaryColor,
      onSave: onSave,
    ),
  );
}

/// 自訂 Gemini API Key 設定 Dialog
class GeminiApiKeyDialog extends StatefulWidget {
  final String initialKey;
  final Color primaryColor;
  final Future<void> Function(String newKey) onSave;

  const GeminiApiKeyDialog({
    super.key,
    required this.initialKey,
    required this.primaryColor,
    required this.onSave,
  });

  @override
  State<GeminiApiKeyDialog> createState() => _GeminiApiKeyDialogState();
}

class _GeminiApiKeyDialogState extends State<GeminiApiKeyDialog> {
  late final TextEditingController _ctrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.key_rounded,
                color: widget.primaryColor, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Gemini API Key 設定',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '設定自訂 Google Gemini API Key，可用於拍照考卷 OCR 辨識、PDF 試卷提取、AI 診斷與題目自動生成等功能。',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Colors.blue),
                      SizedBox(width: 6),
                      Text('如何免費取得 API Key？',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '1. 前往 Google AI Studio 網站\n2. 登入 Google 帳號後點選「Get API key」\n3. 複製並貼上到此處（完全免費、無限制高速）',
                    style: TextStyle(
                        fontSize: 12, height: 1.4, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final uri =
                          Uri.parse('https://aistudio.google.com/app/apikey');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '開啟 Google AI Studio 網頁 ↗',
                          style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newKey = _ctrl.text.trim();
            Navigator.pop(context);
            await widget.onSave(newKey);
          },
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
