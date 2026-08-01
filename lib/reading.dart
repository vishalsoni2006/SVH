class Reading {
  final String siteId;
  final double value;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String photoPath;

  Reading({
    required this.siteId,
    required this.value,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.photoPath,
  });
}