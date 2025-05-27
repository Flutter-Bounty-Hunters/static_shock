---
title: Pickers
---
Static Shock runs on a given source directory. However, by default, Static Shock
doesn't pick any of the files in that directory for processing. Instead, Static
Shock websites must pick which files are pushed through the pipeline.

Plugins pick files by registering `Picker`s. Static Shock provides `Picker`s
for targeting directories, files, and extensions.

`Picker`s are registered during plugin registration.

The following shows how the Markdown plugin picks all the Markdown files from
the source directory for processing.

```dart
@override
FutureOr<void> configure(
  StaticShockPipeline pipeline,
  StaticShockPipelineContext context,
  StaticShockCache pluginCache,
) {
  pipeline.pick(const ExtensionPicker("md"));
}
```
