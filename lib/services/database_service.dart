import '../core/context.dart';

enum DbType { mysql, postgresql, mongodb, redis }

extension DbTypeMeta on DbType {
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

  String get defaultUser => switch (this) {
    DbType.mysql => 'root',
    DbType.postgresql => 'postgres',
    DbType.mongodb => 'admin',
    DbType.redis => 'default',
  };

  /// Env var names that might hold the password for Docker containers.
  List<String> get passwordEnvVars => switch (this) {
    DbType.mysql => ['MYSQL_ROOT_PASSWORD', 'MYSQL_PASSWORD', 'MARIADB_ROOT_PASSWORD'],
    DbType.postgresql => ['POSTGRES_PASSWORD', 'POSTGRES_ROOT_PASSWORD'],
    DbType.mongodb => ['MONGO_INITDB_ROOT_PASSWORD', 'MONGO_INITDB_ROOT_USERNAME'],
    DbType.redis => ['REDIS_PASSWORD', 'REQUIREPASS'],
  };
}

class DbInstance {
  final DbType type;
  final bool inDocker;
  final String? containerName;
  final String? version;
  int? port;         // detected / mapped port
  final String? status;

  // Session-level auth (not persisted)
  String? authUser;
  String? authPass;
  bool authFailed = false;

  DbInstance({
    required this.type,
    this.inDocker = false,
    this.containerName,
    this.version,
    this.port,
    this.status,
    this.authUser,
    this.authPass,
  });

  String get label {
    final v = version ?? '';
    final d = inDocker ? ' [Docker]' : '';
    final n = containerName != null ? ' ($containerName)' : '';
    return '${type.label} $v$d$n';
  }

  String get subtitle {
    final parts = <String>[];
    if (port != null) parts.add('端口: $port');
    if (inDocker) parts.add('容器: $containerName');
    if (status != null) parts.add(status!);
    return parts.join(' · ');
  }

  String get cliCmd => switch (type) {
    DbType.mysql => 'mysql',
    DbType.postgresql => 'psql',
    DbType.mongodb => 'mongosh',
    DbType.redis => 'redis-cli',
  };

  bool get needsAuth => type != DbType.redis || authPass != null;

  /// Build CLI connection args (no password — uses env vars MYSQL_PWD / PGPASSWORD).
  String get connArgs {
    final u = authUser ?? type.defaultUser;
    final buf = StringBuffer();
    if (type == DbType.mysql) {
      buf.write('-u$u');
    } else if (type == DbType.postgresql) {
      buf.write('-U $u');
      if (inDocker) buf.write(' -h localhost');
    } else if (type == DbType.mongodb) {
      buf.write('-u $u');
      if (authPass != null && authPass!.isNotEmpty) {
        buf.write(' -p $authPass --authenticationDatabase admin');
      }
    } else if (type == DbType.redis) {
      if (authPass != null && authPass!.isNotEmpty) {
        buf.write('-a $authPass --no-auth-warning');
      }
    }
    return buf.toString();
  }

  /// Wrap command with env vars (MYSQL_PWD, PGPASSWORD) for password security.
  String wrapCmd(String cmd) {
    final envs = <String>[];
    final p = authPass;
    if (p != null && p.isNotEmpty) {
      final escapedP = p.replaceAll("'", "'\\''");
      if (type == DbType.mysql) envs.add("MYSQL_PWD='$escapedP'");
      if (type == DbType.postgresql) envs.add("PGPASSWORD='$escapedP'");
    }
    final prefix = envs.isNotEmpty ? '${envs.join(' ')} ' : '';

    if (inDocker && containerName != null) {
      final escaped = cmd.replaceAll("'", "'\\''");
      return 'docker exec $containerName sh -c \'$prefix$escaped\'';
    }
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

    // Native
    final results = await Future.wait([
      _detectNative(DbType.mysql),
      _detectNative(DbType.postgresql),
      _detectNative(DbType.mongodb),
      _detectNative(DbType.redis),
    ]);
    instances.addAll(results.whereType<DbInstance>());

    // Docker
    try {
      instances.addAll(await _detectDocker());
    } catch (_) {}

    return instances;
  }

