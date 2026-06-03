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
      if (!simulation.isScanning) return;

      final logTime = _formatTime(DateTime.now());
      final template =
          _logTemplates[DateTime.now().millisecond % _logTemplates.length];

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
        if (_consoleLogs.length > 80) {
          _consoleLogs.removeAt(0);
        }
      });

      Future.delayed(const Duration(milliseconds: 120), () {
        if (_consoleScrollController.hasClients) {
          _consoleScrollController.animateTo(
            _consoleScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
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
              'SYSTEM DIAGNOSTICS',
              style: YamiTheme.monoStyle.copyWith(
                fontSize: 13,
                color: YamiTheme.textPrimary,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              'LOCAL TELEMETRY CONSOLE',
              style: YamiTheme.captionStyle.copyWith(
                fontSize: 8.5,
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
              // HUD grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PEERS FOUND',
                      value: '${simulation.peers.length}',
                      subtitle: 'Active nodes',
                      icon: Icons.radar,
                      accentColor: YamiTheme.glowActive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PACKETS',
                      value: '${simulation.packetsProcessed}',
                      subtitle: 'Routed payloads',
                      icon: Icons.leak_add,
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
                      title: 'SIGNAL STRENGTH',
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
                      title: 'RELAY LIMIT',
                      value: '1-HOP',
                      subtitle: 'Direct bounds',
                      icon: Icons.alt_route,
                      accentColor: YamiTheme.glowAmbient,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Interactive Relay toggle
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
                  glowRadius: simulation.relayEnabled ? 4.0 : 0.0,
                  doubleBorder: true,
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
                            'Transit payload packets from nearby peers.',
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
                      activeTrackColor: YamiTheme.glowSecure.withOpacity(0.2),
                      onChanged: (val) {
                        simulation.toggleRelay();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'LIVE SYSTEM TELEMETRY LOGS',
                style: YamiTheme.monoStyle.copyWith(
                  color: YamiTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),

              // Cyber scrolling terminal
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: YamiTheme.borderGlass),
                  ),
                  child: ListView.builder(
                    controller: _consoleScrollController,
                    itemCount: _consoleLogs.length,
                    itemBuilder: (context, index) {
                      final log = _consoleLogs[index];
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

                      // Sliding fade-in effect for log entries
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: 2.0,
                                bottom: 2.0,
                                left: (1.0 - value) * -10, // slide in from left
                              ),
                              child: Text(
                                log,
                                style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 10.5,
                                  color: logColor,
                                  height: 1.3,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          );
                        },
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
        opacity: 0.75,
        doubleBorder: true,
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
                  fontSize: 9.5,
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
