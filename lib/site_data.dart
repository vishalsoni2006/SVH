import 'dart:math';

class MonitoringSite {
  final String id;
  final String name;
  final double lat;
  final double lng;
  const MonitoringSite(this.id, this.name, this.lat, this.lng);
}

const List<MonitoringSite> sites = [
  MonitoringSite('SITE_01', 'Yamuna Gauge - Delhi', 28.6139, 77.2090),
  MonitoringSite('SITE_02', 'Ganga Gauge - Varanasi', 25.3176, 82.9739),
  MonitoringSite('SITE_03', 'Narmada Gauge - Jabalpur', 23.1815, 79.9864),
];

double distanceInMeters(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371000;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}