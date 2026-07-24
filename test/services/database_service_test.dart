import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/database_service.dart';

void main() {
  test('DbType exposes labels and default ports via extension', () {
    expect(DbType.mysql.label, 'MySQL');
    expect(DbType.redis.label, 'Redis');
    expect(DbType.mysql.defaultPort, '3306');
    expect(DbType.postgresql.defaultPort, '5432');
    expect(DbType.mongodb.defaultUser, 'admin');
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
    expect(DbInstance(type: DbType.mysql, version: '8.0').label, 'MySQL 8.0');
  });
}
