import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/message_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../features/profile/providers/profile_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

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
  bool _loadingMore = false;
  bool _hasMore = true;
  static const _pageSize = 50;
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
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _subscribeRealtime();
    _loadMatchInfo();
  }

  Future<void> _loadMatchInfo() async {
    final client = Supabase.instance.client;
    final matchRow = await client.from('matches').select(
          'user1_id, user2_id, meeting_date, archived_at, '
          'meeting_confirmed_user1, meeting_confirmed_user2, '
          'invitation:invitations(id, title, venue_name, event_date)',
        ).eq('id', widget.matchId).maybeSingle();
    if (matchRow == null || !mounted) return;

    final user1Id = matchRow['user1_id'] as String;
    _isUser1 = user1Id == _currentUid;
    final otherUserId =
        _isUser1 ? matchRow['user2_id'] as String : user1Id;

    final results = await Future.wait([
      client.from('users').select('name, age').eq('id', otherUserId).maybeSingle(),
      client.from('user_photos').select('url').eq('user_id', otherUserId).eq('is_primary', true).maybeSingle(),
    ]);
    final otherUser = results[0] as Map<String, dynamic>?;
    final photoRow  = results[1] as Map<String, dynamic>?;

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

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        _hasMore && !_loadingMore && !_loading) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMessages() async {
    final data = await Supabase.instance.client
        .from('messages')
        .select()
        .eq('match_id', widget.matchId)
        .order('created_at', ascending: false)
        .limit(_pageSize);
    if (!mounted) return;
    final msgs = (data as List)
        .map((r) => MessageModel.fromJson(r))
        .toList()
        .reversed
        .toList();
    setState(() {
      _messages.addAll(msgs);
      _hasMore = data.length == _pageSize;
      _loading = false;
    });
    _scrollToBottom();
    _markRead();
  }

  Future<void> _loadMoreMessages() async {
    if (_messages.isEmpty || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final oldest = _messages.first.createdAt;
    final data = await Supabase.instance.client
        .from('messages')
        .select()
        .eq('match_id', widget.matchId)
        .lt('created_at', oldest.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(_pageSize);
    if (!mounted) return;
    final older = (data as List)
        .map((r) => MessageModel.fromJson(r))
        .toList()
        .reversed
        .toList();
    setState(() {
      _messages.insertAll(0, older);
      _hasMore = data.length == _pageSize;
      _loadingMore = false;
    });
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
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.matchId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final updated = MessageModel.fromJson(payload.newRecord);
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == updated.id);
              if (idx != -1) _messages[idx] = updated;
            });
          },
        )
        .subscribe();
  }

  String _currentUserGender() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return 'other';
    final profile = ref.read(userProfileProvider(uid)).valueOrNull;
    return profile?['gender'] as String? ?? 'other';
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      _channel!.unsubscribe();
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_archivedAt != null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUid == null) return;
    _messageController.clear();

    final rng = Random.secure();
    final tmpId = 'tmp_${List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final optimistic = MessageModel(
      id: tmpId,
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

      // Karşı tarafa push bildirim gönder
      final otherUserId = _matchInfo?['otherUserId'] as String?;
      final myName = (await Supabase.instance.client
          .from('users').select('name').eq('id', _currentUid!).maybeSingle())?['name'] as String? ?? '';
      if (otherUserId != null) {
        Supabase.instance.client.functions.invoke('send-notification', body: {
          'user_id': otherUserId,
          'title': '💬 $myName',
          'body': text.length > 60 ? '${text.substring(0, 60)}...' : text,
          'data': {'type': 'new_message', 'match_id': widget.matchId},
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _messages.removeWhere((m) => m.id == optimistic.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.chat_send_error(e.toString())),
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
        content: Text(attended ? AppLocalizations.of(context)!.chat_meeting_saved : AppLocalizations.of(context)!.chat_noted),
        backgroundColor: attended ? AppColors.success : AppColors.warning,
      ));
    }
  }

  Future<void> _deleteChat() async {
    try {
      await Supabase.instance.client
          .from('matches')
          .delete()
          .eq('id', widget.matchId);
      if (mounted) context.go('/messages');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.chat_send_error(e.toString())),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _block() async {
    final otherUid = _matchInfo?['otherUserId'] as String?;
    if (otherUid == null || _currentUid == null) return;
    final inv = _matchInfo?['invitation'] as Map<String, dynamic>?;
    final invitationId = inv?['id'] as String?;
    final client = Supabase.instance.client;
    try {
      await Future.wait([
        client.from('blocks').upsert({
          'blocker_id': _currentUid,
          'blocked_id': otherUid,
        }, onConflict: 'blocker_id,blocked_id'),
        client.from('matches').delete().eq('id', widget.matchId),
      ]);
    } catch (_) {}
    if (!mounted) return;
    if (invitationId != null) {
      context.go('/invitation/$invitationId/applicants');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _matchInfo?['invitation'] as Map<String, dynamic>?;
    final otherUser = _matchInfo?['other'] as Map<String, dynamic>?;
    final otherName = otherUser?['name'] as String? ?? '—';
    final otherAge = (otherUser?['age'] as int?) ?? 0;
    final invTitle = inv?['title'] as String? ?? '';
    final invVenue = inv?['venue_name'] as String? ?? '';
    final rawDate = inv?['event_date'] as String?;
    final invDate = rawDate != null ? DateTime.tryParse(rawDate) : null;
    final isArchived = _archivedAt != null ||
        (_meetingDate != null &&
            DateTime.now()
                .isAfter(_meetingDate!.add(const Duration(hours: 24))));

    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: Column(
          children: [
            _ChatAppBar(
              otherName: otherName,
              otherAge: otherAge,
              photoUrl: _matchInfo?['photoUrl'] as String?,
              otherUserId: _matchInfo?['otherUserId'] as String?,
              isLoading: _matchInfo == null,
              onBack: () => context.pop(),
              onBlock: _block,
              onDelete: _deleteChat,
            ),
            // Event badge — davet bilgisi özeti
            if (invTitle.isNotEmpty)
              _EventBadge(title: invTitle, venue: invVenue, eventDate: invDate),

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
                          itemCount: _messages.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (_loadingMore && i == _messages.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.red),
                                  ),
                                ),
                              );
                            }
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
              AppLocalizations.of(context)!.chat_archived,
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
                      AppLocalizations.of(context)!.chat_meeting_question,
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
                        label: AppLocalizations.of(context)!.chat_yes_we_met,
                        color: AppColors.success,
                        onTap: onYes,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BannerButton(
                        label: AppLocalizations.of(context)!.chat_other_no_show,
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
  final int otherAge;
  final String? photoUrl;
  final String? otherUserId;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback? onBlock;
  final VoidCallback? onDelete;
  const _ChatAppBar({
    required this.otherName,
    required this.otherAge,
    this.photoUrl,
    this.otherUserId,
    this.isLoading = false,
    required this.onBack,
    this.onBlock,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: onBack,
              ),
              // Avatar + isim — tıklanınca profile git
              Expanded(
               child: GestureDetector(
                onTap: otherUserId != null
                    ? () => context.push('/profile/$otherUserId')
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AuroraTheme.auroraRed, AuroraTheme.auroraViolet, AuroraTheme.auroraBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AuroraTheme.bgDeep, width: 1.5),
                        ),
                        child: isLoading
                            ? Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : ClipOval(
                                child: photoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: photoUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => _DefaultAvatar(name: otherName),
                                      )
                                    : _DefaultAvatar(name: otherName),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLoading)
                          Container(
                            width: 80,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        else ...[
                          Text(
                            otherName,
                            style: const TextStyle(
                              fontFamily: 'Fraunces',
                              fontStyle: FontStyle.italic,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (otherAge > 0)
                            Text(
                              AppLocalizations.of(context)!.chat_other_age(otherAge),
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.50),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              )),
              if (onBlock != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: const Color(0xFF14121E),
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.black54,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    if (val == 'delete') {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF14121E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(
                            AppLocalizations.of(context)!.chat_delete_conversation,
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                          content: Text(
                            AppLocalizations.of(context)!.chat_delete_confirm_body,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(AppLocalizations.of(context)!.btn_cancel,
                                  style: TextStyle(fontFamily: 'JetBrainsMono', color: Colors.white54)),
                            ),
                            TextButton(
                              onPressed: () { Navigator.pop(ctx); onDelete!(); },
                              child: Text(AppLocalizations.of(context)!.btn_delete,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ],
                        ),
                      );
                    } else if (val == 'block') {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF14121E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(
                            AppLocalizations.of(context)!.chat_block_and_close,
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                          content: Text(
                            AppLocalizations.of(context)!.chat_block_confirm_body(_currentUserGender()),
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(AppLocalizations.of(context)!.btn_cancel,
                                  style: TextStyle(fontFamily: 'JetBrainsMono', color: Colors.white54)),
                            ),
                            TextButton(
                              onPressed: () { Navigator.pop(ctx); onBlock!(); },
                              child: Text(AppLocalizations.of(context)!.chat_block,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    color: AuroraTheme.auroraRed,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, color: Colors.white.withOpacity(0.6), size: 18),
                          const SizedBox(width: 10),
                          Text(AppLocalizations.of(context)!.chat_delete_conversation,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              )),
                        ]),
                      ),
                    if (onBlock != null)
                      PopupMenuItem(
                        value: 'block',
                        child: Row(children: [
                          const Icon(Icons.block, color: AuroraTheme.auroraRed, size: 18),
                          const SizedBox(width: 10),
                          Text(AppLocalizations.of(context)!.chat_block_and_close,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              )),
                        ]),
                      ),
                  ],
                ),
            ],
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
  final String venue;
  final DateTime? eventDate;
  const _EventBadge({required this.title, this.venue = '', this.eventDate});

  String get _label {
    final parts = <String>[title];
    if (venue.isNotEmpty) parts.add(venue.toUpperCase());
    if (eventDate != null) {
      final h = eventDate!.hour.toString().padLeft(2, '0');
      final m = eventDate!.minute.toString().padLeft(2, '0');
      parts.add('$h:$m');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AuroraTheme.auroraRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AuroraTheme.auroraRed.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => AuroraTheme.redBlueGradient.createShader(b),
              child: const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                _label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white60,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
            Text(AppLocalizations.of(context)!.chat_empty_hint,
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AuroraTheme.bgDeep.withOpacity(0.0),
            AuroraTheme.bgDeep,
          ],
          stops: const [0.0, 0.38],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 24, 16, MediaQuery.of(context).padding.bottom + 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.chat_input_hint,
                    hintStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.35),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) => onSend(),
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
        );
  }
}

