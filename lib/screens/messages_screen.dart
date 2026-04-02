import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/zu_theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/services.dart';

// ══════════════════════════════════════════════
//  LISTE DES CONVERSATIONS
// ══════════════════════════════════════════════

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(conversationsProvider);
    final uid   = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      backgroundColor: ZuTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZuTheme.bgPrimary,
        title: Text('Messages', style: GoogleFonts.syne(fontWeight: FontWeight.w800)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: ZuTheme.borderColor),
        ),
      ),
      body: convs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (_, __) => const Center(child: Text('Impossible de charger les messages.')),
        data: (list) {
          if (list.isEmpty) {
            return ZuEmptyState(
              emoji: '💬',
              title: 'Aucun message',
              subtitle: 'Tes conversations avec les joueurs et tes matchs apparaîtront ici.',
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => Divider(
              height: 1, indent: 72, color: ZuTheme.borderColor,
            ),
            itemBuilder: (_, i) => _ConvTile(conv: list[i], myUid: uid),
          );
        },
      ),
    );
  }
}

// ── Tuile de conversation ────────────────────────────────────────

class _ConvTile extends ConsumerWidget {
  final ZuConversation conv;
  final String myUid;

  const _ConvTile({required this.conv, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread      = conv.unreadFor(myUid);
    final isDM        = conv.type == ConversationType.direct;
    final otherUid    = isDM
        ? conv.participantIds.firstWhere((id) => id != myUid, orElse: () => '')
        : '';
    final otherPlayer = isDM && otherUid.isNotEmpty
        ? ref.watch(playerMiniProvider(otherUid)).valueOrNull
        : null;

    final title = isDM
        ? (otherPlayer != null
            ? '${otherPlayer.firstName} ${otherPlayer.lastName}'.trim()
            : '...')
        : (conv.matchClub ?? 'Match');

    final subtitle = conv.lastMessage.isEmpty
        ? 'Nouveau groupe créé'
        : conv.lastMessage;

    final timeStr = _formatTime(conv.lastMessageAt);

    return InkWell(
      onTap: () => context.push('/messages/${conv.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                isDM
                    ? ZuAvatar(
                        photoUrl: otherPlayer?.photoUrl,
                        initials: otherPlayer?.initials ?? '?',
                        size: 48,
                        bgColor: ZuTheme.playerColors[0],
                      )
                    : _GroupAvatar(count: conv.participantIds.length),
                if (unread > 0)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: ZuTheme.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: ZuTheme.bgPrimary, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: GoogleFonts.syne(fontSize: 8, fontWeight: FontWeight.w800, color: ZuTheme.bgPrimary),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.syne(
                            fontSize: 14,
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                            color: ZuTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: unread > 0 ? ZuTheme.accent : ZuTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: unread > 0 ? ZuTheme.textSecondary : ZuTheme.textMuted,
                      fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Indicateur type match
            if (!isDM) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: ZuTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🎾',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)   return 'maintenant';
    if (diff.inHours   < 1)   return 'il y a ${diff.inMinutes} min';
    if (diff.inDays    < 1)   return DateFormat('HH:mm').format(dt);
    if (diff.inDays    < 7)   return DateFormat('EEE', 'fr_FR').format(dt);
    return DateFormat('d MMM', 'fr_FR').format(dt);
  }
}

// Avatar pour conversations de groupe
class _GroupAvatar extends StatelessWidget {
  final int count;
  const _GroupAvatar({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ZuTheme.cardGradient,
        border: Border.all(color: ZuTheme.borderColor),
      ),
      child: Center(
        child: Text(
          '🎾',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  ÉCRAN DE CONVERSATION
// ══════════════════════════════════════════════

class ConversationScreen extends ConsumerStatefulWidget {
  final String convId;
  const ConversationScreen({super.key, required this.convId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending     = false;

  @override
  void initState() {
    super.initState();
    // Marque comme lu à l'ouverture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        ref.read(messagingServiceProvider).markAsRead(widget.convId, uid);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid  = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final conv = ref.read(conversationsProvider).valueOrNull
        ?.firstWhere((c) => c.id == widget.convId, orElse: () => throw Exception());

    setState(() => _sending = true);
    _ctrl.clear();

    try {
      await ref.read(messagingServiceProvider).sendMessage(
        convId:         widget.convId,
        senderId:       uid,
        text:           text,
        participantIds: conv?.participantIds ?? [uid],
      );
      // Scroll to bottom
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'envoyer le message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid      = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final convs    = ref.watch(conversationsProvider).valueOrNull ?? [];
    final conv     = convs.where((c) => c.id == widget.convId).firstOrNull;
    final messages = ref.watch(messagesProvider(widget.convId));

    // Titre de la conv
    String title = '...';
    if (conv != null) {
      if (conv.type == ConversationType.direct) {
        final otherUid = conv.participantIds.firstWhere(
          (id) => id != uid, orElse: () => '');
        final other = otherUid.isNotEmpty
            ? ref.watch(playerMiniProvider(otherUid)).valueOrNull
            : null;
        title = other != null
            ? '${other.firstName} ${other.lastName}'.trim()
            : '...';
      } else {
        title = conv.matchClub ?? 'Match';
      }
    }

    return Scaffold(
      backgroundColor: ZuTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZuTheme.bgPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            if (conv != null && conv.type == ConversationType.match)
              Text(
                '${conv.participantIds.length} joueurs',
                style: GoogleFonts.dmSans(fontSize: 11, color: ZuTheme.textMuted),
              ),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: ZuTheme.borderColor),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (_, __) => const Center(child: Text('Erreur de chargement.')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Dis bonjour ! 👋',
                        style: GoogleFonts.dmSans(fontSize: 14, color: ZuTheme.textMuted),
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final msg   = list[i];
                    final isMe  = msg.senderId == uid;
                    final prev  = i > 0 ? list[i - 1] : null;
                    final showSender = !isMe &&
                        conv?.type == ConversationType.match &&
                        (prev == null || prev.senderId != msg.senderId);

                    return _MessageBubble(
                      message:    msg,
                      isMe:       isMe,
                      showSender: showSender,
                    );
                  },
                );
              },
            ),
          ),

          // Barre de saisie
          _InputBar(
            ctrl:     _ctrl,
            sending:  _sending,
            onSend:   _send,
          ),
        ],
      ),
    );
  }
}

// ── Bulle de message ─────────────────────────────────────────────

class _MessageBubble extends ConsumerWidget {
  final ZuMessage message;
  final bool isMe;
  final bool showSender;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Message système
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.dmSans(fontSize: 12, color: ZuTheme.textMuted),
            ),
          ),
        ),
      );
    }

    // Prénom expéditeur (groupe)
    Widget? senderLabel;
    if (showSender) {
      final mini = ref.watch(playerMiniProvider(message.senderId)).valueOrNull;
      senderLabel = Padding(
        padding: const EdgeInsets.only(bottom: 3, left: 44),
        child: Text(
          mini?.firstName ?? '...',
          style: GoogleFonts.syne(fontSize: 11, fontWeight: FontWeight.w700, color: ZuTheme.textSecondary),
        ),
      );
    }

    // Avatar expéditeur
    Widget? avatar;
    if (!isMe) {
      final mini = ref.watch(playerMiniProvider(message.senderId)).valueOrNull;
      avatar = Padding(
        padding: const EdgeInsets.only(right: 8, top: 2),
        child: ZuAvatar(
          photoUrl: mini?.photoUrl,
          initials: mini?.initials ?? '?',
          size: 32,
          bgColor: ZuTheme.playerColors[message.senderId.hashCode.abs() % ZuTheme.playerColors.length],
        ),
      );
    }

    final bubbleColor = isMe
        ? ZuTheme.accent.withOpacity(0.18)
        : ZuTheme.bgCard;

    final borderColor = isMe
        ? ZuTheme.accent.withOpacity(0.4)
        : ZuTheme.borderColor;

    final radius = BorderRadius.only(
      topLeft:     const Radius.circular(16),
      topRight:    const Radius.circular(16),
      bottomLeft:  Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (senderLabel != null) senderLabel,
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && avatar != null) avatar,
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:        bubbleColor,
                    borderRadius: radius,
                    border:       Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        message.text,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: ZuTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: GoogleFonts.dmSans(fontSize: 10, color: ZuTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Barre de saisie ──────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({required this.ctrl, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZuTheme.bgSurface,
        border: Border(top: BorderSide(color: ZuTheme.borderColor)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, 10, 16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: GoogleFonts.dmSans(fontSize: 14, color: ZuTheme.textPrimary),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: GoogleFonts.dmSans(color: ZuTheme.textMuted),
                filled: true,
                fillColor: ZuTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: ZuTheme.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: ZuTheme.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: ZuTheme.accent, width: 1.5)),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: ZuTheme.accent.withOpacity(sending ? 0.5 : 1.0),
                shape: BoxShape.circle,
              ),
              child: sending
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: ZuTheme.bgPrimary,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: ZuTheme.bgPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
