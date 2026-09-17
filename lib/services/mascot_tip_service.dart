// ignore_for_file: prefer_final_fields
import 'dart:math' as math;

/// 伴學精靈成長小語服務
/// 根據時段 × 星期幾 × 語系產生個人化成長小語
class MascotTipService {
  MascotTipService._();
  static final MascotTipService instance = MascotTipService._();

  // 每次冷啟動固定一個隨機種子，使該 session 的第一句小語固定
  static int _sessionSeed = 0;
  static bool _seeded = false;

  static void seedSession() {
    if (!_seeded) {
      _sessionSeed = DateTime.now().millisecondsSinceEpoch;
      _seeded = true;
    }
  }

  /// 取得當下情境最適合的成長小語（每次冷啟動固定同一句）
  static String getTip(String lang) {
    seedSession();
    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday; // 1=Mon ... 7=Sun
    final tips = _selectPool(lang, hour, weekday);
    final idx = _sessionSeed % tips.length;
    return tips[idx];
  }

  /// 點擊刷新，每次隨機換一句
  static String refreshTip(String lang) {
    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday;
    final tips = _selectPool(lang, hour, weekday);
    final rng = math.Random();
    return tips[rng.nextInt(tips.length)];
  }

  static List<String> _selectPool(String lang, int hour, int weekday) {
    final isWeekend = weekday == 6 || weekday == 7;
    if (hour >= 5 && hour < 9) {
      return _morning(lang);
    } else if (hour >= 9 && hour < 12) {
      return _forenoon(lang);
    } else if (hour >= 12 && hour < 14) {
      return _noon(lang, isWeekend);
    } else if (hour >= 14 && hour < 18) {
      return _afternoon(lang);
    } else if (hour >= 18 && hour < 21) {
      return _evening(lang);
    } else if (hour >= 21 || hour < 1) {
      return _lateNight(lang);
    } else {
      return _deepNight(lang);
    }
  }

  // ────────────────────────────────────────────────
  // 各時段小語池
  // ────────────────────────────────────────────────

  static List<String> _morning(String lang) {
    switch (lang) {
      case 'ja':
        return [
          'おはよう！今日も一緒に頑張ろう 🌱',
          '朝の学びが一番染みるよ。さあ始めよう！',
          '新しい一日、新しいスタート。今日も成長しよう ✨',
          '早起きは三文の徳。今日も良い学びを！',
          '今日の目標を決めよう。小さな一歩が大きな変化を生む 🌿',
        ];
      case 'ko':
        return [
          '좋은 아침! 오늘도 함께 성장해요 🌱',
          '아침 공부가 제일 잘 기억돼요. 시작해볼까요?',
          '새로운 하루, 새로운 시작. 오늘도 화이팅! ✨',
          '일찍 일어난 새가 더 많이 배워요 🌿',
          '오늘의 목표를 정해봐요. 작은 한 걸음이 큰 변화를 만들어요!',
        ];
      default:
        return [
          '早安！今天也要一起進步呀 🌱',
          '清晨最適合讀書，趁腦袋清醒動起來！',
          '新的一天，新的開始。小努力，大成長 ✨',
          '早起的你最讚了，加油！',
          '先定一個今天的小目標，葉幫陪你完成 🌿',
        ];
    }
  }

  static List<String> _forenoon(String lang) {
    switch (lang) {
      case 'ja':
        return [
          '今が一番集中できる時間帯！一問やってみよう 💪',
          '午前中の学習は記憶に残りやすいよ。今がチャンス！',
          '問題を一つずつ解くと、自信がどんどん増える 🌿',
          '今日の難しい問題に挑戦してみよう！',
          '苦手を一つ、今日の午前中に克服しよう ✨',
        ];
      case 'ko':
        return [
          '지금이 집중하기 제일 좋은 시간이에요! 한 문제 도전해봐요 💪',
          '오전 공부는 기억에 잘 남아요. 지금이 기회예요!',
          '문제를 하나씩 풀다 보면 자신감이 쌓여요 🌿',
          '오늘의 어려운 문제에 도전해봐요!',
          '지금 집중할 때, 약점 하나를 극복해봐요 ✨',
        ];
      default:
        return [
          '上午效率最高！選一個題庫衝刺 15 分鐘吧 💪',
          '腦袋最靈光，把難題一一擊破！',
          '每道題都是進步的一小步，一起來 🌿',
          '挑戰一道難題，感受突破的快感 ✨',
          '專注的時候最美，把弱點變強點！',
        ];
    }
  }

  static List<String> _noon(String lang, bool isWeekend) {
    switch (lang) {
      case 'ja':
        return isWeekend
            ? [
                '週末のお昼はゆっくり復習しよう ☀️',
                '休憩しながら少し学ぶのが週末スタイル 🌱',
                'のんびりでいいよ。でも一つだけやってみて 😊',
              ]
            : [
                'お昼休みに昨日の間違いを見直してみよう 💡',
                '食後の復習で記憶を定着させよう！',
                '少しだけでいい。ノートを一ページ読んでみて 🌿',
              ];
      case 'ko':
        return isWeekend
            ? [
                '주말 점심엔 여유롭게 복습해봐요 ☀️',
                '쉬면서 조금씩 배우는 게 주말 스타일이에요 🌱',
                '느긋하게 해도 돼요. 한 가지만 해봐요 😊',
              ]
            : [
                '점심 시간에 어제 틀린 문제 다시 봐봐요 💡',
                '밥 먹고 복습하면 기억이 더 잘 돼요!',
                '조금만 해도 돼요. 노트 한 페이지만 읽어봐요 🌿',
              ];
      default:
        return isWeekend
            ? [
                '週末午後，放鬆地複習一下昨天的吧 ☀️',
                '休息中也能學，翻一頁筆記就夠了 🌱',
                '悠閒也沒關係，今天做一件學習小事就好 😊',
              ]
            : [
                '午休時間，把昨天的錯題掃一遍 💡',
                '飯後複習，加深印象超有效！',
                '趁休息翻一頁筆記，學習不間斷 🌿',
              ];
    }
  }

