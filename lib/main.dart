import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'providers/product_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/scraping_provider.dart';
import 'services/share_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  // Note: Run `flutterfire configure` to generate firebase_options.dart
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  
  // Initialize Share Service
  try {
    await ShareService.instance.initialize();
    debugPrint('Share Service initialized successfully');
  } catch (e) {
    debugPrint('Share Service initialization error: $e');
  }
  
  runApp(const GimieApp());
}

class GimieApp extends StatelessWidget {
  const GimieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ScrapingProvider()),
      ],
      child: MaterialApp(
        title: 'Gimie',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF8B7FB8),
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B7FB8),
            primary: const Color(0xFF8B7FB8),
            secondary: const Color(0xFF6B2C5C),
          ),
          fontFamily: 'Raleway',
          textTheme: const TextTheme(
            // Títulos grandes — Raleway SemiBold (ex: "Gimie" no splash/login)
            displayLarge: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w600,
              fontSize: 72,
            ),
            displayMedium: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w600,
              fontSize: 48,
            ),
            displaySmall: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w600,
              fontSize: 36,
            ),
            // Seções e nomes — Raleway SemiBold (ex: "Giulia Alvares", "Pastes")
            headlineLarge: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w600,
              fontSize: 28,
            ),
            headlineMedium: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
            headlineSmall: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
            // AppBar e cards — Raleway Medium
            titleLarge: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
            titleMedium: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            titleSmall: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            // Corpo de texto — Roboto Regular (ex: "@giuliaalvares", descrições)
            bodyLarge: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            bodySmall: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
            // Botões e labels — Raleway SemiBold (ex: "Next→", "Entrar")
            labelLarge: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            labelMedium: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            labelSmall: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
              fontSize: 11,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B7FB8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              textStyle: const TextStyle(
                fontFamily: 'Raleway',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: 'Raleway',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: 'Raleway',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          appBarTheme: const AppBarTheme(
            titleTextStyle: TextStyle(
              fontFamily: 'Raleway',
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Color(0xFF6B2C5C),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            hintStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B7FB8), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
