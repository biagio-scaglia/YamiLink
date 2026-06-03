import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'theme.dart';
import 'repository/yamilink_repository.dart';
import 'entry_screen.dart';
import 'nearby_screen.dart';
import 'room_screen.dart';
import 'diagnostics_screen.dart';
import 'direct_chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YamiLink',
      debugShowCheckedModeBanner: false,
      theme: YamiTheme.themeData,
      home: const InitializerScreen(),
    );
  }
}

class InitializerScreen extends StatefulWidget {
  const InitializerScreen({super.key});

  @override
  State<InitializerScreen> createState() => _InitializerScreenState();
}

class _InitializerScreenState extends State<InitializerScreen> {
  EphemeralProfile? _profile;
  YamiLinkRepository? _yamilinkRepository;

  void _onProfileCreated(EphemeralProfile profile) {
    setState(() {
      _profile = profile;
      _yamilinkRepository = YamiLinkRepository(profile: profile);
      // Auto-start scanning on profile creation
      _yamilinkRepository!.startScanning();
    });
  }

  @override
  void dispose() {
    _yamilinkRepository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return EntryScreen(onProfileCreated: _onProfileCreated);
    }

    return ChangeNotifierProvider<YamiLinkRepository>.value(
      value: _yamilinkRepository!,
      child: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      NearbyScreen(
        onOpenDirectChat: (peer) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<YamiLinkRepository>.value(
                value: Provider.of<YamiLinkRepository>(context, listen: false),
                child: DirectChatScreen(peer: peer),
              ),
            ),
          );
        },
      ),
      const RoomScreen(),
      const DiagnosticsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final simulation = Provider.of<YamiLinkRepository>(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: YamiTheme.surfaceDark,
          border: Border(
            top: BorderSide(color: YamiTheme.borderGlass, width: 1.0),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.radar, 'SPACE', simulation.peers.length),
                _buildNavItem(1, Icons.forum, 'ROOM', 0),
                _buildNavItem(2, Icons.analytics, 'DIAGS', 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, int badgeCount) {
    final isSelected = _currentIndex == index;
    final activeColor = YamiTheme.glowActive;
    final color = isSelected ? activeColor : YamiTheme.textMuted;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 22),
              if (badgeCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: YamiTheme.glowActive,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Center(
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: YamiTheme.bgDeep,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: YamiTheme.monoStyle.copyWith(
              color: color,
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          // Custom glowing bottom highlight indicator line
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 12 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: BorderRadius.circular(1),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
