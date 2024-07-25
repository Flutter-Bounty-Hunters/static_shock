<p align="center">
  <img src="https://github.com/Flutter-Bounty-Hunters/static_shock/assets/7259036/00c27c9f-4efd-4a8f-92fc-0856bf64764a" alt="Static Shock - A static site generator, written in Dart">
</p>

<p align="center">
  <a href="https://flutterbountyhunters.com" target="_blank">
    <img src="https://github.com/Flutter-Bounty-Hunters/flutter_test_robots/assets/7259036/1b19720d-3dad-4ade-ac76-74313b67a898" alt="Built by the Flutter Bounty Hunters">
  </a>
</p>

---

For documentation, visit [staticshock.io](https://staticshock.io)

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
