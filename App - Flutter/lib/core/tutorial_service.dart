import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const _kDrawerTutorialSeen = 'hasSeenDrawerTutorial';

  static Future<bool> shouldShowDrawerTutorial() async {
    final p = await SharedPreferences.getInstance();
    return !(p.getBool(_kDrawerTutorialSeen) ?? false);
  }

  static Future<void> markDrawerTutorialShown() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDrawerTutorialSeen, true);
  }
}