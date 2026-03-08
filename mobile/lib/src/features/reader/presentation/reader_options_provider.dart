import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderOptions {
  final double fontSize;
  final String fontFamily;
  final String theme; // 'light', 'dark', 'sepia'

  ReaderOptions({
    required this.fontSize,
    required this.fontFamily,
    required this.theme,
  });

  ReaderOptions copyWith({
    double? fontSize,
    String? fontFamily,
    String? theme,
  }) {
    return ReaderOptions(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      theme: theme ?? this.theme,
    );
  }
}

class ReaderOptionsNotifier extends StateNotifier<ReaderOptions> {
  final SharedPreferences _prefs;

  ReaderOptionsNotifier(this._prefs)
    : super(
        ReaderOptions(
          fontSize: _prefs.getDouble('reader_font_size') ?? 16.0,
          fontFamily: _prefs.getString('reader_font_family') ?? 'Roboto',
          theme: _prefs.getString('reader_theme') ?? 'light',
        ),
      );

  void updateFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _prefs.setDouble('reader_font_size', size);
  }

  void updateFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
    _prefs.setString('reader_font_family', family);
  }

  void updateTheme(String theme) {
    state = state.copyWith(theme: theme);
    _prefs.setString('reader_theme', theme);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main.dart',
  );
});

final readerOptionsProvider =
    StateNotifierProvider<ReaderOptionsNotifier, ReaderOptions>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ReaderOptionsNotifier(prefs);
    });
