import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClosureService {
  Future<bool> closeDay(String date, String closedBy, String status, String notes) async {
    return true;
  }

  Future<bool> reopenDay(String date, String reopenedBy, String reason) async {
    return true;
  }

  Future<bool> closeMonth(int year, int month, String closedBy, String notes) async {
    return true;
  }

  Future<bool> reopenMonth(int year, int month, String reopenedBy, String reason) async {
    return true;
  }
}

final closureServiceProvider = Provider<ClosureService>((ref) {
  return ClosureService();
});
