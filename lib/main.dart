import 'package:flutter/material.dart';
import 'core/services/api_service.dart';
import 'core/services/ble_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/emergency_service.dart';
import 'core/services/location_service.dart';
import 'core/services/message_service.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_page.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LocalStore();
  final logged = await store.isLoggedIn();
  final onboarded = await store.isOnboarded();

  runApp(ResQNetApp(
    loggedIn: logged,
    onboarded: onboarded,
  ));
}

class ResQNetApp extends StatefulWidget {
  final bool loggedIn;
  final bool onboarded;

  const ResQNetApp({
    super.key,
    required this.loggedIn,
    required this.onboarded,
  });

  @override
  State<ResQNetApp> createState() => _ResQNetAppState();
}

class _ResQNetAppState extends State<ResQNetApp> {
  late bool _loggedIn = widget.loggedIn;
  late bool _onboarded = widget.onboarded;

  final LocalStore _store = LocalStore();
  late final LocationService _locationService;
  late final BleService _bleService;
  late final ApiService _apiService;
  late final ConnectivityService _connectivityService;
  late final MessageService _messageService;
  late final EmergencyService _emergencyService;

  @override
  void initState() {
    super.initState();
    _locationService = LocationService(store: _store);
    _bleService = BleService();
    _apiService = ApiService();
    _connectivityService = ConnectivityService();
    _messageService = MessageService(
      store: _store,
      ble: _bleService,
      connectivity: _connectivityService,
    );
    _emergencyService = EmergencyService(
      store: _store,
      location: _locationService,
      ble: _bleService,
      api: _apiService,
      connectivity: _connectivityService,
      messageService: _messageService,
    );
  }

  @override
  void dispose() {
    _emergencyService.dispose();
    _messageService.dispose();
    _bleService.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    setState(() => _onboarded = true);
  }

  void _login() {
    setState(() => _loggedIn = true);
  }

  void _logout() async {
    await _store.setSession(loggedIn: false);
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget homeWidget;

    if (!_onboarded) {
      homeWidget = OnboardingPage(
        store: _store,
        onFinished: _finishOnboarding,
      );
    } else if (!_loggedIn) {
      homeWidget = AuthPage(
        store: _store,
        onLogin: _login,
      );
    } else {
      homeWidget = HomePage(
        store: _store,
        emergencyService: _emergencyService,
        onLogout: _logout,
      );
    }

    return MaterialApp(
      title: 'ResQNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: homeWidget,
    );
  }
}
