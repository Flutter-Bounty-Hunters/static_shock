import 'package:static_shock/src/files.dart';

class Layout {
  const Layout(this.path, this.value);

  final FileRelativePath path;
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Layout && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
