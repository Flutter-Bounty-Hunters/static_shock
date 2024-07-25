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

# Static Shock CLI
The `static_shock_cli` package is the command-line interface for `static_shock`.

## Activate `static_shock_cli` from Pub

    dart pub global activate static_shock_cli

## Activate `static_shock_cli` from your machine
Activate the local package from anywhere on your machine:

    dart pub global activate --source=path /MY_ROOT_PATH/static_shock/static_shock_cli/

Activate the local package from the root of this repository:

    dart pub global activate --source=path ./static_shock_cli/

Activate the local package from the `static_shock_cli` directory:

    dart pub global activate --source=path .

## Project Templates
The Static Shock CLI helps users get started by creating an initial project
structure. The user can choose from multiple options, e.g., blog, documentation,
empty. Each of these starting project structures are called project templates.

Each template requires 3 representations:
* A buildable/runnable version to verify the correctness of the template.
    * Located at `/template_sources/**`
* A Mason "brick" version with values replaced by Mustache variables so it can be configured by users.
    * Located at `/static_shock_cli/templates/**`
* A Mason "bundle", which reduces the "brick" down to a single file to be included in the CLI package.
    * Located at `/static_shock_cli/lib/templates/**`

### Update a template for distribution
From time to time, it may be necessary to alter a Static Shock project template.
To do this, follow these three steps:

1. Update and verify the correctness of the runnable template under `/static_shock_cli/template_sources/**`.
2. Copy the new/changed files from the runnable template and overwrite the the files in `/static_shock_cli/templates/`.
3. In the template files you just pasted in `/static_shock_cli/templates/`, find and replace every
   hard-coded value with a variable. For changed files, you'll need to inspect the original files
   to ensure that you recover whatever variables you just overwrote.
4. Use `mason` to compile the template and overwrite the existing `bundle` file in `/static_shock_cli/lib/templates/`.

### Working with templates
Static Shock uses Mason to structure and read templates for project generation. Those templates are 
stored under:

    /templates/**

Dart CLI packages don't have an asset management system. Instead, a Dart CLI package must include 
any desired asset files under `/lib`. This creates an issue with Dart project templates because the
Dart build system would treat the template's source files as actual project files. This would blow
up the compiler in areas where we insert code generation values at runtime. For this reason, we
store templates outside the `/lib` directory.

To make the Brick templates usable by `static_shock_cli` as runtime, we have to "bundle" each
template into a single file. Those bundled versions of each template are stored under:

    /lib/templates/**

The bundled template files are shipped with the package. The full template directories are not.

To bundle a Brick directory into a single file, use:

    mason bundle path/to/brick/directory

For example, to update the existing template for `blog`, first run:

    mason bundle templates/blog

The bundle will be generated at the root of that package. The bundle then needs to be moved to its
final location at `lib/templates/blog.bundle`.

Mason uses Mustache templates to insert values in source file content and file names. Static Shock
uses Jinja templates, which also use "{{" and "}}" to insert values. Jinja brackets inside
of Mason templates need to use "mustache case" syntax to keep Mason from processing the Jinja
variables:

    {{#mustacheCase}} myVar {{/mustacheCase}}

