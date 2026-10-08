import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/page_item.dart';
import '../theme/app_theme.dart';
import 'document_detector_service.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final DocumentDetectorService _detector = DocumentDetectorService();

  Future<List<PageItem>> pickImagesFromGallery({bool autoDetect = true}) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty) return [];

      final pages = <PageItem>[];
      for (final xFile in pickedFiles) {
        final id = const Uuid().v4();
        String currentPath = xFile.path;
        String? autoCroppedPath;
        bool wasAutoCropped = false;

        if (autoDetect) {
          final result = await _detector.detectAndAutoCrop(xFile.path);
          if (result.autoCropped) {
            currentPath = result.path;
            autoCroppedPath = result.path;
            wasAutoCropped = true;
          }
        }

        pages.add(PageItem(
          id: id,
          originalPath: xFile.path,
          currentPath: currentPath,
          autoCroppedPath: autoCroppedPath,
          wasAutoCropped: wasAutoCropped,
        ));
      }
      return pages;
    } catch (e) {
      debugPrint('Error picking images from gallery: $e');
      return [];
    }
  }

  Future<PageItem?> pickImageFromCamera({bool autoDetect = true}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) return null;

      final id = const Uuid().v4();
      String currentPath = pickedFile.path;
      String? autoCroppedPath;
      bool wasAutoCropped = false;

      if (autoDetect) {
        final result = await _detector.detectAndAutoCrop(pickedFile.path);
        if (result.autoCropped) {
          currentPath = result.path;
          autoCroppedPath = result.path;
          wasAutoCropped = true;
        }
      }

      return PageItem(
        id: id,
        originalPath: pickedFile.path,
        currentPath: currentPath,
        autoCroppedPath: autoCroppedPath,
        wasAutoCropped: wasAutoCropped,
      );
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  Future<PageItem?> cropPage(PageItem page, BuildContext context) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: page.currentPath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Page',
            toolbarColor: AppTheme.primaryGreen,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppTheme.primaryGreen,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Page',
          ),
        ],
      );

      if (croppedFile == null) return null; // Cancelled

      return page.copyWith(
        currentPath: croppedFile.path,
      );
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    }
  }

  /// Processes rotation (90 deg steps), brightness (-1.0 to 1.0), and contrast (0.5 to 2.0)
  /// Writes to a cache file and returns processed file path.
  Future<String> processImageAdjustments(
    PageItem page, {
    int maxDimension = 2400,
    int quality = 85,
  }) async {
    try {
      final fileBytes = await File(page.currentPath).readAsBytes();
      var image = img.decodeImage(fileBytes);
      if (image == null) return page.currentPath;

      // Downscale if image exceeds max dimension for target quality preset
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width >= image.height) {
          image = img.copyResize(image, width: maxDimension);
        } else {
          image = img.copyResize(image, height: maxDimension);
        }
      }

      // 1. Rotation
      if (page.rotationDegrees != 0) {
        image = img.copyRotate(image, angle: page.rotationDegrees);
      }

      // 2. Brightness & Contrast
      if (page.brightness != 0.0 || page.contrast != 1.0) {
        image = img.adjustColor(
          image,
          brightness: 1.0 + page.brightness,
          contrast: page.contrast,
        );
      }

      // Save processed image to cache
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'proc_${page.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final encodedJpg = img.encodeJpg(image, quality: quality);
      final outFile = File(targetPath);
      await outFile.writeAsBytes(encodedJpg);

      return targetPath;
    } catch (e) {
      debugPrint('Error processing image adjustments: $e');
      return page.currentPath;
    }
  }
}
