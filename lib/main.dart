import 'dart:async';

import 'package:contact_photos/home_page.dart';
import 'package:contact_photos/screens/intro/intro_carousel_screen.dart';
import 'package:contact_photos/services/preferences_service.dart';
import 'package:contact_photos/services/purchase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_widgets/liquid_glass_setup.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();

      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      await PreferencesService.syncFromFirestoreIfNeeded();
      await LiquidGlassWidgets.initialize();
      PurchaseService.instance.initialize();
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
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurpleAccent, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
