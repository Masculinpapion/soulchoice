import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _loading = true;
  List<_BlockedUser> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final rows = await Supabase.instance.client
        .from('blocks')
        .select(
          'blocked_id, '
          'blocked:users!blocks_blocked_id_fkey(id, name, '
          'photos:user_photos(url, is_selfie, order_index))',
        )
        .eq('blocker_id', uid);

    final parsed = (rows as List).map((row) {
      final u = row['blocked'] as Map<String, dynamic>?;
      if (u == null) return null;
      final photos = (u['photos'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .where((p) => p['is_selfie'] == false)
          .toList()
        ..sort((a, b) => (a['order_index'] as int? ?? 99)
            .compareTo(b['order_index'] as int? ?? 99));
      return _BlockedUser(
        id: u['id'] as String,
        name: u['name'] as String? ?? '—',
        photoUrl: photos.firstOrNull?['url'] as String?,
      );
    }).whereType<_BlockedUser>().toList();

    if (mounted) setState(() { _users = parsed; _loading = false; });
  }

  Future<void> _unblock(String blockedId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _users.removeWhere((u) => u.id == blockedId));

    try {
      await Supabase.instance.client
          .from('blocks')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', blockedId);
    } catch (_) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    _GlassPill(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AuroraTheme.redBlueGradient.createShader(b),
                      child: Text(
                        AppLocalizations.of(context)!.blocked_users_title,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontStyle: FontStyle.italic,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : _users.isEmpty
                        ? Center(
                            child: Text(
                              AppLocalizations.of(context)!.blocked_users_empty,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                color: AuroraTheme.textMuted,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _BlockedTile(
                                  user: _users[i],
                                  onUnblock: () => _unblock(_users[i].id),
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

class _BlockedUser {
  final String id;
  final String name;
  final String? photoUrl;
  const _BlockedUser({required this.id, required this.name, this.photoUrl});
}

class _BlockedTile extends StatelessWidget {
  final _BlockedUser user;
  final VoidCallback onUnblock;
  const _BlockedTile({required this.user, required this.onUnblock});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AuroraTheme.glassBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuroraTheme.glassBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AuroraTheme.glassStrong,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Icon(Icons.person_outline,
                          color: Colors.white54, size: 20)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    user.name,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onUnblock,
                  style: TextButton.styleFrom(
                    foregroundColor: AuroraTheme.auroraRed,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.blocked_users_unblock_btn),
                ),
              ],
            ),
          ),
        ),
      );
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassPill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AuroraTheme.glassBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AuroraTheme.glassBorder),
              ),
              child: child,
            ),
          ),
        ),
      );
}
