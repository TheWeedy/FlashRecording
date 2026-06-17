import 'dart:io';

enum FileItemKind { web, text, image, video, pdf, file }

class FileTag {
  const FileTag({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
}

class FileItem {
  const FileItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.mimeType,
    required this.originalUrl,
    required this.localPath,
    required this.markdownPath,
    required this.plainTextPreview,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.archivedAt,
  });

  final String id;
  final String title;
  final FileItemKind kind;
  final String mimeType;
  final String originalUrl;
  final String localPath;
  final String markdownPath;
  final String plainTextPreview;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final List<FileTag> tags;

  bool get isArchived => archivedAt != null;
  bool get canAnswerWithAi =>
      kind == FileItemKind.text ||
      kind == FileItemKind.web ||
      kind == FileItemKind.pdf ||
      kind == FileItemKind.image && markdownPath.isNotEmpty;

  String get primaryPath => markdownPath.isNotEmpty ? markdownPath : localPath;

  Future<String> loadTextContent({bool includeMetadata = false}) async {
    final path = primaryPath;
    if (path.isEmpty) {
      return plainTextPreview;
    }
    if (kind == FileItemKind.image && markdownPath.isEmpty) {
      return plainTextPreview;
    }
    final file = File(path);
    if (!await file.exists()) {
      return plainTextPreview;
    }
    final content = await file.readAsString();
    return includeMetadata ? content : _stripFrontMatter(content);
  }

  String _stripFrontMatter(String value) {
    if (!value.startsWith('---')) {
      return value;
    }
    final match = RegExp(r'^---\s*\n[\s\S]*?\n---\s*\n?').firstMatch(value);
    if (match == null) {
      return value;
    }
    return value.substring(match.end).trimLeft();
  }
}

extension FileItemKindLabel on FileItemKind {
  String get label {
    switch (this) {
      case FileItemKind.web:
        return 'Web';
      case FileItemKind.text:
        return 'Text';
      case FileItemKind.image:
        return 'Image';
      case FileItemKind.video:
        return 'Video';
      case FileItemKind.pdf:
        return 'PDF';
      case FileItemKind.file:
        return 'File';
    }
  }
}
