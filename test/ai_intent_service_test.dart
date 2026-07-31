import 'package:flutter_test/flutter_test.dart';
import 'package:ai_app/services/ai_intent_service.dart';

void main() {
  test('AIIntentService parse tests for generic and specific intents', () {
    expect(AIIntentService.parse('新增').intent, UserIntent.addGeneric);
    expect(AIIntentService.parse('修改').intent, UserIntent.editGeneric);
    expect(AIIntentService.parse('新增行程').intent, UserIntent.createItinerary);
    expect(AIIntentService.parse('新增待辦').intent, UserIntent.createTodo);
    expect(AIIntentService.parse('修改行程').intent, UserIntent.editItinerary);
    expect(AIIntentService.parse('修改待辦').intent, UserIntent.editTodo);
  });
}
