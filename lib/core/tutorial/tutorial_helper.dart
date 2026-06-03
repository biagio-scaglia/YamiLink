import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../theme.dart';

class YamiTutorialHelper {
  static void showOnboardingTutorial({
    required BuildContext context,
    required GlobalKey spaceTabKey,
    required GlobalKey chatsTabKey,
    required GlobalKey roomTabKey,
    required GlobalKey diagsTabKey,
    VoidCallback? onFinished,
    VoidCallback? onSkipped,
  }) {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "space_tab",
        keyTarget: spaceTabKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialCard(
                title: "SPACE (RADAR SCANNER)",
                description:
                    "This is your active sensor view. YamiLink scans the local network for other active nodes in range. Nearby peers will appear here dynamically.",
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
                nextText: "NEXT",
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "chats_tab",
        keyTarget: chatsTabKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialCard(
                title: "DIRECT CHATS",
                description:
                    "Tap any nearby peer to open a secure point-to-point direct chat channel. Conversations persist only during the active session and disappear when peers go offline.",
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
                nextText: "NEXT",
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "room_tab",
        keyTarget: roomTabKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialCard(
                title: "ROOM BROADCAST",
                description:
                    "Need to reach everyone nearby? Post messages to the Room chat. All active users on the local network see this public log, which clears when the session ends.",
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
                nextText: "NEXT",
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "diags_tab",
        keyTarget: diagsTabKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialCard(
                title: "DIAGNOSTICS & SYSTEM",
                description:
                    "Monitor real-time network packets, FFI event bridges, frame statistics, and content moderation logs. Perfect for verifying connection health.",
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
                nextText: "FINISH",
              );
            },
          ),
        ],
      ),
    );

    final tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: YamiTheme.bgDeep.withOpacity(0.92),
      onClickTarget: (target) {},
      onClickOverlay: (target) {},
      onFinish: () {
        if (onFinished != null) onFinished();
      },
      onSkip: () {
        if (onSkipped != null) onSkipped();
        return true;
      },
    );

    tutorial.show(context: context);
  }

  static Widget _buildTutorialCard({
    required String title,
    required String description,
    required VoidCallback onNext,
    required VoidCallback onSkip,
    required String nextText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: YamiTheme.glassDecoration(
          backgroundColor: YamiTheme.surfaceDark,
          opacity: 0.95,
          glowColor: YamiTheme.glowActive,
          glowRadius: 10,
          doubleBorder: true,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: YamiTheme.monoStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: YamiTheme.glowActive,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: YamiTheme.bodyStyle.copyWith(
                color: YamiTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    "SKIP TUTORIAL",
                    style: YamiTheme.monoStyle.copyWith(
                      color: YamiTheme.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YamiTheme.glowActive,
                    foregroundColor: YamiTheme.bgDeep,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onNext,
                  child: Text(
                    nextText,
                    style: YamiTheme.monoStyle.copyWith(
                      color: YamiTheme.bgDeep,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void showHelpBottomSheet(
    BuildContext context,
    VoidCallback onRunTutorial,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: YamiTheme.bgDeep,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: const Border(
              top: BorderSide(color: YamiTheme.borderGlass, width: 1.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: YamiTheme.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'HELP & RESOURCES',
                  textAlign: TextAlign.center,
                  style: YamiTheme.monoStyle.copyWith(
                    color: YamiTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 24),

                _buildActionCard(
                  context: context,
                  icon: Icons.explore_outlined,
                  title: 'Interactive Walkthrough',
                  subtitle: 'Start step-by-step navigation highlighting.',
                  onTap: () {
                    Navigator.pop(context);

                    Future.delayed(
                      const Duration(milliseconds: 250),
                      onRunTutorial,
                    );
                  },
                ),
                const SizedBox(height: 12),

                _buildActionCard(
                  context: context,
                  icon: Icons.menu_book_outlined,
                  title: 'Full User Guide',
                  subtitle:
                      'Read details on proximity discovery, sessions, and privacy.',
                  onTap: () {
                    Navigator.pop(context);
                    _showFullUserGuide(context);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        decoration: YamiTheme.glassDecoration(
          backgroundColor: YamiTheme.surfaceDark,
          opacity: 0.8,
          doubleBorder: true,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: YamiTheme.glowActive.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: YamiTheme.glowActive, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: YamiTheme.bodyStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: YamiTheme.captionStyle.copyWith(
                      color: YamiTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: YamiTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static void _showFullUserGuide(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 30,
          ),
          child: Container(
            decoration: YamiTheme.glassDecoration(
              backgroundColor: YamiTheme.bgDeep,
              opacity: 0.95,
              glowColor: YamiTheme.glowActive,
              glowRadius: 16,
              doubleBorder: true,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 12.0, 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'YAMILINK USER GUIDE',
                        style: YamiTheme.monoStyle.copyWith(
                          color: YamiTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: YamiTheme.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: YamiTheme.borderGlass, height: 1),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20.0),
                    children: [
                      _buildGuideSection(
                        '1. What YamiLink Is',
                        'YamiLink is an offline-first, proximity-based communication application. It is designed to let people in the same room, building, or local area communicate directly with each other without relying on a central internet server, internet service provider, or cloud account.',
                      ),
                      _buildGuideSection(
                        '2. How Nearby Discovery Works',
                        'YamiLink uses your device\'s local network capabilities (such as Wi-Fi or local network discovery) to find other devices running YamiLink nearby.\n\n• When you open the app, it periodically broadcasts a beacon to detect other active devices.\n• You do not need to pair devices, register phone numbers, or exchange email addresses.\n• Any active user within your physical range will automatically appear on your screen as a nearby peer.',
                      ),
                      _buildGuideSection(
                        '3. What a Session Means',
                        'Communication in YamiLink is session-based. A session is a temporary period of activity that begins when you open the app and join the local network, and ends when you close the app or disconnect.\n\n• No permanent accounts: There are no global profiles. Your alias and avatar are generated when you start a session.\n• Local-only data: Your chat history is stored entirely in your device\'s temporary memory (RAM) and local database cache. It is never uploaded to a cloud database.\n• Ephemeral history: When a session is terminated or when you manually clear your session, the message history is deleted.',
                      ),
                      _buildGuideSection(
                        '4. How to Start a Conversation',
                        'Once you discover a peer in the nearby list:\n\n1. Tap their profile alias on the SPACE radar screen to view their details.\n2. Select "Message" to initiate a direct chat.\n3. This will create a conversation entry in your dedicated CHATS tab.\n4. You can navigate back to the conversations tab at any time to resume active chats.',
                      ),
                      _buildGuideSection(
                        '5. How Room Chat Works',
                        'The room chat is a local broadcast channel:\n\n• Every message sent to the room is visible to all active users on the same local network.\n• Think of it as a public bulletin board for the physical room you are in.\n• Like direct messages, room chats are ephemeral and only persist during the active session.',
                      ),
                      _buildGuideSection(
                        '6. Privacy and Temporary Identity',
                        'YamiLink is designed with a privacy-first architecture:\n\n• Anonymity: You choose a temporary display name (alias) when joining a session.\n• Zero Tracking: There are no cookies, trackers, or centralized logging of your conversations.\n• Direct Moderation: If a user is sending unwanted messages or spam, you can mute or block them locally. Blocked peers are immediately hidden from your radar and cannot message you again during the session.',
                      ),
                      _buildGuideSection(
                        '7. Disappearances & Offline Status',
                        'Because the app relies on physical proximity:\n\n• If a peer walks out of range, closes their app, or turns off their device, they will show as offline in your chats.\n• If a peer is inactive for more than 10 seconds, their signal status will fade. If they remain inactive for over 15 seconds, they will be swept from the active list.\n• If they return, they will reconnect under their current session identity, and you can resume the conversation.',
                      ),
                      _buildGuideSection(
                        '8. Tips for Best Use',
                        '• Keep Wi-Fi Active: Ensure your device\'s Wi-Fi or local network permission is enabled, even if you are not connected to the internet.\n• Stay in Range: For stable connections, remain within the same local network subnet or wireless coverage area.\n• Manage Distractions: Use the manual block or temporary mute controls (10 seconds, 30 seconds, or 1 minute) if a peer is sending repetitive messages.',
                      ),
                      _buildGuideSection(
                        '9. Current Limitations',
                        '• Physical Proximity Required: You cannot message users who are in a different city or on a different network.\n• No Offline Delivery: Messages cannot be delivered while a peer is disconnected. If a peer is offline, outgoing messages will wait in queue and attempt to send once they return, but will fail if the session is closed before delivery.\n• No Cloud Backups: Deleted sessions or messages cannot be recovered.',
                      ),
                      _buildGuideSection(
                        '10. Frequently Asked Questions (FAQ)',
                        'Q: Do I need cellular data or internet to use YamiLink?\nA: No. YamiLink operates entirely over local networks. You do not need active cellular data or an internet connection.\n\nQ: Are my messages encrypted?\nA: Messages are transmitted directly over the local network protocol. While they bypass the public internet, they are readable by other nodes on the same local network. Avoid sharing sensitive personal information like passwords or financial data.\n\nQ: Where is my chat history saved?\nA: Your chat history is saved locally on your device. Once you close the app or reset your session, the data is permanently erased.',
                      ),
                    ],
                  ),
                ),
                const Divider(color: YamiTheme.borderGlass, height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: YamiTheme.glowActive,
                        foregroundColor: YamiTheme.bgDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'DISMISS',
                        style: YamiTheme.monoStyle.copyWith(
                          color: YamiTheme.bgDeep,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildGuideSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: YamiTheme.monoStyle.copyWith(
              color: YamiTheme.glowActive,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: YamiTheme.bodyStyle.copyWith(
              color: YamiTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
