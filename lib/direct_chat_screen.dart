import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _DirectChatScreenState extends State<DirectChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  YamiLinkRepository? _repository;
  final Set<String> _revealedMessageIds = {};
  bool _hasText = false;
  late AnimationController _sendBtnCtrl;
  late Animation<double> _sendBtnScale;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);

    _sendBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _sendBtnScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _sendBtnCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(YamiLinkRepository repo) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();

    final decision = await repo.sendDirectMessage(widget.peer.id, text);
    if (!mounted) return;

    if (decision != null) {
      if (decision.action == ModerationAction.block) {
        _showModerationDialog(
          title: 'Message blocked',
          body: 'Your message violates local guidelines:\n\n${decision.explanation}',
          isWarn: false,
          repo: repo,
          text: text,
        );
        return;
      }
      if (decision.action == ModerationAction.warn) {
        _showModerationDialog(
          title: 'Sensitive content',
          body: 'Your message contains sensitive words:\n\n${decision.explanation}\n\nSend anyway?',
          isWarn: true,
          repo: repo,
          text: text,
        );
        return;
      }
    }

    Future.delayed(const Duration(milliseconds: 80), () => _scrollToBottom());
  }

  void _showModerationDialog({
    required String title,
    required String body,
    required bool isWarn,
    required YamiLinkRepository repo,
    required String text,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body, style: YamiTheme.bodySmallStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isWarn ? 'Cancel' : 'OK',
                style: YamiTheme.labelStyle.copyWith(color: YamiTheme.textSub)),
          ),
          if (isWarn)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                repo.sendDirectMessage(widget.peer.id, text, force: true);
                Future.delayed(
                  const Duration(milliseconds: 80),
                  () => _scrollToBottom(),
                );
              },
              child: Text('Send anyway',
                  style: YamiTheme.labelStyle.copyWith(color: YamiTheme.accentEmber)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _repository?.setActiveConversation(null);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendBtnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<YamiLinkRepository>(context);
    final isBlocked = repo.isPeerBlocked(widget.peer.id);
    final isMuted = repo.isPeerMuted(widget.peer.id);

    final livePeer = repo.peers.firstWhere(
      (p) => p.id == widget.peer.id,
      orElse: () => widget.peer,
    );
    final isTrusted = livePeer.trustLevel == TrustLevel.paired;

    final conv = repo.conversations.firstWhere(
      (c) => c.peerId == livePeer.id,
      orElse: () => Conversation(
        id: livePeer.id,
        peerId: livePeer.id,
        peerAlias: livePeer.alias,
        peerAvatarSeed: livePeer.avatarSeed,
        lastMessage: '',
        lastTimestamp: DateTime.now(),
        messages: repo.getDirectMessages(livePeer.id),
        isPeerOnline: !isBlocked,
      ),
    );
    final isPeerOnline = conv.isPeerOnline && !isBlocked;
    final messages = conv.messages;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: YamiTheme.bgDeep,
      appBar: _buildAppBar(repo, livePeer, isTrusted, isBlocked, isMuted, isPeerOnline),
      body: Container(
        decoration: BoxDecoration(gradient: YamiTheme.ambientGradient),
        child: Column(
          children: [
            // Banner di stato
            _StatusBanner(
              isTrusted: isTrusted,
              isPeerOnline: isPeerOnline,
              isBlocked: isBlocked,
              isMuted: isMuted,
            ),

            // Lista messaggi
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyChat(livePeer.alias)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: YamiTheme.spaceMd,
                        vertical: YamiTheme.spaceMd,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = messages[i];
                        final isMe = msg.senderId == repo.profile.id;
                        return _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          isTrusted: isTrusted,
                          isRevealed: _revealedMessageIds.contains(msg.id),
                          onReveal: () => setState(
                            () => _revealedMessageIds.add(msg.id),
                          ),
                        );
                      },
                    ),
            ),

            // Composer
            _buildComposer(repo, isPeerOnline, isBlocked, isTrusted),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    YamiLinkRepository repo,
    Peer livePeer,
    bool isTrusted,
    bool isBlocked,
    bool isMuted,
    bool isPeerOnline,
  ) {
    return AppBar(
      backgroundColor: YamiTheme.bgDeep,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.pop(context),
        color: YamiTheme.textBody,
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          YamiAvatar(
            seed: livePeer.avatarSeed,
            size: 34,
            glowColor: isTrusted ? YamiTheme.accentBrass : YamiTheme.accentWine,
            isGlowing: isTrusted,
          ),
          const SizedBox(width: YamiTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        livePeer.alias,
                        style: YamiTheme.headingStyle.copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isTrusted) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          color: YamiTheme.accentBrass, size: 13),
                    ],
                  ],
                ),
                Text(
                  isBlocked
                      ? 'Blocked'
                      : isMuted
                          ? 'Muted'
                          : !isPeerOnline
                              ? 'Offline'
                              : isTrusted
                                  ? 'Encrypted · Verified'
                                  : 'Unverified channel',
                  style: YamiTheme.captionStyle.copyWith(
                    color: isBlocked || isMuted
                        ? YamiTheme.accentEmber
                        : !isPeerOnline
                            ? YamiTheme.textGhost
                            : isTrusted
                                ? YamiTheme.accentBrass
                                : YamiTheme.textSub,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Mute
        IconButton(
          icon: Icon(
            isMuted ? Icons.volume_off_rounded : Icons.volume_up_outlined,
            size: 20,
          ),
          color: isMuted ? YamiTheme.accentEmber : YamiTheme.textSub,
          onPressed: () => isMuted
              ? _unmute(repo, livePeer)
              : _showMuteSheet(repo, livePeer),
          tooltip: isMuted ? 'Unmute' : 'Mute',
        ),
        // Block
        IconButton(
          icon: Icon(
            isBlocked ? Icons.block_rounded : Icons.block_outlined,
            size: 20,
          ),
          color: isBlocked ? YamiTheme.accentEmber : YamiTheme.textSub,
          onPressed: () => isBlocked
              ? _unblock(repo, livePeer)
              : _block(repo, livePeer),
          tooltip: isBlocked ? 'Unblock' : 'Block',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _unmute(YamiLinkRepository repo, Peer peer) {
    repo.unmutePeer(peer.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${peer.alias} unmuted')),
    );
  }

  void _unblock(YamiLinkRepository repo, Peer peer) {
    repo.unblockPeer(peer.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${peer.alias} unblocked')),
    );
  }

  void _block(YamiLinkRepository repo, Peer peer) {
    repo.blockPeer(peer.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${peer.alias} blocked')),
    );
    Navigator.pop(context);
  }

  void _showMuteSheet(YamiLinkRepository repo, Peer peer) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _MuteSheet(
        peerAlias: peer.alias,
        onMute: (duration) {
          repo.mutePeer(peer.id, duration);
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${peer.alias} muted')),
          );
        },
      ),
    );
  }

  Widget _buildEmptyChat(String alias) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(YamiTheme.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 36, color: YamiTheme.textGhost),
            const SizedBox(height: YamiTheme.spaceMd),
            Text(
              'This channel is empty',
              style: YamiTheme.headingStyle.copyWith(
                fontSize: 16,
                color: YamiTheme.textBody,
              ),
            ),
            const SizedBox(height: YamiTheme.spaceSm),
            Text(
              'Messages to $alias are end-to-end encrypted and ephemeral.',
              textAlign: TextAlign.center,
              style: YamiTheme.captionStyle.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(
    YamiLinkRepository repo,
    bool isPeerOnline,
    bool isBlocked,
    bool isTrusted,
  ) {
    final canSend = isPeerOnline && !isBlocked;
    return Container(
      decoration: const BoxDecoration(
        color: YamiTheme.surfaceBase,
        border: Border(top: BorderSide(color: YamiTheme.borderFaint, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: YamiTheme.spaceMd,
            vertical: YamiTheme.spaceSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Campo testo
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    style: YamiTheme.bodyStyle.copyWith(
                      color: YamiTheme.textBright,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    maxLines: null,
                    enabled: canSend,
                    decoration: InputDecoration(
                      hintText: isBlocked
                          ? 'Peer is blocked'
                          : !isPeerOnline
                              ? 'Peer is offline'
                              : isTrusted
                                  ? 'Encrypted message…'
                                  : 'Message…',
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
                    onSubmitted: canSend ? (_) => _sendMessage(repo) : null,
                  ),
                ),
              ),

              // Bottone invio
              const SizedBox(width: YamiTheme.spaceSm),
              GestureDetector(
                onTapDown: canSend && _hasText ? (_) => _sendBtnCtrl.forward() : null,
                onTapUp: canSend && _hasText
                    ? (_) {
                        _sendBtnCtrl.reverse();
                        _sendMessage(repo);
                      }
                    : null,
                onTapCancel: () => _sendBtnCtrl.reverse(),
                child: ScaleTransition(
                  scale: _sendBtnScale,
                  child: AnimatedContainer(
                    duration: YamiTheme.motionNormal,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: canSend && _hasText
                          ? YamiTheme.accentWine
                          : YamiTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
                      border: Border.all(
                        color: canSend && _hasText
                            ? YamiTheme.accentWine
                            : YamiTheme.borderMid,
                      ),
                      boxShadow: canSend && _hasText
                          ? [
                              BoxShadow(
                                color: YamiTheme.accentWine.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: canSend && _hasText
                          ? YamiTheme.textBright
                          : YamiTheme.textGhost,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Banner
// ---------------------------------------------------------------------------
class _StatusBanner extends StatelessWidget {
  final bool isTrusted;
  final bool isPeerOnline;
  final bool isBlocked;
  final bool isMuted;

  const _StatusBanner({
    required this.isTrusted,
    required this.isPeerOnline,
    required this.isBlocked,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String text;
    final Color color;

    if (isBlocked) {
      icon = Icons.block_rounded;
      text = 'This peer is blocked. No messages will be sent or received.';
      color = YamiTheme.accentEmber;
    } else if (isMuted) {
      icon = Icons.volume_off_rounded;
      text = 'This peer is muted for this session.';
      color = YamiTheme.accentEmber;
    } else if (!isPeerOnline) {
      icon = Icons.cloud_off_rounded;
      text = 'Peer offline. Messages will queue and deliver when they return.';
      color = YamiTheme.textGhost;
    } else if (isTrusted) {
      icon = Icons.lock_rounded;
      text = 'End-to-end encrypted. Session keys verified.';
      color = YamiTheme.accentBrass;
    } else {
      icon = Icons.lock_open_rounded;
      text = 'Unverified. Use Verify Pairing in the Space tab to encrypt.';
      color = YamiTheme.textSub;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: YamiTheme.spaceMd,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: YamiTheme.spaceSm),
          Expanded(
            child: Text(
              text,
              style: YamiTheme.captionStyle.copyWith(
                color: color.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message Bubble
// ---------------------------------------------------------------------------
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isTrusted;
  final bool isRevealed;
  final VoidCallback onReveal;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isTrusted,
    required this.isRevealed,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final shouldBlur = message.isBlurred && !isRevealed;
    final timeStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    // Colori bolla
    final Color bubbleBg;
    final Color bubbleBorder;
    if (shouldBlur) {
      bubbleBg = YamiTheme.surfaceBase;
      bubbleBorder = YamiTheme.accentEmber.withValues(alpha: 0.5);
    } else if (isMe) {
      bubbleBg = YamiTheme.accentWine.withValues(alpha: 0.18);
      bubbleBorder = YamiTheme.accentWine.withValues(alpha: 0.35);
    } else {
      bubbleBg = YamiTheme.surfaceRaised;
      bubbleBorder = YamiTheme.borderMid;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: YamiTheme.spaceSm),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isMe ? 14 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 14),
                  ),
                  border: Border.all(color: bubbleBorder, width: 1.0),
                  boxShadow: YamiTheme.shadowLow,
                ),
                child: shouldBlur
                    ? GestureDetector(
                        onTap: onReveal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
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
            ),

            // Meta riga
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: YamiTheme.captionStyle.copyWith(
                    fontSize: 10,
                    color: YamiTheme.textGhost,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.delivered
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 12,
                    color: message.status == MessageStatus.delivered
                        ? YamiTheme.accentBrass
                        : YamiTheme.textGhost,
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  Text(
                    message.hopCount == 1 ? '· direct' : '· ${message.hopCount}-hop',
                    style: YamiTheme.captionStyle.copyWith(
                      fontSize: 10,
                      color: message.hopCount == 1
                          ? YamiTheme.textGhost
                          : YamiTheme.accentWine,
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

// ---------------------------------------------------------------------------
// Mute Bottom Sheet
// ---------------------------------------------------------------------------
class _MuteSheet extends StatelessWidget {
  final String peerAlias;
  final void Function(Duration) onMute;

  const _MuteSheet({required this.peerAlias, required this.onMute});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        YamiTheme.spaceMd,
        YamiTheme.spaceMd,
        YamiTheme.spaceMd,
        YamiTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: YamiTheme.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: YamiTheme.spaceLg),
          Text(
            'Mute $peerAlias',
            style: YamiTheme.headingStyle,
          ),
          const SizedBox(height: 4),
          Text(
            'Incoming messages will be silenced.',
            style: YamiTheme.captionStyle,
          ),
          const SizedBox(height: YamiTheme.spaceMd),
          ...[
            ('10 seconds', const Duration(seconds: 10)),
            ('30 seconds', const Duration(seconds: 30)),
            ('1 minute', const Duration(minutes: 1)),
            ('5 minutes', const Duration(minutes: 5)),
          ].map((e) => _MuteOption(label: e.$1, onTap: () => onMute(e.$2))),
        ],
      ),
    );
  }
}

class _MuteOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MuteOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(YamiTheme.radiusSoft),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: YamiTheme.spaceMd,
          vertical: 14,
        ),
        margin: const EdgeInsets.only(bottom: YamiTheme.spaceXs),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: YamiTheme.borderFaint, width: 1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: YamiTheme.textSub),
            const SizedBox(width: YamiTheme.spaceMd),
            Text(label, style: YamiTheme.bodyStyle.copyWith(fontSize: 15)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: YamiTheme.textGhost),
          ],
        ),
      ),
    );
  }
}
