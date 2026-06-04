import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'theme.dart';
import 'repository/yamilink_repository.dart';
import 'widgets/avatar.dart';
import 'core/tutorial/tutorial_helper.dart';

class NearbyScreen extends StatefulWidget {
  final Function(Peer) onOpenDirectChat;
  final VoidCallback onRunTutorial;

  const NearbyScreen({
    super.key,
    required this.onOpenDirectChat,
    required this.onRunTutorial,
  });

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulation = Provider.of<YamiLinkRepository>(context);
    final isScanning = simulation.isScanning;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230.0,
            floating: false,
            pinned: true,
            backgroundColor: YamiTheme.bgDeep,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: YamiTheme.ambientBackgroundGradient(),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),

                      AnimatedBuilder(
                        animation: _radarController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 110 * _radarController.value,
                                height: 110 * _radarController.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: YamiTheme.accentActive.withValues(
                                      alpha: isScanning
                                          ? (1.0 - _radarController.value) * 0.4
                                          : 0.1,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),

                              Container(
                                width:
                                    150 *
                                    ((_radarController.value + 0.5) % 1.0),
                                height:
                                    150 *
                                    ((_radarController.value + 0.5) % 1.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: YamiTheme.accentAmbient.withValues(
                                      alpha: isScanning
                                          ? (1.0 -
                                                    ((_radarController.value +
                                                            0.5) %
                                                        1.0)) *
                                                0.25
                                          : 0.05,
                                    ),
                                    width: 1.0,
                                  ),
                                ),
                              ),

                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isScanning
                                      ? YamiTheme.accentActive
                                      : YamiTheme.textMuted,
                                  boxShadow: isScanning
                                      ? [
                                          BoxShadow(
                                            color: YamiTheme.accentActive
                                                .withValues(alpha: 0.4),
                                            blurRadius: 18.0,
                                            spreadRadius: 4.0,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: const Icon(
                                  Icons.wifi_tethering,
                                  size: 14,
                                  color: YamiTheme.bgDeep,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isScanning
                            ? 'BROADCASTING PRESENCE BEACON...'
                            : 'DISCOVERY TRANSMITTER PAUSED',
                        style: YamiTheme.monoStyle.copyWith(
                          color: isScanning
                              ? YamiTheme.accentActive
                              : YamiTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.help_outline,
                  color: YamiTheme.textSecondary,
                  size: 24,
                ),
                onPressed: () {
                  YamiTutorialHelper.showHelpBottomSheet(
                    context,
                    widget.onRunTutorial,
                  );
                },
                tooltip: 'Help',
              ),
              IconButton(
                icon: Icon(
                  isScanning
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: isScanning
                      ? YamiTheme.accentActive
                      : YamiTheme.textSecondary,
                  size: 28,
                ),
                onPressed: () {
                  if (isScanning) {
                    simulation.stopScanning();
                  } else {
                    simulation.startScanning();
                  }
                },
                tooltip: isScanning ? 'Pause beacon' : 'Activate beacon',
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SPATIAL PEERS IN SCOPE',
                    style: YamiTheme.monoStyle.copyWith(
                      color: YamiTheme.textSecondary,
                      letterSpacing: 2.0,
                      fontSize: 11,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: YamiTheme.tactileDecoration(
                      backgroundColor: YamiTheme.surfaceLight,
                      opacity: 0.8,
                      borderRadius: 20,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isScanning
                                ? YamiTheme.accentSecure
                                : YamiTheme.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${simulation.peers.length} ONLINE',
                          style: YamiTheme.monoStyle.copyWith(
                            color: isScanning
                                ? YamiTheme.textPrimary
                                : YamiTheme.textMuted,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          simulation.peers.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radar,
                            size: 48,
                            color: YamiTheme.textMuted.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Local Proximity Layer is Empty.',
                            style: YamiTheme.subtitleStyle.copyWith(
                              color: YamiTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Activate the beacon or wait for peers to enter range.',
                            textAlign: TextAlign.center,
                            style: YamiTheme.captionStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final peer = simulation.peers[index];
                    return _buildPeerTile(context, peer, simulation);
                  }, childCount: simulation.peers.length),
                ),
        ],
      ),
    );
  }

  Widget _buildPeerTile(
    BuildContext context,
    Peer peer,
    YamiLinkRepository simulation,
  ) {
    Color proximityColor;
    String proximityText;
    int proximityBars = 1;

    switch (peer.proximityHint) {
      case ProximityHint.immediate:
        proximityColor = YamiTheme.accentSecure;
        proximityText = 'IMMEDIATE';
        proximityBars = 3;
        break;
      case ProximityHint.near:
        proximityColor = YamiTheme.accentActive;
        proximityText = 'NEAR';
        proximityBars = 2;
        break;
      case ProximityHint.far:
        proximityColor = YamiTheme.accentAmbient;
        proximityText = 'FAR';
        proximityBars = 1;
        break;
      case ProximityHint.unknown:
        proximityColor = YamiTheme.textMuted;
        proximityText = 'UNKNOWN';
        proximityBars = 0;
        break;
    }

    final isTrusted = peer.trustLevel == TrustLevel.paired;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: GestureDetector(
        onTap: () => _showPeerDetailsSheet(context, peer, simulation),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: YamiTheme.tactileDecoration(
            backgroundColor: YamiTheme.surfaceDark,
            borderColor: isTrusted ? YamiTheme.accentSecure : YamiTheme.accentActive,
          ),
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 38,
                decoration: BoxDecoration(
                  color: isTrusted
                      ? YamiTheme.accentSecure
                      : YamiTheme.accentActive.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              YamiAvatar(
                seed: peer.avatarSeed,
                size: 46,
                glowColor: isTrusted
                    ? YamiTheme.accentSecure
                    : YamiTheme.accentActive,
                isGlowing: isTrusted,
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          peer.alias,
                          style: YamiTheme.bodyStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (isTrusted) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: YamiTheme.accentSecure,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Row(
                          children: List.generate(3, (index) {
                            return Container(
                              width: 3,
                              height: 8 + (index * 3.0),
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                color: index < proximityBars
                                    ? proximityColor
                                    : YamiTheme.textMuted.withValues(
                                        alpha: 0.2,
                                      ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          proximityText,
                          style: YamiTheme.monoStyle.copyWith(
                            color: proximityColor,
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                          ),
                        ),

                        if (peer.relayCapability) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.router,
                            size: 11,
                            color: YamiTheme.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'RELAY',
                            style: YamiTheme.captionStyle.copyWith(
                              fontSize: 8,
                              color: YamiTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                size: 18,
                color: YamiTheme.textMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPeerDetailsSheet(
    BuildContext context,
    Peer peer,
    YamiLinkRepository simulation,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentPeer = simulation.peers.firstWhere(
              (p) => p.id == peer.id,
              orElse: () => peer,
            );
            final isTrusted = currentPeer.trustLevel == TrustLevel.paired;

            final sharedKey = simulation.getSharedKey(currentPeer.id);
            String pairCode = 'WAITING FOR DH KEY...';
            if (sharedKey != null) {
              final hash = sharedKey.take(4).toList();
              final code = (hash[0] << 24 | hash[1] << 16 | hash[2] << 8 | hash[3]).abs();
              pairCode = '${code % 9000 + 1000} ${code ~/ 9000 % 9000 + 1000}';
            }

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 26.0,
              ),
              decoration: const BoxDecoration(
                color: YamiTheme.bgDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
                border: Border(
                  top: BorderSide(color: YamiTheme.borderMetallic, width: 1.0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: YamiTheme.borderMetallic,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  YamiAvatar(
                    seed: currentPeer.avatarSeed,
                    size: 80,
                    glowColor: isTrusted
                        ? YamiTheme.accentSecure
                        : YamiTheme.accentActive,
                    isGlowing: true,
                  ),
                  const SizedBox(height: 16),

                  Text(currentPeer.alias, style: YamiTheme.titleStyle),
                  const SizedBox(height: 4),

                  Text(
                    'NODE KEY: sha256::${currentPeer.id.substring(0, 8)}...${currentPeer.id.substring(currentPeer.id.length - 4)}',
                    style: YamiTheme.monoStyle.copyWith(
                      color: YamiTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14.0),
                    decoration: YamiTheme.tactileDecoration(
                      backgroundColor: YamiTheme.surfaceDark,
                      opacity: 0.8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCAL SPACE ADJACENCY',
                          style: YamiTheme.monoStyle.copyWith(
                            color: YamiTheme.textSecondary,
                            fontSize: 9.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Proximity range',
                              style: YamiTheme.bodyStyle.copyWith(
                                color: YamiTheme.textSecondary,
                              ),
                            ),
                            Text(
                              currentPeer.proximityHint
                                  .toString()
                                  .split('.')
                                  .last
                                  .toUpperCase(),
                              style: YamiTheme.monoStyle.copyWith(
                                color:
                                    currentPeer.proximityHint ==
                                        ProximityHint.immediate
                                    ? YamiTheme.accentSecure
                                    : YamiTheme.accentActive,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Relay capabilities',
                              style: YamiTheme.bodyStyle.copyWith(
                                color: YamiTheme.textSecondary,
                              ),
                            ),
                            Text(
                              currentPeer.relayCapability
                                  ? 'ACTIVE MESH NODE'
                                  : 'ENDPOINT NODE',
                              style: YamiTheme.monoStyle.copyWith(
                                color: currentPeer.relayCapability
                                    ? YamiTheme.accentActive
                                    : YamiTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isTrusted) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24.0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: YamiTheme.accentSecure.withValues(alpha: 0.04),
                        border: Border.all(
                          color: YamiTheme.accentSecure.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            color: YamiTheme.accentSecure,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Device verified. Cryptographic pairing completed.',
                              style: YamiTheme.captionStyle.copyWith(
                                color: YamiTheme.accentSecure,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24.0),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: YamiTheme.tactileDecoration(
                        backgroundColor: YamiTheme.surfaceLight,
                        opacity: 0.5,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'MATCHING VERIFICATION CODE',
                            style: YamiTheme.monoStyle.copyWith(
                              fontSize: 9,
                              color: YamiTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pairCode,
                            style: YamiTheme.titleStyle.copyWith(
                              letterSpacing: 3,
                              fontSize: 22,
                              color: YamiTheme.accentActive,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verify this number matches on their screen.',
                            style: YamiTheme.captionStyle.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: YamiTheme.accentActive,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onOpenDirectChat(currentPeer);
                            },
                            child: Text(
                              'DIRECT CHAT',
                              style: YamiTheme.monoStyle.copyWith(
                                color: YamiTheme.accentActive,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isTrusted
                                  ? YamiTheme.accentWarning
                                  : YamiTheme.accentSecure,
                              foregroundColor: YamiTheme.bgDeep,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              if (!isTrusted) {
                                simulation.initiatePairing(currentPeer.id);
                                // Polling or just wait for state change
                              } else {
                                simulation.togglePeerTrust(currentPeer.id);
                              }
                              setModalState(() {});
                            },
                            child: Text(
                              isTrusted ? 'REVOKE TRUST' : 'VERIFY PAIRING',
                              style: YamiTheme.monoStyle.copyWith(
                                color: YamiTheme.bgDeep,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton.icon(
                      icon: Icon(
                        simulation.isPeerMuted(currentPeer.id)
                            ? Icons.volume_up
                            : Icons.volume_off,
                        color: simulation.isPeerMuted(currentPeer.id)
                            ? YamiTheme.accentSecure
                            : YamiTheme.accentWarning,
                        size: 16,
                      ),
                      label: Text(
                        simulation.isPeerMuted(currentPeer.id)
                            ? 'UNMUTE PEER'
                            : 'MUTE PEER',
                        style: YamiTheme.monoStyle.copyWith(
                          color: simulation.isPeerMuted(currentPeer.id)
                              ? YamiTheme.accentSecure
                              : YamiTheme.accentWarning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        if (simulation.isPeerMuted(currentPeer.id)) {
                          simulation.unmutePeer(currentPeer.id);
                          setModalState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${currentPeer.alias} is no longer muted',
                              ),
                              backgroundColor: YamiTheme.accentSecure,
                            ),
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => SimpleDialog(
                              backgroundColor: YamiTheme.bgDeep,
                              title: Text(
                                'SILENZIA PEER',
                                style: YamiTheme.monoStyle.copyWith(
                                  color: YamiTheme.accentActive,
                                ),
                              ),
                              children: [
                                SimpleDialogOption(
                                  onPressed: () {
                                    simulation.mutePeer(
                                      currentPeer.id,
                                      const Duration(seconds: 10),
                                    );
                                    Navigator.pop(context);
                                    setModalState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Peer muted for 10 seconds',
                                        ),
                                        backgroundColor: YamiTheme.accentWarning,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '10 Secondi',
                                    style: YamiTheme.bodyStyle,
                                  ),
                                ),
                                SimpleDialogOption(
                                  onPressed: () {
                                    simulation.mutePeer(
                                      currentPeer.id,
                                      const Duration(seconds: 30),
                                    );
                                    Navigator.pop(context);
                                    setModalState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Peer muted for 30 seconds',
                                        ),
                                        backgroundColor: YamiTheme.accentWarning,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '30 Secondi',
                                    style: YamiTheme.bodyStyle,
                                  ),
                                ),
                                SimpleDialogOption(
                                  onPressed: () {
                                    simulation.mutePeer(
                                      currentPeer.id,
                                      const Duration(minutes: 1),
                                    );
                                    Navigator.pop(context);
                                    setModalState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Peer muted for 1 minute',
                                        ),
                                        backgroundColor: YamiTheme.accentWarning,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '1 Minuto',
                                    style: YamiTheme.bodyStyle,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.block,
                        color: YamiTheme.accentWarning,
                        size: 16,
                      ),
                      label: Text(
                        'BLOCK PEER',
                        style: YamiTheme.monoStyle.copyWith(
                          color: YamiTheme.accentWarning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        simulation.blockPeer(currentPeer.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${currentPeer.alias} bloccato'),
                            backgroundColor: YamiTheme.accentWarning,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
