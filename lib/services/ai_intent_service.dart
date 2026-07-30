enum UserIntent {
  changeNickname,
  changeAvatar,
  editBio,
  changeFontSize,
  changeTheme,
  verifyEmail,
  changePassword,
  logout,
  createPost,
  viewItinerary,
  createItinerary,
  createTodo,
  editItinerary,
  editTodo,
  addGeneric,
  editGeneric,
  viewSocial,
  viewQuestionBank,
  viewProfile,
  viewActivity,
  viewPendingComments,
  help,
  viewNotes,
  createNote,
  searchNote,
  deleteNote,
  organizeNote,
  none,
}

class ParseResult {
  final UserIntent intent;
  final String? suggestionLabel;
  final String? suggestionKeyword;
  final int score;

  ParseResult({required this.intent, this.suggestionLabel, this.suggestionKeyword, required this.score});
}

class AIIntentService {
  static final Map<UserIntent, Map<String, dynamic>> _intentMetadata = {
    UserIntent.changeNickname: {'label': '修改暱稱', 'keywords': ['改名', '暱稱', '改一下名字', '更改名字', '修改名稱', '改個名', '換個名字']},
    UserIntent.changeAvatar: {'label': '更換頭像', 'keywords': ['換頭像', '改頭像', '更換頭像', '換圖', '大頭貼', '上傳照片', '換大頭貼']},
    UserIntent.editBio: {'label': '修改個人簡介', 'keywords': ['簡介', '個人簡介', '自我介紹', '修改簡介', '編輯簡介', '改簡介', '更改簡介', '改一下簡介']},
    UserIntent.createPost: {'label': '發佈貼文', 'keywords': ['發貼文', '發一篇文', '發佈貼文', '分享文章', '分享內容', '新增貼文', '我要發文', '我想發文']},
    UserIntent.createItinerary: {'label': '新增行程', 'keywords': ['新增行程', '加行程', '排行程', '記錄行程', '新增事件', '加一個事件', '新增會議', '排時間', '記錄會議', '我想加行程', '幫我排行程']},
    UserIntent.createTodo: {'label': '新增待辦', 'keywords': ['新增待辦', '加待辦', '待辦事項', '記待辦', '新增代辦', '加代辦', '代辦事項', 'todo', 'to-do', '加一個待辦', '新增待辦事項', '幫我記待辦']},
    UserIntent.editItinerary: {'label': '修改行程', 'keywords': ['修改行程', '更改行程', '編輯行程', '改行程', '修改時間', '更改時間', '行程改時間']},
    UserIntent.editTodo: {'label': '修改待辦', 'keywords': ['修改待辦', '修改代辦', '編輯待辦', '編輯代辦', '改待辦', '改代辦', '更改待辦']},
    UserIntent.addGeneric: {'label': '新增項目', 'keywords': ['新增項目', '幫我新增項目', '添加項目', '建立新項目']},
    UserIntent.editGeneric: {'label': '修改項目', 'keywords': ['修改項目', '編輯項目', '更改項目', '幫我修改項目']},
    UserIntent.viewItinerary: {'label': '查看日曆', 'keywords': ['日曆', '看日曆', '行事曆', '看行程', '行程頁面', '我的行程', '查看行程']},
    UserIntent.viewSocial: {'label': '查看社群', 'keywords': ['社群', '看社群', '朋友圈', '社群頁面', '貼文列表', '查看社群']},
    UserIntent.viewQuestionBank: {'label': '練習題庫', 'keywords': ['題庫', '測驗', '考題', '小測驗', '去題庫', '打開題庫', '我要測驗', '開始測驗']},
    UserIntent.viewPendingComments: {'label': '回覆留言', 'keywords': ['回覆留言', '哪些留言', '待回覆', '留言回覆', '有哪些留言', '幫我回覆']},
    UserIntent.viewProfile: {'label': '個人檔案', 'keywords': ['個人檔案', '我的資料', '主頁', '設定頁面', '我的個人資料', '查看個人檔案', '修改設定', '個人設定', '開啟設定']},
    UserIntent.viewActivity: {'label': '社群動態', 'keywords': ['社群動態', '我的貼文', '收藏貼文', '我的動態', '查看動態']},
    UserIntent.changeTheme: {'label': '切換主題', 'keywords': ['切換主題', '換主題', '深色模式', '深色主題', '改顏色', '換顏色', '主題顏色']},
    UserIntent.changeFontSize: {'label': '字體大小', 'keywords': ['字體大小', '改字型', '字體設定', '調整字體', '字較大', '字較小', '文字大小']},
    UserIntent.verifyEmail: {'label': 'Email 驗證', 'keywords': ['驗證信箱', 'email驗證', '信箱驗證', '驗證email', '驗證郵件']},
    UserIntent.changePassword: {'label': '修改密碼', 'keywords': ['密碼', '改密碼', '修改密碼', '更改密碼', '密碼修改', '換密碼']},
    UserIntent.help: {'label': '幫助', 'keywords': ['幫助', '說明', 'help', '指令清單', '可以幫什麼', '你能幫什麼', '功能說明']},
    UserIntent.viewNotes: {'label': '查看筆記本', 'keywords': ['筆記本', '看筆記', '切換筆記本', '打開筆記', '我的筆記', '查看筆記']},
    UserIntent.createNote: {'label': '新增筆記', 'keywords': ['新增筆記', '寫筆記', '記筆記', '加筆記', '建立筆記', '我想記筆記']},
    UserIntent.searchNote: {'label': '搜尋筆記', 'keywords': ['搜尋筆記', '找筆記', '尋找筆記', '查筆記', '筆記搜尋']},
    UserIntent.deleteNote: {'label': '刪除筆記', 'keywords': ['刪除筆記', '丟棄筆記', '刪筆記', '刪掉筆記', '移除筆記']},
    UserIntent.organizeNote: {'label': '整理筆記', 'keywords': ['整理筆記', '筆記摘要', '重點整理筆記', 'AI摘要', '幫我整理筆記', '筆記重點']},
  };

