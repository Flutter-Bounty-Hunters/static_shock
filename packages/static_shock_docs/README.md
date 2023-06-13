# Static Shock Documentation Website
This project generates the documentation website for Static Shock.

The Static Shock documentation website is built with Static Shock.

## Releasing
Before releasing, first build a new version of the website:

    dart bin/static_shock_docs.dart

Verify the newly built website:

    shock serve

Upload to Firebase hosting:

    firebase deploy --only hosting

