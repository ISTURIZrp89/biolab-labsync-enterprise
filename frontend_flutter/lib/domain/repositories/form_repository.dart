import '../entities/form_entry.dart';

abstract class FormRepository {
  Future<List<FormEntry>> getEntries(String module, String date);
  Future<List<FormEntry>> getEntriesByModule(String module);
  Future<FormEntry?> getEntryById(String id);
  Future<void> saveEntry(FormEntry entry);
  Future<void> deleteEntry(String id);
}
