import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/bootstrap/bootstrap_service.dart';
import '../terms/terms_page.dart';
import '../welcome/welcome_page.dart';

class SplashPage extends ConsumerStatefulWidget {
  static const routePath = '/';
  static const routeName = 'splash';

  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (_handled || !mounted) return;
    _handled = true;

    String target = WelcomePage.routePath;
    try {
      final result = await ref.read(bootstrapProvider.future);
      target = startupRouteForBootstrap(result);
    } catch (_) {
      target = WelcomePage.routePath;
    }

    if (!mounted) return;
    context.go(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

String startupRouteForBootstrap(BootstrapResult result) {
  if (!result.termsAccepted) {
    return TermsPage.routePath;
  }
  return WelcomePage.routePath;
}
