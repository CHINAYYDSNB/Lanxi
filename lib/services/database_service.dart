import '../core/context.dart';

enum DbType { mysql, postgresql, mongodb, redis }

extension DbTypeLabel on DbType {
  String get label => switch (this) {
    DbType.mysql => 'MySQL',
    DbType.postgresql => 'PostgreSQL',
    DbType.mongodb => 'MongoDB',
    DbType.redis => 'Redis',
  };

  String get defaultPort => switch (this) {
    DbType.mysql => '3306',
    DbType.postgresql => '5432',
    DbType.mongodb => '27017',
    DbType.redis => '6379',
  };
}

class DbInstance {
  final DbType type;
  final bool inDocker;
  final String? containerName;
  final String? version;
  final int? port;
  final String? status; // running, stopped

  const DbInstance({
    required this.type,
    this.inDocker = false,
    this.containerName,
    this.version,
    this.port,
    this.status,
  });

  String get label {
    final v = version ?? '';
    final d = inDocker ? ' [Docker]' : '';
    return '${type.label} ${v}$d${containerName != null ? ' ($containerName)' : ''}';
  }

  String get defaultPort => switch (type) {
    DbType.mysql => '3306',
    DbType.postgresql => '5432',
    DbType.mongodb => '27017',
    DbType.redis => '6379',
  };

  String get cliCmd => switch (type) {
    DbType.mysql => 'mysql',
    DbType.postgresql => 'psql',
    DbType.mongodb => 'mongosh',
    DbType.redis => 'redis-cli',
  };

  /// Wrap a command for Docker execution or direct execution.
  String wrapCmd(String cmd, {bool sudo = false}) {
    if (inDocker && containerName != null) {
      final escaped = cmd.replaceAll("'", "'\\''");
      return 'docker exec $containerName sh -c \'$escaped\'';
    }
    final prefix = switch (type) {
      DbType.postgresql => sudo ? 'sudo -u postgres ' : '',
      _ => sudo ? 'sudo ' : '',
    };
    return '$prefix$cmd';
  }
}

class DbDatabase {
  final String name;
  const DbDatabase({required this.name});
}

class DbUser {
  final String name;
  final String? host;
  final String? grants;
  const DbUser({required this.name, this.host, this.grants});
}

class DatabaseService {
  // ─── Detection ───

  static Future<List<DbInstance>> detectAll() async {
    final instances = <DbInstance>[];

    // Check host-native databases
    final results = await Future.wait([
      _detectNative(DbType.mysql),
      _detectNative(DbType.postgresql),
      _detectNative(DbType.mongodb),
      _detectNative(DbType.redis),
    ]);
    instances.addAll(results.whereType<DbInstance>());

    // Check Docker container databases
    try {
      final dockerInstances = await _detectDocker();
      instances.addAll(dockerInstances);
    } catch (_) {}

    return instances;
  }

  static Future<DbInstance?> _detectNative(DbType type) async {
    final checkCmd = switch (type) {
      DbType.mysql => 'mysql --version 2>/dev/null && mysqladmin ping 2>/dev/null || echo "NOPING"',
      DbType.postgresql => 'psql --version 2>/dev/null && sudo -u postgres psql -c "SELECT 1" 2>/dev/null || echo "NOPING"',
      DbType.mongodb => '(mongosh --version 2>/dev/null || mongod --version 2>/dev/null)',
      DbType.redis => 'redis-cli --version 2>/dev/null && redis-cli ping 2>/dev/null || echo "NOPING"',
    };
    try {
      final r = await AppContext.i.exec(checkCmd, timeout: const Duration(seconds: 8));
      if (!r.isSuccess && !r.stdout.contains('--version') && !r.stdout.contains('ping')) return null;

      // Extract version
      String? version;
      final vMatch = RegExp(r'(\d+\.\d+\.?\d*)').firstMatch(r.stdout);
      if (vMatch != null) version = vMatch.group(1);

      // Check if service is reachable
      final alive = !r.stdout.contains('NOPING') || type == DbType.mongodb;
      return DbInstance(type: type, version: version, status: alive ? 'running' : 'stopped', port: int.tryParse(type.defaultPort));
    } catch (_) {
      return null;
    }
  }

