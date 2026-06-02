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
  editItinerary,
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
    UserIntent.changeNickname: {'label': '修改暱稱', 'keywords': ['改名', '暱稱', '名字']},
    UserIntent.changeAvatar: {'label': '更換頭像', 'keywords': ['頭像', '換圖', '大頭貼']},
    UserIntent.createPost: {'label': '發佈貼文', 'keywords': ['發文', '貼文', '發貼文']},
    UserIntent.createItinerary: {'label': '新增行程', 'keywords': ['新增行程', '加行程', '排行程']},
    UserIntent.editItinerary: {'label': '修改行程', 'keywords': ['修改行程', '更改行程', '編輯行程', '改行程', '改時間', '修改時間', '更改時間']},
    UserIntent.viewItinerary: {'label': '查看日曆', 'keywords': ['日曆', '看日曆', '行事曆', '看行程']},
    UserIntent.viewSocial: {'label': '查看社群', 'keywords': ['社群', '看貼文', '朋友圈']},
    UserIntent.viewQuestionBank: {'label': '練習題庫', 'keywords': ['題庫', '測驗', '考題']},
    UserIntent.viewPendingComments: {'label': '回覆留言', 'keywords': ['回覆', '哪些留言', '待回覆']},
    UserIntent.viewProfile: {'label': '個人檔案', 'keywords': ['個人檔案', '我的資料', '主頁']},
    UserIntent.viewActivity: {'label': '社群動態', 'keywords': ['社群動態', '我的貼文', '收藏', '收藏貼文']},
    UserIntent.changeTheme: {'label': '切換主題', 'keywords': ['主題', '換主題', '顏色', '深色模式']},
    UserIntent.changeFontSize: {'label': '字體大小', 'keywords': ['字體', '大小', '字大']},
    UserIntent.verifyEmail: {'label': 'Email 驗證', 'keywords': ['驗證', '信箱', 'email']},
    UserIntent.changePassword: {'label': '修改密碼', 'keywords': ['密碼', '改密碼']},
    UserIntent.help: {'label': '幫助', 'keywords': ['幫助', '說明', 'help', '功能']},
    UserIntent.viewNotes: {'label': '查看筆記本', 'keywords': ['筆記本', '看筆記', '切換筆記本', '打開筆記']},
    UserIntent.createNote: {'label': '新增筆記', 'keywords': ['新增筆記', '寫筆記', '記筆記', '加筆記', '建立筆記']},
    UserIntent.searchNote: {'label': '搜尋筆記', 'keywords': ['搜尋筆記', '找筆記', '尋找筆記', '查筆記']},
    UserIntent.deleteNote: {'label': '刪除筆記', 'keywords': ['刪除筆記', '丟棄筆記', '刪筆記']},
    UserIntent.organizeNote: {'label': '整理筆記', 'keywords': ['整理筆記', '摘要', '重點整理', '幫我整理', '總結']},
  };

  static ParseResult parse(String userInput) {
    if (userInput.isEmpty) return ParseResult(intent: UserIntent.none, score: 0);
    final input = userInput.toLowerCase().trim();

    UserIntent bestMatch = UserIntent.none;
    int highestScore = 0;
    String? bestLabel;
    String? bestKeyword;

    _intentMetadata.forEach((intent, data) {
      List<String> keywords = data['keywords'];
      for (var keyword in keywords) {
        int score = 0;
        if (input == keyword) {
          score = 20; 
        } else if (input.contains(keyword) || keyword.contains(input)) {
          // 只要輸入包含關鍵字，或關鍵字包含輸入（如「日曆」匹配「看日曆」），就給予高分
          score = 10; 
        } else if (keyword.length >= 2) {
          int matches = 0;
          for (var char in input.split('')) {
            if (keyword.contains(char)) matches++;
          }
          if (matches >= keyword.length - 1 && matches > 0) {
            score = 5; 
          }
        }

        if (score > highestScore) {
          highestScore = score;
          bestMatch = intent;
          bestLabel = data['label'];
          bestKeyword = keyword;
        }
      }
    });

    if (highestScore >= 10) {
      return ParseResult(intent: bestMatch, score: highestScore);
    } else if (highestScore >= 5) {
      return ParseResult(
        intent: UserIntent.none, 
        score: highestScore,
        suggestionLabel: bestLabel,
        suggestionKeyword: bestKeyword,
      );
    }

    return ParseResult(intent: UserIntent.none, score: 0);
  }
}
