import 'dart:io';

enum LexState {
  code,
  stringSingle,
  stringDouble,
  stringTripleSingle,
  stringTripleDouble,
  stringRawSingle,
  stringRawDouble,
  stringRawTripleSingle,
  stringRawTripleDouble,
  commentSingle,
  commentMulti,
  commentDocSingle,
  commentDocMulti,
}

void main(List<String> args) {
  final showHelp = args.contains('--help') || args.contains('-h');
  if (showHelp) {
    print('Usage: dart run tool/remove_comments.dart [options]');
    print('Options:');
    print('  --dry-run       Analyze files and show changes without saving');
    print('  --backup        Create a .bak copy of every modified file');
    print('  --no-keep-docs  Strip documentation comments (/// and /**) as well');
    return;
  }

  final isDryRun = args.contains('--dry-run');
  final createBackup = args.contains('--backup');
  final keepDocs = !args.contains('--no-keep-docs');

  print('Starting comment removal process...');
  print('Mode: ${isDryRun ? 'DRY-RUN (No changes will be saved)' : 'WRITE'}');
  print('Backup: ${createBackup ? 'ENABLED' : 'DISABLED'}');
  print('Keep Doc Comments: ${keepDocs ? 'YES' : 'NO'}');

  final libDir = Directory('lib');
  final testDir = Directory('test');

  if (!libDir.existsSync() && !testDir.existsSync()) {
    print('Error: Could not find lib/ or test/ directory.');
    exit(1);
  }

  final files = <File>[];
  if (libDir.existsSync()) {
    _collectDartFiles(libDir, files);
  }
  if (testDir.existsSync()) {
    _collectDartFiles(testDir, files);
  }

  print('Collected ${files.length} Dart source files.');

  int processedCount = 0;
  int modifiedCount = 0;
  int totalBytesSaved = 0;
  final List<String> modifiedPaths = [];

  for (final file in files) {
    processedCount++;
    final relativePath = file.path;
    final content = file.readAsStringSync();
    
    final stripped = removeComments(content, keepDocs: keepDocs);
    if (stripped == content) {
      continue;
    }

    modifiedCount++;
    final bytesSaved = content.length - stripped.length;
    totalBytesSaved += bytesSaved;
    modifiedPaths.add(relativePath);

    print(' - $relativePath (saving $bytesSaved bytes)');

    if (!isDryRun) {
      if (createBackup) {
        final backupFile = File('$relativePath.bak');
        backupFile.writeAsStringSync(content);
      }
      file.writeAsStringSync(stripped);
    }
  }

  print('\n=== SUMMARY ===');
  print('Files scanned: $processedCount');
  print('Files modified: $modifiedCount');
  print('Total bytes saved: $totalBytesSaved bytes');

  if (modifiedCount > 0 && !isDryRun) {
    print('\nFormatting files...');
    _runFormatter(modifiedPaths);
  }
}

void _collectDartFiles(Directory dir, List<File> files) {
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.endsWith('.g.dart') || name.endsWith('.freezed.dart')) {
        continue;
      }
      files.add(entity);
    }
  }
}

