import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'simulation_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final List<String> _consoleLogs = [];
  final ScrollController _consoleScrollController = ScrollController();
  Timer? _logTimer;

  final List<String> _logTemplates = [
    'DBG: Broadcaster beacon sent successfully (size: 32B)',
    'INF: Discovered BLE advertising channel 37',
    'SEC: Ephemeral session signature verified for node',
    'NET: 1-hop handshake packet processed',
    'DBG: P2P route discovery resolved via Wi-Fi socket',
    'INF: Received broadcast payload: [Local Area Broadcast]',
    'SEC: Shared cryptographic secret refreshed',
    'NET: Route capacity validated - active bandwidth ok',
    'INF: Signal ping response received (latency: 18ms)',
    'DBG: Frame checksum validated - no packet loss',
  ];

  @override
  void initState() {
    super.initState();
    // Add initial mock logs
    final now = DateTime.now();
    _consoleLogs.addAll([
      '[${_formatTime(now.subtract(const Duration(seconds: 15)))}] SEC: Initialized ephemeral cryptosystem',
      '[${_formatTime(now.subtract(const Duration(seconds: 10)))}] NET: Core 1-hop socket listening on port 8099',
      '[${_formatTime(now.subtract(const Duration(seconds: 5)))}] INF: Scan initialized for nearby beacons...',
    ]);

    // Periodically append new telemetry logs to the console
    _logTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;

      final simulation = Provider.of<SimulationService>(context, listen: false);
      if (!simulation.isScanning) return; // Only log when scanning is active

      final logTime = _formatTime(DateTime.now());
      final template =
          _logTemplates[DateTime.now().millisecond % _logTemplates.length];

      // Randomly append peer-specific details
      String logLine;
      if (template.contains('node') && simulation.peers.isNotEmpty) {
        final peer = simulation
            .peers[DateTime.now().millisecond % simulation.peers.length];
        logLine = '[$logTime] ${template.replaceFirst('node', peer.alias)}';
      } else {
        logLine = '[$logTime] $template';
      }

      setState(() {
        _consoleLogs.add(logLine);
        // Cap logs at 100 entries to prevent memory leak
        if (_consoleLogs.length > 100) {
          _consoleLogs.removeAt(0);
        }
      });

      // Autoscroll logs
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_consoleScrollController.hasClients) {
          _consoleScrollController.animateTo(
            _consoleScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _consoleScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulation = Provider.of<SimulationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NETWORK STATUS',
              style: YamiTheme.monoStyle.copyWith(
                fontSize: 14,
                color: YamiTheme.textPrimary,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '1-HOP NODE TELEMETRY',
              style: YamiTheme.captionStyle.copyWith(
                fontSize: 9,
                color: YamiTheme.glowActive.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: YamiTheme.bgDeep,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: YamiTheme.borderGlass, height: 1.0),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: YamiTheme.ambientBackgroundGradient(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Grid of metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PEERS FOUND',
                      value: '${simulation.peers.length}',
                      subtitle: 'Active nodes',
                      icon: Icons.cell_tower,
                      accentColor: YamiTheme.glowActive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PACKETS',
                      value: '${simulation.packetsProcessed}',
                      subtitle: 'Routed payloads',
                      icon: Icons.swap_calls,
                      accentColor: YamiTheme.glowSecure,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'SIGNAL',
                      value: '${(simulation.signalStrength * 100).toInt()}%',
                      subtitle: 'Local space quality',
                      icon: Icons.wifi_tethering,
                      accentColor: simulation.signalStrength > 0.8
                          ? YamiTheme.glowSecure
                          : YamiTheme.glowActive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'RELAY HOP',
                      value: '1-HOP',
                      subtitle: 'Direct adjacency limit',
                      icon: Icons.route,
                      accentColor: YamiTheme.glowAmbient,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Interactive Relay Toggle Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                decoration: YamiTheme.glassDecoration(
                  backgroundColor: YamiTheme.surfaceDark,
                  glowColor: simulation.relayEnabled
                      ? YamiTheme.glowSecure
                      : Colors.transparent,
                  glowRadius: simulation.relayEnabled ? 3.0 : 0.0,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.router, color: YamiTheme.glowActive),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ACT AS MESH RELAY',
                            style: YamiTheme.monoStyle.copyWith(
                              fontSize: 12,
                              color: YamiTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Allow packets from other nodes to transit through your device.',
                            style: YamiTheme.captionStyle.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: simulation.relayEnabled,
                      activeColor: YamiTheme.glowSecure,
                      onChanged: (val) {
                        simulation.toggleRelay();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Diagnostics Live Console Console Log header
              Text(
                'LIVE SYSTEM TELEMETRY LOGS',
                style: YamiTheme.monoStyle.copyWith(
                  color: YamiTheme.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              // 4. Cyber Console Feed widget
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: YamiTheme.borderGlass),
                  ),
                  child: ListView.builder(
                    controller: _consoleScrollController,
                    itemCount: _consoleLogs.length,
                    itemBuilder: (context, index) {
                      final log = _consoleLogs[index];
                      // Highlight sections like SEC, NET, INF or DBG with different neon colors
                      Color logColor = YamiTheme.textSecondary;
                      if (log.contains('SEC:')) {
                        logColor = YamiTheme.glowSecure;
                      } else if (log.contains('NET:')) {
                        logColor = YamiTheme.glowAmbient;
                      } else if (log.contains('DBG:')) {
                        logColor = YamiTheme.glowActive;
                      } else if (log.contains('ERR:')) {
                        logColor = YamiTheme.glowWarning;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            color: logColor,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: YamiTheme.glassDecoration(
        backgroundColor: YamiTheme.surfaceDark,
        opacity: 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: YamiTheme.monoStyle.copyWith(
                  fontSize: 10,
                  color: YamiTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, size: 14, color: accentColor.withOpacity(0.8)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: YamiTheme.titleStyle.copyWith(
              fontSize: 22,
              color: YamiTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: YamiTheme.captionStyle.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}
