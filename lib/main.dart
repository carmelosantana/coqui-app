import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Pages/channels_page/channels_page.dart';
import 'package:coqui_app/Pages/commands_help_page/commands_help_page.dart';
import 'package:coqui_app/Pages/config_page/config_page.dart';
import 'package:coqui_app/Pages/info_page/info_page.dart';
import 'package:coqui_app/Pages/main_page.dart';
import 'package:coqui_app/Pages/server_page/server_page.dart';
import 'package:coqui_app/Pages/settings_page/settings_page.dart';
import 'package:coqui_app/Pages/tasks_page/tasks_page.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/channel_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Providers/project_provider.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Providers/schedule_provider.dart';
import 'package:coqui_app/Providers/supporter_provider.dart';
import 'package:coqui_app/Providers/task_provider.dart';
import 'package:coqui_app/Providers/work_provider.dart';
import 'package:coqui_app/Providers/webhook_provider.dart';
import 'package:coqui_app/Pages/work_page/work_page.dart';
import 'package:coqui_app/Pages/work_page/work_navigation.dart';
import 'package:coqui_app/Services/local_server_service.dart';
import 'package:coqui_app/Services/services.dart';
import 'package:coqui_app/Theme/theme.dart';
import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Platform/database_factory.dart' as db_factory;
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:app_links/app_links.dart';
import 'package:coqui_app/Utils/material_color_adapter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await _initializeApp();
  } catch (error) {
    runApp(_StartupFailureApp(message: _startupErrorMessage(error)));
  }
}

Future<void> _initializeApp() async {
  // Initialize platform-appropriate database factory (FFI on desktop, WASM on web)
  await db_factory.initDatabaseFactory();

  // Initialize PathManager (no-op on web)
  await PathManager.initialize();

  // Initialize Hive (uses IndexedDB on web, application support on desktop)
  if (!PlatformInfo.isWeb && PlatformInfo.isDesktop) {
    Hive.init(PathManager.instance.documentsPath);
  } else {
    await Hive.initFlutter();
  }

  // Register adapters before opening any boxes.
  Hive.registerAdapter(MaterialColorAdapter());

  await _openSettingsBoxWithRecovery();

  // Create services
  final apiService = CoquiApiService();
  final databaseService = DatabaseService();
  final instanceService = InstanceService();

  await instanceService.initialize();
  await instanceService.ensureDefaultInstance();

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
          create: (_) => ChannelProvider(
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskProvider(
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WebhookProvider(
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ScheduleProvider(
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LoopProvider(
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ProjectProvider(
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkProvider(
            apiService: apiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SupporterProvider(),
        ),
        if (PlatformInfo.isManagedLocalServerSupported)
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

Future<void> _openSettingsBoxWithRecovery() async {
  try {
    await Hive.openBox('settings');
    return;
  } catch (error) {
    if (_isSettingsLockError(error)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await Hive.openBox('settings');
      return;
    }

    if (_isRecoverableSettingsSchemaError(error)) {
      await Hive.deleteBoxFromDisk('settings');
      await Hive.openBox('settings');
      return;
    }

    rethrow;
  }
}

bool _isSettingsLockError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('settings.lock') ||
      message.contains('lock failed') ||
      message.contains('resource temporarily unavailable');
}

bool _isRecoverableSettingsSchemaError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('unknown typeid') ||
      message.contains('cannot read, unknown typeid') ||
      message.contains('hiveerror');
}

String _startupErrorMessage(Object error) {
  if (_isSettingsLockError(error)) {
    return 'Coqui could not open its local settings because another Coqui instance is already using the same data directory. Close the other instance and relaunch.';
  }

  return 'Coqui failed to start.\n\n$error';
}

class _StartupFailureApp extends StatelessWidget {
  final String message;

  const _StartupFailureApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Startup Failed',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(message),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CoquiApp extends StatefulWidget {
  const CoquiApp({super.key});

  @override
  State<CoquiApp> createState() => _CoquiAppState();
}

class _CoquiAppState extends State<CoquiApp> {
  static const MethodChannel _navigationChannel =
      MethodChannel('coqui/navigation');

  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _installNativeNavigationHandler();
    _initDeepLinks();
  }

  void _installNativeNavigationHandler() {
    _navigationChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'openCommandsHelp':
          _navigatorKey.currentState?.pushNamed('/commands');
          return;
        default:
          throw MissingPluginException(
            'Unhandled navigation method: ${call.method}',
          );
      }
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    // Deep link handler — extend here for chat priming, toolkit install, etc.
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(
        keys: ['brightness', 'selected_theme', 'is_supporter'],
      ),
      builder: (context, box, _) {
        final themeName = _supporterThemeName;
        return MaterialApp(
          navigatorKey: _navigatorKey,
          restorationScopeId: 'coqui_app',
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

            if (settings.name == '/info') {
              return MaterialPageRoute(
                builder: (context) => const InfoPage(),
              );
            }

            if (settings.name == '/commands') {
              return MaterialPageRoute(
                builder: (context) => const CommandsHelpPage(),
              );
            }

            if (settings.name == '/channels') {
              return MaterialPageRoute(
                builder: (context) => const ChannelsPage(),
              );
            }

            if (settings.name == '/tasks') {
              return MaterialPageRoute(
                builder: (context) => const TasksPage(),
              );
            }

            if (settings.name == '/work') {
              final args = WorkPageArguments.fromRouteArguments(
                settings.arguments,
              );
              return MaterialPageRoute(
                builder: (context) => WorkPage(arguments: args),
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
