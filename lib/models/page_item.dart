class PageItem {
  final String id;
  final String originalPath;
  final String currentPath;
  final String? autoCroppedPath;
  final bool wasAutoCropped;
  final int rotationDegrees; // 0, 90, 180, 270
  final double brightness; // -1.0 to 1.0
  final double contrast; // 0.5 to 2.0

  PageItem({
    required this.id,
    required this.originalPath,
    required this.currentPath,
    this.autoCroppedPath,
    this.wasAutoCropped = false,
    this.rotationDegrees = 0,
    this.brightness = 0.0,
    this.contrast = 1.0,
  });

  bool get isAdjusted =>
      rotationDegrees != 0 ||
      brightness != 0.0 ||
      contrast != 1.0 ||
      currentPath != originalPath;

  PageItem copyWith({
    String? currentPath,
    String? autoCroppedPath,
    bool? wasAutoCropped,
    int? rotationDegrees,
    double? brightness,
    double? contrast,
  }) {
    return PageItem(
      id: id,
      originalPath: originalPath,
      currentPath: currentPath ?? this.currentPath,
      autoCroppedPath: autoCroppedPath ?? this.autoCroppedPath,
      wasAutoCropped: wasAutoCropped ?? this.wasAutoCropped,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
    );
  }
}
