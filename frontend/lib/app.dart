/// ProfessorOS – App Root Widget.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/providers/auth_provider.dart';

class ProfessorOSApp extends ConsumerStatefulWidget {
  const ProfessorOSApp({super.key});

  @override
  ConsumerState<ProfessorOSApp> createState() => _ProfessorOSAppState();
}

class _ProfessorOSAppState extends ConsumerState<ProfessorOSApp> {
  Timer? _timer;
  static const _inactivityTimeout = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(_inactivityTimeout, _logOutUser);
  }

  void _logOutUser() {
    final authNotifier = ref.read(authProvider.notifier);
    if (authNotifier.isAuthenticated) {
      authNotifier.logout();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeStateProvider);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: MaterialApp.router(
        title: 'ProfessorOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeFor(themeState.designSystem, themeState.themeMode),
        routerConfig: router,
      ),
    );
  }
}
