/// Métadonnées injectées à la compilation CI (`--dart-define`).
class BuildInfo {
  const BuildInfo._();

  /// Version CalVer (`YYYY.M.N`), si fournie par la CI.
  static const version = String.fromEnvironment('PODAVIO_VERSION');

  /// Identifiant unique du pipeline GitLab (`CI_PIPELINE_ID`).
  static const gitlabPipelineId = String.fromEnvironment('GITLAB_PIPELINE_ID');

  /// Hash court du commit de release (`CI_COMMIT_SHORT_SHA`).
  static const commit = String.fromEnvironment('GITLAB_COMMIT_SHA');

  static bool get hasGitlabId => gitlabPipelineId.isNotEmpty;

  static bool get hasCommit => commit.isNotEmpty;
}
