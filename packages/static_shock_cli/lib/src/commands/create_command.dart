import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:static_shock_cli/src/project_maintenance/build_project.dart';
import 'package:static_shock_cli/src/templates/blog_template.dart';
import 'package:static_shock_cli/src/templates/docs_multi_page_template.dart';
import 'package:static_shock_cli/src/templates/empty_template.dart';
import 'package:static_shock_cli/src/version_check.dart';

/// CLI [Command] that generates a new Static Shock project based on user preferences.
class CreateCommand extends Command with PubVersionCheck {
  static const _templateNamesById = {
    _TemplateType.blog: "Blog",
    _TemplateType.docsMultiPage: "Documentation (multiple pages)",
    // TODO: create single-page docs template
    // _TemplateType.docsSinglePage: "Documentation (single page)",
    _TemplateType.empty: "Empty",
  };

  CreateCommand(this.log);

  @override
  final Logger log;

  @override
  final name = "create";

  @override
  final description = "Creates a new static site project at the desired location.";

  @override
  bool get takesArguments => true;

  @override
  Future<void> run() async {
    await super.run();

    log.info("Welcome to Static Shock! Let's get you started with a new project!");
    log.info("");
    log.info("We'll ask you a series of questions, and then we'll generate a custom website project just for you.");
    log.info("");

    final templateType = log.chooseOne(
      "First, please choose a template for your project:",
      choices: _TemplateType.values,
      display: (templateId) => _templateNamesById[templateId]!,
    );
    log.info("");

    log.info("You chose: ${_templateNamesById[templateType]}.");
    log.info("");
    log.info("We'll ask you a series of questions to configure the template for your specific needs...");
    log.info("");

    late final Directory targetDirectory;
    switch (templateType) {
      case _TemplateType.blog:
        targetDirectory = await runBlogTemplateWizard(log);
      // case _TemplateType.docsSinglePage:
      //   // TODO: Handle this case.
      case _TemplateType.docsMultiPage:
        targetDirectory = await runMultiPageDocsTemplateWizard(log);
      case _TemplateType.empty:
        targetDirectory = await runEmptyTemplateWizard(log);
    }

    log.success("Your new Static Shock website has been generated!\n");
    final shouldInitialize = log.confirm("Would you like to immediately run a build of your new website?");
    log.info("");

    log.info("--------------------------------------");
    if (shouldInitialize) {
      await Project.pubGet(log: log, workingDirectory: targetDirectory);
      await Project.build(log: log, workingDirectory: targetDirectory);
    }
    log.info("--------------------------------------");
    log.info("");

    log.success("Congratulations, your new Static Shock website is ready!");
    log.detail("To learn how to further configure your website, please check our guides at https://staticshock.io");
  }
}

enum _TemplateType {
  blog,
  // TODO: add single page template
  // docsSinglePage,
  docsMultiPage,
  empty,
}
