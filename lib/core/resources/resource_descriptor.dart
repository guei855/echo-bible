enum AppLanguage { fr, en }

enum ResourceLanguage { fr, en, common }

enum ResourceCategory {
  bible,
  strong,
  nave,
  crossReferences,
  dictionary,
  commentary,
  timeline,
  audio,
}

enum RedistributionStatus { permitted, licenseRequired, unavailable }

enum OfflineResourceId {
  lsg,
  darby,
  ostervald,
  neoCrampon,
  martin,
  paroleDeVie,
  francaisCourant,
  bibleAmplifiee,
  worldEnglishBible,
  strong,
  crossReferences,
  nave,
  naveFrench,
  dictionary,
  commentaries,
}

enum OfflineResourceState {
  installed,
  notInstalled,
  updateAvailable,
  downloading,
  error,
  licenseRequired,
  unavailable,
  readyForHosting,
  preparing,
}

class ResourceDescriptor {
  final OfflineResourceId id;
  final String name;
  final String shortName;
  final ResourceLanguage language;
  final ResourceCategory category;
  final String description;
  final String version;
  final int? sizeBytes;
  final String? downloadUrl;
  final String? sha256;
  final String license;
  final String source;
  final String sourceUrl;
  final bool bundled;
  final String? installedVersion;
  final String localFileName;
  final String? copyrightHolder;
  final RedistributionStatus redistributionStatus;

  const ResourceDescriptor({
    required this.id,
    required this.name,
    required this.shortName,
    required this.language,
    required this.category,
    required this.description,
    required this.version,
    this.sizeBytes,
    this.downloadUrl,
    this.sha256,
    required this.license,
    required this.source,
    required this.sourceUrl,
    this.bundled = false,
    this.installedVersion,
    required this.localFileName,
    this.copyrightHolder,
    this.redistributionStatus = RedistributionStatus.permitted,
  });

  String get title => name;
  String get availableVersion => version;
  bool get canDownload =>
      redistributionStatus == RedistributionStatus.permitted &&
      downloadUrl != null &&
      sha256 != null &&
      sizeBytes != null;
  bool get readyForHosting =>
      redistributionStatus == RedistributionStatus.permitted &&
      downloadUrl == null &&
      sha256 != null &&
      sizeBytes != null;

  ResourceDescriptor copyWith({String? downloadUrl}) => ResourceDescriptor(
        id: id,
        name: name,
        shortName: shortName,
        language: language,
        category: category,
        description: description,
        version: version,
        sizeBytes: sizeBytes,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        sha256: sha256,
        license: license,
        source: source,
        sourceUrl: sourceUrl,
        bundled: bundled,
        installedVersion: installedVersion,
        localFileName: localFileName,
        copyrightHolder: copyrightHolder,
        redistributionStatus: redistributionStatus,
      );
}
