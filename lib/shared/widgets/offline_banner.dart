import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../core/theme/aurora_theme.dart';

/// İnce "bağlantı yok" şeridi (30.08) — yalnız cihaz tamamen ağsızken görünür
/// (uçak modu / veri+wifi kapalı). "Bağlı ama internet ölü" (VPN vakası) bu
/// bandın işi DEĞİL; o durumun mesajı istek hatalarında verilir.
/// Ana kabukta içerik üstüne bindirilir; yer kaplamaz, düzeni kaydırmaz.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_apply).catchError((_) {});
    _sub = Connectivity()
        .onConnectivityChanged
        .listen(_apply, onError: (_) {});
  }

  void _apply(List<ConnectivityResult> results) {
    final off = !results.any((r) => r != ConnectivityResult.none);
    if (mounted && off != _offline) setState(() => _offline = off);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AuroraTheme.bgDeep.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AuroraTheme.auroraRed.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 15, color: AuroraTheme.auroraRed),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppLocalizations.of(context)!.offline_banner,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
