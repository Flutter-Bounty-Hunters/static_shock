import 'dart:async';

import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  final staticShock = StaticShock()
    ..plugin(const MarkdownPlugin())
    ..finish(PickedPagesFinisher(picker: DirectoryPicker.parse("posts")));

  // Generate the static website.
  await staticShock.generateSite();
}

class PickedPagesFinisher implements Finisher {
  final Picker picker;
  const PickedPagesFinisher({required this.picker});

  @override
  FutureOr<void> execute(StaticShockPipelineContext context) {
    // a finisher is called after the site is generated and the index containing the picked pages is produced.
    // here we're using that index along with a picker to filter the pages in the index to just those filtered by the
    // picker. this is the base of what an RSS or ATOM generator would do, i.e. filter some set of generated pages in
    // the site to produce an RSS or ATOM feed.
    print("Picked Pages:");
    for (final page in context.pagesIndex.pages) {
      if (picker.shouldPick(page.sourcePath)) print(page);
    }
  }
}
