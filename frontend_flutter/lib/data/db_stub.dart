import 'package:sqflite/sqflite.dart';

Future<Database> openLocalDatabase(String filePath) {
  throw UnsupportedError('Cannot create a database without a platform-specific implementation');
}
