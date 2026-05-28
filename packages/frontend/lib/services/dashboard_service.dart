import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardService {
  Map<String, dynamic> _data = {};

  Map<String, dynamic> get data => _data;

  Future<void> load() async {
    _data = {
      'status': 'loaded',
      'entries_count': 0,
      'pending_sync': 0,
      'modules': [],
    };
  }
}

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService();
});
