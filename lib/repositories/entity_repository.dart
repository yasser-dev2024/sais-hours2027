import '../database/database_service.dart';

/// Thin data-access boundary for screens that need generic CRUD operations.
/// Business validation and cross-table synchronization remain centralized in
/// [DatabaseService], so callers cannot bypass the migration safety rules.
class EntityRepository {
  const EntityRepository(this.table);

  final String table;

  Future<List<Map<String, Object?>>> list({
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) => DatabaseService.instance.rows(
    table,
    where: where,
    whereArgs: whereArgs,
    orderBy: orderBy,
    limit: limit,
  );

  Future<Map<String, Object?>?> find(int id) =>
      DatabaseService.instance.row(table, id);

  Future<int> save(Map<String, Object?> values, {int? id}) =>
      DatabaseService.instance.saveRecord(table, values, id: id);

  Future<void> delete(int id) =>
      DatabaseService.instance.deleteRecord(table, id);
}
