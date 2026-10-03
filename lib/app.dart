import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/setup_controller.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

class FlutterSetupApp extends StatelessWidget {
  const FlutterSetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SetupController()..init(),
      child: MaterialApp(
        title: 'Flutter Environment Setup Assistant',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AppShell(),
      ),
    );
  }
}
