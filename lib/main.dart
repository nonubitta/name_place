import 'package:flutter/material.dart';

import 'screens/splash_page.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeController.instance.load();

  runApp(const NamePlaceAnimalThingApp());
}

class NamePlaceAnimalThingApp extends StatelessWidget {
  const NamePlaceAnimalThingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        final palette = ThemeController.instance.lightPalette;

        return MaterialApp(
          title: 'Name Place Animal Thing',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(palette),
          darkTheme: AppTheme.dark(),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            if (isDark || child == null) {
              return child ?? const SizedBox.shrink();
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.background, palette.backgroundGradientEnd],
                ),
              ),
              child: child,
            );
          },
          home: const SplashPage(),
        );
      },
    );
  }
}