String removeComments(String source, {required bool keepDocs}) {
  final buffer = StringBuffer();
  int i = 0;
  final len = source.length;
  bool isEscaped = false;
  var state = LexState.code;

  while (i < len) {
    final char = source[i];
    final nextChar = (i + 1 < len) ? source[i + 1] : '';
    final nextTwo = (i + 2 < len) ? source[i + 2] : '';

    switch (state) {
      case LexState.code:
        if (char == '/' && nextChar == '*' && nextTwo == '*') {
          if (keepDocs) {
            state = LexState.commentDocMulti;
            buffer.write('/**');
            i += 3;
            continue;
          } else {
            state = LexState.commentMulti;
            i += 3;
            continue;
          }
        }
        if (char == '/' && nextChar == '*') {
          state = LexState.commentMulti;
          i += 2;
          continue;
        }
        if (char == '/' && nextChar == '/' && nextTwo == '/') {
          if (keepDocs) {
            state = LexState.commentDocSingle;
            buffer.write('///');
            i += 3;
            continue;
          } else {
            state = LexState.commentSingle;
            i += 3;
            continue;
          }
        }
        if (char == '/' && nextChar == '/') {
          state = LexState.commentSingle;
          i += 2;
          continue;
        }
        if (char == 'r' || char == 'R') {
          if (nextChar == "'" && nextTwo == "'" && (i + 3 < len && source[i + 3] == "'")) {
            state = LexState.stringRawTripleSingle;
            buffer.write("r'''");
            i += 4;
            continue;
          }
          if (nextChar == '"' && nextTwo == '"' && (i + 3 < len && source[i + 3] == '"')) {
            state = LexState.stringRawTripleDouble;
            buffer.write('r"""');
            i += 4;
            continue;
          }
          if (nextChar == "'") {
            state = LexState.stringRawSingle;
            buffer.write("r'");
            i += 2;
            continue;
          }
          if (nextChar == '"') {
            state = LexState.stringRawDouble;
            buffer.write('r"');
            i += 2;
            continue;
          }
        }
        if (char == "'" && nextChar == "'" && nextTwo == "'") {
          state = LexState.stringTripleSingle;
          buffer.write("'''");
          i += 3;
          continue;
        }
        if (char == '"' && nextChar == '"' && nextTwo == '"') {
          state = LexState.stringTripleDouble;
          buffer.write('"""');
          i += 3;
          continue;
        }
        if (char == "'") {
          state = LexState.stringSingle;
          isEscaped = false;
          buffer.write(char);
          i++;
          continue;
        }
        if (char == '"') {
          state = LexState.stringDouble;
          isEscaped = false;
          buffer.write(char);
          i++;
          continue;
        }
        buffer.write(char);
        i++;
        break;

      case LexState.stringSingle:
        buffer.write(char);
        if (isEscaped) {
          isEscaped = false;
        } else if (char == '\\') {
          isEscaped = true;
        } else if (char == "'") {
          state = LexState.code;
        }
        i++;
        break;

      case LexState.stringDouble:
        buffer.write(char);
        if (isEscaped) {
          isEscaped = false;
        } else if (char == '\\') {
          isEscaped = true;
        } else if (char == '"') {
          state = LexState.code;
        }
        i++;
        break;

      case LexState.stringTripleSingle:
        buffer.write(char);
        if (isEscaped) {
          isEscaped = false;
        } else if (char == '\\') {
          isEscaped = true;
        } else if (char == "'" && nextChar == "'" && nextTwo == "'") {
          buffer.write("''");
          state = LexState.code;
          i += 3;
          continue;
        }
        i++;
        break;

      case LexState.stringTripleDouble:
        buffer.write(char);
        if (isEscaped) {
          isEscaped = false;
        } else if (char == '\\') {
          isEscaped = true;
        } else if (char == '"' && nextChar == '"' && nextTwo == '"') {
          buffer.write('""');
          state = LexState.code;
          i += 3;
          continue;
        }
        i++;
        break;

      case LexState.stringRawSingle:
        buffer.write(char);
        if (char == "'") {
          state = LexState.code;
        }
        i++;
        break;

      case LexState.stringRawDouble:
        buffer.write(char);
        if (char == '"') {
          state = LexState.code;
        }
        i++;
        break;

      case LexState.stringRawTripleSingle:
        buffer.write(char);
        if (char == "'" && nextChar == "'" && nextTwo == "'") {
          buffer.write("''");
          state = LexState.code;
          i += 3;
          continue;
        }
        i++;
        break;

      case LexState.stringRawTripleDouble:
        buffer.write(char);
        if (char == '"' && nextChar == '"' && nextTwo == '"') {
          buffer.write('""');
          state = LexState.code;
          i += 3;
          continue;
        }
        i++;
        break;

      case LexState.commentSingle:
        if (char == '\n' || char == '\r') {
          state = LexState.code;
          buffer.write(char);
        }
        i++;
        break;

      case LexState.commentMulti:
        if (char == '*' && nextChar == '/') {
          state = LexState.code;
          i += 2;
          continue;
        }
        if (char == '\n' || char == '\r') {
          buffer.write(char);
        }
        i++;
        break;

      case LexState.commentDocSingle:
        buffer.write(char);
        if (char == '\n' || char == '\r') {
          state = LexState.code;
        }
        i++;
        break;

      case LexState.commentDocMulti:
        buffer.write(char);
        if (char == '*' && nextChar == '/') {
          buffer.write('/');
          state = LexState.code;
          i += 2;
          continue;
        }
        i++;
        break;
    }
  }

  return buffer.toString();
}

void _runFormatter(List<String> paths) {
  try {
    final result = Process.runSync('dart', ['format', ...paths]);
    if (result.exitCode != 0) {
      print('Warning: Formatter exited with code ${result.exitCode}');
      print(result.stderr);
    } else {
      print('All files formatted successfully.');
    }
  } catch (e) {
    print('Warning: Could not run formatter: $e');
  }
}
