import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DetectionResult {
  final String path;
  final bool autoCropped;
  final String? originalPath;

  DetectionResult({
    required this.path,
    required this.autoCropped,
    this.originalPath,
  });
}

class DocumentDetectorService {
  static final DocumentDetectorService _instance = DocumentDetectorService._internal();
  factory DocumentDetectorService() => _instance;
  DocumentDetectorService._internal();

  /// Attempts automatic document boundary detection and perspective correction.
  /// Prioritizes reliability over aggressive cropping.
  Future<DetectionResult> detectAndAutoCrop(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return DetectionResult(path: imagePath, autoCropped: false);
      }

      final bytes = await file.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        return DetectionResult(path: imagePath, autoCropped: false);
      }

      final width = originalImage.width;
      final height = originalImage.height;

      // Downsample for fast contour / edge analysis
      final sampleWidth = 300;
      final sampleHeight = (height * (300 / width)).round();
      final sampleImage = img.copyResize(originalImage, width: sampleWidth, height: sampleHeight);

      // Convert sample to grayscale
      final grayscale = img.grayscale(sampleImage);

      // Simple edge detection & bounding box estimation for document paper
      final bounds = _findDocumentQuad(grayscale, sampleWidth, sampleHeight);

      if (bounds == null) {
        // Detection uncertain — preserve original image
        return DetectionResult(path: imagePath, autoCropped: false);
      }

      // Map sampled quad coordinates back to full image dimensions
      final scaleX = width / sampleWidth;
      final scaleY = height / sampleHeight;

      final topLeft = img.Point(
        (bounds.topLeft.x * scaleX).round().clamp(0, width - 1),
        (bounds.topLeft.y * scaleY).round().clamp(0, height - 1),
      );
      final topRight = img.Point(
        (bounds.topRight.x * scaleX).round().clamp(0, width - 1),
        (bounds.topRight.y * scaleY).round().clamp(0, height - 1),
      );
      final bottomLeft = img.Point(
        (bounds.bottomLeft.x * scaleX).round().clamp(0, width - 1),
        (bounds.bottomLeft.y * scaleY).round().clamp(0, height - 1),
      );
      final bottomRight = img.Point(
        (bounds.bottomRight.x * scaleX).round().clamp(0, width - 1),
        (bounds.bottomRight.y * scaleY).round().clamp(0, height - 1),
      );

      // Perform perspective rectification using copyRectify
      final rectified = img.copyRectify(
        originalImage,
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
      );

      // Save auto-cropped image to temporary directory
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'autocrop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final encodedJpg = img.encodeJpg(rectified, quality: 88);
      final outFile = File(targetPath);
      await outFile.writeAsBytes(encodedJpg);

      return DetectionResult(
        path: targetPath,
        autoCropped: true,
        originalPath: imagePath,
      );
    } catch (e) {
      debugPrint('Auto document detection fallback to original: $e');
      return DetectionResult(path: imagePath, autoCropped: false);
    }
  }

  /// Internal helper to detect high-contrast document boundaries
  _QuadPoints? _findDocumentQuad(img.Image grayscale, int width, int height) {
    int minX = width;
    int minY = height;
    int maxX = 0;
    int maxY = 0;

    int paperPixelCount = 0;

    // Scan pixels for paper-like high brightness area against background
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = grayscale.getPixel(x, y);
        final luminance = pixel.r; // grayscale red channel is luminance

        // High threshold indicating light background/paper
        if (luminance > 140) {
          paperPixelCount++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    final totalPixels = width * height;
    final coverageRatio = paperPixelCount / totalPixels;

    // Only rectify if bounding rect covers between 30% and 90% of frame (reliable paper boundary)
    if (coverageRatio < 0.30 || coverageRatio > 0.92) {
      return null;
    }

    final marginX = ((maxX - minX) * 0.02).round();
    final marginY = ((maxY - minY) * 0.02).round();

    minX = (minX + marginX).clamp(0, width - 1);
    maxX = (maxX - marginX).clamp(0, width - 1);
    minY = (minY + marginY).clamp(0, height - 1);
    maxY = (maxY - marginY).clamp(0, height - 1);

    if (maxX - minX < width * 0.35 || maxY - minY < height * 0.35) {
      return null;
    }

    return _QuadPoints(
      topLeft: img.Point(minX, minY),
      topRight: img.Point(maxX, minY),
      bottomLeft: img.Point(minX, maxY),
      bottomRight: img.Point(maxX, maxY),
    );
  }
}

class _QuadPoints {
  final img.Point topLeft;
  final img.Point topRight;
  final img.Point bottomLeft;
  final img.Point bottomRight;

  _QuadPoints({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });
}
