import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/database_service.dart';

void main() {
  test('DbTypeMeta exposes labels and default ports', () {
    expect(DbTypeMeta.label(DbType.mysql), 'MySQL');
    expect(DbTypeMeta.label(DbType.redis), 'Redis');
    expect(DbTypeMeta.defaultPort(DbType.mysql), '3306');
    expect(DbTypeMeta.defaultPort(DbType.postgresql), '5432');
    expect(DbTypeMeta.defaultUser(DbType.mongodb), 'admin');
  });

  test('DbInstance builds connection args and wraps commands', () {
    final db = DbInstance(type: DbType.mysql, authUser: 'root');
    expect(db.connArgs, contains('-uroot'));
    expect(db.wrapCmd('SELECT 1'), 'SELECT 1');

    final dockerDb = DbInstance(
      type: DbType.mysql,
      inDocker: true,
      containerName: 'db1',
      authPass: 'secret',
    );
    final wrapped = dockerDb.wrapCmd('SELECT 1');
    expect(wrapped, contains('docker exec db1'));
    expect(wrapped, contains("MYSQL_PWD='secret'"));
  });

  test('DbInstance.label includes version', () {
    expect(const DbInstance(type: DbType.mysql, version: '8.0').label, 'MySQL 8.0');
  });
}
