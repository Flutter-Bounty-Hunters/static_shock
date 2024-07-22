import 'dart:io';
import 'dart:isolate';

import 'package:mason/mason.dart';



/// Generates a new Static Shock project using the "blog" template, placing
/// the files in the given [targetDirectory].
///
/// The generated files are configured with the given properties.
Future<void> generateBlogTemplate(
  Directory targetDirectory, {
  required String projectName,
  required String projectDescription,
}) async {
  final bundle = await _loadTemplateBundle();
  final generator = await MasonGenerator.fromBundle(bundle);
  final target = DirectoryGeneratorTarget(targetDirectory);

  await generator.generate(target, vars: {
    _templateKeyProjectName: projectName,
    _templateKeyProjectDescription: projectDescription,
  });
}

Future<MasonBundle> _loadTemplateBundle() async {
  // We expect to run as a globally activated Dart package. To access assets bundled
  // with our package, we need to resolve a package path to a file system path, as
  // shown below.
  //
  // Note: Dart automatically looks under "lib/" within a package. When reading the
  // path below, mentally insert "/lib/" between the package name and the first sub-directory.
  //
  // Reference: https://stackoverflow.com/questions/72255508/how-to-get-the-file-path-to-an-asset-included-in-a-dart-package
  final packageUri = Uri.parse('package:static_shock_cli/templates/blog.bundle');
  final absoluteUri = await Isolate.resolvePackageUri(packageUri);

  final file = File.fromUri(absoluteUri!);
  if (!file.existsSync()) {
    throw Exception(
        "Couldn't locate the Static Shock 'blog' template in the package assets. Looked in: '${file.path}'");
  }

  // Decode the file's bytes into a Mason bundle. Return it.
  return await MasonBundle.fromUniversalBundle(file.readAsBytesSync());
}

const _templateKeyProjectName = "project_name";
const _templateKeyProjectDescription = "project_description";
