import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:baqati/app/app_dependencies.dart';
import 'package:baqati/router.dart';
import 'package:baqati/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The whole graph is built before the first frame so navigation never has to
  // guess whether the user has already onboarded.
  final AppDependencies dependencies = await AppDependencies.bootstrap();
  runApp(BaqatiApp(dependencies: dependencies));
}

class BaqatiApp extends StatefulWidget {
  const BaqatiApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<BaqatiApp> createState() => _BaqatiAppState();
}

class _BaqatiAppState extends State<BaqatiApp> {
  late final GoRouter _router = buildRouter(widget.dependencies);

  @override
  void dispose() {
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'باقتي',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: _router,
    locale: const Locale('ar'),
    supportedLocales: const <Locale>[Locale('ar')],
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The Arabic locale already implies RTL; this makes it unconditional, so a
    // future locale addition can't silently flip the layout the app was
    // designed around.
    builder: (BuildContext context, Widget? child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
