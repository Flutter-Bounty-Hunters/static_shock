import 'dart:convert';

import 'package:github/github.dart';
import 'package:http/http.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/data.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

/// A [StaticShockPlugin] that loads lists of contributors into the pipeline data hierarchy.
///
/// Contributor lists can be found within the data hierarchy at:
///
///     data["github"][{MY_ORGANIZATION}][{MY_REPOSITORY_NAME}]
///
/// Repositories can be requested in two ways.
///
/// The first way is through code. Wherever you instantiate this plugin, pass desired
/// repositories in [repositories].
///
/// The second way is through a configuration file. Create a top-level file under the source
/// directory called `_data.yaml` and then declare desired repositories under `github`:
///
///     github:
///       contributors:
///         repositories:
///           - { organization: flutter-bounty-hunters, name: static_shock }
///
class GitHubContributorsPlugin extends StaticShockPlugin {
  GitHubContributorsPlugin({
    required this.authToken,
    this.repositories = const {},
  });

  @override
  final id = "io.staticshock.githubcontributors";

  /// GitHub auth token that's tied to a GitHub account.
  ///
  /// GitHub allows many more API calls given an auth token. If [authToken] is `null` then
  /// API calls are made anonymously, which is more restricted by GitHub.
  final String? authToken;

  /// A set of repositories for which this plugin should load lists of contributors.
  ///
  /// There are two ways to request the loading of contributors. Passing the repositories
  /// into this property is one way. Another way is to declare repositories in a top-level
  /// `_data.yaml` file in the project source code.
  final Set<GitHubRepository> repositories;

  @override
  void configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.loadData(_GitHubDataLoader(authToken, repositories));
  }
}

class _GitHubDataLoader implements DataLoader {
  const _GitHubDataLoader(this.authToken, [this.repositories = const {}]);

  final String? authToken;
  final Set<GitHubRepository> repositories;

  @override
  Future<Map<String, Object>> loadData(StaticShockPipelineContext context) async {
    final httpClient = Client();
    final github = GitHub(
      auth: authToken != null ? Authentication.withToken(authToken) : Authentication.anonymous(),
      client: httpClient,
    );

    // Collect all the different repositories for which we want the contributors list.
    final allDesiredRepositories = _desiredRepositories(context);

    // Request all desired repository contributors.
    final apiFutures = allDesiredRepositories.map((repo) => _fetchRepositoryContributors(context.log, github, repo));

    // Wait for all GitHub API calls to return.
    List<_GitHubRepositoryContributors> contributorsByOrganizationAndRepo = await Future.wait(apiFutures);

    // We have to manually close the HTTP client because the GitHub package seems to leave it
    // open, which then causes the CLI to hang for about 20 seconds after our code is done.
    httpClient.close();

    // Construct contributor data that's available to the rest of the pipeline in the following structure:
    //
    // {
    //   "github": {
    //     "flutter-bounty-hunters": {
    //       "static_shock": [{
    //         "userId": "some-user",
    //         "userUrl": "github.com/some-user",
    //         "avatarUrl": "avatars.githubusercontent.com/avatars/some-avatar.png",
    //       }],
    //     },
    //   },
    // }
    final organizations = <String, dynamic>{};
    for (final repo in contributorsByOrganizationAndRepo) {
      if (!organizations.containsKey(repo.repository.organization)) {
        organizations[repo.repository.organization] = <String, dynamic>{};
      }

      final organization = organizations[repo.repository.organization] as Map<String, dynamic>;
      organization[repo.repository.name] = repo.contributors
          .map((contributor) => <String, dynamic>{
                "userId": contributor.userId,
                "userUrl": contributor.userUrl,
                "avatarUrl": contributor.avatarUrl,
              })
          .toList();
    }

    final contributorData = {
      "github": organizations,
    };

    return contributorData;
  }

  Set<GitHubRepository> _desiredRepositories(StaticShockPipelineContext context) {
    final allDesiredRepositories = Set<GitHubRepository>.from(repositories);

    final dataRepos = context.dataIndex.getAtPath(["github", "contributors", "repositories"]) as List<dynamic>?;
    if (dataRepos != null) {
      allDesiredRepositories.addAll(
        dataRepos.map(
          (dynamic repoData) => GitHubRepository(
            organization: repoData["organization"],
            name: repoData["name"],
          ),
        ),
      );
    }

    return allDesiredRepositories;
  }

  Future<_GitHubRepositoryContributors> _fetchRepositoryContributors(
      Logger log, GitHub github, GitHubRepository repository) async {
    late final Object json;
    try {
      json = await github.requestJson("GET", "repos/${repository.organization}/${repository.name}/contributors");
    } catch (exception) {
      log.warn("Failed to load GitHub contributors:\n${exception}");
      return _GitHubRepositoryContributors(repository, const []);
    }

    if (json is! List<dynamic>) {
      log.warn("Received unexpected response from GitHub:");
      log.warn(const JsonEncoder.withIndent("  ").convert(json));
      return _GitHubRepositoryContributors(repository, []);
    }

    return _GitHubRepositoryContributors(
      repository,
      json.map((dynamic contributor) {
        return _GitHubContributor(
          userId: contributor["login"],
          userUrl: contributor["html_url"],
          avatarUrl: contributor["avatar_url"],
        );
      }).toList(),
    );
  }
}

/// Identifying information for a specific repository on GitHub.
class GitHubRepository {
  const GitHubRepository({
    required this.organization,
    required this.name,
  });

  /// Name of the GitHub owner/organization, e.g., "flutter_bounty_hunters".
  final String organization;

  /// Name of the GitHub repo, e.g., "static_shock".
  final String name;

  @override
  String toString() => "[GitHubRepository] - organization: $organization, name: $name";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubRepository &&
          runtimeType == other.runtimeType &&
          organization == other.organization &&
          name == other.name;

  @override
  int get hashCode => organization.hashCode ^ name.hashCode;
}

class _GitHubRepositoryContributors {
  const _GitHubRepositoryContributors(this.repository, this.contributors);

  final GitHubRepository repository;
  final List<_GitHubContributor> contributors;
}

class _GitHubContributor {
  const _GitHubContributor({
    required this.userId,
    required this.userUrl,
    required this.avatarUrl,
  });

  final String userId;
  final String userUrl;
  final String avatarUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GitHubContributor &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          userUrl == other.userUrl &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode => userId.hashCode ^ userUrl.hashCode ^ avatarUrl.hashCode;
}
