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
    with TickerProviderStateMixin {
  final TextEditingController _aliasController = TextEditingController();
  int _currentSeed = 12345;
  final Random _random = Random();

  late AnimationController _ambientCtrl;
  late AnimationController _enterCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  bool _isGeneratingKeys = false;

  final List<String> _prefixes = [
    'Ghost', 'Echo', 'Vector', 'Shadow', 'Void',
    'Ash', 'Cipher', 'Dusk', 'Frost', 'Nox',
  ];
  final List<String> _suffixes = [
    'Rider', 'Node', 'Phantom', 'Pulse', 'Signal',
    'Veil', 'Drift', 'Flux', 'Shard', 'Wire',
  ];

  @override
  void initState() {
    super.initState();
    _generateRandomAlias();

    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _enterCtrl.forward();
    });
  }

  void _generateRandomAlias() {
    final prefix = _prefixes[_random.nextInt(_prefixes.length)];
    final suffix = _suffixes[_random.nextInt(_suffixes.length)];
    final code = _random.nextInt(900) + 100;
    setState(() {
      _aliasController.text = '$prefix$suffix·$code';
      _currentSeed = _random.nextInt(1000000);
    });
  }

  Future<void> _onEnter() async {
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) return;

    setState(() => _isGeneratingKeys = true);
    try {
      final profile = await EphemeralProfile.generate(alias);
      widget.onProfileCreated(profile);
    } finally {
      if (mounted) setState(() => _isGeneratingKeys = false);
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _ambientCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: YamiTheme.bgDeep,
      body: Stack(
        children: [
          // Sfondo atmosferico animato
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (context, child) => Positioned(
              left: -size.width * 0.3 + (20 * _ambientCtrl.value),
              bottom: -size.height * 0.2 - (15 * _ambientCtrl.value),
              width: size.width * 1.2,
              height: size.height * 0.7,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      YamiTheme.accentWine.withValues(
                        alpha: 0.05 + 0.04 * _ambientCtrl.value,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Linea sottile decorativa in alto
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 1, color: YamiTheme.borderFaint),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: YamiTheme.spaceMd,
                  vertical: YamiTheme.spaceXl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideIn,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBrand(),
                          const SizedBox(height: YamiTheme.spaceXl),
                          _buildProfileCard(),
                          const SizedBox(height: YamiTheme.spaceLg),
                          _buildEnterButton(),
                          const SizedBox(height: YamiTheme.spaceMd),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo mark
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: YamiTheme.surfaceBase,
            borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
            border: Border.all(color: YamiTheme.borderStrong, width: 1.0),
            boxShadow: YamiTheme.shadowMid,
          ),
          child: const Icon(
            Icons.radar,
            size: 28,
            color: YamiTheme.accentWine,
          ),
        ),
        const SizedBox(height: YamiTheme.spaceMd),

        // Titolo display
        Text(
          'YamiLink',
          style: YamiTheme.displayStyle.copyWith(
            fontSize: 36,
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: YamiTheme.spaceSm),

        // Tag line
        Text(
          'Local · Private · Ephemeral',
          style: YamiTheme.captionStyle.copyWith(
            color: YamiTheme.textSub,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(YamiTheme.spaceLg),
      decoration: YamiTheme.surfaceCard(
        borderColor: YamiTheme.borderMid,
        radius: YamiTheme.radiusRound,
      ).copyWith(
        boxShadow: YamiTheme.shadowHigh,
      ),
      child: Column(
        children: [
          // Avatar con tap per rigenerare
          GestureDetector(
            onTap: _generateRandomAlias,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                YamiAvatar(
                  seed: _currentSeed,
                  size: 80,
                  glowColor: YamiTheme.accentWine,
                  isGlowing: false,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: YamiTheme.surfaceRaised,
                    shape: BoxShape.circle,
                    border: Border.all(color: YamiTheme.borderStrong),
                  ),
                  child: const Icon(
                    Icons.shuffle_rounded,
                    size: 12,
                    color: YamiTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: YamiTheme.spaceLg),

          // Campo alias
          TextField(
            controller: _aliasController,
            style: YamiTheme.bodyStyle.copyWith(
              color: YamiTheme.textBright,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Your alias',
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: YamiTheme.textSub,
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.shuffle_rounded,
                  size: 16,
                  color: YamiTheme.accentWine,
                ),
                onPressed: _generateRandomAlias,
                tooltip: 'Regenerate',
              ),
            ),
            onChanged: (val) {
              setState(() => _currentSeed = val.hashCode.abs());
            },
            onSubmitted: (_) => _onEnter(),
          ),
          const SizedBox(height: YamiTheme.spaceMd),

          // Nota ephemeral
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_clock_outlined,
                size: 14,
                color: YamiTheme.textGhost,
              ),
              const SizedBox(width: YamiTheme.spaceSm),
              Expanded(
                child: Text(
                  'Your identity lives only in volatile memory. Keys evaporate when you close the app.',
                  style: YamiTheme.captionStyle.copyWith(
                    color: YamiTheme.textGhost,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnterButton() {
    return _PressableButton(
      onTap: _isGeneratingKeys ? null : _onEnter,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: YamiTheme.accentWine,
          borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
          boxShadow: [
            BoxShadow(
              color: YamiTheme.accentWine.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isGeneratingKeys
              ? const YamiTactileLoader(size: 22, activeColor: YamiTheme.textBright)
              : Text(
                  'Enter the network',
                  style: YamiTheme.labelStyle.copyWith(
                    color: YamiTheme.textBright,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, size: 12, color: YamiTheme.textGhost),
        const SizedBox(width: 6),
        Text(
          'Fully offline · Zero trace · No accounts',
          style: YamiTheme.captionStyle.copyWith(
            color: YamiTheme.textGhost,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Bottone con feedback scale-on-press
class _PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableButton({required this.child, this.onTap});

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
