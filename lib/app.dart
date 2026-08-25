import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/noir_theme.dart';
import 'presentation/providers/play_controller.dart';
import 'presentation/providers/premium_provider.dart';
import 'presentation/providers/session_provider.dart';
import 'presentation/providers/tactics_controller.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/play_screen.dart';
import 'presentation/screens/premium_screen.dart';
import 'presentation/screens/progress_screen.dart';
import 'presentation/screens/reward_sim_screen.dart';
import 'presentation/screens/tactics_screen.dart';

class OctApp extends StatefulWidget {
  const OctApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<OctApp> createState() => _OctAppState();
}

class _OctAppState extends State<OctApp> {
  SessionProvider? _session;

  @override
  void initState() {
    super.initState();
    _session = SessionProvider(widget.prefs);
    _session!.initDatabase();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session!;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => PlayController(session)),
        ChangeNotifierProvider(create: (_) => TacticsController(session)),
        ChangeNotifierProvider(create: (_) => PremiumProvider()),
      ],
      child: MaterialApp(
        title: 'OCT - Offline Chess Training',
        debugShowCheckedModeBanner: false,
        theme: NoirTheme.dark,
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/play': (_) => const PlayScreen(),
          '/tactics': (_) => const TacticsScreen(),
          '/progress': (_) => const ProgressScreen(),
          '/premium': (_) => const PremiumScreen(),
          '/reward_sim': (_) => const RewardSimScreen(),
        },
      ),
    );
  }
}
