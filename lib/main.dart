import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;

  final GlobalKey _spaceTabKey = GlobalKey();
  final GlobalKey _chatsTabKey = GlobalKey();
  final GlobalKey _roomTabKey  = GlobalKey();
  final GlobalKey _diagsTabKey = GlobalKey();

  late final List<Widget> _screens;

  // Animazioni nav pill
  late AnimationController _navPillController;

  @override
  void initState() {
    super.initState();

    _navPillController = AnimationController(
      vsync: this,
      duration: YamiTheme.motionNormal,
    );

    _screens = [
      NearbyScreen(
        onOpenDirectChat: (peer) {
          Navigator.push(
            context,
            _buildPageRoute(
              ChangeNotifierProvider<YamiLinkRepository>.value(
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

    // Tutorial once-only tramite SharedPreferences
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('onboarding_done') ?? false;
      if (!seen && mounted) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) _runTutorial();
      }
    });
  }

  @override
  void dispose() {
    _navPillController.dispose();
    super.dispose();
  }

  /// Costruisce una page route con transizione fade + slide leggera
  PageRoute<T> _buildPageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, animation, secondaryAnimation) => page,
      transitionDuration: YamiTheme.motionNormal,
      reverseTransitionDuration: YamiTheme.motionFast,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    );
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  Future<void> _runTutorial() async {
    YamiTutorialHelper.showOnboardingTutorial(
      context: context,
      spaceTabKey: _spaceTabKey,
      chatsTabKey: _chatsTabKey,
      roomTabKey:  _roomTabKey,
      diagsTabKey: _diagsTabKey,
      onFinished: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_done', true);
      },
      onSkipped: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_done', true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final simulation = Provider.of<YamiLinkRepository>(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: YamiTheme.bgVoid,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: YamiTheme.borderFaint, width: 1.0),
                ),
              ),
              child: Scaffold(
                backgroundColor: YamiTheme.bgDeep,
                body: AnimatedSwitcher(
                  duration: YamiTheme.motionNormal,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.015, 0),
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
                bottomNavigationBar: _YamiNavBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabTap,
                  spaceKey: _spaceTabKey,
                  chatsKey: _chatsTabKey,
                  roomKey: _roomTabKey,
                  diagsKey: _diagsTabKey,
                  unreadChats: simulation.totalUnreadCount,
                  peersCount: simulation.peers.length,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav Bar
// ---------------------------------------------------------------------------

class _YamiNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final GlobalKey spaceKey;
  final GlobalKey chatsKey;
  final GlobalKey roomKey;
  final GlobalKey diagsKey;
  final int unreadChats;
  final int peersCount;

  const _YamiNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.spaceKey,
    required this.chatsKey,
    required this.roomKey,
    required this.diagsKey,
    required this.unreadChats,
    required this.peersCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: YamiTheme.surfaceBase,
        border: Border(top: BorderSide(color: YamiTheme.borderFaint, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                navKey: spaceKey,
                icon: Icons.radar_outlined,
                iconSelected: Icons.radar,
                label: 'Space',
                badge: peersCount,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                navKey: chatsKey,
                icon: Icons.chat_bubble_outline_rounded,
                iconSelected: Icons.chat_bubble_rounded,
                label: 'Chats',
                badge: unreadChats,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                navKey: roomKey,
                icon: Icons.forum_outlined,
                iconSelected: Icons.forum_rounded,
                label: 'Room',
                badge: 0,
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                navKey: diagsKey,
                icon: Icons.monitor_heart_outlined,
                iconSelected: Icons.monitor_heart,
                label: 'Diags',
                badge: 0,
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final GlobalKey navKey;
  final IconData icon;
  final IconData iconSelected;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.navKey,
    required this.icon,
    required this.iconSelected,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _scaleCtrl.forward();
  void _onTapUp(_) => _scaleCtrl.reverse();
  void _onTapCancel() => _scaleCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? YamiTheme.accentWine : YamiTheme.textSub;

    return Expanded(
      child: GestureDetector(
        key: widget.navKey,
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Indicatore selected + icona
              AnimatedContainer(
                duration: YamiTheme.motionNormal,
                curve: Curves.easeOutCubic,
                width: widget.selected ? 44 : 36,
                height: 30,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? YamiTheme.accentWine.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: YamiTheme.motionFast,
                      child: Icon(
                        widget.selected ? widget.iconSelected : widget.icon,
                        key: ValueKey<bool>(widget.selected),
                        color: color,
                        size: 20,
                      ),
                    ),
                    if (widget.badge > 0)
                      Positioned(
                        top: 2,
                        right: 6,
                        child: _Badge(count: widget.badge),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: YamiTheme.motionFast,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                  letterSpacing: 0.1,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey<int>(count),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: YamiTheme.accentWine,
          borderRadius: BorderRadius.circular(YamiTheme.radiusPill),
        ),
        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: GoogleFonts.inter(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: YamiTheme.textBright,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
