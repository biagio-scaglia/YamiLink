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
                    Container(
                      width: 64,
                      height: 64,
                      decoration: YamiTheme.tactileDecoration(
                        backgroundColor: YamiTheme.bgDeep,
                        borderColor: YamiTheme.accentActive,
                        raised: true,
                        borderRadius: 16.0,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.radar,
                          size: 32,
                          color: YamiTheme.accentActive,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'YAMILINK',
                      style: YamiTheme.titleStyle.copyWith(
                        fontSize: 32,
                        letterSpacing: 8.0,
                        color: YamiTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: YamiTheme.accentActive.withValues(alpha: 0.1),
                        border: Border.all(color: YamiTheme.accentActive.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SECURE LOCAL BROADCAST',
                        textAlign: TextAlign.center,
                        style: YamiTheme.monoStyle.copyWith(
                          fontSize: 10,
                          color: YamiTheme.accentActive,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: YamiTheme.tactileDecoration(
                        backgroundColor: YamiTheme.surfaceDark,
                        opacity: 1.0,
                        borderColor: YamiTheme.borderMetallic,
                        raised: true,
                      ),
                      child: Column(
                        children: [
                          YamiAvatar(
                            seed: _currentSeed,
                            size: 84,
                            glowColor: YamiTheme.accentActive,
                            isGlowing: true,
                          ),
                          const SizedBox(height: 24),

                          Container(
                            decoration: YamiTheme.tactileDecoration(
                              backgroundColor: YamiTheme.bgDeep,
                              borderColor: YamiTheme.borderMetallic,
                            ),
                            child: TextField(
                              controller: _aliasController,
                              style: YamiTheme.monoStyle.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                              decoration: InputDecoration(
                                labelText: 'EPHEMERAL ALIAS',
                                labelStyle: YamiTheme.captionStyle.copyWith(
                                  color: YamiTheme.textSecondary,
                                  letterSpacing: 1.5,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                prefixIcon: const Icon(
                                  Icons.terminal,
                                  color: YamiTheme.textSecondary,
                                  size: 18,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.autorenew,
                                    color: YamiTheme.accentActive,
                                    size: 18,
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
                          ),
                          const SizedBox(height: 16),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: YamiTheme.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Identity is stored in volatile memory only. Cryptographic keys evaporate upon termination.',
                                  style: YamiTheme.monoStyle.copyWith(
                                    color: YamiTheme.textSecondary,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: GestureDetector(
                        onTap: _isGeneratingKeys ? null : _onEnter,
                        child: Container(
                          decoration: YamiTheme.tactileDecoration(
                            backgroundColor: YamiTheme.accentActive,
                            borderColor: YamiTheme.borderMetallic,
                            raised: true,
                          ),
                          child: Center(
                            child: _isGeneratingKeys 
                              ? const YamiTactileLoader(size: 24, activeColor: YamiTheme.bgDeep)
                              : Text(
                                  'INITIALIZE SYSTEM',
                                  style: YamiTheme.monoStyle.copyWith(
                                    color: YamiTheme.bgDeep,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                    fontSize: 13,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield,
                          size: 12,
                          color: YamiTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'FULLY OFFLINE. ZERO TRACE.',
                          style: YamiTheme.monoStyle.copyWith(
                            color: YamiTheme.textMuted,
                            fontSize: 9,
                            letterSpacing: 1.0,
                          ),
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
