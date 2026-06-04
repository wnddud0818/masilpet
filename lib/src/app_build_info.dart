class AppBuildInfo {
  const AppBuildInfo({
    required this.version,
    required this.channel,
    required this.builtAtUtc,
  });

  final String version;
  final String channel;
  final String builtAtUtc;

  bool get hasBuildTime => builtAtUtc.isNotEmpty && builtAtUtc != 'not-set';

  String get versionLabel => version.isEmpty ? 'local-dev' : version;

  String get channelLabel => channel.isEmpty ? 'local' : channel;

  String get buildTimeLabel => hasBuildTime ? builtAtUtc : 'local build';
}

const appBuildInfo = AppBuildInfo(
  version: String.fromEnvironment(
    'MASILPET_APP_VERSION',
    defaultValue: 'local-dev',
  ),
  channel: String.fromEnvironment(
    'MASILPET_BUILD_CHANNEL',
    defaultValue: 'local',
  ),
  builtAtUtc: String.fromEnvironment(
    'MASILPET_BUILD_TIME_UTC',
    defaultValue: 'not-set',
  ),
);
