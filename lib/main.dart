import 'dart:async';

import 'package:contact_photos/home_page.dart';
import 'package:contact_photos/screens/intro/intro_carousel_screen.dart';
import 'package:contact_photos/services/preferences_service.dart';
import 'package:contact_photos/services/purchase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liquid_glass_widgets/liquid_glass_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final initialBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      SystemChrome.setSystemUIOverlayStyle(
        initialBrightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      );
      await Firebase.initializeApp();

      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      await PreferencesService.syncFromFirestoreIfNeeded();
      await LiquidGlassWidgets.initialize();
      PurchaseService.instance.initialize();
      final prefs = await SharedPreferences.getInstance();
      final isFirstRun = prefs.getBool('app_installed') == null;
      if (isFirstRun) {
        await const FlutterSecureStorage()
            .deleteAll(); // clear leftover keychain
        await prefs.setBool('app_installed', true);
      }
      runApp(LiquidGlassWidgets.wrap(
        child: const MyApp(),
        adaptiveQuality: true,
      ));
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class MyApp extends HookWidget {
  const MyApp({
    this.initialIntroShown,
    super.key,
  });

  final bool? initialIntroShown;

  @override
  Widget build(BuildContext context) {
    final introShown = useState<bool?>(null);

    useEffect(() {
      if (initialIntroShown != null) {
        introShown.value = initialIntroShown;
        return null;
      }

      Future<void> loadIntroShown() async {
        introShown.value = await PreferencesService.hasShownIntro();
      }

      unawaited(loadIntroShown());
      return null;
    }, const []);

    final Widget home;
    if (introShown.value == null) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (introShown.value ?? false) {
      home = const HomePage();
    } else {
      home = IntroCarouselScreen(
        onFinished: () async {
          await PreferencesService.setIntroShown(value: true);
          introShown.value = true;
        },
      );
    }

    return MaterialApp(
      title: 'Contact Photos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurpleAccent, brightness: Brightness.dark),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: home,
    );
  }
}
