import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static const String _maxLevelKey = 'max_level_reached';

  /// 保存最高关卡
  static Future<void> saveMaxLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxLevelKey, level);
  }

  /// 获取最高关卡
  static Future<int> getMaxLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxLevelKey) ?? 1;
  }
}
