import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finetime/theme.dart';

void main() {
  test('FineTime theme uses the premium dark palette', () {
    final theme = FT.theme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, FT.obsidian);
    expect(theme.colorScheme.primary, FT.gold);
  });
}
