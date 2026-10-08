import 'dart:convert';

class PdfItem {
  final String id;
  final String filename;
  final String path;
  final DateTime createdAt;
  final int pageCount;
  final int fileSizeBytes;
  final String? thumbnailPath;

  PdfItem({
    required this.id,
    required this.filename,
    required this.path,
    required this.createdAt,
    required this.pageCount,
    required this.fileSizeBytes,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'path': path,
      'createdAt': createdAt.toIso8601String(),
      'pageCount': pageCount,
      'fileSizeBytes': fileSizeBytes,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory PdfItem.fromJson(Map<String, dynamic> json) {
    return PdfItem(
      id: json['id'] as String,
      filename: json['filename'] as String,
      path: json['path'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      pageCount: json['pageCount'] as int,
      fileSizeBytes: json['fileSizeBytes'] as int,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  static String encodeList(List<PdfItem> items) {
    return json.encode(items.map((i) => i.toJson()).toList());
  }

  static List<PdfItem> decodeList(String rawJson) {
    final List<dynamic> list = json.decode(rawJson);
    return list.map((item) => PdfItem.fromJson(item as Map<String, dynamic>)).toList();
  }
}
