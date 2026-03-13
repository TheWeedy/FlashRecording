class NoteItem {
  final String id;
  final String title;
  final String deltaJson;
  final String plainTextPreview;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const NoteItem({
    required this.id,
    required this.title,
    required this.deltaJson,
    required this.plainTextPreview,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });
}
