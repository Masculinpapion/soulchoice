import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final List<File?> _photos = List.filled(AppConstants.maxPhotos, null);
  final _picker = ImagePicker();

  int get _filledCount => _photos.where((p) => p != null).length;
  bool get _canContinue => _filledCount >= AppConstants.minPhotos;

  Future<void> _pickPhoto(int index) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1080,
    );
    if (picked != null) {
      setState(() => _photos[index] = File(picked.path));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos[index] = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fotoğraflarını ekle', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Min ${AppConstants.minPhotos}, max ${AppConstants.maxPhotos} fotoğraf  •  $_filledCount / ${AppConstants.maxPhotos}',
                  style: AppTextStyles.mono,
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: AppConstants.maxPhotos,
                    itemBuilder: (_, i) => _PhotoSlot(
                      file: _photos[i],
                      isPrimary: i == 0,
                      onTap: () => _photos[i] == null ? _pickPhoto(i) : _removePhoto(i),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ScButton(
                  label: 'Devam',
                  onPressed: _canContinue ? () => context.go('/profile/selfie') : null,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final File? file;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PhotoSlot({required this.file, required this.isPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file != null)
              Image.file(file!, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPrimary ? AppColors.red.withOpacity(0.5) : AppColors.glassBorder,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: isPrimary ? AppColors.red : AppColors.textTertiary,
                      size: 28,
                    ),
                    if (isPrimary) ...[
                      const SizedBox(height: 6),
                      Text('Ana fotoğraf', style: AppTextStyles.monoSmall.copyWith(color: AppColors.red)),
                    ],
                  ],
                ),
              ),
            if (file != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.bgBlack.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: AppColors.textPrimary),
                ),
              ),
            if (isPrimary && file != null)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Ana', style: AppTextStyles.monoSmall.copyWith(color: AppColors.textPrimary)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
