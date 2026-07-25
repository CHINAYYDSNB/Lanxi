import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lanxi/services/file_preview_service.dart';

class MockRemoteFileSource extends Mock implements RemoteFileSource {}

/// 按请求长度返回对应大小的字节，用于模拟真实远程读取。
Future<Uint8List> _sized(Invocation inv) async {
  final length = inv.positionalArguments[2] as int;
  return Uint8List(length);
}

void main() {
  group('FilePreviewService 行为测试 (verify 远程操作被执行)', () {
    test('大文件预览必须分批读取，每次 64KB', () async {
      final mock = MockRemoteFileSource();
      const path = '/var/log/big.txt';
      const total = 200 * 1024; // 200KB
      when(() => mock.fileSize(any())).thenAnswer((_) async => total);
      when(() => mock.readBytes(any(), any(), any())).thenAnswer(_sized);

      final svc = FilePreviewService(mock);
      final result = await svc.preview(path);

      expect(result.ok, isTrue);
      // 分批粒度严格为 64KB（最后一次不足 64KB 按余数）
      verify(() => mock.readBytes(path, 0, 65536)).called(1);
      verify(() => mock.readBytes(path, 65536, 65536)).called(1);
      verify(() => mock.readBytes(path, 131072, 65536)).called(1);
      verify(() => mock.readBytes(path, 196608, 8192)).called(1);
      verify(() => mock.readBytes(path, 0, 256)).called(1); // magic 判定
    });

    test('二进制文件 > 1MB 必须拒绝预览', () async {
      final mock = MockRemoteFileSource();
      const path = '/images/big.iso';
      const total = 2 * 1024 * 1024; // 2MB
      when(() => mock.fileSize(any())).thenAnswer((_) async => total);
      // 返回 PDF 头，明确是二进制
      when(() => mock.readBytes(any(), any(), any()))
          .thenAnswer((_) async => Uint8List.fromList(
                [0x25, 0x50, 0x44, 0x46, 0x00], // %PDF
              ));

      final svc = FilePreviewService(mock);
      final result = await svc.preview(path);

      expect(result.ok, isFalse);
      expect(result.error, contains('不支持预览'));
      // magic 判定确实执行了一次远程读取
      verify(() => mock.readBytes(path, 0, 256)).called(1);
    });

    test('文本文件即使 > 1MB 也允许预览', () async {
      final mock = MockRemoteFileSource();
      const path = '/var/log/huge.log';
      const total = 3 * 1024 * 1024; // 3MB
      when(() => mock.fileSize(any())).thenAnswer((_) async => total);
      when(() => mock.readBytes(any(), any(), any())).thenAnswer(_sized);

      final svc = FilePreviewService(mock);
      final result = await svc.preview(path);

      expect(result.ok, isTrue);
      expect(result.size, total);
    });

    test('magic number 正确识别文件类型', () async {
      Future<void> check(FileType expected, Uint8List head) async {
        final mock = MockRemoteFileSource();
        when(() => mock.readBytes(any(), any(), any()))
            .thenAnswer((_) async => head);
        final svc = FilePreviewService(mock);
        expect(await svc.detectType('/x'), expected);
        // 远程读取确实被执行
        verify(() => mock.readBytes('/x', 0, 256)).called(1);
      }

      await check(FileType.png,
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00, 0x00]));
      await check(
          FileType.jpeg, Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00, 0x00]));
      await check(FileType.gif,
          Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39]));
      await check(FileType.pdf,
          Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x00]));
      await check(FileType.zip,
          Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x00]));
      await check(FileType.gzip, Uint8List.fromList([0x1F, 0x8B, 0x00]));
      await check(FileType.unknown,
          Uint8List.fromList([0x00, 0x01, 0x02, 0x03]));
    });
  });
}
