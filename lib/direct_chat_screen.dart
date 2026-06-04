import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/moderation/moderation_models.dart';
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
  final Set<String> _revealedMessageIds = {};

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

  Future<void> _sendMessage(YamiLinkRepository simulation) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final decision = await simulation.sendDirectMessage(widget.peer.id, text);
    if (!mounted) return;
    if (decision == null) return;

    if (decision.action == ModerationAction.block) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: YamiTheme.bgDeep,
          title: Text(
            'MESSAGGIO BLOCCATO',
            style: YamiTheme.monoStyle.copyWith(color: YamiTheme.accentWarning),
          ),
          content: Text(
            'Il tuo messaggio viola le linee guida locali:\n\n${decision.explanation}',
            style: YamiTheme.bodyStyle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: YamiTheme.monoStyle.copyWith(
                  color: YamiTheme.accentActive,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (decision.action == ModerationAction.warn) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: YamiTheme.bgDeep,
          title: Text(
            'CONTENUTO SENSIBILE',
            style: YamiTheme.monoStyle.copyWith(color: YamiTheme.accentWarning),
          ),
          content: Text(
            'Il tuo messaggio contiene parole sensibili:\n\n${decision.explanation}\n\nVuoi inviarlo comunque?',
            style: YamiTheme.bodyStyle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ANNULLA',
                style: YamiTheme.monoStyle.copyWith(
                  color: YamiTheme.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                simulation.sendDirectMessage(widget.peer.id, text, force: true);
                _messageController.clear();
                Future.delayed(
                  const Duration(milliseconds: 80),
                  () => _scrollToBottom(),
                );
              },
              child: Text(
                'INVIA COMUNQUE',
                style: YamiTheme.monoStyle.copyWith(
                  color: YamiTheme.accentWarning,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

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

    final isBlocked = simulation.isPeerBlocked(widget.peer.id);
    final isMuted = simulation.isPeerMuted(widget.peer.id);

    final livePeer = simulation.peers.firstWhere(
      (p) => p.id == widget.peer.id,
      orElse: () => widget.peer,
    );
    final isTrusted = livePeer.trustLevel == TrustLevel.paired;

    final conv = simulation.conversations.firstWhere(
      (c) => c.peerId == livePeer.id,
      orElse: () {
        return Conversation(
          id: livePeer.id,
          peerId: livePeer.id,
          peerAlias: livePeer.alias,
          peerAvatarSeed: livePeer.avatarSeed,
          lastMessage: '',
          lastTimestamp: DateTime.now(),
          messages: simulation.getDirectMessages(livePeer.id),
          isPeerOnline: !isBlocked,
        );
      },
    );
    final isPeerOnline = conv.isPeerOnline && !isBlocked;
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
                  ? YamiTheme.accentSecure
                  : YamiTheme.accentActive,
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
                          color: YamiTheme.accentSecure,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    isBlocked
                        ? 'PEER BLOCCATO'
                        : (isMuted
                              ? 'PEER SILENZIATO'
                              : (!isPeerOnline
                                    ? 'PEER OFFLINE - SECURE LINE SUSPENDED'
                                    : (isTrusted
                                          ? 'ENCRYPTED P2P CHANNEL'
                                          : 'UNVERIFIED P2P CHANNEL'))),
                    style: YamiTheme.captionStyle.copyWith(
                      fontSize: 8.5,
                      color: isBlocked
                          ? YamiTheme.accentWarning
                          : (isMuted
                                ? YamiTheme.accentWarning
                                : (!isPeerOnline
                                      ? YamiTheme.textMuted
                                      : (isTrusted
                                            ? YamiTheme.accentSecure
                                            : YamiTheme.accentActive))),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isMuted ? Icons.volume_off : Icons.volume_up,
              color: isMuted ? YamiTheme.accentWarning : YamiTheme.textSecondary,
            ),
            onPressed: () {
              if (isMuted) {
                simulation.unmutePeer(livePeer.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${livePeer.alias} non è più silenziato'),
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
                            livePeer.id,
                            const Duration(seconds: 10),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Peer silenziato per 10 secondi'),
                              backgroundColor: YamiTheme.accentWarning,
                            ),
                          );
                        },
                        child: Text('10 Secondi', style: YamiTheme.bodyStyle),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          simulation.mutePeer(
                            livePeer.id,
                            const Duration(seconds: 30),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Peer silenziato per 30 secondi'),
                              backgroundColor: YamiTheme.accentWarning,
                            ),
                          );
                        },
                        child: Text('30 Secondi', style: YamiTheme.bodyStyle),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          simulation.mutePeer(
                            livePeer.id,
                            const Duration(minutes: 1),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Peer silenziato per 1 minuto'),
                              backgroundColor: YamiTheme.accentWarning,
                            ),
                          );
                        },
                        child: Text('1 Minuto', style: YamiTheme.bodyStyle),
                      ),
                    ],
                  ),
                );
              }
            },
            tooltip: 'Silenzia/Ripristina Peer',
          ),
          IconButton(
            icon: Icon(
              isBlocked ? Icons.block : Icons.block_outlined,
              color: isBlocked
                  ? YamiTheme.accentWarning
                  : YamiTheme.textSecondary,
            ),
            onPressed: () {
              if (isBlocked) {
                simulation.unblockPeer(livePeer.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${livePeer.alias} sbloccato'),
                    backgroundColor: YamiTheme.accentSecure,
                  ),
                );
              } else {
                simulation.blockPeer(livePeer.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${livePeer.alias} bloccato'),
                    backgroundColor: YamiTheme.accentWarning,
                  ),
                );
                Navigator.pop(context);
              }
            },
            tooltip: 'Block/Unblock Peer',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: YamiTheme.borderMetallic, height: 1.0),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: YamiTheme.ambientBackgroundGradient(),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: isBlocked
                  ? YamiTheme.accentWarning.withValues(alpha: 0.08)
                  : (isMuted
                        ? YamiTheme.accentWarning.withValues(alpha: 0.05)
                        : (!isPeerOnline
                              ? YamiTheme.textMuted.withValues(alpha: 0.08)
                              : (isTrusted
                                    ? YamiTheme.accentSecure.withValues(
                                        alpha: 0.04,
                                      )
                                    : YamiTheme.surfaceDark.withValues(
                                        alpha: 0.85,
                                      )))),
              child: Row(
                children: [
                  Icon(
                    isBlocked
                        ? Icons.block
                        : (isMuted
                              ? Icons.volume_off
                              : (!isPeerOnline
                                    ? Icons.cloud_off
                                    : (isTrusted
                                          ? Icons.lock
                                          : Icons.lock_open))),
                    size: 14,
                    color: isBlocked || isMuted
                        ? YamiTheme.accentWarning
                        : (!isPeerOnline
                              ? YamiTheme.textMuted
                              : (isTrusted
                                    ? YamiTheme.accentSecure
                                    : YamiTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBlocked
                          ? 'Questo peer è bloccato. Non riceverai né invierai messaggi.'
                          : (isMuted
                                ? 'Questo peer è silenziato localmente per la sessione corrente.'
                                : (!isPeerOnline
                                      ? 'Connessione persa. La consegna dei messaggi riprenderà quando il peer tornerà online.'
                                      : (isTrusted
                                            ? 'Crittografia 1-hop verificata. Chiavi di sessione verificate.'
                                            : 'Accoppiamento non verificato. Tocca la scheda peer nello spazio Vicini per autorizzare.'))),
                      style: YamiTheme.captionStyle.copyWith(
                        fontSize: 10,
                        color: isBlocked || isMuted
                            ? YamiTheme.accentWarning
                            : (!isPeerOnline
                                  ? YamiTheme.textMuted
                                  : (isTrusted
                                        ? YamiTheme.accentSecure
                                        : YamiTheme.textSecondary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: YamiTheme.surfaceDark.withValues(alpha: 0.95),
              child: Row(
                children: [
                  const Icon(
                    Icons.security,
                    size: 14,
                    color: YamiTheme.accentSecure,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La moderazione è locale ed effimera per la sessione corrente.',
                      style: YamiTheme.captionStyle.copyWith(
                        fontSize: 10,
                        color: YamiTheme.accentSecure,
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

            Container(height: 1, color: YamiTheme.borderMetallic),
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
                            color: YamiTheme.borderMetallic,
                            width: 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: YamiTheme.bodyStyle,
                          enabled: isPeerOnline && !isBlocked,
                          decoration: InputDecoration(
                            hintText: isBlocked
                                ? 'Impossibile trasmettere a peer bloccato'
                                : (isPeerOnline
                                      ? 'Transmit direct packet...'
                                      : 'Cannot transmit while peer is offline'),
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
                        color: (!isPeerOnline || isBlocked)
                            ? YamiTheme.textMuted.withValues(alpha: 0.1)
                            : (isTrusted
                                  ? YamiTheme.accentSecure
                                  : YamiTheme.accentActive),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_upward,
                          color: (!isPeerOnline || isBlocked)
                              ? YamiTheme.textMuted
                              : YamiTheme.bgDeep,
                          size: 20,
                        ),
                        onPressed: (isPeerOnline && !isBlocked)
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

    final shouldBlur =
        message.isBlurred && !_revealedMessageIds.contains(message.id);

    final glowColor = shouldBlur
        ? YamiTheme.accentWarning
        : (isMe
              ? YamiTheme.accentActive
              : (isTrusted ? YamiTheme.accentSecure : Colors.transparent));

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
              decoration: YamiTheme.tactileDecoration(
                backgroundColor: shouldBlur
                    ? YamiTheme.surfaceDark
                    : (isMe ? YamiTheme.surfaceLight : YamiTheme.surfaceDark),
                opacity: 0.85,
                borderColor: glowColor == Colors.transparent ? YamiTheme.borderMetallic : glowColor,
                borderRadius: 12.0,
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
                            Icons.visibility_off,
                            size: 14,
                            color: YamiTheme.accentWarning.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              message.moderationExplanation != null
                                  ? 'Sensibile: ${message.moderationExplanation} (Tocca per rivelare)'
                                  : 'Contenuto Sensibile (Tocca per rivelare)',
                              style: YamiTheme.captionStyle.copyWith(
                                color: YamiTheme.accentWarning,
                                fontStyle: FontStyle.italic,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(message.content, style: YamiTheme.bodyStyle),
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
                        ? YamiTheme.accentSecure
                        : YamiTheme.textMuted,
                  ),
                ] else ...[
                  Text(
                    message.hopCount == 1 ? '1-HOP P2P' : '${message.hopCount}-HOP MESH',
                    style: YamiTheme.monoStyle.copyWith(
                      fontSize: 7.5,
                      color: message.hopCount == 1 ? YamiTheme.textMuted : YamiTheme.accentActive,
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