  static Future<List<DbInstance>> _detectDocker() async {
    final r = await AppContext.i.exec(
      "docker ps --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null | grep -iE 'mysql|maria|postgres|mongo|redis' || echo ''",
      timeout: const Duration(seconds: 8),
    );
    if (!r.isSuccess || r.stdout.trim().isEmpty) return [];

    final instances = <DbInstance>[];
    for (final line in r.stdout.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length < 3) continue;
      final name = parts[1];
      final image = parts[2].toLowerCase();

      DbType? type;
      if (image.contains('mysql') || image.contains('maria')) {
        type = DbType.mysql;
      } else if (image.contains('postgres')) {
        type = DbType.postgresql;
      } else if (image.contains('mongo')) {
        type = DbType.mongodb;
      } else if (image.contains('redis')) {
        type = DbType.redis;
      }
      if (type == null) continue;

      instances.add(DbInstance(type: type, inDocker: true, containerName: name, status: 'running', port: int.tryParse(type.defaultPort)));
    }
    return instances;
  }

  // ─── Database operations ───

  static Future<List<DbDatabase>> listDatabases(DbInstance inst) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} -e "SHOW DATABASES" -N 2>/dev/null',
      DbType.postgresql => 'sudo -u postgres ${inst.cliCmd} -c "\\\\l" -t -A -F "|" 2>/dev/null',
      DbType.mongodb => '${inst.cliCmd} --eval "db.adminCommand({listDatabases:1}).databases.forEach(d=>print(d.name))" --quiet 2>/dev/null',
      DbType.redis => 'echo "__REDIS_DB__"; ${inst.cliCmd} CONFIG GET databases 2>/dev/null',
    };

    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    if (!r.isSuccess) return [];

    if (inst.type == DbType.redis) {
      // Parse Redis DB count
      final match = RegExp(r'(\d+)').firstMatch(r.stdout);
      final count = match != null ? int.tryParse(match.group(1)!) ?? 16 : 16;
      return List.generate(count, (i) => DbDatabase(name: 'db$i'));
    }

    final dbs = <DbDatabase>[];
    for (final line in r.stdout.split('\n')) {
      final name = line.trim();
      if (name.isEmpty || name == 'Database' || name.startsWith('information_schema') ||
          name.startsWith('performance_schema') || name == 'mysql' || name == 'sys' ||
          name.startsWith('template') || name.startsWith('__')) continue;
      if (inst.type == DbType.postgresql) {
        final parts = name.split('|');
        if (parts.isNotEmpty && parts[0].isNotEmpty) dbs.add(DbDatabase(name: parts[0].trim()));
      } else {
        dbs.add(DbDatabase(name: name));
      }
    }
    return dbs;
  }

  static Future<String> createDatabase(DbInstance inst, String name) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} -e "CREATE DATABASE \\`$name\\`" 2>&1',
      DbType.postgresql => 'sudo -u postgres ${inst.cliCmd} -c "CREATE DATABASE \\"$name\\"" 2>&1',
      DbType.mongodb => '${inst.cliCmd} --eval "db.getSiblingDB(\'$name\').createCollection(\'_init\')" --quiet 2>&1',
      DbType.redis => 'echo "Redis: no explicit DB creation; use SELECT"',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : r.stderr;
  }

  static Future<String> deleteDatabase(DbInstance inst, String name) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} -e "DROP DATABASE \\`$name\\`" 2>&1',
      DbType.postgresql => 'sudo -u postgres ${inst.cliCmd} -c "DROP DATABASE \\"$name\\"" 2>&1',
      DbType.mongodb => '${inst.cliCmd} --eval "db.getSiblingDB(\'$name\').dropDatabase()" --quiet 2>&1',
      DbType.redis => 'echo "Redis: use FLUSHDB in selected DB"',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : r.stderr;
  }

  // ─── User operations ───

  static Future<List<DbUser>> listUsers(DbInstance inst) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} -e "SELECT user,host FROM mysql.user" -N 2>/dev/null',
      DbType.postgresql => 'sudo -u postgres ${inst.cliCmd} -c "\\\\du" -t -A 2>/dev/null',
      DbType.mongodb => '${inst.cliCmd} --eval "db.system.users.find().forEach(u=>print(u.user+\'@\'+(u.db||\'\')))" admin --quiet 2>/dev/null',
      DbType.redis => '${inst.cliCmd} ACL LIST 2>/dev/null || echo "Redis <6: single user"',
    };

    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    if (!r.isSuccess) return [];

    final users = <DbUser>[];
    for (final line in r.stdout.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.contains('rows in set') || t.startsWith('user')) continue;
      if (inst.type == DbType.postgresql) {
        final parts = t.split('|');
        if (parts.isNotEmpty) users.add(DbUser(name: parts[0].trim()));
      } else if (inst.type == DbType.mongodb) {
        final atIdx = t.indexOf('@');
        users.add(DbUser(name: atIdx > 0 ? t.substring(0, atIdx) : t));
      } else if (inst.type == DbType.redis) {
        if (t.startsWith('user ')) {
          final parts = t.split(RegExp(r'\s+'));
          if (parts.length >= 2) users.add(DbUser(name: parts[1]));
        } else {
          users.add(const DbUser(name: 'default'));
        }
      } else {
        // MySQL
        final parts = t.split(RegExp(r'\t|\s{2,}'));
        if (parts.length >= 2) {
          users.add(DbUser(name: parts[0].trim(), host: parts[1].trim()));
        } else if (parts.isNotEmpty) {
          users.add(DbUser(name: parts[0].trim()));
        }
      }
    }
    return users;
  }

  static Future<String> createUser(DbInstance inst, String name, String password, {String host = '%'}) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} -e "CREATE USER \'$name\'@\'$host\' IDENTIFIED BY \'$password\'" 2>&1',
      DbType.postgresql => 'sudo -u postgres ${inst.cliCmd} -c "CREATE USER \\"$name\\" WITH PASSWORD \'$password\'" 2>&1',
      DbType.mongodb => '${inst.cliCmd} admin --eval "db.createUser({user:\'$name\',pwd:\'$password\',roles:[]})" --quiet 2>&1',
      DbType.redis => '${inst.cliCmd} ACL SETUSER $name on >$password 2>&1',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : r.stderr;
  }

  static Future<String> deleteUser(DbInstance inst, String name, {String host = '%'}) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} -e "DROP USER \'$name\'@\'$host\'" 2>&1',
      DbType.postgresql => 'sudo -u postgres ${inst.cliCmd} -c "DROP USER \\"$name\\"" 2>&1',
      DbType.mongodb => '${inst.cliCmd} admin --eval "db.dropUser(\'$name\')" --quiet 2>&1',
      DbType.redis => '${inst.cliCmd} ACL DELUSER $name 2>&1',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : r.stderr;
  }

  static Future<String> changePassword(DbInstance inst, String name, String newPass, {String host = '%'}) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} -e "ALTER USER \'$name\'@\'$host\' IDENTIFIED BY \'$newPass\'" 2>&1',
      DbType.postgresql => 'sudo -u postgres ${inst.cliCmd} -c "ALTER USER \\"$name\\" WITH PASSWORD \'$newPass\'" 2>&1',
      DbType.mongodb => '${inst.cliCmd} admin --eval "db.changeUserPassword(\'$name\',\'$newPass\')" --quiet 2>&1',
      DbType.redis => '${inst.cliCmd} ACL SETUSER $name resetpass on >$newPass 2>&1',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : r.stderr;
  }

  static Future<String> grantPrivileges(DbInstance inst, String user, String database, {String host = '%'}) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} -e "GRANT ALL PRIVILEGES ON \\`$database\\`.* TO \'$user\'@\'$host\'; FLUSH PRIVILEGES" 2>&1',
      DbType.postgresql => 'sudo -u postgres ${inst.cliCmd} -c "GRANT ALL PRIVILEGES ON DATABASE \\"$database\\" TO \\"$user\\"" 2>&1',
      DbType.mongodb => '${inst.cliCmd} admin --eval "db.grantRolesToUser(\'$user\',[{role:\'readWrite\',db:\'$database\'}])" --quiet 2>&1',
      DbType.redis => '${inst.cliCmd} ACL SETUSER $user ~* &* +@all 2>&1',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : r.stderr;
  }

  // ─── Connection info ───

  static Future<String> getConnectionInfo(DbInstance inst) async {
    if (inst.inDocker && inst.containerName != null) {
      final r = await AppContext.i.exec("docker port $inst.containerName 2>/dev/null", timeout: const Duration(seconds: 5));
      return 'Docker: ${inst.containerName}\n端口映射: ${r.stdout.trim()}\n类型: ${inst.type.label}';
    }

    final cmd = switch (inst.type) {
      DbType.mysql => 'mysql -e "SELECT @@hostname,@@port,@@version" -N 2>/dev/null',
      DbType.postgresql => 'sudo -u postgres psql -c "SELECT inet_server_addr(),inet_server_port(),version()" -t -A 2>/dev/null',
      DbType.mongodb => 'mongosh --eval "db.runCommand({connectionStatus:1})" --quiet 2>/dev/null',
      DbType.redis => 'redis-cli INFO server 2>/dev/null | grep -E "tcp_port|redis_version|os"',
    };
    try {
      final r = await AppContext.i.exec(inst.wrapCmd(cmd, sudo: inst.type == DbType.postgresql), timeout: const Duration(seconds: 5));
      return r.stdout.trim();
    } catch (e) {
      return e.toString();
    }
  }
}
