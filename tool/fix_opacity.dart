import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Error: Could not find lib/ directory.');
    exit(1);
  }

  final files = <File>[];
  _collectDartFiles(libDir, files);

  final testDir = Directory('test');
  if (testDir.existsSync()) {
    _collectDartFiles(testDir, files);
  }

  for (final file in files) {
    var content = file.readAsStringSync();
    var modified = false;

    if (file.path.endsWith('diagnostics_screen.dart')) {
      final oldActiveColor = 'activeColor: YamiTheme.glowSecure,';
      final newActiveColor = 'activeThumbColor: YamiTheme.glowSecure,';
      if (content.contains(oldActiveColor)) {
        content = content.replaceAll(oldActiveColor, newActiveColor);
        modified = true;
      }
    }

    if (file.path.endsWith('theme.dart')) {
      final oldBackground = 'background: bgDeep,';
      final newBackground = 'surface: bgDeep,';
      if (content.contains(oldBackground)) {
        content = content.replaceAll(oldBackground, newBackground);
        modified = true;
      }
    }

    if (content.contains('.withOpacity(')) {
      content = _replaceOpacity(content);
      modified = true;
    }

    if (modified) {
      file.writeAsStringSync(content);
      print('Updated deprecations in: ${file.path}');
    }
  }

  _runFormatter();
}

void _collectDartFiles(Directory dir, List<File> files) {
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }
}

String _replaceOpacity(String source) {
  final buffer = StringBuffer();
  int i = 0;
  final len = source.length;

  while (i < len) {
    if (i + 13 < len && source.substring(i, i + 13) == '.withOpacity(') {
      int startArg = i + 13;
      int parenCount = 1;
      int j = startArg;
      
      while (j < len && parenCount > 0) {
        final char = source[j];
        if (char == '(') {
          parenCount++;
        } else if (char == ')') {
          parenCount--;
        }
        j++;
      }
      
      if (parenCount == 0) {
        final arg = source.substring(startArg, j - 1);
        buffer.write('.withValues(alpha: $arg)');
        i = j;
        continue;
      }
    }
    
    buffer.write(source[i]);
    i++;
  }

  return buffer.toString();
}

void _runFormatter() {
  try {
    Process.runSync('dart', ['format', 'lib', 'test']);
    print('Formatted files successfully.');
  } catch (e) {
    print('Warning: Formatting failed: $e');
  }
}
