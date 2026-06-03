import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/avatar.dart';

class EntryScreen extends StatefulWidget {
  final Function(EphemeralProfile) onProfileCreated;

  const EntryScreen({super.key, required this.onProfileCreated});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final TextEditingController _aliasController = TextEditingController();
  int _currentSeed = 12345;
  final Random _random = Random();

  final List<String> _prefixes = [
    'Ghost',
    'Neon',
    'Echo',
    'Vector',
    'Quantum',
    'Shadow',
    'Solar',
    'Void',
    'Grid',
    'Net',
  ];
  final List<String> _suffixes = [
    'Seeker',
    'Rider',
    'Node',
    'Beacon',
    'Phantom',
    'Runner',
    'Pulse',
    'Link',
    'Signal',
    'Zero',
  ];

  @override
  void initState() {
    super.initState();
    _generateRandomAlias();
  }

  void _generateRandomAlias() {
    final prefix = _prefixes[_random.nextInt(_prefixes.length)];
    final suffix = _suffixes[_random.nextInt(_suffixes.length)];
    final code = _random.nextInt(900) + 100;

    setState(() {
      _aliasController.text = '$prefix$suffix-$code';
      _currentSeed = _random.nextInt(1000000);
    });
  }

  void _onEnter() {
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) return;

    final profile = EphemeralProfile(
      id: List.generate(
        16,
        (_) => _random.nextInt(16).toRadixString(16),
      ).join(),
      alias: alias,
      avatarSeed: _currentSeed,
      createdAt: DateTime.now(),
    );

    widget.onProfileCreated(profile);
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background atmospheric glows
          Positioned.fill(child: Container(color: YamiTheme.bgDeep)),
          Positioned(
            right: -100,
            top: -100,
            width: 400,
            height: 400,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x117000FF), // Subtle ambient purple glow
              ),
            ),
          ),
          Positioned(
            left: -150,
            bottom: -150,
            width: 500,
            height: 500,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0E00F0FF), // Subtle ambient cyan glow
              ),
            ),
          ),

          // Form Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand / Logo Header
                    const Icon(
                      Icons.blur_on,
                      size: 64,
                      color: YamiTheme.glowActive,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'YAMILINK',
                      style: YamiTheme.titleStyle.copyWith(
                        fontSize: 32,
                        letterSpacing: 4.0,
                        color: YamiTheme.textPrimary,
                        shadows: [
                          BoxShadow(
                            color: YamiTheme.glowActive.withOpacity(0.4),
                            blurRadius: 12.0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'A social layer that exists only when you are there.',
                      textAlign: TextAlign.center,
                      style: YamiTheme.subtitleStyle.copyWith(
                        color: YamiTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Avatar custom preview card
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: YamiTheme.glassDecoration(
                        backgroundColor: YamiTheme.surfaceDark,
                        opacity: 0.6,
                        glowColor: YamiTheme.glowActive,
                        glowRadius: 10.0,
                      ),
                      child: Column(
                        children: [
                          // Interactive Procedural Avatar preview
                          YamiAvatar(
                            seed: _currentSeed,
                            size: 80,
                            isGlowing: true,
                          ),
                          const SizedBox(height: 24),

                          // Input text field
                          TextField(
                            controller: _aliasController,
                            style: YamiTheme.bodyStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            decoration: InputDecoration(
                              labelText: 'EPHEMERAL ALIAS',
                              labelStyle: YamiTheme.captionStyle.copyWith(
                                color: YamiTheme.textSecondary,
                                letterSpacing: 1.5,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: YamiTheme.borderGlass,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: YamiTheme.glowActive,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(
                                Icons.face,
                                color: YamiTheme.textSecondary,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.refresh,
                                  color: YamiTheme.glowActive,
                                ),
                                onPressed: _generateRandomAlias,
                                tooltip: 'Regenerate Identity',
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                // Keep seed locked or change slightly based on text change
                                _currentSeed = val.hashCode;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: YamiTheme.glowActive,
                          foregroundColor: YamiTheme.bgDeep,
                          elevation: 6,
                          shadowColor: YamiTheme.glowActive.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _onEnter,
                        child: Text(
                          'INITIALIZE LINK',
                          style: YamiTheme.bodyStyle.copyWith(
                            color: YamiTheme.bgDeep,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.security,
                          size: 14,
                          color: YamiTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Fully offline. Zero data saved to servers.',
                          style: YamiTheme.captionStyle.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
