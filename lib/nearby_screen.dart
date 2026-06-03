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

class _NearbyScreenState extends State<NearbyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
          // Elegant atmospheric space header
          SliverAppBar(
            expandedHeight: 220.0,
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
                      const SizedBox(height: 40),
                      // Animated scanning radar
                      AnimatedBuilder(
                        animation: _radarController,
                        builder: (context, child) {
                          return Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: YamiTheme.glowActive.withOpacity(
                                  isScanning ? (1.0 - _radarController.value) : 0.2,
                                ),
                                width: 2 + (8 * _radarController.value),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isScanning ? YamiTheme.glowActive : YamiTheme.textMuted,
                                  boxShadow: isScanning
                                      ? [
                                          BoxShadow(
                                            color: YamiTheme.glowActive.withOpacity(0.6),
                                            blurRadius: 16.0,
                                            spreadRadius: 4.0,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isScanning ? 'SCANNING LOCAL SPACE...' : 'DISCOVERY PAUSED',
                        style: YamiTheme.monoStyle.copyWith(
                          color: isScanning ? YamiTheme.glowActive : YamiTheme.textMuted,
                          fontSize: 11,
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
                  isScanning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: isScanning ? YamiTheme.glowActive : YamiTheme.textSecondary,
                  size: 28,
                ),
                onPressed: () {
                  if (isScanning) {
                    simulation.stopScanning();
                  } else {
                    simulation.startScanning();
                  }
                },
                tooltip: isScanning ? 'Metti in pausa scansione' : 'Avvia scansione',
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Discovered list section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Text(
                    'PEERS IN RANGE',
                    style: YamiTheme.monoStyle.copyWith(
                      color: YamiTheme.textSecondary,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, py: 3),
                    decoration: YamiTheme.glassDecoration(
                      backgroundColor: YamiTheme.surfaceLight,
                      opacity: 0.8,
                      borderRadius: 20,
                    ),
                    child: Text(
                      '${simulation.peers.length} ACTIVE',
                      style: YamiTheme.monoStyle.copyWith(
                        color: YamiTheme.glowActive,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Empty State or list of discovered nodes
          simulation.peers.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radar,
                          size: 48,
                          color: YamiTheme.textMuted.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No peer detected in this area.',
                          style: YamiTheme.subtitleStyle.copyWith(
                            color: YamiTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        if (!isScanning) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => simulation.startScanning(),
                            child: const Text('Start Discovery'),
                          )
                        ],
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final peer = simulation.peers[index];
                      return _buildPeerTile(context, peer, simulation);
                    },
                    childCount: simulation.peers.length,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPeerTile(BuildContext context, Peer peer, SimulationService simulation) {
    // Proximity indicator builder
    Color proximityColor;
    String proximityText;
    switch (peer.proximityHint) {
      case ProximityHint.immediate:
        proximityColor = YamiTheme.glowSecure;
        proximityText = 'IMMEDIATE';
        break;
      case ProximityHint.near:
        proximityColor = YamiTheme.glowActive;
        proximityText = 'NEAR';
        break;
      case ProximityHint.far:
        proximityColor = YamiTheme.glowAmbient;
        proximityText = 'FAR';
        break;
      case ProximityHint.unknown:
      default:
        proximityColor = YamiTheme.textMuted;
        proximityText = 'UNKNOWN';
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
            glowRadius: isTrusted ? 3.0 : 0.0,
          ),
          child: Row(
            children: [
              // Geometric Avatar
              YamiAvatar(
                seed: peer.avatarSeed,
                size: 48,
                glowColor: isTrusted ? YamiTheme.glowSecure : YamiTheme.glowActive,
                isGlowing: isTrusted,
              ),
              const SizedBox(width: 14),

              // Title and proximity hint
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          peer.alias,
                          style: YamiTheme.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: proximityColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          proximityText,
                          style: YamiTheme.monoStyle.copyWith(
                            color: proximityColor,
                            fontSize: 10,
                          ),
                        ),
                        if (peer.relayCapability) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.router, size: 10, color: YamiTheme.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            'RELAY',
                            style: YamiTheme.captionStyle.copyWith(fontSize: 8, letterSpacing: 0.5),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action Arrow button
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: YamiTheme.textMuted.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPeerDetailsSheet(BuildContext context, Peer peer, SimulationService simulation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Find current peer state from simulation
            final currentPeer = simulation.peers.firstWhere((p) => p.id == peer.id, orElse: () => peer);
            final isTrusted = currentPeer.trustLevel == TrustLevel.paired;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
              decoration: BoxDecoration(
                color: YamiTheme.bgDeep,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                border: const Border(
                  top: BorderSide(color: YamiTheme.borderGlass, width: 1.0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicator drag handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: YamiTheme.borderGlass,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Peer Avatar
                  YamiAvatar(
                    seed: currentPeer.avatarSeed,
                    size: 80,
                    glowColor: isTrusted ? YamiTheme.glowSecure : YamiTheme.glowActive,
                    isGlowing: true,
                  ),
                  const SizedBox(height: 16),

                  // Alias
                  Text(
                    currentPeer.alias,
                    style: YamiTheme.titleStyle,
                  ),
                  const SizedBox(height: 6),

                  // Hash Key details
                  Text(
                    'NODE ID: sha256::${currentPeer.id.substring(0, 8)}...${currentPeer.id.substring(currentPeer.id.length - 4)}',
                    style: YamiTheme.monoStyle.copyWith(
                      color: YamiTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Distance HUD Widget
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                    decoration: YamiTheme.glassDecoration(
                      backgroundColor: YamiTheme.surfaceDark,
                      opacity: 0.8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCAL TELEMETRY',
                          style: YamiTheme.monoStyle.copyWith(
                            color: YamiTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Proximity Rating',
                              style: YamiTheme.bodyStyle.copyWith(color: YamiTheme.textSecondary),
                            ),
                            Text(
                              currentPeer.proximityHint.toString().split('.').last.toUpperCase(),
                              style: YamiTheme.monoStyle.copyWith(
                                color: currentPeer.proximityHint == ProximityHint.immediate
                                    ? YamiTheme.glowSecure
                                    : YamiTheme.glowActive,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mesh Relay Support',
                              style: YamiTheme.bodyStyle.copyWith(color: YamiTheme.textSecondary),
                            ),
                            Text(
                              currentPeer.relayCapability ? 'ACTIVE CAPABILITY' : 'TERMINAL NODE',
                              style: YamiTheme.monoStyle.copyWith(
                                color: currentPeer.relayCapability ? YamiTheme.glowActive : YamiTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pairing Key matching mockup
                  if (isTrusted) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.bottom(24.0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: YamiTheme.glowSecure.withOpacity(0.05),
                        border: Border.all(color: YamiTheme.glowSecure.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: YamiTheme.glowSecure, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Device trust established. 1-hop encryption verified.',
                              style: YamiTheme.captionStyle.copyWith(color: YamiTheme.glowSecure),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.bottom(24.0),
                      padding: const EdgeInsets.all(12),
                      decoration: YamiTheme.glassDecoration(
                        backgroundColor: YamiTheme.surfaceLight,
                        opacity: 0.5,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'MATCHING VERIFICATION CODE',
                            style: YamiTheme.monoStyle.copyWith(fontSize: 10, color: YamiTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            // Generated deterministic verification code based on peer IDs
                            '${(currentPeer.id.hashCode % 900 + 100)} ${(currentPeer.alias.hashCode % 900 + 100)}',
                            style: YamiTheme.titleStyle.copyWith(
                              letterSpacing: 2,
                              color: YamiTheme.glowActive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      // Direct Chat button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: YamiTheme.glowActive),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onOpenDirectChat(currentPeer);
                            },
                            child: Text(
                              'OPEN CHAT',
                              style: YamiTheme.monoStyle.copyWith(color: YamiTheme.glowActive),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Trust pairing toggle button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isTrusted ? YamiTheme.glowWarning : YamiTheme.glowSecure,
                              foregroundColor: YamiTheme.bgDeep,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              simulation.togglePeerTrust(currentPeer.id);
                              setModalState(() {}); // rebuild local sheet state
                            },
                            child: Text(
                              isTrusted ? 'REVOKE TRUST' : 'ESTABLISH TRUST',
                              style: YamiTheme.monoStyle.copyWith(
                                color: YamiTheme.bgDeep,
                                fontWeight: FontWeight.bold,
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
