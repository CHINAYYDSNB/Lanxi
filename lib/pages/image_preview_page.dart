import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// 全屏图片查看页
class ImagePreviewPage extends StatelessWidget {
  final Future<Uint8List> imageData;
  final String name;

  const ImagePreviewPage({
    super.key,
    required this.imageData,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: FutureBuilder<Uint8List>(
        future: imageData,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    snap.hasError ? '.error' : 'Empty',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return PhotoView(
            imageProvider: MemoryImage(snap.data!),
            minScale: PhotoViewComputedScale.contained,
            initialScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3.0,
          );
        },
      ),
    );
  }
}