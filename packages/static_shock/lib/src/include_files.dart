import 'package:path/path.dart';
import 'package:static_shock/src/source_files.dart';

/// A layout template for a static site page.
///
/// A page specifies its layout with Front Matter:
///
/// ```yaml
/// ---
/// layout: my-layout.jinja
/// ---
/// ```
class Layout {
  const Layout({
    required this.sourceFile,
    required this.code,
  });

  final SourceFile sourceFile;

  /// The template's source code.
  final String code;

  String describe() => "[Layout]\nsource: $sourceFile\n$code";

  @override
  String toString() => "[Layout] - source: ${sourceFile.subPath}";
}

/// A template, which can be inserted into a page.
///
/// A component can be included in a layout template as follows:
///
/// ```jinja
/// <div>
///   {{ components.footer() }}
/// </div>
/// ```
class Component {
  const Component({
    required this.sourceFile,
    required this.code,
  });

  final SourceFile sourceFile;

  /// The name of the component, which is the name of the component's file,
  /// minus the extension, e.g., "footer" from "footer.jinja".
  String get name => basenameWithoutExtension(sourceFile.subPath);

  /// The component's source code.
  final String code;

  String describe() => "[Layout]\nsource: $sourceFile\n$code";

  @override
  String toString() => "[Component] - source: ${sourceFile.subPath}";
}
