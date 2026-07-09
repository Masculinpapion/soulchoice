import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';

/// Profil → Abonelik (F2-2: en fazla 2 tıkla iptal).
/// Veri kaynağı: manage-subscription edge fn. iOS'ta ödeme başlatan aksiyonlar
/// (abone ol / devam et) paywall_mode bayrağıyla gizlenir; iptal HER ZAMAN görünür.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  late String _mode = Platform.isIOS ? 'hidden' : 'link';

  @override
  void initState() {
    super.initState();
    _loadMode();
    _refresh();
  }

  Future<void> _loadMode() async {
    try {
      final row = await Supabase.instance.client
          .from('feature_flags')
          .select('value')
          .eq('key', 'paywall_mode')
          .maybeSingle();
      final value = row?['value'];
      if (value is Map) {
        final mode = value[Platform.isIOS ? 'ios' : 'android'];
        if (mode is String && mounted) setState(() => _mode = mode);
      }
    } catch (_) {
      // Bayrak okunamazsa platform varsayılanı geçerli
    }
  }

  Future<void> _refresh() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'manage-subscription',
        body: {'action': 'status'},
      );
      if (mounted) {
        setState(() {
          _data = (response.data as Map?)?.cast<String, dynamic>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // P8 kurtarma: past_due'da kullanıcı tetikli çekim denemesi
  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'manage-subscription',
        body: {
          'action': 'retry',
          'source': Platform.isIOS ? 'ios_app' : 'android',
        },
      );
      final data = (response.data as Map?)?.cast<String, dynamic>();
      if (data?['ok'] == true) {
        await _refresh();
      } else if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _snack(data?['reason'] == 'retry_limit'
            ? l10n.sub_retry_limit
            : l10n.sub_retry_failed);
      }
    } catch (_) {
      if (mounted) _snack(AppLocalizations.of(context)!.error_generic);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'manage-subscription',
        body: {
          'action': action,
          'source': Platform.isIOS ? 'ios_app' : 'android',
        },
      );
      await _refresh();
    } catch (_) {
      if (mounted) _snack(AppLocalizations.of(context)!.error_generic);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      backgroundColor: AuroraTheme.bgDeep,
      content: Text(msg,
          style: const TextStyle(
              fontFamily: 'Manrope', fontSize: 13, color: Colors.white)),
    ));
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year}';
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context)!;
    final until = _fmtDate(_data?['premium_until'] as String?);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.sub_cancel_confirm_title,
            style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontSize: 20,
                color: Colors.white)),
        content: Text(l10n.sub_cancel_confirm_body(until),
            style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.sub_cancel_confirm_no,
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.sub_cancel_confirm_yes,
                style: const TextStyle(
                    fontFamily: 'Manrope', color: Color(0xFFFF6B81))),
          ),
        ],
      ),
    );
    if (yes == true) await _action('cancel');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sub = _data?['subscription'] as Map<String, dynamic>?;
    final premiumUntil = _data?['premium_until'] as String?;
    final payments = (_data?['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = sub?['status'] as String?;
    final premiumActive = premiumUntil != null &&
        (DateTime.tryParse(premiumUntil)?.isAfter(DateTime.now()) ?? false);

    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 24, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    Text(
                      l10n.sub_title,
                      style: const TextStyle(
                        fontFamily: 'Fraunces',
                        fontStyle: FontStyle.italic,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.2))
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                          children: [
                            // Dönemi bitmiş cancelled/expired abonelik = fiilen "abonelik yok":
                            // boş tarihli iptal notu yerine boş-durum kartı (09.07 cihaz bulgusu)
                            if (sub == null ||
                                (!premiumActive &&
                                    (status == 'expired' || status == 'cancelled'))) ...[
                              _buildEmpty(l10n),
                              const SizedBox(height: 24), // ПЛАТЕЖИ başlığı karta yapışmasın
                            ] else ...[
                              _buildStatusCard(l10n, sub, premiumUntil, premiumActive),
                              const SizedBox(height: 24),
                            ],
                            if (payments.isNotEmpty) ...[
                              _SectionHeader(label: l10n.sub_history_title),
                              const SizedBox(height: 12),
                              _Glass(
                                child: Column(
                                  children: [
                                    for (final p in payments) _paymentRow(p),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return _Glass(
      child: Column(
        children: [
          Text(l10n.sub_none_title,
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(l10n.sub_none_body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AuroraTheme.textSecondary)),
          if (_mode == 'link') ...[
            const SizedBox(height: 16),
            _GradientButton(
              label: l10n.sub_get_premium,
              onTap: () => context.push('/paywall'),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AppLocalizations l10n, Map<String, dynamic> sub,
      String? premiumUntil, bool premiumActive) {
    final status = sub['status'] as String?;
    final until = _fmtDate(premiumUntil);
    final masked = (sub['card_masked_pan'] as String?) ?? '';
    final last4 = masked.length >= 4 ? masked.substring(masked.length - 4) : '';
    final isActive = status == 'active';
    final isPastDue = status == 'past_due';
    final isCancelled = status == 'cancelled';

    final statusLabel = isActive
        ? l10n.sub_status_active
        : isPastDue
            ? l10n.sub_status_past_due
            : l10n.sub_status_cancelled;
    final statusColor = isActive
        ? const Color(0xFF6EE7A0)
        : isPastDue
            ? const Color(0xFFFFB020)
            : AuroraTheme.textMuted;

    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: statusColor),
              ),
              const SizedBox(width: 10),
              Text(statusLabel,
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ],
          ),
          const SizedBox(height: 16),
          if (isCancelled)
            // KARAR 4: sade mesaj — kart saklama lafı ekranda geçmez
            Text(l10n.sub_cancelled_note(until),
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.white))
          else ...[
            _infoRow(l10n.sub_price_label, l10n.paywall_price),
            if (sub['next_billing_at'] != null)
              _infoRow(l10n.sub_next_charge,
                  _fmtDate(sub['next_billing_at'] as String?)),
            if (last4.isNotEmpty) _infoRow(l10n.sub_card, '•••• $last4'),
            if (until.isNotEmpty)
              _infoRow('', l10n.sub_premium_until(until)),
          ],
          const SizedBox(height: 18),
          if (isPastDue) ...[
            // P8: kurtarma eylemi — tek eylem iptal olmasın
            _GradientButton(
              label: l10n.sub_retry_button,
              isLoading: _busy,
              onTap: _retry,
            ),
            const SizedBox(height: 10),
          ],
          if (isActive || isPastDue)
            _OutlineButton(
              label: l10n.sub_cancel_button,
              color: const Color(0xFFFF6B81),
              isLoading: _busy,
              onTap: _confirmCancel,
            )
          else if (isCancelled && premiumActive && _mode == 'link')
            _GradientButton(
              label: l10n.sub_resume_button(last4),
              isLoading: _busy,
              onTap: () => _action('resume'),
            )
          else if (isCancelled && !premiumActive && _mode == 'link')
            _GradientButton(
              label: l10n.sub_get_premium,
              onTap: () => context.push('/paywall'),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AuroraTheme.textMuted)),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _paymentRow(Map<String, dynamic> p) {
    final paid = p['status'] == 'paid';
    final refunded = p['status'] == 'refunded';
    final date = _fmtDate((p['paid_at'] ?? p['created_at']) as String?);
    final amount = p['amount']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            paid
                ? Icons.check_circle_outline
                : refunded
                    ? Icons.replay_circle_filled_outlined
                    : Icons.schedule,
            size: 16,
            color: paid
                ? const Color(0xFF6EE7A0)
                : refunded
                    ? AuroraTheme.textMuted
                    : const Color(0xFFFFB020),
          ),
          const SizedBox(width: 10),
          Text(date,
              style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: AuroraTheme.textSecondary)),
          const Spacer(),
          Text('$amount ₽',
              style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: refunded ? AuroraTheme.textMuted : Colors.white,
                  decoration:
                      refunded ? TextDecoration.lineThrough : null)),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AuroraTheme.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AuroraTheme.textMuted,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const _GradientButton(
      {required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Text(label,
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  const _OutlineButton(
      {required this.label,
      required this.color,
      required this.onTap,
      this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color)),
              )
            : Text(label,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color)),
      ),
    );
  }
}
