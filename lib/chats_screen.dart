import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DIRECT CHATS',
              style: YamiTheme.monoStyle.copyWith(
                fontSize: 13,
                color: YamiTheme.textPrimary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'EPHEMERAL POINT-TO-POINT CHANNELS',
              style: YamiTheme.captionStyle.copyWith(
                fontSize: 8,
                color: YamiTheme.glowActive,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: YamiTheme.bgDeep,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline,
              color: YamiTheme.textSecondary,
              size: 24,
            ),
            onPressed: () {
              YamiTutorialHelper.showHelpBottomSheet(context, onRunTutorial);
            },
            tooltip: 'Help',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: YamiTheme.borderGlass, height: 1.0),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: YamiTheme.ambientBackgroundGradient(),
        ),
        child: conversations.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                itemCount: conversations.length,
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

                  return _buildConversationTile(
                    context,
                    conv,
                    livePeer,
                    isTrusted,
                    repository,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: YamiTheme.glassDecoration(
                backgroundColor: YamiTheme.surfaceDark.withOpacity(0.4),
                glowColor: YamiTheme.glowActive,
                glowRadius: 10,
                borderRadius: 50,
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: YamiTheme.glowActive,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SECURE P2P SPACE',
              style: YamiTheme.monoStyle.copyWith(
                fontSize: 14,
                color: YamiTheme.textPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No direct connection records in the current session.\nTap a nearby node in the SPACE radar tab to open a private encrypted channel.',
              textAlign: TextAlign.center,
              style: YamiTheme.captionStyle.copyWith(
                fontSize: 11,
                color: YamiTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    Conversation conv,
    Peer peer,
    bool isTrusted,
    YamiLinkRepository repository,
  ) {
    final String timeStr =
        '${conv.lastTimestamp.hour.toString().padLeft(2, '0')}:${conv.lastTimestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<YamiLinkRepository>.value(
                value: repository,
                child: DirectChatScreen(peer: peer),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: YamiTheme.glassDecoration(
            backgroundColor: YamiTheme.surfaceDark,
            glowColor: conv.unreadCount > 0
                ? YamiTheme.glowActive
                : (isTrusted ? YamiTheme.glowSecure : Colors.transparent),
            glowRadius: conv.unreadCount > 0 ? 3.0 : (isTrusted ? 2.0 : 0.0),
            doubleBorder: true,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  YamiAvatar(
                    seed: conv.peerAvatarSeed,
                    size: 46,
                    glowColor: isTrusted
                        ? YamiTheme.glowSecure
                        : YamiTheme.glowActive,
                    isGlowing: isTrusted,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: conv.isPeerOnline
                            ? YamiTheme.glowSecure
                            : YamiTheme.textMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: YamiTheme.bgDeep, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          conv.peerAlias,
                          style: YamiTheme.bodyStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (isTrusted) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            color: YamiTheme.glowSecure,
                            size: 13,
                          ),
                        ],
                        if (!conv.isPeerOnline) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: YamiTheme.textMuted.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: YamiTheme.textMuted.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'OFFLINE',
                              style: YamiTheme.monoStyle.copyWith(
                                fontSize: 6.5,
                                color: YamiTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      conv.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YamiTheme.captionStyle.copyWith(
                        color: conv.unreadCount > 0
                            ? YamiTheme.textPrimary
                            : YamiTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: YamiTheme.monoStyle.copyWith(
                      color: YamiTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (conv.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: YamiTheme.glowActive,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: YamiTheme.glowActive.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Center(
                        child: Text(
                          '${conv.unreadCount}',
                          style: YamiTheme.monoStyle.copyWith(
                            color: YamiTheme.bgDeep,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
