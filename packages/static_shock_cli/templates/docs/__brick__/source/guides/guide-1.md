---
title: Guide 1
navOrder: 1
---
Phasellus aliquam congue odio, vitae commodo nisi molestie sit amet. Quisque at leo in nisl sodales porta quis nec justo. Vivamus ornare lacus gravida fringilla lacinia. Donec in imperdiet augue, non gravida eros. Nulla neque leo, auctor sed quam tincidunt, sagittis finibus augue. In et mollis felis. Phasellus vel posuere nunc, a efficitur tellus. Praesent eu porta augue. Phasellus sit amet ex dictum, feugiat justo vitae, consectetur ante. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nunc nec hendrerit metus. Nulla placerat enim a libero sagittis, at fringilla lacus ullamcorper.

```dart
import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    // Here, you can directly hook into the StaticShock pipeline. For example,
    // you can copy an "images" directory from the source set to build set:
    ..pick(DirectoryPicker.parse("images"))
    // All 3rd party behavior is added through plugins, even the behavior
    // shipped with Static Shock.
    ..plugin(const MarkdownPlugin())
    ..plugin(const JinjaPlugin())
    ..plugin(const PrettyUrlsPlugin())
    ..plugin(const SassPlugin());

  // Generate the static website.
  await staticShock.generateSite();
}
```

Fusce in leo tortor. Curabitur blandit mauris eu dui rutrum pretium. Fusce sed semper tellus, non tincidunt mauris. Donec et velit tristique odio feugiat ultrices. Nulla fringilla metus quam, sed commodo massa auctor id. Duis at mi nulla. Nullam eget velit eu dui ultrices feugiat. Nulla dolor erat, iaculis vel viverra eu, convallis a elit. Vestibulum luctus aliquam leo vitae ullamcorper. Sed dolor orci, faucibus vitae faucibus sit amet, pretium a orci. Vivamus eget mi sed massa scelerisque hendrerit. Mauris at commodo erat. Praesent luctus leo quis pulvinar euismod.

Nulla suscipit tempor placerat. Ut lacinia nisi eget libero laoreet, volutpat elementum risus lacinia. Fusce scelerisque risus eget libero dictum vestibulum. Proin tristique arcu metus, eget mattis urna mollis semper. In turpis ante, sagittis id ornare eget, bibendum in nulla. Aliquam ut orci scelerisque, vestibulum turpis eu, sagittis lectus. Quisque fermentum lectus eu velit dictum porta eget vel erat.

Duis pulvinar, leo at blandit fermentum, leo neque auctor purus, eget efficitur lorem metus et arcu. Quisque facilisis tristique mi ac cursus. Pellentesque id felis vehicula, scelerisque ante ut, finibus est. Vestibulum egestas augue lorem, vel bibendum est lobortis ac. Nulla et est at ipsum venenatis dignissim eu et ante. Maecenas pharetra mi ac auctor maximus. Nulla dictum condimentum porta. Fusce at efficitur ex. Curabitur vitae aliquam augue. Sed dignissim mattis diam, at dapibus ante viverra id. Donec a interdum ipsum, eget laoreet orci. Proin maximus, justo at iaculis mollis, felis odio laoreet ligula, vel efficitur libero quam eu justo. In porta aliquam lacus, quis hendrerit quam tristique in.

Aliquam erat volutpat. Phasellus sollicitudin scelerisque leo porta elementum. Integer ac odio tincidunt, laoreet lacus eget, molestie leo. Mauris leo elit, euismod sed mi vel, accumsan mattis metus. Aliquam blandit molestie nibh sed tristique. Morbi accumsan vel felis ut rhoncus. Phasellus vulputate ex eros, et fermentum nisl vulputate et. Duis tempor, ex eu molestie tempor, lorem leo lobortis nisi, ac pulvinar nulla enim ut ipsum. Vivamus sed metus ac odio euismod maximus ac id justo. Nullam mollis quam eu erat fermentum placerat. Quisque pretium quam sollicitudin orci auctor finibus in eget libero. Maecenas vel tempor felis. Maecenas lacinia dapibus tellus quis facilisis. Donec faucibus ultrices viverra. Donec maximus lectus vel purus convallis molestie. In in libero vitae ex dapibus maximus eu vehicula felis.