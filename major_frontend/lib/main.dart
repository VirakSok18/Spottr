import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'services/config.dart' as app_config;
import 'screens/home/home_screen.dart';
import 'screens/main_navigation_wrapper.dart';
import 'screens/landing/onboarding_screen.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/body_data/body_data.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:flutter/services.dart';

enum AuthView { landing, signup, signin }

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background Handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  await Firebase.initializeApp();
  await NotificationService().ensureInitialized(); // Must initialize in background isolate
  // Removed showLocalNotification here to prevent duplicates (system shows it automatically for background)
}

void main() async {
  print('App starting...');
  WidgetsFlutterBinding.ensureInitialized();
  print('Binding initialized');
  try {
    await Firebase.initializeApp();
    print('Firebase initialized');
    
    // Initialize Config and find workign IP
    await app_config.Config.init();
    await Supabase.initialize(
      url: app_config.Config.supabaseUrl,
      anonKey: app_config.Config.supabaseAnonKey,
    );
    print('Supabase initialized');
    
    // Initialize Notification Service
    await NotificationService().initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  // Disable runtime fetching to ensure only local bundled fonts are used (prevents flickering)
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const MyApp());
  print('MyApp running');
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFinder',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1B1B1B),
        // Use the font family directly. If bundled in pubspec.yaml, this will be instant.
        fontFamily: 'Poppins',
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      navigatorKey: navigatorKey,
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  static _AuthWrapperState? of(BuildContext context) =>
      context.findAncestorStateOfType<_AuthWrapperState>();

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  AuthView _currentView = AuthView.landing;
  Future<Map<String, dynamic>?>? _profileFuture;
  String? _lastUid;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  static bool _handledInitialLink = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null && !_handledInitialLink) {
        _handledInitialLink = true;
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('Deep Link Init Failed: $e');
    }

    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      print('Deep Link Stream Error: $err');
    });
  }

  void _handleDeepLink(Uri? uri) {
    if (uri == null) return;
    print('Received Deep Link: $uri');

    // Ensure we run navigation logic after the current frame to avoid
    // conflicts with initial app building or pending transitions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // popUntil((route) => route.isFirst) can sometimes fail if called too early
      // or if the stack is in a transition. We'll pop until we can't pop anymore.
      while (navigatorKey.currentState?.canPop() ?? false) {
        navigatorKey.currentState?.pop();
      }

      if (uri.scheme == 'spottr') {
        if (uri.host == 'payment-success' || uri.host == 'profile') {
          // Trigger a refresh of the profile data
          refreshProfile();
          // Broadcast to any active screens
          AuthService.notifyProfileUpdate();
        }
      }
    });
  }

  void showSignUp() {
    setState(() {
      _currentView = AuthView.signup;
    });
  }

  void showSignIn() {
    setState(() {
      _currentView = AuthView.signin;
    });
  }

  void handleLogout() async {
    print('Logging out...');
    await AuthService().signOut();
    setState(() {
      _profileFuture = null;
      _lastUid = null;
      _currentView = AuthView.signin; // Default to Sign In
    });
  }

  void handleAccountMissing() async {
    print('AuthWrapper: Account missing in DB, signing out and redirecting to landing');
    await AuthService().signOut();
    setState(() {
      _profileFuture = null;
      _lastUid = null;
      _currentView = AuthView.landing; // Fresh start
    });
  }

  void refreshProfile() {
    setState(() {
      _lastUid = null; // Force re-fetch
      _profileFuture = AuthService().getUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final user = snapshot.data;
        print('StreamBuilder Update: User UID = ${user?.uid}');
        
        if (user != null) {
          // If user changed or profile not fetched yet
          if (_profileFuture == null || _lastUid != user.uid) {
            print('AuthWrapper: Fetching profile for ${user.uid}');
            _lastUid = user.uid;
            _profileFuture = AuthService().getUserProfile();
          } else {
            print('AuthWrapper: Profile already exists or fetching for ${user.uid}');
          }

          return FutureBuilder<Map<String, dynamic>?>(
            future: _profileFuture,
            builder: (context, profileSnapshot) {
              print('FutureBuilder State: ${profileSnapshot.connectionState}');
              
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              final profile = profileSnapshot.data;
              print('AuthWrapper Profile Received: $profile');

              // Update FCM Token for existing sessions
              if (profile != null) {
                  NotificationService().updateTokenOnServer(user.uid);
              }
              
              if (profileSnapshot.hasError) {
                print('AuthWrapper Profile Error: ${profileSnapshot.error}');
              }
              
              final isSetup = profile != null && (profile['is_setup_completed'] == true || profile['is_setup_completed'] == 1);
              print('AuthWrapper: isSetup = $isSetup');
              
              if (profile == null) {
                print('AuthWrapper: Profile is NULL after fetch. Ghost session detected.');
                // Use a post-frame callback to avoid calling handleAccountMissing during build
                WidgetsBinding.instance.addPostFrameCallback((_) => handleAccountMissing());
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!isSetup) {
                print('AuthWrapper: Navigating to GenderSelectionScreen');
                return GenderSelectionScreen(
                  onComplete: () {
                    print('AuthWrapper: GenderSelection complete, refreshing profile');
                    refreshProfile();
                  },
                  onLogout: () => handleLogout(),
                );
              }
              
              print('AuthWrapper: Navigating to MainNavigationWrapper');
              return MainNavigationWrapper(onLogout: () => handleLogout());
            },
          );
        }

        // If not logged in, reset profile state
        if (_lastUid != null) {
          print('AuthWrapper: User logged out, clearing state');
          _profileFuture = null;
          _lastUid = null;
        }

        // Routing for unauthenticated users
        switch (_currentView) {
          case AuthView.landing:
            return OnboardingScreen(onComplete: () => showSignIn());
          case AuthView.signup:
            return SignUpScreen(
              onShowSignIn: () => showSignIn(),
            );
          case AuthView.signin:
            return SignInScreen(
              onShowSignUp: () => showSignUp(),
            );
        }
      },
    );
  }
}
