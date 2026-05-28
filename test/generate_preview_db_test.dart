// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:ai_app/database/database_helper.dart';

void main() {
  test('Generate DB', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    var db = await DatabaseHelper.instance.database;
    var originalPath = db.path;
    await db.close();
    
    var targetFile = File('app_database_preview.db');
    var srcFile = File(originalPath);
    if (srcFile.existsSync()) {
      srcFile.copySync(targetFile.path);
      print('@@@ SUCCESS @@@');
    }
  });
}
