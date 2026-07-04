import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AuroraTheme.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.admin_title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AuroraTheme.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
          ),
          labelColor: AuroraTheme.auroraRed,
          unselectedLabelColor: AuroraTheme.textMuted,
          indicatorColor: AuroraTheme.auroraRed,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.admin_tab_selfies),
            Tab(text: AppLocalizations.of(context)!.admin_tab_reports),
          ],
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          top: false,
          child: TabBarView(
            controller: _tabController,
            children: const [
              _PendingSelfiestTab(),
              _ReportsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Selfies Tab
// ─────────────────────────────────────────────────────────────────────────────

class _PendingSelfiestTab extends StatefulWidget {
  const _PendingSelfiestTab();

  @override
  State<_PendingSelfiestTab> createState() => _PendingSelfiestTabState();
}

class _PendingSelfiestTabState extends State<_PendingSelfiestTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  List<String> _rejectReasons(AppLocalizations l) => [
    l.admin_reject_reason_no_face,
    l.admin_reject_reason_inappropriate,
    l.admin_reject_reason_mismatch,
    l.admin_reject_reason_quality,
    l.admin_reject_reason_other,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('users')
        .select(
            'id, name, age, selfie_status, photos:user_photos(url, is_primary, is_selfie, order_index)')
        .eq('selfie_status', 'pending')
        .order('created_at');
    if (mounted) {
      setState(() {
        _users = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    }
  }

  Future<void> _approve(String userId) async {
    await Supabase.instance.client.from('users').update({
      'selfie_status': 'approved',
    }).eq('id', userId);
    _load();
  }

  Future<void> _showRejectDialog(String userId) async {
    final l = AppLocalizations.of(context)!;
    final reasons = _rejectReasons(l);
    int? selectedReason;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AuroraTheme.bgDeep,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l.admin_reject_reason_title,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AuroraTheme.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.asMap().entries.map((e) {
              return RadioListTile<int>(
                value: e.key,
                groupValue: selectedReason,
                onChanged: (v) => setSt(() => selectedReason = v),
                title: Text(
                  e.value,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: AuroraTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                activeColor: AuroraTheme.auroraRed,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.admin_btn_cancel,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                  color: AuroraTheme.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await Supabase.instance.client.from('users').update({
                        'selfie_status': 'rejected',
                        'selfie_rejected_reason': reasons[selectedReason!],
                      }).eq('id', userId);
                      _load();
                    },
              child: Text(
                l.admin_btn_reject,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                  color: AuroraTheme.auroraRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AuroraTheme.auroraRed),
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF10B981), size: 48),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.admin_selfies_empty,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AuroraTheme.auroraRed,
      backgroundColor: AuroraTheme.glassBg,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final u = _users[i];
          final photos = (u['photos'] as List<dynamic>?) ?? [];
          final profilePhoto = photos
              .cast<Map<String, dynamic>>()
              .where((p) => p['is_selfie'] == false)
              .toList()
            ..sort((a, b) => (a['order_index'] as int? ?? 99)
                .compareTo(b['order_index'] as int? ?? 99));
          final selfiePhoto = photos
              .cast<Map<String, dynamic>>()
              .where((p) => p['is_selfie'] == true)
              .toList();

          final profileUrl =
              profilePhoto.firstOrNull?['url'] as String?;
          final selfieUrl = selfiePhoto.firstOrNull?['url'] as String?;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Text(
                        '${u['name']}, ${u['age']}',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AuroraTheme.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/profile/${u['id']}'),
                        child: Text(
                          AppLocalizations.of(context)!.admin_view_profile,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.25,
                            color: AuroraTheme.auroraRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Photos
                  Row(
                    children: [
                      Expanded(
                        child: _PhotoBox(
                          url: profileUrl,
                          label: AppLocalizations.of(context)!.admin_photo_label_profile,
                          isSelfie: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PhotoBox(
                          url: selfieUrl,
                          label: AppLocalizations.of(context)!.admin_photo_label_selfie,
                          isSelfie: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _approve(u['id'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.5)),
                            ),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.admin_btn_approve,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.05,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              _showRejectDialog(u['id'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: AuroraTheme.auroraRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AuroraTheme.auroraRed.withOpacity(0.5)),
                            ),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.admin_btn_reject_action,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.05,
                                  color: AuroraTheme.auroraRed,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String? url;
  final String label;
  final bool isSelfie;
  const _PhotoBox({this.url, required this.label, required this.isSelfie});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: CachedNetworkImage(imageUrl: url!),
                ),
              ),
            ),
          ),
          child: CachedNetworkImage(
            imageUrl: url!,
            height: 180,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
      );
    }
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AuroraTheme.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuroraTheme.glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelfie
                ? Icons.camera_front
                : Icons.person_outline,
            color: AuroraTheme.textMuted,
            size: 36,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.25,
              color: AuroraTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reports Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('reports')
        .select(
            'id, reason, description, created_at, status, '
            'reporter:users!reporter_id(name), reported:users!reported_id(name, id)')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(50);
    if (mounted) {
      setState(() {
        _reports = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    }
  }

  Future<void> _banUser(String userId) async {
    await Supabase.instance.client
        .from('users')
        .update({'banned': true}).eq('id', userId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context)!.admin_user_banned),
      backgroundColor: AuroraTheme.auroraRed,
    ));
  }

  Future<void> _dismiss(String reportId) async {
    await Supabase.instance.client
        .from('reports')
        .update({'status': 'dismissed'}).eq('id', reportId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AuroraTheme.auroraRed),
          ),
        ),
      );
    }
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined,
                color: Color(0xFF10B981), size: 48),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.admin_reports_empty,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AuroraTheme.auroraRed,
      backgroundColor: AuroraTheme.glassBg,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (_, i) {
          final r = _reports[i];
          final reporter = r['reporter'] as Map<String, dynamic>?;
          final reported = r['reported'] as Map<String, dynamic>?;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag, color: AuroraTheme.auroraRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.admin_report_about(reported?['name'] ?? '—'),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AuroraTheme.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.admin_reporter_label(reporter?['name'] ?? '—'),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.25,
                      color: AuroraTheme.textMuted,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.admin_reason_label(r['reason'] as String? ?? '—'),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: AuroraTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if ((r['description'] as String?)?.isNotEmpty == true)
                    Text(
                      r['description'] as String,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        height: 1.5,
                        color: AuroraTheme.textMuted,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ActionBtn(
                        label: AppLocalizations.of(context)!.admin_btn_ban,
                        color: AuroraTheme.auroraRed,
                        onTap: () => _banUser(reported?['id'] as String? ?? ''),
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        label: AppLocalizations.of(context)!.admin_btn_dismiss,
                        color: AuroraTheme.textMuted,
                        onTap: () => _dismiss(r['id'] as String),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.25,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      );
}
