import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/guard_errors.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/message_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../features/profile/providers/profile_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/services/photo_focus.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String matchId;

  // initialPartner: mesaj listesinin ZATEN bildiği isim/yaş/foto — başlık
  // sunucu cevabını beklemeden anında dolu açılsın diye elden geçirilir
  // (13.07 fix: boş daire + iskelet flaşı).
  final Map<String, dynamic>? initialPartner;
  const ChatScreen({super.key, required this.matchId, this.initialPartner});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _loading = true;
  bool _loadError = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  static const _pageSize = 50;
  RealtimeChannel? _channel;

  // Match meta
  Map<String, dynamic>? _matchInfo;
  String? _currentUid;
  bool _isUser1 = false;
  // Karşı taraf hesabını silmiş (matches.user*_id SET NULL) — yazma kapalı
  bool _otherDeleted = false;
  // Hediye ürün linki — yalnız seçilen kişiye + moderasyon onaylı (get_gift_link)
  String? _giftUrl;
  // Tarihsiz gift buluşma anketi için: gift match'te meeting_date null olabilir
  bool _isGiftMatch = false;
  DateTime? _matchCreatedAt;

  // Derived from match
  DateTime? _meetingDate;
  bool? _myConfirmation;
  bool? _theirConfirmation;

  // Timezone offsets — gönderenin seçtiği şehir saatine göre mesaj zamanı
  int? _myUtcOffset;
  int? _otherUtcOffset;

  @override
  void initState() {
    super.initState();
    _currentUid = Supabase.instance.client.auth.currentUser?.id;
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _subscribeRealtime();
    _loadMatchInfo();
    _loadGiftLink();
    // 24.07: cinsiyetli RU metinleri — provider soğukken 'other'a (eril)
    // düşüyordu (Natalia dialog vakası); cinsiyet bir kez yüklenip saklanır.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyGender());
  }

  String _myGender = 'other';

  Future<void> _loadMyGender() async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final profile = await ref.read(userProfileProvider(uid).future);
      final g = profile?['gender'] as String?;
      if (mounted && g != null) setState(() => _myGender = g);
    } catch (_) {}
  }

  // Hediye linki: yalnız match tarafı + moderasyon onaylı ise döner (RPC).
  Future<void> _loadGiftLink() async {
    try {
      final gl = await Supabase.instance.client
          .rpc('get_gift_link', params: {'p_match_id': widget.matchId});
      if (gl is String && gl.isNotEmpty && mounted) {
        setState(() => _giftUrl = gl);
      }
    } catch (_) {}
  }

  Future<void> _loadMatchInfo() async {
    final client = Supabase.instance.client;
    try {
      final matchRow = await client.from('matches').select(
            'user1_id, user2_id, meeting_date, created_at, '
            'meeting_confirmed_user1, meeting_confirmed_user2, '
            'invitation:invitations(id, title, venue_name, event_date, category)',
          ).eq('id', widget.matchId).maybeSingle();
      if (matchRow == null || !mounted) {
        if (mounted) setState(() => _matchInfo = {});
        return;
      }

      final user1Id = matchRow['user1_id'] as String?;
      _isUser1 = user1Id == _currentUid;
      final otherUserId =
          _isUser1 ? matchRow['user2_id'] as String? : user1Id;

      Map<String, dynamic>? otherUser;
      Map<String, dynamic>? myUser;
      String? photoUrl;
      try {
        final results = await Future.wait<dynamic>([
          if (otherUserId != null)
            client.from('users').select('name, age, gender, city:cities(utc_offset)').eq('id', otherUserId).maybeSingle()
          else
            Future.value(null),
          client.from('users').select('city:cities(utc_offset)').eq('id', _currentUid as Object).maybeSingle(),
        ]);
        otherUser = results[0] as Map<String, dynamic>?;
        myUser = results[1] as Map<String, dynamic>?;
      } catch (_) {}
      if (otherUserId != null) {
        try {
          final photoRows = await client
              .from('user_photos')
              .select('url')
              .eq('user_id', otherUserId)
              .eq('is_primary', true)
              .eq('is_selfie', false)
              .limit(1);
          if (photoRows is List && photoRows.isNotEmpty) {
            photoUrl = (photoRows.first as Map<String, dynamic>)['url'] as String?;
          }
        } catch (_) {}
      }

      if (!mounted) return;

      final meetDate = matchRow['meeting_date'];
      final matchCreated = matchRow['created_at'];
      final invMap = matchRow['invitation'] as Map<String, dynamic>?;
      final isGift = invMap?['category'] == 'gift';

      final otherCity = otherUser?['city'] as Map<String, dynamic>?;
      final myCity = myUser?['city'] as Map<String, dynamic>?;

      setState(() {
        _otherDeleted = otherUserId == null;
        _isGiftMatch = isGift;
        _matchCreatedAt =
            matchCreated != null ? DateTime.tryParse(matchCreated) : null;
        _matchInfo = {
          'invitation': matchRow['invitation'],
          'other': otherUser,
          'otherUserId': otherUserId,
          'photoUrl': photoUrl,
        };
        _meetingDate = meetDate != null ? DateTime.parse(meetDate) : null;
        _myConfirmation = _isUser1
            ? matchRow['meeting_confirmed_user1'] as bool?
            : matchRow['meeting_confirmed_user2'] as bool?;
        _theirConfirmation = _isUser1
            ? matchRow['meeting_confirmed_user2'] as bool?
            : matchRow['meeting_confirmed_user1'] as bool?;
        _myUtcOffset = (myCity?['utc_offset'] as num?)?.toInt();
        _otherUtcOffset = (otherCity?['utc_offset'] as num?)?.toInt();
      });
    } catch (_) {
      if (mounted) setState(() => _matchInfo = {});
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
    // 24.07 denetim: hatasız try'da spinner sonsuza kalıyordu — hata durumu + retry
    try {
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
        _loadError = false;
      });
      _scrollToBottom();
      _markRead();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
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
    // sender_id silinmiş kullanıcıda NULL — neq NULL satırı atlar, or ile kapsa
    await Supabase.instance.client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('match_id', widget.matchId)
        .or('sender_id.neq.${_currentUid ?? ''},sender_id.is.null')
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

  void _showAuroraSnack(String message,
      {required Color accentColor, required IconData icon}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      backgroundColor: AuroraTheme.bgDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withOpacity(0.4)),
      ),
      content: Row(
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ));
  }

  String _currentUserGender() => _myGender;

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
    if (_otherDeleted) return;
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
        // Mesaj İÇERİĞİ push'a konmaz (kilit ekranı gizliliği, 15.07 kararı);
        // metin sunucu şablonundan alıcının dilinde üretilir.
        Supabase.instance.client.functions.invoke('send-notification', body: {
          'user_id': otherUserId,
          'title': '💬 $myName',
          'body': 'Новое сообщение',
          'data': {'type': 'new_message', 'match_id': widget.matchId},
          'template': {'name': myName},
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _messages.removeWhere((m) => m.id == optimistic.id));
        // Bilinen guard hatası (örn. ACCOUNT_SUSPENDED) lokalize gösterilir
        final guard = GuardError.from(context, e);
        if (guard != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => guard.navigate(context));
        }
        _showAuroraSnack(
          guard?.message ??
              AppLocalizations.of(context)!.chat_send_error(AppLocalizations.of(context)!.error_generic),
          accentColor: AuroraTheme.auroraRed,
          icon: Icons.error_outline,
        );
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
    if (_myConfirmation != null) return false;
    // Tarihli buluşma: saatinden sonra
    if (_meetingDate != null) return DateTime.now().isAfter(_meetingDate!);
    // Tarihsiz hediye buluşması: eşleşmeden (kabul) 24 saat sonra anket çıkar —
    // gift ilanında tarih opsiyonel olduğundan meeting_date olmayabilir, ama
    // no-show yine izlenebilmeli.
    if (_isGiftMatch && _matchCreatedAt != null) {
      return DateTime.now()
          .isAfter(_matchCreatedAt!.add(const Duration(hours: 24)));
    }
    return false;
  }

  Future<void> _confirmAttendance(bool attended) async {
    // Tek RPC: kendi teyidini yazar + "gelmedi" ise karşı tarafın no-show'unu
    // güvenle artırır (gift ağırlıklı, 2x-suspend). Eski app-side fallback users
    // RLS'ine takılıyordu — hiç çalışmıyordu.
    try {
      await Supabase.instance.client.rpc('confirm_meeting', params: {
        'p_match_id': widget.matchId,
        'p_attended': attended,
      });
    } catch (_) {}

    if (mounted) {
      setState(() => _myConfirmation = attended);
      _showAuroraSnack(
        attended
            ? AppLocalizations.of(context)!.chat_meeting_saved
            : AppLocalizations.of(context)!.chat_noted,
        accentColor: attended ? AuroraTheme.auroraBlue : AuroraTheme.auroraGold,
        icon: attended ? Icons.check_circle_outline : Icons.info_outline,
      );
    }
  }

  // Tek-taraflı gizleme (WhatsApp standardı): match SİLİNMEZ, yalnız benim
  // listemden kalkar; karşı taraf sohbeti aynen görür; yeni mesajla geri döner.
  Future<void> _hideChat() async {
    try {
      await Supabase.instance.client
          .rpc('hide_chat', params: {'p_match_id': widget.matchId});
      if (mounted) context.go('/messages');
    } catch (e) {
      if (mounted) {
        _showAuroraSnack(
          AppLocalizations.of(context)!.chat_send_error(AppLocalizations.of(context)!.error_generic),
          accentColor: AuroraTheme.auroraRed,
          icon: Icons.error_outline,
        );
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
    } catch (_) {
      // 24.07 denetim: engelleme başarısızsa "engellendi" gibi çıkıp gitme
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.error_generic)));
      }
      return;
    }
    if (!mounted) return;
    if (invitationId != null) {
      context.go('/invitation/$invitationId/applicants');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(photoFocusProvider); // yüz odak haritası — gelince rebuild
    final inv = _matchInfo?['invitation'] as Map<String, dynamic>?;
    final otherUser = _matchInfo?['other'] as Map<String, dynamic>?;
    final initial = widget.initialPartner;
    final otherName = _otherDeleted
        ? AppLocalizations.of(context)!.chat_deleted_user
        : otherUser?['name'] as String? ?? initial?['name'] as String? ?? '—';
    final otherAge =
        (otherUser?['age'] as int?) ?? (initial?['age'] as int?) ?? 0;
    final invTitle = inv?['title'] as String? ?? '';
    final invVenue = inv?['venue_name'] as String? ?? '';
    final rawDate = inv?['event_date'] as String?;
    final invDate = rawDate != null ? DateTime.tryParse(rawDate) : null;
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: Column(
          children: [
            _ChatAppBar(
              otherName: otherName,
              otherAge: otherAge,
              photoUrl: _matchInfo?['photoUrl'] as String? ??
                  initial?['photoUrl'] as String?,
              otherUserId: _matchInfo?['otherUserId'] as String?,
              isLoading: _matchInfo == null && initial == null,
              onBack: () => context.pop(),
              onBlock: _block,
              onHide: _hideChat,
              currentUserGender: _currentUserGender(),
            ),
            // Event badge — davet bilgisi özeti
            if (invTitle.isNotEmpty)
              _EventBadge(title: invTitle, venue: invVenue, eventDate: invDate),

            // Hediye linki kartı — yalnız seçilen kişide görünür (get_gift_link)
            if (_giftUrl != null) _GiftLinkCard(url: _giftUrl!),

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
                              AuroraTheme.auroraRed),
                        ),
                      ),
                    )
                  : _loadError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(AppLocalizations.of(context)!.error_generic,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _loadError = false;
                                  });
                                  _loadMessages();
                                },
                                child: Text(AppLocalizations.of(context)!
                                    .inv_detail_retry),
                              ),
                            ],
                          ),
                        )
                  : _messages.isEmpty
                      ? _EmptyState(
                          welcomeText: (_matchInfo != null &&
                                  !_isUser1 &&
                                  !_otherDeleted)
                              ? AppLocalizations.of(context)!
                                  .chat_selected_welcome(
                                    otherName,
                                    ((_matchInfo?['other']
                                                as Map<String, dynamic>?)?[
                                            'gender'] as String?) ??
                                        'other',
                                  )
                              : null,
                        )
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
                                        color: AuroraTheme.auroraRed),
                                  ),
                                ),
                              );
                            }
                            final msg = _messages[_messages.length - 1 - i];
                            final isMe = msg.senderId == _currentUid;
                            final senderOffset = isMe ? _myUtcOffset : _otherUtcOffset;
                            return _MessageBubble(message: msg, isMe: isMe, senderUtcOffset: senderOffset);
                          },
                        ),
            ),

            // Input bar (partner hesabı durdukça hep açık — sohbetler kalıcı)
            if (_otherDeleted)
              const _DeletedUserBanner()
            else
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
// Deleted User Banner — input bar yerine gösterilir, yazma kapalı
// ─────────────────────────────────────────────────────────────────────────────