class _BlockSheet extends StatelessWidget {
  final VoidCallback onBlock;
  const _BlockSheet({required this.onBlock});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            border: Border(
              top: BorderSide(color: AuroraTheme.glassBorder, width: 0.5),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Seçenek: Engelle
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _BlockConfirmSheet(onBlock: onBlock),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AuroraTheme.auroraRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AuroraTheme.auroraRed.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.block, color: AuroraTheme.auroraRed, size: 20),
                    const SizedBox(width: 14),
                    Text(
                      AppLocalizations.of(context)!.chat_block_and_close,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AuroraTheme.auroraRed,
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              // İptal
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Text(
                    AppLocalizations.of(context)!.btn_cancel,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
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

class _BlockConfirmSheet extends StatelessWidget {
  final VoidCallback onBlock;
  const _BlockConfirmSheet({required this.onBlock});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            border: Border(
              top: BorderSide(color: AuroraTheme.glassBorder, width: 0.5),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                AppLocalizations.of(context)!.chat_block_and_close,
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.chat_block_confirm_body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AuroraTheme.auroraRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AuroraTheme.auroraRed.withOpacity(0.4)),
                  ),
                  child: TextButton(
                    onPressed: () { Navigator.pop(context); onBlock(); },
                    child: const Text(
                      'Evet, engelle',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AuroraTheme.auroraRed,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context)!.btn_cancel,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.4),
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
