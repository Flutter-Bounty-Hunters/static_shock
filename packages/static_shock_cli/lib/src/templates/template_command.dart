import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:static_shock_cli/src/templates/docs_template_cli.dart';
import 'package:static_shock_cli/src/templates/empty_template.dart';

class TemplateCommand extends Command {
  TemplateCommand(Logger log) {
    addSubcommand(EmptyTemplateCommand(log));
    addSubcommand(DocsTemplateCommand(log));
  }

  @override
  String get name => "template";

  @override
  String get description => "Create a project from a template.";
}
