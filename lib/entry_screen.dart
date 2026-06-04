import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/avatar.dart';
import 'widgets/loaders.dart';

class EntryScreen extends StatefulWidget {
  final Function(EphemeralProfile) onProfileCreated;

  const EntryScreen({super.key, required this.onProfileCreated});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _aliasController = TextEditingController();
  int _currentSeed = 12345;
  final Random _random = Random();
  late AnimationController _pulseController;
  bool _isGeneratingKeys = false;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
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

  Future<void> _onEnter() async {
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) return;

    setState(() {
      _isGeneratingKeys = true;
    });

    try {
      final profile = await EphemeralProfile.generate(alias);
      widget.onProfileCreated(profile);
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingKeys = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: YamiTheme.bgDeep)),

          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Positioned(
                right: -100 + (30 * _pulseController.value),
                top: -100 + (20 * _pulseController.value),
                width: 450,
                height: 450,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: YamiTheme.accentAmbient.withValues(
                      alpha: 0.04 + (0.04 * _pulseController.value),
                    ),
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.blur_on,
                      size: 64,
                      color: YamiTheme.accentActive.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'YAMILINK',
                      style: YamiTheme.titleStyle.copyWith(
                        fontSize: 32,
                        letterSpacing: 6.0,
                        shadows: [
                          BoxShadow(
                            color: YamiTheme.accentActive.withValues(alpha: 0.35),
                            blurRadius: 16.0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'A social layer that exists only when you are there.',
                      textAlign: TextAlign.center,
                      style: YamiTheme.subtitleStyle,
                    ),
                    const SizedBox(height: 40),

                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: YamiTheme.tactileDecoration(
                        backgroundColor: YamiTheme.surfaceDark,
                        opacity: 0.65,
                        borderColor: YamiTheme.accentActive,
                      ),
                      child: Column(
                        children: [
                          YamiAvatar(
                            seed: _currentSeed,
                            size: 84,
                            isGlowing: true,
                          ),
                          const SizedBox(height: 24),

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
                                  color: YamiTheme.borderMetallic,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: YamiTheme.accentActive,
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
                                  color: YamiTheme.accentActive,
                                ),
                                onPressed: _generateRandomAlias,
                                tooltip: 'Regenerate',
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _currentSeed = val.hashCode;
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Saved in memory only. Keys evaporate on exit.',
                            style: YamiTheme.monoStyle.copyWith(
                              color: YamiTheme.accentActive.withValues(
                                alpha: 0.85,
                              ),
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: YamiTheme.accentActive,
                          foregroundColor: YamiTheme.bgDeep,
                          elevation: 8,
                          shadowColor: YamiTheme.accentActive.withValues(
                            alpha: 0.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isGeneratingKeys ? null : _onEnter,
                        child: _isGeneratingKeys 
                          ? const SizedBox(
                              width: 20, height: 20, 
                              child: YamiTactileLoader(size: 24, activeColor: YamiTheme.accentActive),
                            )
                          : Text(
                          'INITIALIZE CONNECTION',
                          style: YamiTheme.bodyStyle.copyWith(
                            color: YamiTheme.bgDeep,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
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
                          'Fully offline. Zero trace left behind.',
                          style: YamiTheme.captionStyle,
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
