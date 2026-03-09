import 'package:flutter/material.dart';
import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Pages/config_page/config_page.dart';
import 'package:coqui_app/Pages/main_page.dart';
import 'package:coqui_app/Pages/server_page/server_page.dart';
import 'package:coqui_app/Pages/settings_page/settings_page.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Providers/supporter_provider.dart';
import 'package:coqui_app/Services/local_server_service.dart';
import 'package:coqui_app/Services/services.dart';
import 'package:coqui_app/Theme/theme.dart';
import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Platform/database_factory.dart' as db_factory;
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:responsive_framework/responsive_framework.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize platform-appropriate database factory (FFI on desktop, WASM on web)
  await db_factory.initDatabaseFactory();

  // Initialize PathManager (no-op on web)
  await PathManager.initialize();

  // Initialize Hive (uses IndexedDB on web, filesystem on native)
  if (!PlatformInfo.isWeb && PlatformInfo.isLinux) {
    Hive.init(PathManager.instance.documentsPath);
  } else {
    await Hive.initFlutter();
  }

  await Hive.openBox('settings');

  // Create services
  final apiService = CoquiApiService();
  final databaseService = DatabaseService();
  final instanceService = InstanceService();
  final purchaseService = PurchaseService();

  // Initialize in-app purchase listener (no-op on non-iOS).
  await purchaseService.initialize();

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
        ChangeNotifierProxyProvider<InstanceProvider, ChatProvider>(
          create: (_) => ChatProvider(
            apiService: apiService,
            databaseService: databaseService,
          ),
          update: (_, instanceProvider, chatProvider) {
            chatProvider!.listenToInstanceChanges(instanceProvider);
            return chatProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => RoleProvider(
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SupporterProvider(
            purchaseService: purchaseService,
          ),
        ),
        if (PlatformInfo.isDesktop)
          ChangeNotifierProvider(
            create: (context) => LocalServerProvider(
              service: LocalServerService(),
              instanceProvider:
                  Provider.of<InstanceProvider>(context, listen: false),
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
        keys: ['brightness', 'selected_theme', 'is_supporter'],
      ),
      builder: (context, box, _) {
        final themeName = _supporterThemeName;
        return MaterialApp(
          title: AppConstants.appName,
          theme: CoquiTheme.light(themeName: themeName),
          darkTheme: CoquiTheme.dark(themeName: themeName),
          themeMode: _themeMode,
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

            if (settings.name == '/server' && PlatformInfo.isDesktop) {
              return MaterialPageRoute(
                builder: (context) => const ServerPage(),
              );
            }

            if (settings.name == '/config') {
              return MaterialPageRoute(
                builder: (context) => const ConfigPage(),
              );
            }

            assert(false, 'Need to implement ${settings.name}');
            return null;
          },
        );
      },
    );
  }

  ThemeMode get _themeMode {
    final brightnessValue = Hive.box('settings').get('brightness');
    if (brightnessValue == null) return ThemeMode.system;
    return brightnessValue == 1 ? ThemeMode.light : ThemeMode.dark;
  }

  /// Returns the active supporter theme name, or null for the default palette.
  /// Only returns a theme when the user is a verified supporter.
  String? get _supporterThemeName {
    final box = Hive.box('settings');
    final isSupporter = box.get('is_supporter', defaultValue: false);
    if (isSupporter != true) return null;
    return box.get('selected_theme') as String?;
  }
}
