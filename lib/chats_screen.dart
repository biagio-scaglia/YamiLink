import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'theme.dart';
import 'repository/yamilink_repository.dart';
import 'widgets/avatar.dart';
import 'direct_chat_screen.dart';
import 'core/tutorial/tutorial_helper.dart';

class ChatsScreen extends StatelessWidget {
  final VoidCallback onRunTutorial;
  const ChatsScreen({super.key, required this.onRunTutorial});

  @override
  Widget build(BuildContext context) {
    final repository = Provider.of<YamiLinkRepository>(context);
    final conversations = repository.conversations;

    return Scaffold(
      backgroundColor: YamiTheme.bgDeep,
      appBar: _buildAppBar(context),
      body: Container(
        decoration: BoxDecoration(gradient: YamiTheme.ambientGradient),
        child: conversations.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: YamiTheme.spaceMd,
                  horizontal: YamiTheme.spaceMd,
                ),
                itemCount: conversations.length,
                separatorBuilder: (context, index) => const SizedBox(height: YamiTheme.spaceSm),
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  final livePeer = repository.peers.firstWhere(
                    (p) => p.id == conv.peerId,
                    orElse: () => Peer(
                      id: conv.peerId,
                      alias: conv.peerAlias,
                      avatarSeed: conv.peerAvatarSeed,
                      trustLevel: TrustLevel.unverified,
                      lastSeen: conv.lastTimestamp,
                    ),
                  );
                  final isTrusted = livePeer.trustLevel == TrustLevel.paired;
                  return _ConversationTile(
                    conv: conv,
                    peer: livePeer,
                    isTrusted: isTrusted,
                    repository: repository,
                  );
                },
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: YamiTheme.bgDeep,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Direct Chats', style: YamiTheme.headingStyle),
          Text(
            'Encrypted point-to-point',
            style: YamiTheme.headingSubStyle,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () => YamiTutorialHelper.showHelpBottomSheet(
            context, onRunTutorial,
          ),
          tooltip: 'Help',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: YamiTheme.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EmptyStateIcon(),
            const SizedBox(height: YamiTheme.spaceLg),
            Text(
              'No conversations yet',
              style: YamiTheme.headingStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: YamiTheme.spaceSm),
            Text(
              'Find nearby users in the Space tab and open a private encrypted channel.',
              textAlign: TextAlign.center,
              style: YamiTheme.bodySmallStyle.copyWith(
                color: YamiTheme.textSub,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state icon con animazione respiro
// ---------------------------------------------------------------------------
class _EmptyStateIcon extends StatefulWidget {
  @override
  State<_EmptyStateIcon> createState() => _EmptyStateIconState();
}

class _EmptyStateIconState extends State<_EmptyStateIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: YamiTheme.surfaceBase,
          shape: BoxShape.circle,
          border: Border.all(color: YamiTheme.borderMid, width: 1.0),
          boxShadow: YamiTheme.shadowMid,
        ),
        child: const Icon(
          Icons.chat_bubble_outline_rounded,
          size: 32,
          color: YamiTheme.textSub,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation tile
// ---------------------------------------------------------------------------
class _ConversationTile extends StatefulWidget {
  final Conversation conv;
  final Peer peer;
  final bool isTrusted;
  final YamiLinkRepository repository;

  const _ConversationTile({
    required this.conv,
    required this.peer,
    required this.isTrusted,
    required this.repository,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final conv = widget.conv;
    final isTrusted = widget.isTrusted;
    final hasUnread = conv.unreadCount > 0;

    final String timeStr =
        '${conv.lastTimestamp.hour.toString().padLeft(2, '0')}:${conv.lastTimestamp.minute.toString().padLeft(2, '0')}';

    Color borderColor = YamiTheme.borderMid;
    if (hasUnread) {
      borderColor = YamiTheme.accentWine;
    } else if (isTrusted) {
      borderColor = YamiTheme.accentBrass.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, secondaryAnimation) =>
                ChangeNotifierProvider<YamiLinkRepository>.value(
              value: widget.repository,
              child: DirectChatScreen(peer: widget.peer),
            ),
            transitionDuration: YamiTheme.motionNormal,
            transitionsBuilder: (_, anim, secondaryAnimation, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: child,
            ),
          ),
        );
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: YamiTheme.motionFast,
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: YamiTheme.spaceMd,
            vertical: YamiTheme.spaceMd,
          ),
          decoration: YamiTheme.surfaceCard(borderColor: borderColor),
          child: Row(
            children: [
              // Avatar + online dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  YamiAvatar(
                    seed: conv.peerAvatarSeed,
                    size: 48,
                    glowColor: isTrusted
                        ? YamiTheme.accentBrass
                        : YamiTheme.accentWine,
                    isGlowing: isTrusted,
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: _OnlineDot(isOnline: conv.isPeerOnline),
                  ),
                ],
              ),
              const SizedBox(width: YamiTheme.spaceMd),

              // Contenuto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome + trust badge + offline tag
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.peerAlias,
                            style: YamiTheme.bodyStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: YamiTheme.textBright,
                              fontSize: 15,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isTrusted) ...[
                          const SizedBox(width: YamiTheme.spaceXs),
                          const Icon(
                            Icons.verified_rounded,
                            color: YamiTheme.accentBrass,
                            size: 14,
                          ),
                        ],
                        if (!conv.isPeerOnline) ...[
                          const SizedBox(width: YamiTheme.spaceSm),
                          _StatusTag(label: 'Offline', color: YamiTheme.textGhost),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Preview messaggio
                    Text(
                      conv.lastMessage.isEmpty ? 'No messages yet' : conv.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YamiTheme.bodySmallStyle.copyWith(
                        color: hasUnread ? YamiTheme.textBody : YamiTheme.textSub,
                        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: YamiTheme.spaceSm),

              // Timestamp + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: YamiTheme.captionStyle.copyWith(
                      color: hasUnread ? YamiTheme.accentWine : YamiTheme.textGhost,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: YamiTheme.spaceSm),
                  if (hasUnread)
                    _UnreadBadge(count: conv.unreadCount)
                  else
                    const SizedBox(width: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineDot extends StatefulWidget {
  final bool isOnline;
  const _OnlineDot({required this.isOnline});

  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOnline ? YamiTheme.accentBrass : YamiTheme.textGhost;
    return widget.isOnline
        ? AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => _dot(color.withValues(alpha: _pulse.value)),
          )
        : _dot(color);
  }

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: YamiTheme.bgDeep, width: 1.5),
        ),
      );
}

class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(YamiTheme.radiusSharp),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: YamiTheme.accentWine,
        borderRadius: BorderRadius.circular(YamiTheme.radiusPill),
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: YamiTheme.textBright,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
