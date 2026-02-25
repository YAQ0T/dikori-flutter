class CategoryNode {
  final String main;
  final List<String> subs;
  final String? image;
  final String? label;
  final Map<String, String> subLabels;
  final Map<String, String> subImages;

  CategoryNode({
    required this.main,
    required this.subs,
    this.image,
    this.label,
    this.subLabels = const <String, String>{},
    this.subImages = const <String, String>{},
  });

  String get displayMain => (label ?? '').trim().isNotEmpty ? label!.trim() : main;

  String displaySub(String subValue) {
    final mapped = subLabels[subValue]?.trim() ?? '';
    return mapped.isNotEmpty ? mapped : subValue;
  }

  String? imageForSub(String subValue) {
    final mapped = subImages[subValue]?.trim() ?? '';
    return mapped.isNotEmpty ? mapped : null;
  }
}
