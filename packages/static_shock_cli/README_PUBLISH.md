# Publishing static_shock_cli
Follow these steps to publish a new version of `static_shock_cli`:

 1. Increment the package version in `pubspec.yaml`.
 2. Update the `CHANGELOG.md` with all changes since the last release.
 3. Run `dart run build_runner build` to update the package version number in generated code.
 4. Run `melos publish` to validate and publish the package.
