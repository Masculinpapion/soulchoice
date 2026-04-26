import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/message_model.dart';
import '../../../shared/widgets/ambient_background.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String matchId;
  const ChatScreen({super.key, required this.matchId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  // Match meta
  Map<String, dynamic>? _matchInfo;
  String? _currentUid;
  bool _isUser1 = false;

  // Derived from match
  DateTime? _meetingDate;
  DateTime? _archivedAt;
  bool? _myConfirmation;
  bool? _theirConfirmation;

  @override
  void initState() {
    super.initState();
    _currentUid = Supabase.instance.client.auth.currentUser?.id;
    _loadMessages();
    _subscribeRealtime();
    _loadMatchInfo();
  }

  Future<void> _loadMatchInfo() async {
    final client = Supabase.instance.client;
    final matchRow = await client.from('matches').select(
          'user1_id, user2_id, meeting_date, archived_at, '
          'meeting_confirmed_user1, meeting_confirmed_user2, '
          'invitation:invitations(title, venue_name, event_date)',
        ).eq('id', widget.matchId).maybeSingle();
    if (matchRow == null || !mounted) return;

    final user1Id = matchRow['user1_id'] as String;
    _isUser1 = user1Id == _currentUid;
    final otherUserId =
        _isUser1 ? matchRow['user2_id'] as String : user1Id;

    final otherUser = await client
        .from('users')
        .select('name, age')
        .eq('id', otherUserId)
        .maybeSingle();

    final photoRow = await client
        .from('user_photos')
        .select('url')
        .eq('user_id', otherUserId)
        .eq('is_primary', true)
        .maybeSingle();

    if (!mounted) return;

    final meetDate = matchRow['meeting_date'];
    final archDate = matchRow['archived_at'];

    setState(() {
      _matchInfo = {
        'invitation': matchRow['invitation'],
        'other': otherUser,
        'otherUserId': otherUserId,
        'photoUrl': photoRow?['url'],
      };
      _meetingDate = meetDate != null ? DateTime.parse(meetDate) : null;
      _archivedAt = archDate != null ? DateTime.parse(archDate) : null;
      _myConfirmation = _isUser1
          ? matchRow['meeting_confirmed_user1'] as bool?
          : matchRow['meeting_confirmed_user2'] as bool?;
      _theirConfirmation = _isUser1
          ? matchRow['meeting_confirmed_user2'] as bool?
          : matchRow['meeting_confirmed_user1'] as bool?;
    });

    // Auto-archive if meeting was >24h ago and not yet archived
    if (_archivedAt == null &&
        _meetingDate != null &&
        DateTime.now()
            .isAfter(_meetingDate!.add(const Duration(hours: 24)))) {
      await client
          .from('matches')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', widget.matchId);
      if (mounted) setState(() => _archivedAt = DateTime.now());
    }
  }

  Future<void> _loadMessages() async {
    final data = await Supabase.instance.client
        .from('messages')
        .select()
        .eq('match_id', widget.matchId)
        .order('created_at');
    if (!mounted) return;
    setState(() {
      _messages.addAll((data as List).map((r) => MessageModel.fromJson(r)));
      _loading = false;
    });
    _scrollToBottom();
    _markRead();
  }

  Future<void> _markRead() async {
    await Supabase.instance.client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('match_id', widget.matchId)
        .neq('sender_id', _currentUid ?? '')
        .isFilter('read_at', null);
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('chat:${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.matchId,
          ),
          callback: (payload) {
            final newMsg = MessageModel.fromJson(payload.newRecord);
            if (newMsg.senderId != _currentUid && mounted) {
              setState(() => _messages.add(newMsg));
              _scrollToBottom();
              _markRead();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_archivedAt != null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    final optimistic = MessageModel(
      id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      matchId: widget.matchId,
      senderId: _currentUid!,
      content: text,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      await Supabase.instance.client.from('messages').insert({
        'match_id': widget.matchId,
        'sender_id': _currentUid,
        'content': text,
      });
    } catch (e) {
      if (mounted) {
        setState(() =>
            _messages.removeWhere((m) => m.id == optimistic.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gönderilemedi: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Attendance confirmation ────────────────────────────────────────────────

  bool get _showAttendanceBanner {
    if (_meetingDate == null) return false;
    if (_myConfirmation != null) return false;
    return DateTime.now().isAfter(_meetingDate!);
  }

  Future<void> _confirmAttendance(bool attended) async {
    final col = _isUser1
        ? 'meeting_confirmed_user1'
        : 'meeting_confirmed_user2';

    await Supabase.instance.client
        .from('matches')
        .update({col: attended})
        .eq('id', widget.matchId);

    if (!attended) {
      // Increment no-show count for the other user
      final otherUid = _matchInfo?['otherUserId'] as String?;
      if (otherUid != null) {
        await Supabase.instance.client.rpc('increment_no_show', params: {
          'target_user_id': otherUid,
        }).catchError((_) async {
          // Fallback: manual increment
          final row = await Supabase.instance.client
              .from('users')
              .select('no_show_count')
              .eq('id', otherUid)
              .maybeSingle();
          final cur = (row?['no_show_count'] as int?) ?? 0;
          final newCount = cur + 1;
          await Supabase.instance.client.from('users').update({
            'no_show_count': newCount,
            if (newCount >= 2) ...{
              'suspended_at': DateTime.now().toIso8601String(),
              'suspension_reason': '2x no-show',
            },
          }).eq('id', otherUid);
        });
      }
    }

    if (mounted) {
      setState(() => _myConfirmation = attended);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(attended ? 'Teşekkürler! Buluşma kaydedildi.' : 'Bildirim alındı.'),
        backgroundColor: attended ? AppColors.success : AppColors.warning,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _matchInfo?['invitation'] as Map<String, dynamic>?;
    final otherUser = _matchInfo?['other'] as Map<String, dynamic>?;
    final otherName = otherUser?['name'] as String? ?? '—';
    final invTitle = inv?['title'] as String? ?? '';
    final isArchived = _archivedAt != null ||
        (_meetingDate != null &&
            DateTime.now()
                .isAfter(_meetingDate!.add(const Duration(hours: 24))));

    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _ChatAppBar(
          otherName: otherName,
          invTitle: invTitle,
          photoUrl: _matchInfo?['photoUrl'] as String?,
          onBack: () => context.pop(),
        ),
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Event badge — sadece başlık doluysa göster
            if (inv != null && invTitle.isNotEmpty) _EventBadge(title: invTitle),

            // Archived banner
            if (isArchived) const _ArchivedBanner(),

            // "Geldi mi?" banner
            if (_showAttendanceBanner)
              _AttendanceBanner(
                onYes: () => _confirmAttendance(true),
                onNo: () => _confirmAttendance(false),
              ),

            // Messages
            Expanded(
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              AppColors.gradientStart),
                        ),
                      ),
                    )
                  : _messages.isEmpty
                      ? _EmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final msg = _messages[_messages.length - 1 - i];
                            final isMe = msg.senderId == _currentUid;
                            return _MessageBubble(message: msg, isMe: isMe);
                          },
                        ),
            ),

            // Input bar (only when not archived)
            if (!isArchived)
              _InputBar(
                controller: _messageController,
                onSend: _sendMessage,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Archived Banner
// ─────────────────────────────────────────────────────────────────────────────

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textTertiary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 8),
            Text(
              'Bu sohbet arşivlendi',
              style: AppTextStyles.monoSmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Banner
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceBanner extends StatelessWidget {
  final VoidCallback onYes;
  final VoidCallback onNo;
  const _AttendanceBanner({required this.onYes, required this.onNo});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      'Buluşmanız gerçekleşti mi?',
                      style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.warning, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _BannerButton(
                        label: 'Evet, geldik',
                        color: AppColors.success,
                        onTap: onYes,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BannerButton(
                        label: 'Diğer taraf gelmedi',
                        color: AppColors.error,
                        onTap: onNo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
}

class _BannerButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BannerButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium
                .copyWith(color: color, fontSize: 12),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  final String otherName;
  final String invTitle;
  final String? photoUrl;
  final VoidCallback onBack;
  const _ChatAppBar({
    required this.otherName,
    required this.invTitle,
    this.photoUrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AuroraTheme.bgDeep,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: AppColors.textPrimary, size: 20),
                onPressed: onBack,
              ),
              if (photoUrl != null)
                ClipOval(
                  child: Image.network(
                    photoUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _DefaultAvatar(name: otherName),
                  ),
                )
              else
                _DefaultAvatar(name: otherName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(otherName, style: AppTextStyles.titleMedium),
                    if (invTitle.isNotEmpty)
                      Text(
                        invTitle,
                        style: AppTextStyles.monoSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  final String name;
  const _DefaultAvatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Badge
// ─────────────────────────────────────────────────────────────────────────────

class _EventBadge extends StatelessWidget {
  final String title;
  const _EventBadge({required this.title});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gradientStart.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.gradientStart.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.primaryGradient.createShader(b),
                    child: const Icon(Icons.event,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: AppTextStyles.monoSmall.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppColors.primaryGradient.createShader(b),
              child: const Icon(Icons.chat_bubble_outline,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 16),
            Text('İlk mesajı sen gönder!',
                style: AppTextStyles.bodyMedium),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: isMe
              ? _SentBubble(message: message, time: time)
              : _ReceivedBubble(message: message, time: time),
        ),
      ),
    );
  }
}

class _SentBubble extends StatelessWidget {
  final MessageModel message;
  final String time;
  const _SentBubble({required this.message, required this.time});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gradientStart.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.content,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              time,
              style: AppTextStyles.monoSmall
                  .copyWith(color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
      );
}

class _ReceivedBubble extends StatelessWidget {
  final MessageModel message;
  final String time;
  const _ReceivedBubble({required this.message, required this.time});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.glassBgMedium,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.content, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(time, style: AppTextStyles.monoSmall),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Bar
// ─────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
          decoration: const BoxDecoration(
            color: AppColors.glassBg,
            border: Border(top: BorderSide(color: AppColors.glassBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.glassBgMedium,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: TextField(
                    controller: controller,
                    style: AppTextStyles.bodyLarge,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      hintStyle: AppTextStyles.bodyMedium,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gradientStart.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
