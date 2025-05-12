---
title: The Repository
---
Static Shock lives on a GitHub, like most other open source projects.

To begin contributing, fork [the repository](https://github.com/flutter-bounty-hunters/static_shock) 
so that you can make and submit changes.

## A Monorepo
Static Shock is configured as a monorepo, which means that multiple packages
exist in the same repository.

 * `static_shock`: The implementation of Static Shock, witch which every static site builds.
 * `static_shock_cli`: A command line tool that makes it easy to generate, build, and test Static Shock websites.
 * `static_shock_docs`: The documentation website for Static Shock, which is built with Static Shock.

Each of the aforementioned tools is an independent Dart package. All of these
packages collectively comprise the Static Shock project on GitHub.