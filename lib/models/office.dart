class Office {
  const Office({required this.id, required this.name, this.building='', this.directorate='', this.department='', this.room='', this.manager='', this.phone='', this.notes='', this.isActive=true});
  final String id, name, building, directorate, department, room, manager, phone, notes;
  final bool isActive;
  Map<String,Object?> toMap()=>{'id':id,'name':name.trim(),'building':building.trim(),'directorate':directorate.trim(),'department':department.trim(),'room':room.trim(),'manager':manager.trim(),'phone':phone.trim(),'notes':notes.trim(),'isActive':isActive};
  factory Office.fromMap(String id, Map<String,dynamic> m)=>Office(id:id,name:m['name'] as String? ?? '',building:m['building'] as String? ?? '',directorate:m['directorate'] as String? ?? '',department:m['department'] as String? ?? '',room:m['room'] as String? ?? '',manager:m['manager'] as String? ?? '',phone:m['phone'] as String? ?? '',notes:m['notes'] as String? ?? '',isActive:m['isActive'] as bool? ?? true);
}