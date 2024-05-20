## 0.0.6 - May 20, 2024
 * Added a template for doc websites: `shock templates docs`
 * Upgraded `static_shock` to `0.0.5`
 * Version check is now done silently - only visible if version is out of date
 * Improved instructions for how to upgrade their CLI version
 * Fixed terminal colors so that they work through `shock build` and `shock serve`

## 0.0.5 - April 9, 2024
 * Upgraded `static_shock` to `0.0.4` to resolve a dependency conflict.

## 0.0.4 - April 9, 2024
 * Project creation: the chosen package name is validated against Dart standards.
 * All CLI commands fail more gracefully.
 * Reduced dev server crashes by only refreshing connected webpages after all queued builds compete.
 * Upgraded internal `static_shock` dependency to `0.0.3`.

## 0.0.3 - March 23, 2024
`shock build` and `shock serve` can take extra custom arguments, e.g. `shock serve preview`.

## 0.0.2 - Dec 10, 2023
`shock serve` auto-refreshes HTML pages on change, dev server port is configurable.

## 0.0.1 - July 19, 2023
First non-preview release.

Commands:
 * `shock create`
 * `shock build`
 * `shock serve`
 * `shock version`
 * `shock upgrade`

## 0.0.1-dev.5 - July 1, 2023
Added version checks to notify users when newer versions of the CLI are available.

## 0.0.1-dev.4 - June 17, 2023
Fixed "new project" Mason template variable syntax.

## 0.0.1-dev.3 - June 14, 2023
Fixed "new project" template resolution to work in a global pub scenario.

## 0.0.1-dev.2 - June 12, 2023
Updated template to match `static_shock` `v0.0.1-dev.2`.

## 0.0.1-dev.1 - June 9, 2023
Initial release: Includes `create` and `serve` behavior.