  static Future<DbInstance?> _detectNative(DbType type) async {
    final checkCmd = switch (type) {
      DbType.mysql => 'mysql --version 2>/dev/null && echo "FOUND"',
      DbType.postgresql => 'psql --version 2>/dev/null && echo "FOUND"',
      DbType.mongodb => '(mongosh --version 2>/dev/null || mongod --version 2>/dev/null) && echo "FOUND"',
      DbType.redis => 'redis-cli --version 2>/dev/null && echo "FOUND"',
    };
    try {
      final r = await AppContext.i.exec(checkCmd, timeout: const Duration(seconds: 8));
      if (!r.stdout.contains('FOUND')) return null;
      final vMatch = RegExp(r'(\d+\.\d+\.?\d*)').firstMatch(r.stdout);
      return DbInstance(type: type, version: vMatch?.group(1), status: 'detected', port: int.tryParse(type.defaultPort));
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

      // Extract mapped port from "0.0.0.0:3306->3306/tcp"
      int? mappedPort;
      if (parts.length > 3) {
        final portMatch = RegExp(r':(\d+)->').firstMatch(parts[3]);
        if (portMatch != null) mappedPort = int.tryParse(portMatch.group(1)!);
      }
      // Get version from docker inspect
      String? version;
      try {
        final vr = await AppContext.i.exec(
          "docker inspect --format '{{.Config.Image}}' $name 2>/dev/null",
          timeout: const Duration(seconds: 5),
        );
        final imgTag = vr.stdout.trim();
        final vMatch = RegExp(r':(\d+\.\d+[.\d]*)').firstMatch(imgTag);
        if (vMatch != null) version = vMatch.group(1);
      } catch (_) {}

      instances.add(DbInstance(
        type: type, inDocker: true, containerName: name,
        version: version, status: 'running',
        port: mappedPort ?? int.tryParse(type.defaultPort),
      ));
    }
    return instances;
  }

  // ─── Auto credential detection ───

  /// Try to read credentials from Docker environment variables using grep.
  /// Returns (user, password) if found.
  static Future<({String user, String pass})?> tryDetectCredentials(DbInstance inst) async {
    if (!inst.inDocker || inst.containerName == null) return null;
    final envVars = inst.type.passwordEnvVars;
    try {
      // Use grep to find env var values (more reliable than JSON regex)
      final grepPattern = envVars.map((v) => '^$v=').join('\\|');
      final r = await AppContext.i.exec(
        "docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' ${inst.containerName} 2>/dev/null | grep -E '$grepPattern' | head -3",
        timeout: const Duration(seconds: 5),
      );
      if (!r.isSuccess || r.stdout.trim().isEmpty) return null;

      String? user = inst.type.defaultUser;
      String? pass;
      for (final line in r.stdout.split('\n')) {
        final eq = line.indexOf('=');
        if (eq < 0) continue;
        final key = line.substring(0, eq);
        final val = line.substring(eq + 1);
        if (val.isEmpty) continue;
        if (key.contains('USERNAME') || key.contains('USER')) {
          user = val;
        } else {
          pass = val;
        }
      }
      if (pass != null) return (user: user!, pass: pass);
    } catch (_) {}
    return null;
  }

