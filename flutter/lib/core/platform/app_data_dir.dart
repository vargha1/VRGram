import 'dart:io';

/// Provides the app's data directory path for file storage.
/// Set by main.dart on startup with the value from native getDataDir.
class AppDataDir {
  static String _path = '';

  static String get path => _path;

  static void init(String dataDir) {
    _path = dataDir;
  }

  static File file(String name) {
    if (_path.isEmpty) {
      throw StateError('AppDataDir not initialized. Call AppDataDir.init() first.');
    }
    return File('$_path/$name');
  }
}
