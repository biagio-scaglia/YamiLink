import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/qr_pairing_screen.dart';
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
      backgroundColor: YamiTheme.bgDeep,
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
                                    color: YamiTheme.accentWine.withValues(
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
                                    color: YamiTheme.accentBrass.withValues(
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
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isScanning
                                      ? YamiTheme.accentWine
                                      : YamiTheme.surfaceRaised,
                                  border: Border.all(
                                    color: isScanning ? YamiTheme.accentBrass : YamiTheme.borderMid,
                                    width: 1,
                                  ),
                                  boxShadow: isScanning
                                      ? [
                                          BoxShadow(
                                            color: YamiTheme.accentWine.withValues(alpha: 0.5),
                                            blurRadius: 16.0,
                                            spreadRadius: 2.0,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  Icons.radar_rounded,
                                  size: 16,
                                  color: isScanning ? YamiTheme.textBright : YamiTheme.textSub,
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
                        style: YamiTheme.monoBrightStyle.copyWith(
                          color: isScanning
                              ? YamiTheme.accentBrass
                              : YamiTheme.textGhost,
                          fontSize: 9.5,
                          letterSpacing: 1.2,
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
                  Icons.help_outline_rounded,
                  color: YamiTheme.textSub,
                  size: 22,
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
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: isScanning
                      ? YamiTheme.accentWine
                      : YamiTheme.textSub,
                  size: 26,
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
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SPATIAL PEERS IN SCOPE',
                    style: YamiTheme.labelStyle.copyWith(
                      color: YamiTheme.textSub,
                      letterSpacing: 1.5,
                      fontSize: 10.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: YamiTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: YamiTheme.borderFaint),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isScanning
                                ? YamiTheme.accentBrass
                                : YamiTheme.textGhost,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${simulation.peers.length} ONLINE',
                          style: YamiTheme.labelStyle.copyWith(
                            color: isScanning
                                ? YamiTheme.textBright
                                : YamiTheme.textSub,
                            fontSize: 9.5,
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
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sensors_off_rounded,
                            size: 40,
                            color: YamiTheme.textGhost.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Proximity Layer Offline',
                            style: YamiTheme.headingStyle.copyWith(
                              color: YamiTheme.textBright,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Activate the beacon or wait for nearby peers to join the grid.',
                            textAlign: TextAlign.center,
                            style: YamiTheme.bodySmallStyle.copyWith(
                              color: YamiTheme.textSub,
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
    YamiLinkRepository simulation,
  ) {
    Color proximityColor;
    String proximityText;
    int proximityBars = 1;

    switch (peer.proximityHint) {
      case ProximityHint.immediate:
        proximityColor = YamiTheme.accentBrass;
        proximityText = 'IMMEDIATE';
        proximityBars = 3;
        break;
      case ProximityHint.near:
        proximityColor = YamiTheme.accentWine;
        proximityText = 'NEAR';
        proximityBars = 2;
        break;
      case ProximityHint.far:
        proximityColor = YamiTheme.textSub;
        proximityText = 'FAR';
        proximityBars = 1;
        break;
      case ProximityHint.unknown:
        proximityColor = YamiTheme.textGhost;
        proximityText = 'UNKNOWN';
        proximityBars = 0;
        break;
    }

    final isTrusted = peer.trustLevel == TrustLevel.paired;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: YamiTheme.spaceMd, vertical: YamiTheme.spaceXs),
      child: GestureDetector(
        onTap: () => _showPeerDetailsSheet(context, peer, simulation),
        child: Container(
          padding: const EdgeInsets.all(YamiTheme.spaceMd),
          decoration: YamiTheme.surfaceCard(
            borderColor: isTrusted ? YamiTheme.accentBrass.withValues(alpha: 0.3) : YamiTheme.borderMid,
          ),
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 38,
                decoration: BoxDecoration(
                  color: isTrusted
                      ? YamiTheme.accentBrass
                      : YamiTheme.textGhost,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              YamiAvatar(
                seed: peer.avatarSeed,
                size: 48,
                glowColor: isTrusted ? YamiTheme.accentBrass : YamiTheme.accentWine,
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
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: YamiTheme.textBright,
                          ),
                        ),
                        if (isTrusted) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: YamiTheme.accentBrass,
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
                                    : YamiTheme.textGhost.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          proximityText,
                          style: YamiTheme.monoBrightStyle.copyWith(
                            color: proximityColor,
                            fontSize: 9,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (peer.relayCapability) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.router_rounded,
                            size: 12,
                            color: YamiTheme.textSub,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'RELAY',
                            style: YamiTheme.captionStyle.copyWith(
                              fontSize: 8.5,
                              color: YamiTheme.textSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: YamiTheme.textGhost,
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

            Color proximityColor;
            switch (currentPeer.proximityHint) {
              case ProximityHint.immediate:
                proximityColor = YamiTheme.accentBrass;
                break;
              case ProximityHint.near:
                proximityColor = YamiTheme.accentWine;
                break;
              case ProximityHint.far:
                proximityColor = YamiTheme.textSub;
                break;
              case ProximityHint.unknown:
                proximityColor = YamiTheme.textGhost;
                break;
            }

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 26.0,
              ),
              decoration: const BoxDecoration(
                color: YamiTheme.surfaceRaised,
                borderRadius: BorderRadius.vertical(top: Radius.circular(YamiTheme.radiusRound)),
                border: Border(
                  top: BorderSide(color: YamiTheme.borderMid, width: 1.0),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: YamiTheme.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    YamiAvatar(
                      seed: currentPeer.avatarSeed,
                      size: 80,
                      glowColor: isTrusted ? YamiTheme.accentBrass : YamiTheme.accentWine,
                      isGlowing: true,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      currentPeer.alias,
                      style: YamiTheme.headingStyle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'NODE KEY: sha256::${currentPeer.id.substring(0, 8)}...${currentPeer.id.substring(currentPeer.id.length - 4)}',
                      style: YamiTheme.monoBrightStyle.copyWith(
                        color: YamiTheme.textSub,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(YamiTheme.spaceMd),
                      decoration: BoxDecoration(
                        color: YamiTheme.surfaceBase,
                        borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                        border: Border.all(color: YamiTheme.borderFaint),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOCAL SPACE ADJACENCY',
                            style: YamiTheme.monoStyle.copyWith(
                              color: YamiTheme.accentWine,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Proximity range',
                                style: YamiTheme.bodyStyle.copyWith(
                                  color: YamiTheme.textBody,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                currentPeer.proximityHint
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                style: YamiTheme.monoBrightStyle.copyWith(
                                  color: proximityColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Relay capabilities',
                                style: YamiTheme.bodyStyle.copyWith(
                                  color: YamiTheme.textBody,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                currentPeer.relayCapability
                                    ? 'ACTIVE MESH NODE'
                                    : 'ENDPOINT NODE',
                                style: YamiTheme.monoBrightStyle.copyWith(
                                  color: currentPeer.relayCapability
                                      ? YamiTheme.accentBrass
                                      : YamiTheme.textSub,
                                  fontSize: 11,
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
                        margin: const EdgeInsets.only(bottom: YamiTheme.spaceLg),
                        padding: const EdgeInsets.all(YamiTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: YamiTheme.accentBrass.withValues(alpha: 0.05),
                          border: Border.all(
                            color: YamiTheme.accentBrass.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: YamiTheme.accentBrass,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Device verified. Cryptographic pairing completed.',
                                style: YamiTheme.bodySmallStyle.copyWith(
                                  color: YamiTheme.accentBrass,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: YamiTheme.spaceLg),
                        padding: const EdgeInsets.all(YamiTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: YamiTheme.surfaceBase,
                          borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                          border: Border.all(color: YamiTheme.borderMid),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'MATCHING VERIFICATION CODE',
                              style: YamiTheme.labelStyle.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.0,
                                color: YamiTheme.textSub,
                              ),
                            ),
                            const SizedBox(height: YamiTheme.spaceSm),
                            Text(
                              pairCode,
                              style: YamiTheme.displayStyle.copyWith(
                                letterSpacing: 4,
                                fontSize: 24,
                                color: YamiTheme.accentWine,
                              ),
                            ),
                            const SizedBox(height: YamiTheme.spaceXs),
                            Text(
                              'Verify this number matches on their screen.',
                              style: YamiTheme.captionStyle.copyWith(
                                color: YamiTheme.textSub,
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
                                  color: YamiTheme.borderStrong,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                                ),
                                foregroundColor: YamiTheme.textBright,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onOpenDirectChat(currentPeer);
                              },
                              child: Text(
                                'DIRECT CHAT',
                                style: YamiTheme.labelStyle.copyWith(
                                  fontSize: 12,
                                  letterSpacing: 0.5,
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
                                    ? YamiTheme.accentEmber
                                    : YamiTheme.accentWine,
                                foregroundColor: YamiTheme.textBright,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                                ),
                              ),
                              onPressed: () {
                                if (!isTrusted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QRPairingScreen(
                                        myProfile: simulation.profile,
                                        targetPeer: currentPeer,
                                        onVerified: (verifiedId) {
                                          simulation.initiatePairing(verifiedId);
                                          simulation.togglePeerTrust(verifiedId);
                                        },
                                      ),
                                    ),
                                  ).then((_) {
                                    setModalState(() {});
                                  });
                                } else {
                                  simulation.togglePeerTrust(currentPeer.id);
                                }
                                setModalState(() {});
                              },
                              child: Text(
                                isTrusted ? 'REVOKE TRUST' : 'VERIFY PAIRING',
                                style: YamiTheme.labelStyle.copyWith(
                                  color: YamiTheme.textBright,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
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
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: simulation.isPeerMuted(currentPeer.id)
                              ? YamiTheme.accentBrass
                              : YamiTheme.accentEmber,
                          size: 18,
                        ),
                        label: Text(
                          simulation.isPeerMuted(currentPeer.id)
                              ? 'UNMUTE PEER'
                              : 'MUTE PEER',
                          style: YamiTheme.labelStyle.copyWith(
                            color: simulation.isPeerMuted(currentPeer.id)
                                ? YamiTheme.accentBrass
                                : YamiTheme.accentEmber,
                            fontSize: 12,
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
                                backgroundColor: YamiTheme.accentBrass,
                              ),
                            );
                          } else {
                            showDialog(
                              context: context,
                              builder: (context) => SimpleDialog(
                                backgroundColor: YamiTheme.surfaceRaised,
                                title: Text(
                                  'MUTE PEER',
                                  style: YamiTheme.headingStyle.copyWith(fontSize: 16),
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
                                          backgroundColor: YamiTheme.accentEmber,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '10 Seconds',
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
                                          backgroundColor: YamiTheme.accentEmber,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '30 Seconds',
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
                                          backgroundColor: YamiTheme.accentEmber,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '1 Minute',
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
                          Icons.block_rounded,
                          color: YamiTheme.accentEmber,
                          size: 18,
                        ),
                        label: Text(
                          'BLOCK PEER',
                          style: YamiTheme.labelStyle.copyWith(
                            color: YamiTheme.accentEmber,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          simulation.blockPeer(currentPeer.id);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${currentPeer.alias} blocked'),
                              backgroundColor: YamiTheme.accentEmber,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
