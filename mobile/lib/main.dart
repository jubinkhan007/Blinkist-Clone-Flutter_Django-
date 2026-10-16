import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/routing/app_router.dart';
import 'package:mobile/src/features/reader/presentation/reader_options_provider.dart';
import 'package:mobile/src/features/reader/data/audio_handler.dart';

final audioHandlerProvider = Provider<AppAudioHandler>((ref) {
  throw UnimplementedError();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final audioHandler = await AudioService.init(
    builder: () => AppAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.blinkist.clone.audio',
      androidNotificationChannelName: 'Blinkist Audio Narration',
      androidNotificationChannelDescription: 'Blinkist audio summaries and narrated blinks',
      androidNotificationIcon: 'mipmap/ic_launcher',
      notificationColor: Color(0xFF2CE080),
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 15),
      rewindInterval: Duration(seconds: 15),
    ),
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Blinkist App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
