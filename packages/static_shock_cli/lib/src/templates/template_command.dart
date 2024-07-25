import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:static_shock_cli/src/templates/blog_template.dart';
import 'package:static_shock_cli/src/templates/docs_multi_page_template.dart';
import 'package:static_shock_cli/src/templates/empty_template.dart';

class TemplateCommand extends Command {
  TemplateCommand(Logger log) {
    addSubcommand(EmptyTemplateCommand(log));
    addSubcommand(BlogTemplateCommand(log));
    addSubcommand(DocsMultiPageTemplateCommand(log));
  }

  @override
  String get name => "template";

  @override
  String get description => "Create a project from a template.";
}
