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

## Quickstart
Generate a new Static Shock project with `static_shock_cli`:

```sh
# Activate the CLI tool.
dart pub global activate static_shock_cli

# Generate a new project.
shock create
```

Once you've created a project, you can (re)build your static site as needed:

```sh
# Build directly
dart bin/my_site.dart

# Or, build with the CLI tool
shock build
```

To demo your static site, run a local server from your project directory, using the CLI tool:

    shock serve

The local server automatically rebuilds and reloads your pages as you work.

## Packages
Packages in this repository:

 * `/packages/static_shock_cli`: project that implements the Static Shock CLI tool.
 * `/packages/static_shock`: the core of Static Shock, which builds static websites.
 * `/packages/static_shock_docs`: the website for Static Shock documentation.

## Development
This repository is a mono-repo. To work with it, you need Melos available on your path:

    dart pub global activate melos

When you first open the root of the project for development, bootstrap Melos:

    melos bootstrap

