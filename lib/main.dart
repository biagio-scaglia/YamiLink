import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'theme.dart';
import 'repository/yamilink_repository.dart';
import 'entry_screen.dart';
import 'nearby_screen.dart';
import 'chats_screen.dart';
import 'room_screen.dart';
import 'diagnostics_screen.dart';
import 'direct_chat_screen.dart';
import 'core/tutorial/tutorial_helper.dart';
import 'core/security/tamper_guard.dart';

void main() {
  TamperGuard.instance.initialize();
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

  final GlobalKey _spaceTabKey = GlobalKey();
  final GlobalKey _chatsTabKey = GlobalKey();
  final GlobalKey _roomTabKey = GlobalKey();
  final GlobalKey _diagsTabKey = GlobalKey();
  bool _hasRunTutorial = false;

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
        onRunTutorial: _runTutorial,
      ),
      ChatsScreen(onRunTutorial: _runTutorial),
      RoomScreen(onRunTutorial: _runTutorial),
      const DiagnosticsScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasRunTutorial) {
        _hasRunTutorial = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _runTutorial();
          }
        });
      }
    });
  }

  void _runTutorial() {
    YamiTutorialHelper.showOnboardingTutorial(
      context: context,
      spaceTabKey: _spaceTabKey,
      chatsTabKey: _chatsTabKey,
      roomTabKey: _roomTabKey,
      diagsTabKey: _diagsTabKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final simulation = Provider.of<YamiLinkRepository>(context);

    return Scaffold(
      backgroundColor: YamiTheme.bgDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: YamiTheme.borderMetallic.withValues(alpha: 0.3), width: 1.0),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0.0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: _screens[_currentIndex],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            decoration: BoxDecoration(
              color: YamiTheme.surfaceDark,
              border: Border(
                top: const BorderSide(color: YamiTheme.borderMetallic, width: 1.0),
                left: BorderSide(color: YamiTheme.borderMetallic.withValues(alpha: 0.3), width: 1.0),
                right: BorderSide(color: YamiTheme.borderMetallic.withValues(alpha: 0.3), width: 1.0),
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
                _buildNavItem(
                  0,
                  Icons.radar,
                  'SPACE',
                  simulation.peers.length,
                  _spaceTabKey,
                ),
                _buildNavItem(
                  1,
                  Icons.chat_bubble_outline,
                  'CHATS',
                  simulation.totalUnreadCount,
                  _chatsTabKey,
                ),
                _buildNavItem(2, Icons.forum, 'ROOM', 0, _roomTabKey),
                _buildNavItem(3, Icons.analytics, 'DIAGS', 0, _diagsTabKey),
              ],
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    int badgeCount,
    GlobalKey key,
  ) {
    final isSelected = _currentIndex == index;
    final activeColor = YamiTheme.accentActive;
    final color = isSelected ? activeColor : YamiTheme.textMuted;

    return GestureDetector(
      key: key,
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
                      color: YamiTheme.accentActive,
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

          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 12 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: BorderRadius.circular(1),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.5),
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
