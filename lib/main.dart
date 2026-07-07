import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JobTrackrApp());
}

class JobTrackrApp extends StatefulWidget {
  const JobTrackrApp({super.key});
  @override
  State<JobTrackrApp> createState() => _JobTrackrAppState();
}

class _JobTrackrAppState extends State<JobTrackrApp> {
  ThemeMode _mode = ThemeMode.system;
  static const _kThemeKey = 'theme_mode';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final m = p.getString(_kThemeKey);
      if (m != null) {
        setState(() => _mode = ThemeMode.values.firstWhere(
              (e) => e.name == m,
              orElse: () => ThemeMode.system,
            ));
      }
    });
  }

  Future<void> _setMode(ThemeMode m) async {
    setState(() => _mode = m);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeKey, m.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JobTrackr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      home: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('JobTrackr'),
            actions: [
              PopupMenuButton<ThemeMode>(
                icon: const Icon(Icons.brightness_6_outlined),
                onSelected: _setMode,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: ThemeMode.system, child: Text('System')),
                  PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
                  PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
              ),
            ],
          ),
          body: const HomeScreen(),
        );
      }),
    );
  }
}
