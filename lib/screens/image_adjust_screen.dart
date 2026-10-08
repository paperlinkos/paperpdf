import 'dart:io';
import 'package:flutter/material.dart';
import '../models/page_item.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';

class ImageAdjustScreen extends StatefulWidget {
  final PageItem page;

  const ImageAdjustScreen({
    super.key,
    required this.page,
  });

  @override
  State<ImageAdjustScreen> createState() => _ImageAdjustScreenState();
}

class _ImageAdjustScreenState extends State<ImageAdjustScreen> {
  late PageItem _currentPage;
  final ImageService _imageService = ImageService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.page;
  }

  void _rotateImage() {
    final nextRotation = (_currentPage.rotationDegrees + 90) % 360;
    setState(() {
      _currentPage = _currentPage.copyWith(rotationDegrees: nextRotation);
    });
  }

  Future<void> _cropImage() async {
    setState(() => _isProcessing = true);
    final croppedPage = await _imageService.cropPage(_currentPage, context);
    setState(() => _isProcessing = false);

    if (croppedPage != null) {
      setState(() {
        _currentPage = croppedPage;
      });
    }
  }

  void _useOriginalImage() {
    setState(() {
      _currentPage = PageItem(
        id: _currentPage.id,
        originalPath: _currentPage.originalPath,
        currentPath: _currentPage.originalPath,
        wasAutoCropped: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Adjust Image'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _currentPage);
            },
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Auto crop indicator badge if active
            if (_currentPage.wasAutoCropped)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.primaryGreen.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Document boundary detected and auto-cropped.',
                        style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: _useOriginalImage,
                      child: const Text('Use Original', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Preview area
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotatedBox(
                        quarterTurns: _currentPage.rotationDegrees ~/ 90,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            _currentPage.contrast, 0, 0, 0, _currentPage.brightness * 255,
                            0, _currentPage.contrast, 0, 0, _currentPage.brightness * 255,
                            0, 0, _currentPage.contrast, 0, _currentPage.brightness * 255,
                            0, 0, 0, 1, 0,
                          ]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_currentPage.currentPath),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Unable to load image preview'),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      if (_isProcessing)
                        const CircularProgressIndicator(color: AppTheme.primaryGreen),
                    ],
                  ),
                ),
              ),
            ),

            // Controls section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.cardLight,
                border: Border(
                  top: BorderSide(color: AppTheme.borderLight),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Action buttons: Crop & Rotate
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _cropImage,
                          icon: const Icon(Icons.crop),
                          label: const Text('Crop'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _rotateImage,
                          icon: const Icon(Icons.rotate_right),
                          label: Text('Rotate (${_currentPage.rotationDegrees}°)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Brightness Slider
                  Row(
                    children: [
                      const Icon(Icons.brightness_6, size: 20, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 70,
                        child: Text('Brightness', style: TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentPage.brightness,
                          min: -0.5,
                          max: 0.5,
                          activeColor: AppTheme.primaryGreen,
                          onChanged: (val) {
                            setState(() {
                              _currentPage = _currentPage.copyWith(brightness: val);
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  // Contrast Slider
                  Row(
                    children: [
                      const Icon(Icons.contrast, size: 20, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 70,
                        child: Text('Contrast', style: TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentPage.contrast,
                          min: 0.5,
                          max: 1.5,
                          activeColor: AppTheme.primaryGreen,
                          onChanged: (val) {
                            setState(() {
                              _currentPage = _currentPage.copyWith(contrast: val);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Reset button if adjusted
                  if (_currentPage.isAdjusted || _currentPage.wasAutoCropped)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentPage = PageItem(
                            id: _currentPage.id,
                            originalPath: _currentPage.originalPath,
                            currentPath: _currentPage.originalPath,
                          );
                        });
                      },
                      child: const Text(
                        'Reset to Original Image',
                        style: TextStyle(color: AppTheme.errorRed),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
