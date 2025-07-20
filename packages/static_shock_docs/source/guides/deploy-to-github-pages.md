---
title: Deploy to GitHub Pages
tags: publishing
contentRenderers:
  - jinja
  - markdown
---
GitHub provides a free tool for building, deploying, and serving static websites - it's called
[GitHub Pages](https://pages.github.com/).

If you want fully automated GitHub Pages deployment without any intervention, you have to use a
static site generator called Jekyll. However, with a little bit of custom configuration, you can
setup an automatic build and deployment Action for Static Shock on GitHub Pages.

## Set the website base path
Are you using a custom domain, or are you using the domain provided by GitHub Pages?

A custom domain looks like `https://staticshock.io/`.

A GitHub Pages domain looks like `https://flutterbountyhunters.github.io/static_shock/`.

The GitHub Pages domain automatically inserts the name of your GitHub package as a base path
for all URLs in your website.

Custom domains don't require any additional configuration. However, if you're using the GitHub Pages 
domain, you **must** configure the base path of your Static Shock website.

{% raw %}
```dart
StaticShock(
  site: SiteMetadata(
    basePath: "/static_shock/",
    // ^ replace with your actual base path.
  ),
);
```
{% endraw %}

Learn more about [base paths]({{ "guides/base-url" | local_link }}).

### Run locally with a base path
When running your Static Shock website locally, the Static Shock dev server supports
simulating a custom base path.

See the [base paths guide]({{ "guides/base-url" | local_link }}) for more information.

## Build and deploy a GitHub Pages website with Static Shock
First, configure your Static Shock website project as you would for any other purpose. Make sure
that you're able to run a Static Shock build locally, as expected.

### Create a GitHub Action file
Once your Static Shock website builds the way you want locally, it's time to configure a GitHub Action
to build and deploy your Static Shock website to GitHub Pages.

At the root of your repository, create the following directories and file:

    /.github/workflows/build_gh_pages.yaml

The name of `build_gh_pages.yaml` can be whatever you'd like.

When you commit this file to your repository, and push to GitHub, GitHub will automatically identify
this file as an Action definition. GitHub will then follow whatever instructions are in the file.

In the `build_gh_pages.yaml` file, add the following configuration:

{% raw %}
```yaml
name: Build and deploy website
on:
  push:
    branches:
      main
```
{% endraw %}

This configuration gives your Action a name, and tells GitHub to trigger this action whenever you
push a commit to `main`, or merge a PR into `main`.

### Create a build job in the Action file
We'll separate your Actions into two steps: build and deploy. First, we'll configure the build
process.

Add the following job to your `build_gh_pages.yaml` file:

{% raw %}
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    defaults:
      run:
        # If your website isn't at the root of your repository, then
        # specify your website directory as your working directory for
        # this job. Otherwise, you don't need any "defaults".
        working-directory: ./packages/static_shock_docs
    steps:
      # Checkout the repository
      - uses: actions/checkout@v3

      # Setup a Dart environment
      - uses: dart-lang/setup-dart@v1

      # Download all the packages that the app uses
      - run: dart pub get

      # Build the static site
      # Replace the following Dart file name with your project's main executable.
      - run: dart run bin/my_project_name.dart

      # Zip and upload the static site.
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v1
        with:
          # Replace the following with the local repository path
          # to your Static Shock build directory.
          path: ./packages/static_shock_docs/build
```
{% endraw %}

GitHub will now run Static Shock to build your static website. Then, GitHub will upload your website
`/build` directory to the GitHub Pages system. However, you still need a step for deployment. We
separate build from deployment so that if one of those steps fail, it's easy to figure out why.

### Create a deployment job in the Action file
Tell GitHub to deploy your static website by adding the following step to your `build_gh_pages.yaml` 
file:

{% raw %}
```yaml
  deploy:
    name: Deploy
    needs: build
    runs-on: ubuntu-latest
    
    # Grant GITHUB_TOKEN the permissions required to make a Pages deployment
    permissions:
      pages: write      # to deploy to Pages
      id-token: write   # to verify the deployment originates from an appropriate source
    
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v2
```
{% endraw %}

Your Static Shock website will now build and deploy every time you push a commit to `main`.

To configure a custom domain for your static website, check the [GitHub Pages Guides](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)

## Commit your website cache
Some Static Shock plugins write to a local cache located at `[source]/.shock/cache/`. For example,
the `LinksPlugin` writes all known page paths to that cache, so that you don't accidentally remove
pages between deployments. This cache should be checked into version control, but it should also
be updated whenever you deploy.

When using GitHub Pages with auto-deployment, your deployment happens within a GitHub workflow.
Therefore, you should capture any cache changes that happen during your workflow, and commit them
to your repository.

Here is an example of a couple steps that you can add after your "Upload artifact" step, which
will automatically generate a PR into your repository whenever your GitHub deployment causes changes
to your cache.

{% raw %}
```yaml
- name: Check for cache changes
  id: detect_changes
  run: |
    # Check for changes to the cache.
    if [[ -n "$(git status --porcelain source/.shock/cache)" ]]; then
      echo "Changes detected in the source cache"
      echo "changed=true" >> "$GITHUB_OUTPUT"
    else
      echo "No changes in the source cache"
      echo "changed=false" >> "$GITHUB_OUTPUT"
    fi

- name: Create cache update pull request
  if: steps.detect_changes.outputs.changed == 'true'
  uses: peter-evans/create-pull-request@v6
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    base: main
    branch: cache-updates-${{ github.run_id }}
    title: "[GitHub] - Update source cache for latest deployment"
    body: "Auto-generated update to the source cache after the latest public deployment."
    commit-message: "[GitHub Deployment] - Push changes to the source cache (run ID: ${{ github.run_id }})  [skip ci]"
    committer: "github-actions[bot] <github-actions[bot]@users.noreply.github.com>"
    labels: generated
    reviewers: [your-github-id]
```
{% endraw %}

With these new steps, whenever your website is deployed from GitHub actions, GitHub
will also create a new PR with cache changes. You'll need to explicitly merge each of
those PRs.

One thing to keep in mind is that you now have GitHub auto-building your website every
time you merge into `main`, and then also creating PRs that you then merge into `main`.
This could cause an infinite workflow loop. To prevent this, the above example includes
"[skip ci]" in the commit message. This is a syntax that's understood by GitHub and will
cause GitHub to skip any workflows that would otherwise run on that commit. This way, when
your build generates a PR, your PR won't generate another build.