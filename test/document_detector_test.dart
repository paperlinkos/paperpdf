import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('Test Dart image package rectifying and edge detection', () {
    // Create a 100x100 white image with a dark rectangle in center
    final image = img.Image(width: 200, height: 200);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    // Draw a dark inner rectangle (simulating a document on background)
    img.fillRect(image, x1: 20, y1: 30, x2: 180, y2: 170, color: img.ColorRgb8(40, 40, 40));

    // Test copyRectify in image package
    final rectified = img.copyRectify(
      image,
      topLeft: img.Point(20, 30),
      topRight: img.Point(180, 30),
      bottomLeft: img.Point(20, 170),
      bottomRight: img.Point(180, 170),
    );

    expect(rectified.width, greaterThan(0));
    expect(rectified.height, greaterThan(0));
  });
}
