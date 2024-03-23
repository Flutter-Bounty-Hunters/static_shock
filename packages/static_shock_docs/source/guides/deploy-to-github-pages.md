---
title: Deploy to GitHub Pages
tags: publishing
---
# GitHub Pages
GitHub provides a free tool for building, deploying, and serving static websites - it's called
[GitHub Pages](https://pages.github.com/).

If you want fully automated GitHub Pages deployment without any intervention, you have to use a
static site generator called Jekyll. However, with a little bit of custom configuration, you can
setup an automatic build and deployment Action for Static Shock on GitHub Pages.

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

```yaml
name: Build and deploy website
on:
  push:
    branches:
      main
```

This configuration gives your Action a name, and tells GitHub to trigger this action whenever you
push a commit to `main`, or merge a PR into `main`.

### Create a build job in the Action file
We'll separate your Actions into two steps: build and deploy. First, we'll configure the build
process.

Add the following job to your `build_gh_pages.yaml` file:

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

GitHub will now run Static Shock to build your static website. Then, GitHub will upload your website
`/build` directory to the GitHub Pages system. However, you still need a step for deployment. We
separate build from deployment so that if one of those steps fail, it's easy to figure out why.

### Create a deployment job in the Action file
Tell GitHub to deploy your static website by adding the following step to your `build_gh_pages.yaml` 
file:

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

Your Static Shock website will now build and deploy every time you push a commit to `main`.

To configure a custom domain for your static website, check the [GitHub Pages Guides](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)
