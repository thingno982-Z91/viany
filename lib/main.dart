import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/app_controller.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() {
  // runZonedGuarded catches errors thrown outside the normal Flutter
  // widget-build error handling (e.g. inside async gaps, timers, or
  // Future callbacks that aren't awaited directly by a widget). Without
  // this, such errors would crash the whole app silently in release mode.
  runZonedGuarded(() {
    runApp(const FinanceApp());
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  final AppController _controller = AppController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);
    _controller.load();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'البيان المالي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Follows the device's system setting automatically. If manual
      // in-app toggling is wanted later, swap this for a value stored
      // in AppSettings and controlled from the settings screen.
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          if (_controller.isLoading) {
            return const _LoadingScreen();
          }

          return Stack(
            children: [
              _controller.hasOnboarded
                  ? HomeScreen(controller: _controller)
                  : OnboardingScreen(
                      controller: _controller,
                      onDone: () => setState(() {}),
                    ),
              if (_controller.lastError != null)
                _ErrorBanner(
                  message: _controller.lastError!,
                  onDismiss: _controller.clearError,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgApp,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.of(context).primary),
      ),
    );
  }
}

/// A small dismissible banner shown at the top of the app whenever a
/// storage/PDF/etc. operation fails, so the user always gets clear
/// feedback instead of the app silently doing nothing.
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.redBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.red),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: colors.red, fontSize: 13),
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, color: colors.red, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
