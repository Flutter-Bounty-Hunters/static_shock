import 'package:static_shock/src/files.dart';

class Component {
  const Component(this.path, this.data, this.content);

  final FileRelativePath path;
  final Map<String, dynamic> data;
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Component && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