class _DeletedUserBanner extends StatelessWidget {
  const _DeletedUserBanner();

  @override
  Widget build(BuildContext context) => Container(
        // _InputBar ile aynı sistem-alt-boşluğu kalıbı — nav bar altına taşmasın
        margin: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.of(context).padding.bottom + 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.person_off_outlined,
                size: 16, color: AuroraTheme.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.chat_deleted_user_info,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  color: AuroraTheme.textSecondary,
                  letterSpacing: 0.25,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Gift Link Card — hediye ürün linki (yalnız seçilen kişide, onaylı)
// ─────────────────────────────────────────────────────────────────────────────

class _GiftLinkCard extends StatelessWidget {
  final String url;
  const _GiftLinkCard({required this.url});

  bool get _isLink =>
      RegExp(r'^https?://', caseSensitive: false).hasMatch(url);

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Link ise host + "görüntüle" + tıklanır; düz metin ise ürün adı, tıklanmaz
    final subtitle =
        _isLink ? (Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url) : url;
    final label =
        _isLink ? l10n.chat_gift_link_label : l10n.chat_gift_text_label;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AuroraTheme.auroraGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuroraTheme.auroraGold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: AuroraTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_isLink)
            Icon(Icons.open_in_new_rounded,
                size: 16, color: AuroraTheme.auroraGold),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isLink
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _open,
                    borderRadius: BorderRadius.circular(14),
                    child: card,
                  ),
                )
              : card,
          // Hukuki + güven: satın alma app dışında, sorumluluk kullanıcılarda
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              AppLocalizations.of(context)!.chat_gift_disclaimer,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10.5,
                height: 1.4,
                color: AuroraTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
                color: AuroraTheme.auroraGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AuroraTheme.auroraGold.withOpacity(0.4)),
              ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline,
                        size: 16, color: AuroraTheme.auroraGold),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.chat_meeting_question,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AuroraTheme.auroraGold,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _BannerButton(
                        label: AppLocalizations.of(context)!.chat_yes_we_met,
                        color: AuroraTheme.auroraBlue,
                        onTap: onYes,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BannerButton(
                        label: AppLocalizations.of(context)!.chat_other_no_show,
                        color: AuroraTheme.auroraRed,
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
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: color,
              letterSpacing: 0.05,
            ),
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
  final VoidCallback? onHide;
  final String currentUserGender;
  const _ChatAppBar({
    required this.otherName,
    required this.otherAge,
    this.photoUrl,
    this.otherUserId,
    this.isLoading = false,
    required this.onBack,
    this.onBlock,
    this.onHide,
    this.currentUserGender = 'other',
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
                                        // Liste avatarıyla aynı memCacheWidth → aynı
                                        // decode cache'i, başlık girişte hazır.
                                        memCacheWidth: 156,
                                        fadeInDuration: const Duration(milliseconds: 150),
                                        placeholder: (_, __) => _DefaultAvatar(name: otherName),
                                        alignment: PhotoFocus.of(photoUrl, fallback: Alignment.center),
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
                    if (val == 'hide') {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF14121E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(
                            AppLocalizations.of(context)!.chat_hide_conversation,
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                          content: Text(
                            AppLocalizations.of(context)!.chat_hide_confirm_body,
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
                              onPressed: () { Navigator.pop(ctx); onHide!(); },
                              child: Text(AppLocalizations.of(context)!.chat_hide,
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
                            AppLocalizations.of(context)!.chat_block_confirm_body(currentUserGender),
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
                    if (onHide != null)
                      PopupMenuItem(
                        value: 'hide',
                        child: Row(children: [
                          Icon(Icons.visibility_off_outlined, color: Colors.white.withOpacity(0.6), size: 18),
                          const SizedBox(width: 10),
                          Text(AppLocalizations.of(context)!.chat_hide_conversation,
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
          gradient: AuroraTheme.redBlueGradient,
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
  // Seçilen taraf (user2) için karşılama: "{isim} seni seçti — ..."
  // Seçen taraf ve bilinmeyen durumda genel ipucu gösterilir.
  final String? welcomeText;
  const _EmptyState({this.welcomeText});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AuroraTheme.redBlueGradient.createShader(b),
                child: Icon(
                    welcomeText != null
                        ? Icons.celebration_outlined
                        : Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 44),
              ),
              const SizedBox(height: 16),
              if (welcomeText != null) ...[
                Text(welcomeText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.5,
                    )),
                const SizedBox(height: 8),
              ],
              Text(AppLocalizations.of(context)!.chat_empty_hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: AuroraTheme.textSecondary,
                    height: 1.5,
                  )),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final int? senderUtcOffset;
  const _MessageBubble({required this.message, required this.isMe, this.senderUtcOffset});

  @override
  Widget build(BuildContext context) {
    // Mesaj saati: gönderenin seçtiği şehrin TZ'sine göre.
    // city.utc_offset bilinmiyorsa fallback olarak cihaz local saati.
    final DateTime shown = senderUtcOffset != null
        ? message.createdAt.toUtc().add(Duration(hours: senderUtcOffset!))
        : message.createdAt.toLocal();
    final time =
        '${shown.hour.toString().padLeft(2, '0')}:${shown.minute.toString().padLeft(2, '0')}';

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

/// Salt-emoji mesajlar büyük gösterilir. Manrope'ta emoji glifi yok;
/// iOS'ta fallback emoji 16pt'te minicik kalıyordu — emoji-only balonlarda
/// fontFamily verilmez (platform emoji fontu) ve boyut büyütülür.
bool _isEmojiOnly(String s) {
  final t = s.trim();
  if (t.isEmpty || t.runes.length > 12) return false;
  final re = RegExp(
    r'^(?:\p{Extended_Pictographic}|[\u{1F1E6}-\u{1F1FF}\u{1F3FB}-\u{1F3FF}\u{200D}\u{FE0F}\s])+$',
    unicode: true,
  );
  return re.hasMatch(t);
}

TextStyle _bubbleTextStyle(String content) {
  if (!_isEmojiOnly(content)) {
    return const TextStyle(
      fontFamily: 'Manrope',
      fontSize: 16,
      color: AuroraTheme.textPrimary,
      height: 1.6,
    );
  }
  // Emoji sayısına göre kademeli boyut (WhatsApp benzeri): tek emoji en
  // büyük, kalabalık dizi normale yaklaşır — göze hoş oran.
  final n = RegExp(r'\p{Extended_Pictographic}', unicode: true)
      .allMatches(content)
      .length;
  final size = n <= 1 ? 30.0 : (n <= 3 ? 26.0 : 20.0);
  return TextStyle(fontSize: size, height: 1.25);
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
          gradient: AuroraTheme.redBlueGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AuroraTheme.auroraRed.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.content, style: _bubbleTextStyle(message.content)),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: Colors.white.withOpacity(0.6),
                letterSpacing: 0.25,
              ),
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
              color: AuroraTheme.glassStrong,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: AuroraTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.content, style: _bubbleTextStyle(message.content)),
                const SizedBox(height: 4),
                Text(time,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AuroraTheme.textMuted,
                      letterSpacing: 0.25,
                    )),
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
                    gradient: AuroraTheme.redBlueGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AuroraTheme.auroraRed.withOpacity(0.35),
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
  final String currentUserGender;
  const _BlockSheet({required this.onBlock, this.currentUserGender = 'other'});

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
                    builder: (_) => _BlockConfirmSheet(onBlock: onBlock, currentUserGender: currentUserGender),
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
  final String currentUserGender;
  const _BlockConfirmSheet({required this.onBlock, this.currentUserGender = 'other'});

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
                AppLocalizations.of(context)!.chat_block_confirm_body(currentUserGender),
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
