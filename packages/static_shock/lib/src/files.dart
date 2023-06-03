import 'dart:io';
import 'package:path/path.dart' as path;

extension SubPath on Directory {
  Directory subDir(List<String> segments) {
    return Directory(path.joinAll([this.path, ...segments]));
  }

  File descFile(List<String> segments) {
    return File(path.joinAll([this.path, ...segments]));
  }
}
