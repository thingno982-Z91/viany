import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
  final AppController controller;
  final VoidCallback onDone;

  const OnboardingScreen({
    super.key,
    required this.controller,
    required this.onDone,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_submitting) return; // guard against double-tap while saving
    setState(() => _submitting = true);
    try {
      await widget.controller.completeOnboarding(_nameCtrl.text);
      widget.onDone();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // Cap the card width on large/tablet screens, but let it shrink
    // fluidly on narrow phones instead of a fixed width that could
    // overflow on very small devices.
    final cardWidth = screenWidth < 380 ? screenWidth - 48 : 340.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bgApp,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand logo shown once on first launch, above the
                  // welcome text. errorBuilder keeps the screen usable
                  // even if the asset is ever missing from a build.
                  Image.asset(
                    'assets/images/logo.png',
                    height: 110,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(height: 0),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'مرحباً بك',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ما اسم البيان الذي تود إنشاءه؟',
                    style: TextStyle(color: colors.textSub, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'مثال: مصاريف المشروع',
                    ),
                    onSubmitted: (_) => _confirm(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _confirm,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('إنشاء البيان'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
