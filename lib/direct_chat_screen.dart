import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'theme.dart';
import 'repository/yamilink_repository.dart';
import 'widgets/avatar.dart';

class DirectChatScreen extends StatefulWidget {
  final Peer peer;

  const DirectChatScreen({super.key, required this.peer});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  YamiLinkRepository? _repository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = Provider.of<YamiLinkRepository>(context, listen: false);
    _repository?.setActiveConversation(widget.peer.id);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(YamiLinkRepository simulation) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    simulation.sendDirectMessage(widget.peer.id, text);
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 80), () => _scrollToBottom());
  }

  @override
  void dispose() {
    _repository?.setActiveConversation(null);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulation = Provider.of<YamiLinkRepository>(context);

    final livePeer = simulation.peers.firstWhere(
      (p) => p.id == widget.peer.id,
      orElse: () => widget.peer,
    );
    final isTrusted = livePeer.trustLevel == TrustLevel.paired;

    // Check conversation online status and retrieve messages list
    final conv = simulation.conversations.firstWhere(
      (c) => c.peerId == livePeer.id,
      orElse: () => Conversation(
        id: livePeer.id,
        peerId: livePeer.id,
        peerAlias: livePeer.alias,
        peerAvatarSeed: livePeer.avatarSeed,
        lastMessage: '',
        lastTimestamp: DateTime.now(),
        messages: [],
        isPeerOnline: true,
      ),
    );
    final isPeerOnline = conv.isPeerOnline;
    final messages = conv.messages;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: YamiTheme.bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: YamiTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            YamiAvatar(
              seed: livePeer.avatarSeed,
              size: 34,
              glowColor: isTrusted
                  ? YamiTheme.glowSecure
                  : YamiTheme.glowActive,
              isGlowing: isTrusted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        livePeer.alias,
                        style: YamiTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isTrusted) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: YamiTheme.glowSecure,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    !isPeerOnline
                        ? 'PEER OFFLINE - SECURE LINE SUSPENDED'
                        : (isTrusted
                              ? 'ENCRYPTED P2P CHANNEL'
                              : 'UNVERIFIED P2P CHANNEL'),
                    style: YamiTheme.captionStyle.copyWith(
                      fontSize: 8.5,
                      color: !isPeerOnline
                          ? YamiTheme.textMuted
                          : (isTrusted
                                ? YamiTheme.glowSecure
                                : YamiTheme.glowActive),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            // Safe pairing / offline banner
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: !isPeerOnline
                  ? YamiTheme.textMuted.withOpacity(0.08)
                  : (isTrusted
                        ? YamiTheme.glowSecure.withOpacity(0.04)
                        : YamiTheme.surfaceDark.withOpacity(0.85)),
              child: Row(
                children: [
                  Icon(
                    !isPeerOnline
                        ? Icons.cloud_off
                        : (isTrusted ? Icons.lock : Icons.lock_open),
                    size: 14,
                    color: !isPeerOnline
                        ? YamiTheme.textMuted
                        : (isTrusted
                              ? YamiTheme.glowSecure
                              : YamiTheme.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !isPeerOnline
                          ? 'Connection lost. Message delivery will pause until peer is back online.'
                          : (isTrusted
                                ? '1-hop encryption verified. Local key comparison verified.'
                                : 'Unverified pairing. Tap peer card in Nearby space to authorize keys.'),
                      style: YamiTheme.captionStyle.copyWith(
                        fontSize: 10,
                        color: !isPeerOnline
                            ? YamiTheme.textMuted
                            : (isTrusted
                                  ? YamiTheme.glowSecure
                                  : YamiTheme.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Messages feed
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == simulation.profile.id;

                  return _buildMessageRow(message, isMe, isTrusted);
                },
              ),
            ),

            // Text input panel
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
                          enabled: isPeerOnline,
                          decoration: InputDecoration(
                            hintText: isPeerOnline
                                ? 'Transmit direct packet...'
                                : 'Cannot transmit while peer is offline',
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !isPeerOnline
                            ? YamiTheme.textMuted.withOpacity(0.1)
                            : (isTrusted
                                  ? YamiTheme.glowSecure
                                  : YamiTheme.glowActive),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_upward,
                          color: !isPeerOnline
                              ? YamiTheme.textMuted
                              : YamiTheme.bgDeep,
                          size: 20,
                        ),
                        onPressed: isPeerOnline
                            ? () => _sendMessage(simulation)
                            : null,
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

  Widget _buildMessageRow(Message message, bool isMe, bool isTrusted) {
    final Alignment alignment = isMe
        ? Alignment.centerRight
        : Alignment.centerLeft;
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
      child: Align(
        alignment: alignment,
        child: Column(
          crossAxisAlignment: crossAlignment,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
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
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$timeStr | ',
                  style: YamiTheme.captionStyle.copyWith(fontSize: 8.5),
                ),
                if (isMe) ...[
                  Icon(
                    message.status == MessageStatus.delivered
                        ? Icons.done_all
                        : Icons.done,
                    size: 11,
                    color: message.status == MessageStatus.delivered
                        ? YamiTheme.glowSecure
                        : YamiTheme.textMuted,
                  ),
                ] else ...[
                  Text(
                    '1-HOP P2P',
                    style: YamiTheme.monoStyle.copyWith(
                      fontSize: 7.5,
                      color: YamiTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
