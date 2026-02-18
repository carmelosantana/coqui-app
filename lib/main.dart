import 'package:flutter/material.dart';
import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Pages/main_page.dart';
import 'package:coqui_app/Pages/settings_page/settings_page.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/services.dart';
import 'package:coqui_app/Utils/material_color_adapter.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize PathManager
  await PathManager.initialize();

  // Initialize Hive
  if (Platform.isLinux) {
    Hive.init(PathManager.instance.documentsDirectory.path);
  } else {
    await Hive.initFlutter();
  }

  Hive.registerAdapter(MaterialColorAdapter());

  await Hive.openBox('settings');

  // Create services
  final apiService = CoquiApiService();
  final databaseService = DatabaseService();
  final instanceService = InstanceService();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: apiService),
        Provider.value(value: databaseService),
        Provider.value(value: instanceService),
        ChangeNotifierProvider(
          create: (_) => InstanceProvider(
            instanceService: instanceService,
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            apiService: apiService,
            databaseService: databaseService,
          ),
        ),
      ],
      child: const CoquiApp(),
    ),
  );
}

class CoquiApp extends StatelessWidget {
  const CoquiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(
        keys: ['color', 'brightness'],
      ),
      builder: (context, box, _) {
        return MaterialApp(
          title: AppConstants.appName,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              brightness:
                  _brightness ?? MediaQuery.platformBrightnessOf(context),
              dynamicSchemeVariant: DynamicSchemeVariant.neutral,
              seedColor: box.get('color', defaultValue: Colors.green),
            ),
            appBarTheme: const AppBarTheme(centerTitle: true),
            useMaterial3: true,
          ),
          builder: (context, child) => ResponsiveBreakpoints.builder(
            breakpoints: [
              const Breakpoint(start: 0, end: 450, name: MOBILE),
              const Breakpoint(start: 451, end: 800, name: TABLET),
              const Breakpoint(start: 801, end: 1920, name: DESKTOP),
            ],
            useShortestSide: true,
            child: child!,
          ),
          onGenerateRoute: (settings) {
            if (settings.name == '/') {
              return MaterialPageRoute(
                builder: (context) => const CoquiMainPage(),
              );
            }

            if (settings.name == '/settings') {
              return MaterialPageRoute(
                builder: (context) => const SettingsPage(),
              );
            }

            assert(false, 'Need to implement ${settings.name}');
            return null;
          },
        );
      },
    );
  }

  Brightness? get _brightness {
    final brightnessValue = Hive.box('settings').get('brightness');
    if (brightnessValue == null) return null;
    return brightnessValue == 1 ? Brightness.light : Brightness.dark;
  }
}
