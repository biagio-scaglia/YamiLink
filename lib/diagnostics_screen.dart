import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'repository/yamilink_repository.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final ScrollController _consoleScrollController = ScrollController();
  int _lastLogCount = 0;

  @override
  void dispose() {
    _consoleScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulation = Provider.of<YamiLinkRepository>(context);
    final logs = simulation.diagnosticsLogs;

    if (logs.length != _lastLogCount) {
      _lastLogCount = logs.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_consoleScrollController.hasClients) {
          _consoleScrollController.animateTo(
            _consoleScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }

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
                color: YamiTheme.accentActive.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: YamiTheme.bgDeep,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: YamiTheme.borderMetallic, height: 1.0),
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
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PEERS FOUND',
                      value: '${simulation.peers.length}',
                      subtitle: 'Active nodes',
                      icon: Icons.radar,
                      accentColor: YamiTheme.accentActive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PACKETS',
                      value: '${simulation.packetsProcessed}',
                      subtitle: 'Routed payloads',
                      icon: Icons.leak_add,
                      accentColor: YamiTheme.accentSecure,
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
                          ? YamiTheme.accentSecure
                          : YamiTheme.accentActive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'RELAY LIMIT',
                      value: '3-HOPS',
                      subtitle: 'Epidemic bounds',
                      icon: Icons.alt_route,
                      accentColor: YamiTheme.accentAmbient,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                decoration: YamiTheme.tactileDecoration(
                  backgroundColor: YamiTheme.surfaceDark,
                  borderColor: simulation.relayEnabled
                      ? YamiTheme.accentSecure
                      : YamiTheme.borderMetallic,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.router, color: YamiTheme.accentActive),
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
                      activeThumbColor: YamiTheme.accentSecure,
                      activeTrackColor: YamiTheme.accentSecure.withValues(
                        alpha: 0.2,
                      ),
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

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: YamiTheme.borderMetallic),
                  ),
                  child: ListView.builder(
                    controller: _consoleScrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      Color logColor = YamiTheme.textSecondary;
                      if (log.contains('SEC:')) {
                        logColor = YamiTheme.accentSecure;
                      } else if (log.contains('NET:')) {
                        logColor = YamiTheme.accentAmbient;
                      } else if (log.contains('DBG:')) {
                        logColor = YamiTheme.accentActive;
                      } else if (log.contains('ERR:')) {
                        logColor = YamiTheme.accentWarning;
                      }

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Transform.translate(
                                offset: Offset((1.0 - value) * -12, 0.0),
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
      decoration: YamiTheme.tactileDecoration(
        backgroundColor: YamiTheme.surfaceDark,
        opacity: 0.75,
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
              Icon(icon, size: 14, color: accentColor.withValues(alpha: 0.8)),
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
