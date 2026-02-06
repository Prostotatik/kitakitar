import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/firebase_options.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/providers/user_provider.dart';
import 'package:kitakitar_mobile/screens/auth/login_screen.dart';
import 'package:kitakitar_mobile/screens/auth/register_screen.dart';
import 'package:kitakitar_mobile/screens/auth/forgot_password_screen.dart';
import 'package:kitakitar_mobile/screens/main/main_screen.dart';
import 'package:kitakitar_mobile/screens/scan/scan_result_screen.dart';
import 'package:kitakitar_mobile/screens/qr/qr_scanner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with project configuration
  // IMPORTANT: First configure Firebase via flutterfire configure
  // or create firebase_options.dart manually
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // If firebase_options.dart is not configured or already initialized
    if (e.toString().contains('duplicate-app')) {
      // Firebase already initialized, this is normal
      print('ℹ️ Firebase already initialized');
    } else {
      print('⚠️ ERROR: Firebase not configured!');
      print('📖 See README.md for setup instructions');
      print('Error: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, authProvider, previous) {
            final up = previous ?? UserProvider();
            if (authProvider.user != null &&
                up.user?.id != authProvider.user!.uid) {
              up.init(authProvider);
            } else if (authProvider.user == null) {
              up.init(authProvider);
            }
            return up;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'KitaKitar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          primaryColor: const Color(0xFF4CAF50),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        routerConfig: _router,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isAuthenticated;
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/forgot-password';

    // If not logged in and trying to access protected route, redirect to login
    if (!isLoggedIn && !isAuthRoute) {
      return '/login';
    }
    // If logged in and on login screen, redirect to home
    // Do NOT redirect from /register or /forgot-password - allow users to access these screens
    // even if logged in (they might want to create another account or reset password)
    if (isLoggedIn && state.matchedLocation == '/login') {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/scan-result',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        return ScanResultScreen(
          detectedMaterials: args?['detectedMaterials'] ?? [],
          imagePath: args?['imagePath'],
        );
      },
    ),
    GoRoute(
      path: '/qr-scanner',
      builder: (context, state) => const QrScannerScreen(),
    ),
  ],
);

