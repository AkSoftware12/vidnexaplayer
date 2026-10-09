/// A language selectable from the app's language picker bottom sheet.
///
/// `en` and `hi` live inline in each strings file; the other languages live
/// in translations/<code>.dart. A key a language leaves out falls back to
/// English. The Flutter framework's own widgets (date pickers, "OK"/"Cancel",
/// RTL for Arabic) come from `flutter_localizations`.
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
  AppLanguage(code: 'es', nativeName: 'Español', englishName: 'Spanish', flag: '🇪🇸'),
  AppLanguage(code: 'pt', nativeName: 'Português (Brasil)', englishName: 'Portuguese', flag: '🇧🇷'),
  AppLanguage(code: 'id', nativeName: 'Bahasa Indonesia', englishName: 'Indonesian', flag: '🇮🇩'),
  AppLanguage(code: 'ar', nativeName: 'العربية', englishName: 'Arabic', flag: '🇸🇦'),
  AppLanguage(code: 'bn', nativeName: 'বাংলা', englishName: 'Bengali', flag: '🇧🇩'),
  AppLanguage(code: 'ru', nativeName: 'Русский', englishName: 'Russian', flag: '🇷🇺'),
  AppLanguage(code: 'tr', nativeName: 'Türkçe', englishName: 'Turkish', flag: '🇹🇷'),
  AppLanguage(code: 'vi', nativeName: 'Tiếng Việt', englishName: 'Vietnamese', flag: '🇻🇳'),
  // AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French', flag: '🇫🇷'),
  // AppLanguage(code: 'de', nativeName: 'Deutsch', englishName: 'German', flag: '🇩🇪'),
  // AppLanguage(code: 'zh', nativeName: '中文', englishName: 'Chinese', flag: '🇨🇳'),
];
