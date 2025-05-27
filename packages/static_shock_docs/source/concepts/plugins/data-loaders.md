---
title: Data Loaders
contentRenderers:
  - jinja
  - markdown
---
Plugins can load data into the `DataIndex` by registering `DataLoader`s with
the pipeline.

[Learn more]({{ "concepts/how-it-works/data-index" | local_link }}) about the `DataIndex`.

To load data in a plugin, first define a `DataLoader` implementation, and
then register that `DataLoader` with the pipeline.

The `DataLoader` can load whatever data it wants, from any source that it
wants. The data returned from the `DataLoader` is merged into the `DataIndex`
beginning at the root `/` of the index.

```dart
class MyDataLoader implements DataLoader {
  MyDataLoader();

  @override
  Future<Map<String, Object>> loadData(StaticShockPipelineContext context) async {
    // Load data from wherever you'd like.
    
    // Return the data that you want merged into the `DataIndex`. To avoid
    // data conflicts, it's recommended that you create a namespace for
    // the data.
    return {
      "io.staticshock": {
        "thing1": "some value",
        "thing2": "some value",
      },
    };
  }
}
```

Register the `DataLoader` with the pipeline from within the plugin.

```dart
@override
FutureOr<void> configure(
  StaticShockPipeline pipeline,
  StaticShockPipelineContext context,
  StaticShockCache pluginCache,
) {
  pipeline.loadData(
    MyDataLoader(),
  );
}
```
