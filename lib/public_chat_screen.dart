import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/moderation/moderation_models.dart';
import 'models.dart';
import 'theme.dart';
import 'repository/session_chat_repository.dart';
import 'widgets/avatar.dart';
import 'core/tutorial/tutorial_helper.dart';

class PublicChatScreen extends StatefulWidget {
  final VoidCallback onRunTutorial;

  const PublicChatScreen({super.key, required this.onRunTutorial});

  @override
  State<PublicChatScreen> createState() => _PublicChatScreenState();
}

class _PublicChatScreenState extends State<PublicChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _revealedMessageIds = {};

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

  Future<void> _sendMessage(SessionChatRepository simulation) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final decision = await simulation.sendBroadcastMessage(text);
    if (decision != null) {
      if (decision.action == ModerationAction.block) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: YamiTheme.bgDeep,
            title: Text(
              'MESSAGE BLOCKED',
              style: YamiTheme.headingStyle.copyWith(color: YamiTheme.accentEmber),
            ),
            content: Text(
              'Your message violates local guidelines:\n\n${decision.explanation}',
              style: YamiTheme.bodyStyle,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: YamiTheme.labelStyle.copyWith(
                    color: YamiTheme.accentWine,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      if (decision.action == ModerationAction.warn) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: YamiTheme.bgDeep,
            title: Text(
              'SENSITIVE CONTENT',
              style: YamiTheme.headingStyle.copyWith(color: YamiTheme.accentEmber),
            ),
            content: Text(
              'Your message contains sensitive words:\n\n${decision.explanation}\n\nSend anyway?',
              style: YamiTheme.bodyStyle,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCEL',
                  style: YamiTheme.labelStyle.copyWith(
                    color: YamiTheme.textBody,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await simulation.sendBroadcastMessage(text, force: true);
                  _messageController.clear();
                  Future.delayed(
                    const Duration(milliseconds: 80),
                    () => _scrollToBottom(),
                  );
                },
                child: Text(
                  'SEND ANYWAY',
                  style: YamiTheme.labelStyle.copyWith(
                    color: YamiTheme.accentEmber,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }
    }

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
    final simulation = Provider.of<SessionChatRepository>(context);
    final profile = simulation.profile;
    final messages = simulation.roomMessages;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: YamiTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: YamiTheme.bgDeep,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session Room', style: YamiTheme.headingStyle),
            Text('Local · Ephemeral · Public Local Chat', style: YamiTheme.headingSubStyle),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => YamiTutorialHelper.showHelpBottomSheet(
              context, widget.onRunTutorial,
            ),
            tooltip: 'Help',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: YamiTheme.ambientGradient),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: YamiTheme.surfaceBase.withValues(alpha: 0.85),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_toggle_off,
                    size: 14,
                    color: YamiTheme.accentWine,
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

            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: YamiTheme.spaceMd,
              ),
              decoration: BoxDecoration(
                color: YamiTheme.accentBrass.withValues(alpha: 0.06),
                border: Border(bottom: BorderSide(color: YamiTheme.accentBrass.withValues(alpha: 0.12))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_outlined, size: 13, color: YamiTheme.accentBrass),
                  const SizedBox(width: YamiTheme.spaceSm),
                  Expanded(
                    child: Text(
                      'Moderation is local and ephemeral for the current session.',
                      style: YamiTheme.captionStyle.copyWith(
                        color: YamiTheme.accentBrass.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

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

                  return _buildMessageRow(
                    message,
                    isMe,
                    senderPeer.avatarSeed,
                  );
                },
              ),
            ),

            Container(height: 1, color: YamiTheme.borderFaint),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: YamiTheme.spaceMd,
                  vertical: YamiTheme.spaceSm,
                ),
                color: YamiTheme.surfaceBase,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: _messageController,
                          style: YamiTheme.bodyStyle.copyWith(
                            color: YamiTheme.textBright,
                            fontSize: 15,
                          ),
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'Message the room…',
                            hintStyle: YamiTheme.bodyStyle.copyWith(
                              color: YamiTheme.textGhost,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: YamiTheme.spaceMd,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(simulation),
                        ),
                      ),
                    ),
                    const SizedBox(width: YamiTheme.spaceSm),
                    GestureDetector(
                      onTap: () => _sendMessage(simulation),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: YamiTheme.accentWine,
                          borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                          boxShadow: [
                            BoxShadow(
                              color: YamiTheme.accentWine.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: YamiTheme.textBright,
                        ),
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
    LocalRoomMessage message,
    bool isMe,
    int avatarSeed,
  ) {
    final CrossAxisAlignment crossAlignment = isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final String timeStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    final shouldBlur =
        message.isBlurred && !_revealedMessageIds.contains(message.id);

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
              glowColor: YamiTheme.accentWine,
              isGlowing: false,
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: crossAlignment,
              children: [
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
                        style: YamiTheme.labelStyle.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isMe
                              ? YamiTheme.accentWine
                              : YamiTheme.textSecondary,
                        ),
                      ),
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

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 10.0,
                  ),
                  decoration: BoxDecoration(
                    color: shouldBlur
                        ? YamiTheme.surfaceBase
                        : (isMe
                              ? YamiTheme.accentWine.withValues(alpha: 0.18)
                              : YamiTheme.surfaceRaised),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isMe ? 12 : 3),
                      bottomRight: Radius.circular(isMe ? 3 : 12),
                    ),
                    border: Border.all(
                      color: shouldBlur
                          ? YamiTheme.accentEmber.withValues(alpha: 0.4)
                          : (isMe
                                ? YamiTheme.accentWine.withValues(alpha: 0.3)
                                : YamiTheme.borderMid),
                    ),
                    boxShadow: YamiTheme.shadowLow,
                  ),
                  child: shouldBlur
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _revealedMessageIds.add(message.id);
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_outlined,
                                size: 14,
                                color: YamiTheme.accentEmber,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Sensitive content · tap to reveal',
                                  style: YamiTheme.bodySmallStyle.copyWith(
                                    color: YamiTheme.accentEmber,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          message.content,
                          style: YamiTheme.bodyStyle.copyWith(
                            color: YamiTheme.textBright,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                ),

                Padding(
                  padding: const EdgeInsets.only(
                    top: 2.0,
                    left: 4.0,
                    right: 4.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: YamiTheme.captionStyle.copyWith(
                          fontSize: 10,
                          color: YamiTheme.textGhost,
                        ),
                      ),
                      Text(
                        ' · ${message.hopCount}-hop',
                        style: YamiTheme.monoBrightStyle.copyWith(
                          fontSize: 9,
                          color: YamiTheme.textGhost,
                        ),
                      ),
                    ],
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
              glowColor: YamiTheme.accentWine,
              isGlowing: false,
            ),
          ],
        ],
      ),
    );
  }
}
