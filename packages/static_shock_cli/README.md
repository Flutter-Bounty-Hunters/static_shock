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

## Working with templates
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

For example, to update the existing template for `new_project`, first run:

    mason bundle templates/new_project

The bundle will be generated at the root of that package. The bundle then needs to be moved to its
final location at `lib/templates/new_project.bundle`.

Mason uses Mustache templates to insert values in source file content and file names. Static Shock
uses Jinja templates, which also use "{{" and "}}" to insert values. Jinja brackets inside
of Mason templates need to use "mustache case" syntax to keep Mason from processing the Jinja
variables:

    {{#mustacheCase}} myVar {{/mustacheCase}}

