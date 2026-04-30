import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _onboardingSeenKey = 'onboarding_seen_v1';
  bool _checkingFirstAccess = true;
  bool _showOnboarding = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeEntryFlow();
  }

  Future<void> _initializeEntryFlow() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool(_onboardingSeenKey) ?? false;

    if (!mounted) return;

    if (seenOnboarding) {
      setState(() {
        _checkingFirstAccess = false;
      });
      await _goToNextScreen();
      return;
    }

    setState(() {
      _checkingFirstAccess = false;
      _showOnboarding = true;
    });
  }

  Future<void> _goToNextScreen() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    var attempts = 0;
    while (!authProvider.isSessionInitialized && attempts < 25 && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      attempts++;
    }
    if (!mounted) return;

    final shouldGoToHome =
        authProvider.rememberMe && authProvider.isAuthenticated;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => shouldGoToHome ? const MainShell() : const LoginScreen(),
      ),
    );
  }

  Future<void> _handleStart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    if (!mounted) return;
    await _goToNextScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingFirstAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFF8B7FB8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF5F3E8)),
        ),
      );
    }

    if (!_showOnboarding) {
      return const Scaffold(
        backgroundColor: Color(0xFF8B7FB8),
        body: SizedBox.expand(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF8B7FB8),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Gimie',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF5F3E8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Conectando pessoas e produtos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFF5F3E8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F3E8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3E8).withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3E8).withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Next Button
            Padding(
              padding: const EdgeInsets.only(right: 40, bottom: 40),
              child: Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: _handleStart,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F3E8),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(100),
                        topRight: Radius.circular(100),
                        bottomLeft: Radius.circular(100),
                      ),
                    ),
                    child: const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Começar',
                              style: TextStyle(
                                fontFamily: 'Raleway',
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B2C5C),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              color: Color(0xFF6B2C5C),
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
