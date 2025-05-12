---
title: Data Index
---
The `DataIndex` is the primary way that data is shared between steps of the
pipeline, and between plugins. The `DataIndex` is also the primary means by which
data is made available to page renderers, such as the Jinja page renderer.

The `DataIndex` can be accessed through the `StaticShockPipelineContext`.

## Hierarchical Data
The `DataIndex` is hierarchical, similar to a JSON object, which can contain other
JSON objects.

Data can be pulled from multiple locations and merged into the `DataIndex`.

Data can be queried in two unique ways: data can be requested for a specified path,
or data can be inherited up to and including a specified path.

### Data Sources
#### Data Pulled from Directories
One of the places where data can be contributed to the `DataIndex` is from
files called `_data.yaml`, which users can place within any sub-directory in
the source directory.

```
/source
  _data.yaml
  /guides
    _data.yaml
  /contributing
    _data.yaml
```

When data is pulled from these `_data.yaml` files, the data in each file is
stored in a hierarchy that resembles the directory structure:

```
{
  "topLevel": "some top level value",
  "guides": {
    "inGuides": "some value from the guides directory" 
  },
  "contributing": {
    "inContributing": "some value from the contributing directory"
  }
}
```

#### Data Loaded by `DataLoader`s
Developers can register `DataLoader`s to merge arbitrary data into the `DataIndex`.

A `DataLoader` can return its own hierarchical structure. For example, the GitHub
plugin returns contributor data.

```
{
  "github": {
    "flutter-bounty-hunters": {
      "static_shock": [...],
      "super_editor": [...]
    }
  }
}
```

When the GitHub plugin loads contributor data, the `DataIndex` might already have
data in it.

```
{
  "rootUrl": "https://flutterbountyhunters.github.io",
  "basePath": "/static_shock/",
  "pub": {
    "packages": ["static_shock", "static_shock_cli"]
  }
}
```

The GitHub plugin's data is merged, key-by-key, from the top level of the existing
`DataIndex` structure. In this particular example, that means that the `github`
object is added to the existing `DataIndex`.

```
{
  "rootUrl": "https://flutterbountyhunters.github.io",
  "basePath": "/static_shock/",
  "pub": {
    "packages": ["static_shock", "static_shock_cli"]
  },
  "github": {
    "flutter-bounty-hunters": {
      "static_shock": [...],
      "super_editor": [...]
    }
  }
}
```

It's recommended that plugins use keys that are unlikely to be used by other plugins.

#### Merging New Data into the Index
When using `_data.yaml` files, or providing data through a `DataLoader`, data is 
automatically merged into the `DataIndex` without writing any code. When working
directly with a `DataIndex`, developers must instruct the `DataIndex` to merge the
given data at a desired path.

When merging data, the developer specifies the path where the provided data should
be merged. I.e., data doesn't have to be inserted at the root of `DataIndex`.

```dart
dataIndex.mergeAtPath(
  DirectoryRelativePath("/contact"),
  {
    "email": "me@gmail.com",
  },
);
```

### Data Queries
#### Data at a Path
The `DataIndex` has a tree structure, and arbitrary data can be stored at every
level of that tree. As a result of the hierarchical structure, data is accessed 
by a path, rather than a key.

The following example queries the data at the path `/guides/inGuides`, which
happens to be a `String` value.

```dart
final guidesValue = dataIndex.getAtPath(["guides", "inGuides"]) as String;
```

Developers can query the entire collection of data at a given path, too, as
shown in the following example.

```dart
final guidesValue = dataIndex.getAtPath(["guides"]) as Map<String, dynamic>;
```

#### Data Inheritance at a Path
The primary reason that the `DataIndex` is hierarchical is so that a given `Page`
can be rendered with all of the `Page`'s data, along with all data contributed
from all higher directories, up to the root.

Consider the website's `basePath`, which is defined at the top level of the `DataIndex`.

```
{
  "basePath": "/static_shock/"
}
```

The `basePath` is critical for building links. Despite `basePath` being defined at the 
root of the `DataIndex`, we want this property to be available to every `Page` in the 
website.

There might be any number of properties that a developer wants to be available to sub-pages.

For this reason, the `DataIndex` supports querying an entire subtree, which we call
data inheritance. Inherited data is provided automatically to each `Page` in the pipeline.
Inherited data can also be queried directly from the `DataIndex`. 

The following example shows how to query data from `/`, `/guides`, `/guides/getting-started`, 
and `/guides/getting-started/overview` all in one returned data structure.

```dart
final data = dataIndex.inheritDataForPath(
  DirectoryRelativePath("/guides/getting-started/overview"),
);
```

In addition to querying scoped data, data inheritance also supports overwriting higher
level data. Consider the following `DataIndex` data.

```
{
  "title": "root",
  "guides": {
    "title": "guides",
    "getting-started": {
      "title": "getting-started",
      "overview": {
        "title": "overview
      }
    }
  }
}
```

Then, given the data above, consider the following inherited data query.

```dart
final data = dataIndex.inheritDataForPath(
  DirectoryRelativePath("/guides/getting-started/overview"),
);
```

The returned data would look like the following.

```
{
  "title": "overview"
}
```

Notice that the returned data doesn't have the same levels of hierarchy as
the original `DataIndex`. That's because all levels of data across `/`,
`/guides`, `/guides/getting-started`, and `/guides/getting-started/overview`
were all merged together and then returned. When they were merged, there were
conflicts for the `title` property. When inheriting data, the lowest level
value wins. In this case, that lowest level value was `"overview"`.

Not only does inherited data work this way when querying the `DataIndex` directly,
it also works this way with `_data.yaml` files. Developers can re-define
properties in lower level `_data.yaml` files and they will overwrite the existing
values from higher level `_data.yaml` files.
