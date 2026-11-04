class Office {
  const Office({
    required this.id,
    required this.name,
    this.building = '',
    this.directorate = '',
    this.department = '',
    this.room = '',
    this.manager = '',
  });

  final String id;
  final String name;
  final String building;
  final String directorate;
  final String department;
  final String room;
  final String manager;

  Map<String, Object?> toMap() => {
    'id': id, 'name': name, 'building': building,
    'directorate': directorate, 'department': department,
    'room': room, 'manager': manager,
  };
}
