import 'package:static_shock/src/destination_files.dart';

import 'source_files.dart';

class Asset {
  Asset({
    required this.source,
    this.destination,
  });

  final SourceFile source;
  DestinationFile? destination;
}
