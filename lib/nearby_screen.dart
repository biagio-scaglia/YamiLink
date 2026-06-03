import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'theme.dart';
import 'simulation_service.dart';
import 'widgets/avatar.dart';

class NearbyScreen extends StatefulWidget {
  final Function(Peer) onOpenDirectChat;

  const NearbyScreen({super.key, required this.onOpenDirectChat});

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
    final simulation = Provider.of<SimulationService>(context);
    final isScanning = simulation.isScanning;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Elevated spatial radar header
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
                      const SizedBox(height: 50),
                      // Double pulsing outer circles for radar
                      AnimatedBuilder(
                        animation: _radarController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse Ring 1
                              Container(
                                width: 110 * _radarController.value,
                                height: 110 * _radarController.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: YamiTheme.glowActive.withOpacity(
                                      isScanning
                                          ? (1.0 - _radarController.value) * 0.4
                                          : 0.1,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              // Pulse Ring 2
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
                                    color: YamiTheme.glowAmbient.withOpacity(
                                      isScanning
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
                              // Central Core
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isScanning
                                      ? YamiTheme.glowActive
                                      : YamiTheme.textMuted,
                                  boxShadow: isScanning
                                      ? [
                                          BoxShadow(
                                            color: YamiTheme.glowActive
                                                .withOpacity(0.4),
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
                              ? YamiTheme.glowActive
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
                icon: Icon(
                  isScanning
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: isScanning
                      ? YamiTheme.glowActive
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
                tooltip: isScanning ? 'Metti in pausa' : 'Attiva scansione',
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Proximity list header
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
                    decoration: YamiTheme.glassDecoration(
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
                                ? YamiTheme.glowSecure
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

          // Discovered Peers list
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
                            color: YamiTheme.textMuted.withOpacity(0.2),
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
                          const SizedBox(height: 24),
                          // Empty state simulation trigger
                          if (!isScanning)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: YamiTheme.glowActive,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                simulation.startScanning();
                              },
                              icon: const Icon(Icons.flash_on, size: 14),
                              label: Text(
                                'SIMULATE ACTIVE PEERS',
                                style: YamiTheme.monoStyle.copyWith(
                                  fontSize: 10,
                                ),
                              ),
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
    SimulationService simulation,
  ) {
    Color proximityColor;
    String proximityText;
    int proximityBars = 1;

    switch (peer.proximityHint) {
      case ProximityHint.immediate:
        proximityColor = YamiTheme.glowSecure;
        proximityText = 'IMMEDIATE';
        proximityBars = 3;
        break;
      case ProximityHint.near:
        proximityColor = YamiTheme.glowActive;
        proximityText = 'NEAR';
        proximityBars = 2;
        break;
      case ProximityHint.far:
        proximityColor = YamiTheme.glowAmbient;
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
          decoration: YamiTheme.glassDecoration(
            backgroundColor: YamiTheme.surfaceDark,
            glowColor: isTrusted ? YamiTheme.glowSecure : YamiTheme.glowActive,
            glowRadius: isTrusted ? 4.0 : 0.0,
            doubleBorder: true,
          ),
          child: Row(
            children: [
              // Custom left state highlighter bar
              Container(
                width: 3.5,
                height: 38,
                decoration: BoxDecoration(
                  color: isTrusted
                      ? YamiTheme.glowSecure
                      : YamiTheme.glowActive.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Generative Procedural Avatar
              YamiAvatar(
                seed: peer.avatarSeed,
                size: 46,
                glowColor: isTrusted
                    ? YamiTheme.glowSecure
                    : YamiTheme.glowActive,
                isGlowing: isTrusted,
              ),
              const SizedBox(width: 14),

              // Peer Ident details
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
                            color: YamiTheme.glowSecure,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Signal proximity telemetry indicators
                    Row(
                      children: [
                        // Proximity visual bars
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
                                    : YamiTheme.textMuted.withOpacity(0.2),
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
                color: YamiTheme.textMuted.withOpacity(0.7),
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
    SimulationService simulation,
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

            // Generate deterministic pair passcode
            final pairCode =
                '${(currentPeer.id.hashCode % 900 + 100)} ${(currentPeer.alias.hashCode % 900 + 100)}';

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 26.0,
              ),
              decoration: const BoxDecoration(
                color: YamiTheme.bgDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
                border: Border(
                  top: BorderSide(color: YamiTheme.borderGlass, width: 1.0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: YamiTheme.borderGlass,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Big Glowing Avatar
                  YamiAvatar(
                    seed: currentPeer.avatarSeed,
                    size: 80,
                    glowColor: isTrusted
                        ? YamiTheme.glowSecure
                        : YamiTheme.glowActive,
                    isGlowing: true,
                  ),
                  const SizedBox(height: 16),

                  Text(currentPeer.alias, style: YamiTheme.titleStyle),
                  const SizedBox(height: 4),

                  // Monospace identity code
                  Text(
                    'NODE KEY: sha256::${currentPeer.id.substring(0, 8)}...${currentPeer.id.substring(currentPeer.id.length - 4)}',
                    style: YamiTheme.monoStyle.copyWith(
                      color: YamiTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Relative Telemetry HUD Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14.0),
                    decoration: YamiTheme.glassDecoration(
                      backgroundColor: YamiTheme.surfaceDark,
                      opacity: 0.8,
                      doubleBorder: true,
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
                                    ? YamiTheme.glowSecure
                                    : YamiTheme.glowActive,
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
                                    ? YamiTheme.glowActive
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

                  // Key comparison module
                  if (isTrusted) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24.0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: YamiTheme.glowSecure.withOpacity(0.04),
                        border: Border.all(
                          color: YamiTheme.glowSecure.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            color: YamiTheme.glowSecure,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Device verified. Cryptographic pairing completed.',
                              style: YamiTheme.captionStyle.copyWith(
                                color: YamiTheme.glowSecure,
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
                      decoration: YamiTheme.glassDecoration(
                        backgroundColor: YamiTheme.surfaceLight,
                        opacity: 0.5,
                        doubleBorder: true,
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
                              color: YamiTheme.glowActive,
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

                  // Action sheet buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: YamiTheme.glowActive,
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
                                color: YamiTheme.glowActive,
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
                                  ? YamiTheme.glowWarning
                                  : YamiTheme.glowSecure,
                              foregroundColor: YamiTheme.bgDeep,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              simulation.togglePeerTrust(currentPeer.id);
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
                ],
              ),
            );
          },
        );
      },
    );
  }
}
