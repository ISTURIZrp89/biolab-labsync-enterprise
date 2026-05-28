import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_service.g.dart';

@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  @override
  Map<String, dynamic> build() => {};

  Future<void> loadDashboard() async {
    state = {'status': 'loaded', 'entries': 0, 'pending_sync': 0};
  }
}
