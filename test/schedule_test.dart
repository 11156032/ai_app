import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_app/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Test schedule insertion by manual method and agent method', () async {
    final db = await DatabaseHelper.instance.database;

    // Simulate current user id
    const userId = 'u1';

    // 1. Test manual schedule addition
    // _addSchedule(String timeRange, String title, int color)
    final key = DateTime.now().toString().split(' ')[0];
    final timeRange = "10:00~11:00";
    final manualStartStr = "$key ${timeRange.split('~')[0]}:00";
    final manualEndStr = "$key ${timeRange.split('~')[1]}:00";
    final manualColor = 0xFFFFCC80;

    await db.insert('calendar_events', {
      'user_id': userId,
      'title': 'Manual Meeting',
      'start_time': manualStartStr,
      'end_time': manualEndStr,
      'color': '0x${manualColor.toRadixString(16)}',
    });

    // 2. Test AI schedule agent addition
    // In _handleAISubmit:
    final startStr = '$key 12:00';
    final endStr = '$key 13:00';
    final agentColor = 4292473265; // 0xFFD9F1B1

    var finalStart = startStr;
    var finalEnd = endStr;
    if (finalStart.length <= 16) finalStart = "$finalStart:00";
    if (finalEnd.length <= 16) finalEnd = "$finalEnd:00";

    await db.insert('calendar_events', {
      'user_id': userId,
      'title': 'Agent Meeting',
      'start_time': finalStart,
      'end_time': finalEnd,
      'color': '0x${agentColor.toRadixString(16)}',
    });

    // Query both events
    final events = await db.query('calendar_events', where: 'user_id = ?', whereArgs: [userId]);
    print('Inserted events count: ${events.length}');
    for (var event in events) {
      print('Event: ${event['title']}, start: ${event['start_time']}, end: ${event['end_time']}, color: ${event['color']}');
    }

    expect(events.any((e) => e['title'] == 'Manual Meeting'), isTrue);
    expect(events.any((e) => e['title'] == 'Agent Meeting'), isTrue);

    // 3. Test malformed time parsing logic
    final malformedStart = "明天早上九點:00";
        
    // Simulating parsing logic in _loadData:
    String parseDate(String dateTimeStr) {
      final parts = dateTimeStr.split(' ');
      if (parts.isNotEmpty) {
        return parts[0];
      }
      return '';
    }

    String parseHr(String dateTimeStr) {
      final parts = dateTimeStr.split(' ');
      if (parts.length > 1) {
        final rawTime = parts[1];
        return rawTime.substring(0, rawTime.length >= 5 ? 5 : rawTime.length);
      }
      return '00:00';
    }

    expect(parseDate(malformedStart), equals('明天早上九點:00'));
    expect(parseHr(malformedStart), equals('00:00'));
    expect(parseDate(manualStartStr), equals(key));
    expect(parseHr(manualStartStr), equals('10:00'));

    await db.close();
  });
}