  static ParseResult parse(String userInput) {
    if (userInput.isEmpty) return ParseResult(intent: UserIntent.none, score: 0);
    final input = userInput.toLowerCase().trim();

    UserIntent bestMatch = UserIntent.none;
    int highestScore = 0;
    int bestKeywordLength = 0;

    _intentMetadata.forEach((intent, data) {
      List<String> keywords = data['keywords'];
      for (var keyword in keywords) {
        int score = 0;
        if (input == keyword) {
          // 完全精確匹配：最高分
          score = 20;
        } else if (input.contains(keyword)) {
          // 輸入包含關鍵字（例如「我想新增行程」包含「新增行程」）
          score = 10;
        } else if (keyword.contains(input) && input.length >= 2) {
          // 關鍵字包含輸入（例如輸入「日曆」，關鍵字有「看日曆」）
          // 只有輸入長度 >= 2 才匹配，避免單字造成誤判
          score = 10;
        }
        // ✅ 移除字符級模糊匹配（原 score=5 分支）：
        // 字符級匹配過於寬鬆，「今天心情累」等日常話語會被誤判為「整理筆記」，
        // 導致嚴重的誤觸發問題，因此完全移除。

        if (score > highestScore) {
          highestScore = score;
          bestMatch = intent;
          bestKeywordLength = keyword.length;
        } else if (score == highestScore && score > 0) {
          if (keyword.length > bestKeywordLength) {
            bestMatch = intent;
            bestKeywordLength = keyword.length;
          }
        }
      }
    });


    if (highestScore >= 10) {
      return ParseResult(intent: bestMatch, score: highestScore);
    }

    // ✅ 移除 score=5 的「建議引導」回應：
    // 低信心的模糊建議容易在不恰當的時機打斷使用者的正常對話，
    // 現在分數不足時直接返回 none，讓輸入流向 OpenRouter AI 自由回覆。
    return ParseResult(intent: UserIntent.none, score: 0);
  }
}
