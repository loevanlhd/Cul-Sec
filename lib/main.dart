import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';
import 'services/display_service.dart';
import 'services/haptics.dart';
import 'services/sounds.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialisation de Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Initialisation de Google Sign-In (OBLIGATOIRE avant tout le reste)
  await AuthService.instance.initialize();

  // 3. Connexion anonyme (silencieuse)
  await AuthService.instance.signInAnonymously();

  await DisplayService.enableHighRefreshRate();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  Animate.defaultDuration = AppMotion.base;
  Animate.defaultCurve = AppMotion.enter;

  final AppState appState = await AppState.load();
  
  final String? uid = AuthService.instance.uid;
  if (uid != null) {
    await appState.setFirebaseUid(uid);
  }

  Haptics.enabled = appState.hapticsEnabled;
  Sounds.enabled = appState.soundsEnabled;

  unawaited(ContentService.instance.preloadAll());

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const CulSecApp(),
    ),
  );
}

class CulSecApp extends StatelessWidget {
  const CulSecApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.watch<AppState>().themeMode;

    return MaterialApp(
      title: 'Cul Sec',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      scrollBehavior: const AppScrollBehavior(),
      home: const SplashScreen(),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}