  static List<String> _afternoon(String lang) {
    switch (lang) {
      case 'ja':
        return [
          '午後の集中力で得意分野をもっと伸ばそう 🌿',
          '今日はどれくらい学んだ？記録してみよう 📒',
          '少し疲れたら 5 分休んで再スタート 💪',
          '一つ目標達成したら、次の目標へ！',
          '苦手な問題、今日こそ向き合ってみよう ✨',
        ];
      case 'ko':
        return [
          '오후 집중력으로 잘하는 부분을 더 키워봐요 🌿',
          '오늘 얼마나 공부했어요? 기록해봐요 📒',
          '조금 지치면 5분 쉬고 다시 시작해요 💪',
          '목표 하나 달성했으면 다음 목표로 고고!',
          '약한 문제, 오늘 한번 정면으로 도전해봐요 ✨',
        ];
      default:
        return [
          '下午也要把握！用強項帶動弱項 🌿',
          '今天學了多少？記錄一下成就感滿滿 📒',
          '有點累？休息 5 分鐘再繼續，你可以的 💪',
          '完成一個小目標，馬上迎接下一個！',
          '弱點不要怕，今天就讓葉幫陪你攻克 ✨',
        ];
    }
  }

  static List<String> _evening(String lang) {
    switch (lang) {
      case 'ja':
        return [
          '夕方は黄金の復習時間🌙今日学んだことを整理しよう',
          '今日の学びをノートにまとめると明日が楽になるよ 📒',
          '目標達成したら、コミュニティで共有してみて！',
          '明日のために今日をしっかり復習しよう ✨',
          '今日頑張った自分を褒めてあげよう 🌿',
        ];
      case 'ko':
        return [
          '저녁은 황금 복습 시간이에요 🌙 오늘 배운 걸 정리해봐요',
          '오늘 공부한 내용을 노트에 정리하면 내일이 편해져요 📒',
          '목표 달성했으면 커뮤니티에 공유해봐요!',
          '내일을 위해 오늘을 확실히 복습해요 ✨',
          '오늘 열심히 한 나 자신을 칭찬해요 🌿',
        ];
      default:
        return [
          '黃金複習時段到！把今天的學習整理一下 🌙',
          '今日筆記整理好，明天更輕鬆 📒',
          '達成目標了嗎？去社群分享你的進步吧！',
          '為明天的自己準備好，今晚好好複習 ✨',
          '好好稱讚一下今天努力的自己 🌿',
        ];
    }
  }

  static List<String> _lateNight(String lang) {
    switch (lang) {
      case 'ja':
        return [
          'そろそろ休んでね。睡眠が最強の復習法だよ 😴',
          '今日よく頑張った！ゆっくり休んで明日また一緒に頑張ろう 🌙',
          '夜遅くまでお疲れ様。明日も応援してるよ 💪',
          '睡眠中に記憶が定着するよ。おやすみなさい 🌿',
          '無理しないで。明日の自分のために今は休もう ✨',
        ];
      case 'ko':
        return [
          '이제 좀 쉬어요. 잠이 최고의 복습이에요 😴',
          '오늘 잘했어요! 푹 쉬고 내일 또 같이 해요 🌙',
          '늦게까지 수고했어요. 내일도 응원할게요 💪',
          '자는 동안 기억이 굳어져요. 잘 자요 🌿',
          '무리하지 말고. 내일의 나를 위해 지금은 쉬어요 ✨',
        ];
      default:
        return [
          '快去休息吧！睡眠才是最強複習法 😴',
          '今天辛苦了，好好睡一覺，明天繼續加油 🌙',
          '熬夜不如早起！葉幫明天早上陪你 💪',
          '睡眠讓記憶更牢固，晚安 🌿',
          '別逞強，為明天的自己存點能量 ✨',
        ];
    }
  }

  static List<String> _deepNight(String lang) {
    switch (lang) {
      case 'ja':
        return [
          'こんな時間まで…本当にお疲れ様 💤',
          '明日に備えて、今すぐ寝よう！ 🌙',
          '睡眠不足は学習の大敵。今日はここまで 😴',
        ];
      case 'ko':
        return [
          '이 시간까지... 정말 수고했어요 💤',
          '내일을 위해 지금 바로 자요! 🌙',
          '수면 부족은 공부의 적이에요. 오늘은 여기까지 😴',
        ];
      default:
        return [
          '這時間還沒睡... 真的辛苦了 💤',
          '明天還有更多挑戰，現在去睡吧！ 🌙',
          '睡眠不足是學習大敵，今天就到這裡 😴',
        ];
    }
  }
}
