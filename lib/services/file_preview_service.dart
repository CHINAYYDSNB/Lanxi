import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// 文件类型，由头部 magic number 判定。
enum FileType {
  text,
  png,
  jpeg,
  gif,
  pdf,
  zip,
  gzip,
  binary,
  unknown,
}

/// 远程文件读取抽象（SFTP）。
///
/// 注入此依赖，测试时可用 Mock 验证「远程操作确实被执行」。
abstract class RemoteFileSource {
  /// 从 [remotePath] 的 [offset] 处读取 [length] 字节。
  Future<Uint8List> readBytes(String remotePath, int offset, int length);

  /// 返回远程文件总字节数。
  Future<int> fileSize(String remotePath);
}

/// 文件预览服务：分批读取 + magic number 识别 + 大二进制拒绝。
///
/// 反壳规则：所有远程 I/O 都通过 [RemoteFileSource] 真实执行，
/// 测试用 verify() 断言 readBytes 被按 64KB 分批调用。
class FilePreviewService {
  static const int chunkSize = 64 * 1024; // 64KB
  static const int magicBytes = 256;
  static const int maxPreviewBytes = 1 * 1024 * 1024; // 1MB

  final RemoteFileSource source;

  FilePreviewService(this.source);

  /// 读取头部 [magicBytes] 字节并判定类型。
  Future<FileType> detectType(String remotePath) async {
    final head = await source.readBytes(remotePath, 0, magicBytes);
    return _magicToType(head);
  }

  bool _isKnownBinary(FileType t) =>
      t == FileType.png ||
      t == FileType.jpeg ||
      t == FileType.gif ||
      t == FileType.pdf ||
      t == FileType.zip ||
      t == FileType.gzip;

  FileType _magicToType(Uint8List head) {
    if (head.length >= 4 &&
        head[0] == 0x89 &&
        head[1] == 0x50 &&
        head[2] == 0x4E &&
        head[3] == 0x47) {
      return FileType.png;
    }
    if (head.length >= 3 &&
        head[0] == 0xFF &&
        head[1] == 0xD8 &&
        head[2] == 0xFF) {
      return FileType.jpeg;
    }
    if (head.length >= 4 &&
        head[0] == 0x47 &&
        head[1] == 0x49 &&
        head[2] == 0x46 &&
        head[3] == 0x38) {
      return FileType.gif;
    }
    if (head.length >= 4 &&
        head[0] == 0x25 &&
        head[1] == 0x50 &&
        head[2] == 0x44 &&
        head[3] == 0x46) {
      return FileType.pdf;
    }
    if (head.length >= 4 &&
        head[0] == 0x50 &&
        head[1] == 0x4B &&
        head[2] == 0x03 &&
        head[3] == 0x04) {
      return FileType.zip;
    }
    if (head.length >= 2 && head[0] == 0x1F && head[1] == 0x8B) {
      return FileType.gzip;
    }
    return FileType.unknown;
  }

  /// 预览远程文件。
  /// - 二进制且 > 1MB：拒绝（返回 error）。
  /// - 其余：按 64KB 分批读取，返回全部分块。
  Future<FilePreviewResult> preview(String remotePath) async {
    final size = await source.fileSize(remotePath);
    final type = await detectType(remotePath);

    if (size > maxPreviewBytes && _isKnownBinary(type)) {
      return FilePreviewResult.rejected(
          '不支持预览：文件大于 1MB 且为二进制 ($type)');
    }

    final chunks = <Uint8List>[];
    for (int offset = 0; offset < size; offset += chunkSize) {
      final length =
          (offset + chunkSize < size) ? chunkSize : (size - offset);
      chunks.add(await source.readBytes(remotePath, offset, length));
    }
    return FilePreviewResult.ok(chunks, size, type);
  }
}

/// 预览结果。
class FilePreviewResult {
  final bool ok;
  final String? error;
  final List<Uint8List>? chunks;
  final int? size;
  final FileType? type;

  FilePreviewResult.ok(this.chunks, this.size, this.type)
      : ok = true,
        error = null;

  FilePreviewResult.rejected(this.error)
      : ok = false,
        chunks = null,
        size = null,
        type = null;
}

/// dartssh2 SFTP 实现：真实在远端执行读取（非壳）。
///
/// 由连接层把 dartssh2 的 [SSHClient] 注入即可用于真机。
class SftpRemoteFileSource implements RemoteFileSource {
  final SSHClient client;

  SftpRemoteFileSource(this.client);

  @override
  Future<Uint8List> readBytes(String remotePath, int offset, int length) async {
    final sftp = await client.sftp();
    final file = await sftp.open(remotePath);
    return file.readBytes(offset: offset, length: length);
  }

  @override
  Future<int> fileSize(String remotePath) async {
    final sftp = await client.sftp();
    final file = await sftp.open(remotePath);
    final stat = await file.stat();
    return stat.size ?? 0;
  }
}
