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

class MapTileBuildConfig {
  const MapTileBuildConfig({
    required this.urlTemplate,
    required this.userAgentPackageName,
  });

  static const defaultOpenStreetMapUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final String urlTemplate;
  final String userAgentPackageName;

  bool get usesDefaultOpenStreetMapTiles {
    return urlTemplate == defaultOpenStreetMapUrlTemplate;
  }

  String get providerLabel {
    return usesDefaultOpenStreetMapTiles ? 'OpenStreetMap 기본 타일' : '사용자 지정 타일';
  }

  String get userAgentLabel {
    return userAgentPackageName.isEmpty ? '요청 식별자 미설정' : userAgentPackageName;
  }
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

const mapTileBuildConfig = MapTileBuildConfig(
  urlTemplate: String.fromEnvironment(
    'MASILPET_MAP_TILE_URL_TEMPLATE',
    defaultValue: MapTileBuildConfig.defaultOpenStreetMapUrlTemplate,
  ),
  userAgentPackageName: String.fromEnvironment(
    'MASILPET_MAP_TILE_USER_AGENT',
    defaultValue: 'com.masilpet.app',
  ),
);
