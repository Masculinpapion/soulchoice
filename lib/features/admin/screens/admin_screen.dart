import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';

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
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Moderasyon', style: AppTextStyles.titleMedium),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: AppTextStyles.labelMedium,
          unselectedLabelStyle: AppTextStyles.labelMedium,
          labelColor: AppColors.red,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.red,
          tabs: const [
            Tab(text: 'Bekleyen Selfieler'),
            Tab(text: 'Şikayetler'),
          ],
        ),
      ),
      body: AmbientBackground(
        child: TabBarView(
          controller: _tabController,
          children: const [
            _PendingSelfiestTab(),
            _ReportsTab(),
          ],
        ),
      ),
    );
  }
}

class _PendingSelfiestTab extends StatelessWidget {
  const _PendingSelfiestTab();

  @override
  Widget build(BuildContext context) {
    // TODO: load from Supabase (user_photos where is_selfie = true AND moderation_status = 'pending')
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kullanıcı ${i + 1}', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline, color: AppColors.textTertiary, size: 40),
                            SizedBox(height: 4),
                            Text('Profil Fotoğrafı', style: TextStyle(color: AppColors.textTertiary, fontFamily: 'JetBrainsMono', fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_front, color: AppColors.textTertiary, size: 40),
                            SizedBox(height: 4),
                            Text('Selfie', style: TextStyle(color: AppColors.textTertiary, fontFamily: 'JetBrainsMono', fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {}, // TODO: approve
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      child: const Text('Onayla'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {}, // TODO: reject
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      child: const Text('Reddet'),
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

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    // TODO: load from Supabase reports table
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Text('Kullanıcı ${i + 1} hakkında şikayet', style: AppTextStyles.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text('Sebep: Uygunsuz içerik', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ActionBtn(label: 'Uyarı', color: AppColors.warning, onTap: () {}),
                  const SizedBox(width: 8),
                  _ActionBtn(label: 'Geçici Ban', color: AppColors.error, onTap: () {}),
                  const SizedBox(width: 8),
                  _ActionBtn(label: 'Kalıcı Ban', color: AppColors.error.withOpacity(0.7), onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.color, required this.onTap});

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
              child: Text(label, style: AppTextStyles.monoSmall.copyWith(color: color)),
            ),
          ),
        ),
      );
}
