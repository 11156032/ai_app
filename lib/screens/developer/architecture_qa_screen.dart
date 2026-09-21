import 'package:flutter/material.dart';
import '../../services/architecture_qa_service.dart';

class ArchitectureQaScreen extends StatefulWidget {
  const ArchitectureQaScreen({super.key});

  @override
  State<ArchitectureQaScreen> createState() => _ArchitectureQaScreenState();
}

class _ArchitectureQaScreenState extends State<ArchitectureQaScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '全部';
  List<QaItem> _displayedFaqs = [];
  String? _customAiAnswer;
  bool _isSearchingAi = false;

  @override
  void initState() {
    super.initState();
    _displayedFaqs = ArchitectureQaService.presetFaqs;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _customAiAnswer = null;
      if (_selectedCategory == '全部') {
        _displayedFaqs = ArchitectureQaService.search(query);
      } else {
        _displayedFaqs = ArchitectureQaService.search(query)
            .where((i) => i.category == _selectedCategory)
            .toList();
      }
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _onSearchChanged(_searchController.text);
    });
  }

  Future<void> _handleAskQuestion() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearchingAi = true;
      _customAiAnswer = null;
    });

    final answer = await ArchitectureQaService.askAiAssistant(query);

    if (mounted) {
      setState(() {
        _isSearchingAi = false;
        _customAiAnswer = answer;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final categories = ArchitectureQaService.getCategories();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          color: Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('架構智慧問答與 FAQ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 搜尋與提問卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '想了解專案的哪一部分？',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: (_) => _handleAskQuestion(),
                        decoration: InputDecoration(
                          hintText: '輸入問題（如：Service、登入、SQLite）...',
                          hintStyle: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSearchingAi ? null : _handleAskQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSearchingAi
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('詢問',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 類別標籤過濾列
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: primaryColor.withValues(alpha: 0.15),
                    checkmarkColor: primaryColor,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? primaryColor : Colors.grey.shade700,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => _onCategorySelected(cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // 自訂詢問回傳結果
          if (_customAiAnswer != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: Color(0xFF7B1FA2), size: 18),
                      SizedBox(width: 8),
                      Text(
                        '架構助手回覆：',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7B1FA2),
                            fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _customAiAnswer!,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Color(0xFF311B92)),
                  ),
                ],
              ),
            ),
          ],

          // 預設常見問題清單
          if (_displayedFaqs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.help_outline_rounded,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('找不到與「${_searchController.text}」相符的常見問題',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Text('可以點擊「詢問」按鈕讓架構助手為您檢索！',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            )
          else
            ..._displayedFaqs.map((faq) => _buildFaqCard(faq, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildFaqCard(QaItem faq, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.help_center_rounded,
                color: primaryColor, size: 20),
          ),
          title: Text(
            faq.question,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              faq.summary,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    faq.answer,
                    style: const TextStyle(
                        fontSize: 13, height: 1.55, color: Color(0xFF37474F)),
                  ),
                  if (faq.relatedFiles.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('相關實作檔案：',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: faq.relatedFiles.map((rf) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            rf,
                            style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: Color(0xFF00695C),
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
