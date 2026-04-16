import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'lib/database/database_helper.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  var db = await DatabaseHelper.instance.database;
  var originalPath = db.path;
  await db.close();
  
  // Copy to project root so user can easily click it
  var targetFile = File('app_database_preview.db');
  var srcFile = File(originalPath);
  if (srcFile.existsSync()) {
    srcFile.copySync(targetFile.path);
    print('成功！已經產生檔案在：');
    print(targetFile.absolute.path);
  } else {
    print('找不到產生的檔案。');
  }
  exit(0);
}
