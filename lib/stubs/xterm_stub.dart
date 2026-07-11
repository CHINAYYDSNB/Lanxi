import 'package:flutter/material.dart';

/// xterm 桩 — 替换 `package:xterm/xterm.dart`
class Terminal {
  int maxLines;
  void Function(String data)? onOutput;
  void Function(int w, int h, int pw, int ph)? onResize;

  Terminal({this.maxLines = 2000});

  void write(String data) {}
  void textInput(String key) {}
}

class TerminalTheme {
  final Color? cursor;
  final Color? selection;
  final Color? foreground;
  final Color? background;
  final Color? black;
  final Color? red;
  final Color? green;
  final Color? yellow;
  final Color? blue;
  final Color? magenta;
  final Color? cyan;
  final Color? white;
  final Color? brightBlack;
  final Color? brightRed;
  final Color? brightGreen;
  final Color? brightYellow;
  final Color? brightBlue;
  final Color? brightMagenta;
  final Color? brightCyan;
  final Color? brightWhite;
  final Color? searchHitForeground;
  final Color? searchHitBackground;
  final Color? searchHitBackgroundCurrent;

  const TerminalTheme({
    this.cursor,
    this.selection,
    this.foreground,
    this.background,
    this.black,
    this.red,
    this.green,
    this.yellow,
    this.blue,
    this.magenta,
    this.cyan,
    this.white,
    this.brightBlack,
    this.brightRed,
    this.brightGreen,
    this.brightYellow,
    this.brightBlue,
    this.brightMagenta,
    this.brightCyan,
    this.brightWhite,
    this.searchHitForeground,
    this.searchHitBackground,
    this.searchHitBackgroundCurrent,
  });
}

class TerminalStyle {
  final double? fontSize;
  final double? height;
  final List<String>? fontFamilyFallback;

  const TerminalStyle({this.fontSize, this.height, this.fontFamilyFallback});
}

/// TerminalView 桩
class TerminalView extends StatelessWidget {
  final Terminal controller;
  final TerminalTheme? theme;
  final TerminalStyle? textStyle;
  final bool autofocus;

  const TerminalView(this.controller, {
    super.key,
    this.theme,
    this.textStyle,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('SSH 终端 (需要 xterm 包)',
          style: TextStyle(color: Colors.grey)),
    );
  }
}