  /// Test if credentials work for given instance.
  static Future<String?> testCredentials(DbInstance inst) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "SELECT 1"',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "SELECT 1"',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.runCommand({ping:1})" --quiet',
      DbType.redis => '${inst.cliCmd} ${inst.connArgs} PING',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    final ok = r.exitCode == 0 &&
        (r.stdout.contains('1') || r.stdout.contains('PONG') || r.stdout.contains('ok'));
    if (ok) return null;
    return _errMsg(r);
  }

  /// Extract error message from SshResult.
  static String _errMsg(dynamic r) {
    final stderr = r.stderr?.toString() ?? '';
    final stdout = r.stdout?.toString() ?? '';
    return stderr.isNotEmpty ? stderr : (stdout.isNotEmpty ? stdout : '命令执行失败');
  }

  // ─── Database operations ───

  static Future<List<DbDatabase>> listDatabases(DbInstance inst) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "SHOW DATABASES" -N',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "\\\\l" -t -A -F "|"',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.adminCommand({listDatabases:1}).databases.forEach(d=>print(d.name))" --quiet',
      DbType.redis => 'echo "__REDIS__"; ${inst.cliCmd} ${inst.connArgs} CONFIG GET databases',
    };

    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 10));
    if (!r.isSuccess && !r.stdout.contains('__REDIS__')) return [];

    if (inst.type == DbType.redis) {
      final match = RegExp(r'(\d+)').firstMatch(r.stdout);
      final count = match != null ? int.tryParse(match.group(1)!) ?? 16 : 16;
      return List.generate(count, (i) => DbDatabase(name: 'db$i'));
    }

    final dbs = <DbDatabase>[];
    for (final line in r.stdout.split('\n')) {
      final name = line.trim();
      if (name.isEmpty || name == 'Database' || name.startsWith('information_schema') ||
          name.startsWith('performance_schema') || name == 'mysql' || name == 'sys' ||
          name.startsWith('template') || name.startsWith('__') || name == 'postgres') continue;
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
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "CREATE DATABASE \\`$name\\`"',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "CREATE DATABASE \\"$name\\""',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.getSiblingDB(\'$name\').createCollection(\'_init\')" --quiet',
      DbType.redis => 'echo "Redis: use SELECT"',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : _errMsg(r);
  }

  static Future<String> deleteDatabase(DbInstance inst, String name) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "DROP DATABASE \\`$name\\`"',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "DROP DATABASE \\"$name\\""',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.getSiblingDB(\'$name\').dropDatabase()" --quiet',
      DbType.redis => 'echo "Redis: use FLUSHDB"',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : _errMsg(r);
  }

  // ─── User operations ───

  static Future<List<DbUser>> listUsers(DbInstance inst) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "SELECT user,host FROM mysql.user" -N',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "\\\\du" -t -A',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.system.users.find().forEach(u=>print(u.user+\'@\'+(u.db||\'\')))" admin --quiet',
      DbType.redis => '${inst.cliCmd} ${inst.connArgs} ACL LIST || echo "single_user"',
    };

    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    if (!r.isSuccess && inst.type != DbType.redis) return [];

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
        } else if (t == 'single_user') {
          users.add(const DbUser(name: 'default'));
        }
      } else {
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
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "CREATE USER \'$name\'@\'$host\' IDENTIFIED BY \'$password\'"',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "CREATE USER \\"$name\\" WITH PASSWORD \'$password\'"',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.createUser({user:\'$name\',pwd:\'$password\',roles:[]})" --quiet',
      DbType.redis => '${inst.cliCmd} ${inst.connArgs} ACL SETUSER $name on >$password',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : _errMsg(r);
  }

  static Future<String> deleteUser(DbInstance inst, String name, {String host = '%'}) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "DROP USER \'$name\'@\'$host\'"',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "DROP USER \\"$name\\""',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.dropUser(\'$name\')" --quiet',
      DbType.redis => '${inst.cliCmd} ${inst.connArgs} ACL DELUSER $name',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : _errMsg(r);
  }

  static Future<String> changePassword(DbInstance inst, String name, String newPass, {String host = '%'}) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "ALTER USER \'$name\'@\'$host\' IDENTIFIED BY \'$newPass\'"',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "ALTER USER \\"$name\\" WITH PASSWORD \'$newPass\'"',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.changeUserPassword(\'$name\',\'$newPass\')" --quiet',
      DbType.redis => '${inst.cliCmd} ${inst.connArgs} ACL SETUSER $name resetpass on >$newPass',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : _errMsg(r);
  }

  static Future<String> grantPrivileges(DbInstance inst, String user, String database, {String host = '%'}) async {
    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "GRANT ALL PRIVILEGES ON \\`$database\\`.* TO \'$user\'@\'$host\'; FLUSH PRIVILEGES"',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "GRANT ALL PRIVILEGES ON DATABASE \\"$database\\" TO \\"$user\\""',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.grantRolesToUser(\'$user\',[{role:\'readWrite\',db:\'$database\'}])" --quiet',
      DbType.redis => '${inst.cliCmd} ${inst.connArgs} ACL SETUSER $user ~* &* +@all',
    };
    final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 8));
    return r.isSuccess ? '' : _errMsg(r);
  }

  // ─── Connection info ───

  static Future<String> getConnectionInfo(DbInstance inst) async {
    if (inst.inDocker && inst.containerName != null) {
      // Get port mapping
      String portInfo = '';
      try {
        final pr = await AppContext.i.exec("docker port ${inst.containerName} 2>/dev/null | head -5",
            timeout: const Duration(seconds: 5));
        portInfo = pr.stdout.trim();
      } catch (_) {}

      final buf = StringBuffer();
      buf.writeln('容器: ${inst.containerName}');
      if (inst.authUser != null) buf.writeln('用户: ${inst.authUser}');
      if (inst.port != null) buf.writeln('端口: ${inst.port}');
      if (portInfo.isNotEmpty) {
        buf.writeln('端口映射:');
        for (final line in portInfo.split('\n')) {
          buf.writeln('  $line');
        }
      }
      buf.writeln('类型: ${inst.type.label}');
      if (inst.version != null) buf.writeln('版本: ${inst.version}');
      buf.writeln('连接方式: docker exec ${inst.containerName} ${inst.cliCmd}');
      return buf.toString();
    }

    final cmd = switch (inst.type) {
      DbType.mysql => '${inst.cliCmd} ${inst.connArgs} -e "SELECT @@hostname,@@port,@@version" -N',
      DbType.postgresql => '${inst.cliCmd} ${inst.connArgs} -c "SELECT inet_server_addr(),inet_server_port(),version()" -t -A',
      DbType.mongodb => '${inst.cliCmd} ${inst.connArgs} --eval "db.runCommand({connectionStatus:1})" --quiet',
      DbType.redis => '${inst.cliCmd} ${inst.connArgs} INFO server | grep -E "tcp_port|redis_version|os"',
    };
    try {
      final r = await AppContext.i.exec(inst.wrapCmd(cmd), timeout: const Duration(seconds: 5));
      return r.stdout.trim();
    } catch (e) {
      return e.toString();
    }
  }
}
