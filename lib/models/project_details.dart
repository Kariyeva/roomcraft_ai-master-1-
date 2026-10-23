/// Optional metadata on an existing savedWorks document. Legacy works need none.
class ProjectDetails {
  final String title;
  final String interiorStyle;
  final String roomType;
  final double area;
  final String palette;
  final String materials;
  final String wishes;
  final double? budget;
  final String sourceImageBase64;
  final String status;

  const ProjectDetails({
    required this.title,
    this.interiorStyle = '',
    required this.roomType,
    required this.area,
    this.palette = '',
    this.materials = '',
    this.wishes = '',
    this.budget,
    required this.sourceImageBase64,
    this.status = 'draft',
  });

  String get statusLabel => status == 'ready' ? 'Концепция готова' : 'Черновик';
  String get brief => [
    'Помещение: $roomType, $area м².',
    if (palette.isNotEmpty) 'Цвета: $palette.',
    if (materials.isNotEmpty) 'Материалы: $materials.',
    if (wishes.isNotEmpty) wishes,
    if (budget != null) 'Бюджет: $budget KZT.',
  ].join('\n');

  Map<String, dynamic> toMap() => {
    'title': title,
    'interiorStyle': interiorStyle,
    'roomType': roomType,
    'area': area,
    'palette': palette,
    'materials': materials,
    'wishes': wishes,
    'budget': budget,
    'currency': 'KZT',
    'sourceImageBase64': sourceImageBase64,
    'status': status,
  };

  factory ProjectDetails.fromMap(Map<String, dynamic> data) => ProjectDetails(
    title: data['title'] as String? ?? '',
    interiorStyle: data['interiorStyle'] as String? ?? '',
    roomType: data['roomType'] as String? ?? '',
    area: (data['area'] as num?)?.toDouble() ?? 0,
    palette: data['palette'] as String? ?? '',
    materials: data['materials'] as String? ?? '',
    wishes: data['wishes'] as String? ?? '',
    budget: (data['budget'] as num?)?.toDouble(),
    sourceImageBase64: data['sourceImageBase64'] as String? ?? '',
    status: data['status'] == 'ready' ? 'ready' : 'draft',
  );
}
