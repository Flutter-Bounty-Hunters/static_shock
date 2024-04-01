# Static Shock
A static site generator for Dart.

## How to use from the command line
To use Static Shock as a command-line tool, use the `static_shock_cli` package.

## How to use programmatically
To use Static Shock programmatically, create a new `StaticShock` instance, and then generate a static website.

```dart
final staticShock = StaticShock()
  ..pick(...)
  ..[configuration here]
  ..plugin(...)
  ..plugin(...);

// Generate a static website.
await staticShock.generateSite();
```
