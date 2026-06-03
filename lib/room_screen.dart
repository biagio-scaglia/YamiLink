import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'theme.dart';
import 'repository/yamilink_repository.dart';
import 'widgets/avatar.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(YamiLinkRepository simulation) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    simulation.sendBroadcastMessage(text);
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 80), () {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulation = Provider.of<YamiLinkRepository>(context);
    final profile = simulation.profile;
    final messages = simulation.roomMessages;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOCAL BROADCAST ROOM',
              style: YamiTheme.monoStyle.copyWith(
                fontSize: 13,
                color: YamiTheme.textPrimary,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              '1-HOP ADJACENCY LIMIT • EPHEMERAL SEGMENT',
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
        child: Column(
          children: [
            // Warning bar
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: YamiTheme.surfaceDark.withOpacity(0.85),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_toggle_off,
                    size: 14,
                    color: YamiTheme.glowActive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All local packet data evaporates when leaving the scope.',
                      style: YamiTheme.captionStyle.copyWith(
                        fontSize: 10,
                        color: YamiTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == profile.id;

                  final senderPeer = simulation.peers.firstWhere(
                    (p) => p.id == message.senderId,
                    orElse: () => Peer(
                      id: message.senderId,
                      alias: message.senderAlias,
                      avatarSeed: message.senderAlias.hashCode,
                      lastSeen: DateTime.now(),
                    ),
                  );
                  final isTrusted = senderPeer.trustLevel == TrustLevel.paired;

                  return _buildMessageRow(
                    message,
                    isMe,
                    isTrusted,
                    senderPeer.avatarSeed,
                  );
                },
              ),
            ),

            // Text transmitter keyboard
            Container(height: 1, color: YamiTheme.borderGlass),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                color: YamiTheme.surfaceDark,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: YamiTheme.bgDeep,
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: YamiTheme.borderGlass,
                            width: 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: YamiTheme.bodyStyle,
                          decoration: InputDecoration(
                            hintText: 'Transmit payload to local space...',
                            hintStyle: YamiTheme.captionStyle.copyWith(
                              fontSize: 13,
                              color: YamiTheme.textMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 11.0,
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(simulation),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: YamiTheme.glowActive,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_upward,
                          color: YamiTheme.bgDeep,
                          size: 20,
                        ),
                        onPressed: () => _sendMessage(simulation),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(
    Message message,
    bool isMe,
    bool isTrusted,
    int avatarSeed,
  ) {
    final CrossAxisAlignment crossAlignment = isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final String timeStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    final glowColor = isMe
        ? YamiTheme.glowActive
        : (isTrusted ? YamiTheme.glowSecure : Colors.transparent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            YamiAvatar(
              seed: avatarSeed,
              size: 32,
              glowColor: isTrusted
                  ? YamiTheme.glowSecure
                  : YamiTheme.glowActive,
              isGlowing: isTrusted,
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: crossAlignment,
              children: [
                // Sender tag row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isMe ? 'YOU' : message.senderAlias,
                        style: YamiTheme.monoStyle.copyWith(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: isMe
                              ? YamiTheme.glowActive
                              : (isTrusted
                                    ? YamiTheme.glowSecure
                                    : YamiTheme.textSecondary),
                        ),
                      ),
                      if (isTrusted && !isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: YamiTheme.glowSecure,
                          size: 10,
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        '[$timeStr]',
                        style: YamiTheme.captionStyle.copyWith(
                          fontSize: 8,
                          color: YamiTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bubble Container with Double border Glassmorphic outline
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 10.0,
                  ),
                  decoration: YamiTheme.glassDecoration(
                    backgroundColor: isMe
                        ? YamiTheme.surfaceLight
                        : YamiTheme.surfaceDark,
                    opacity: 0.85,
                    glowColor: glowColor,
                    glowRadius: (isMe || isTrusted) ? 3.0 : 0.0,
                    borderRadius: 12.0,
                    doubleBorder: true,
                  ),
                  child: Text(message.content, style: YamiTheme.bodyStyle),
                ),

                // Node key details in monospace
                Padding(
                  padding: const EdgeInsets.only(
                    top: 2.0,
                    left: 4.0,
                    right: 4.0,
                  ),
                  child: Text(
                    'PK: ${message.senderId.substring(0, 5)} | ${message.hopCount}-HOP RELAY',
                    style: YamiTheme.captionStyle.copyWith(
                      fontSize: 8,
                      fontFamily: 'SpaceMono',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isMe) ...[
            const SizedBox(width: 8),
            YamiAvatar(
              seed: avatarSeed,
              size: 32,
              glowColor: YamiTheme.glowActive,
              isGlowing: true,
            ),
          ],
        ],
      ),
    );
  }
}
