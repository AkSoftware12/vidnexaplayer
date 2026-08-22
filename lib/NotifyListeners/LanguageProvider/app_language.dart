/// A language selectable from the app's language picker bottom sheet.
///
/// Only [AppStrings] entries for `en` and `hi` are actually translated today
/// (see app_strings.dart) — every other language here falls back to the
/// English strings until real translations are added, but the Flutter
/// framework's own widgets (date pickers, "OK"/"Cancel", etc.) already speak
/// all of these via `flutter_localizations`.
class AppLanguage {
  final String code;
  final String nativeName;
  final String englishName;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flag,
  });
}

const List<AppLanguage> kAppLanguages = [
  AppLanguage(code: 'en', nativeName: 'English', englishName: 'English', flag: '🇬🇧'),
  AppLanguage(code: 'hi', nativeName: 'हिन्दी', englishName: 'Hindi', flag: '🇮🇳'),
  // AppLanguage(code: 'es', nativeName: 'Español', englishName: 'Spanish', flag: '🇪🇸'),
  // AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French', flag: '🇫🇷'),
  // AppLanguage(code: 'ar', nativeName: 'العربية', englishName: 'Arabic', flag: '🇸🇦'),
  // AppLanguage(code: 'de', nativeName: 'Deutsch', englishName: 'German', flag: '🇩🇪'),
  // AppLanguage(code: 'pt', nativeName: 'Português', englishName: 'Portuguese', flag: '🇵🇹'),
  // AppLanguage(code: 'bn', nativeName: 'বাংলা', englishName: 'Bengali', flag: '🇧🇩'),
  // AppLanguage(code: 'ru', nativeName: 'Русский', englishName: 'Russian', flag: '🇷🇺'),
  // AppLanguage(code: 'zh', nativeName: '中文', englishName: 'Chinese', flag: '🇨🇳'),
];
