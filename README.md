# Static Shock
A static site generator, written in dart.

For documentation, visit [staticshock.io](https://staticshock.io)

## Quickstart
Generate a new Static Shock project with `static_shock_cli`:

    # Activate the CLI tool.
    dart pub global activate static_shock_cli

    # Generate a new project.
    shock create

Once you've created a project, you can (re)build your static site as needed:

    dart bin/my_site.dart

To demo your static site, run a local server from your project directory, using the CLI tool:

    shock serve

## Packages
Packages in this repository:

 * `/packages/static_shock_cli`: project that implements the Static Shock CLI tool.
 * `/packages/static_shock`: the core of Static Shock, which builds static websites.
 * `/packages/static_shock_docs`: the website for Static Shock documentation.