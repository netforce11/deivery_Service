class RiderLocation {
  final double lat;
  final double lng;
  final DateTime updatedAt;

  RiderLocation({
    required this.lat,
    required this.lng,
    required this.updatedAt,
  });

  factory RiderLocation.fromMap(Map<String, dynamic> map) {
    return RiderLocation(
      lat: map['lat'] ?? 0.0,
      lng: map['lng'] ?? 0.0,
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'updatedAt': updatedAt,
    };
  }
}

class RiderModel {
  final String id;
  final String name;
  final String phone;
  final bool isActive;
  final String status; // idle, delivering
  final RiderLocation? currentLocation;
  final DateTime createdAt;

  RiderModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
    required this.status,
    this.currentLocation,
    required this.createdAt,
  });

  factory RiderModel.fromMap(Map<String, dynamic> map, String id) {
    return RiderModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      isActive: map['isActive'] ?? false,
      status: map['status'] ?? 'idle',
      currentLocation: map['currentLocation'] != null
          ? RiderLocation.fromMap(map['currentLocation'])
          : null,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'isActive': isActive,
      'status': status,
      'currentLocation': currentLocation?.toMap(),
      'createdAt': createdAt,
    };
  }
}
