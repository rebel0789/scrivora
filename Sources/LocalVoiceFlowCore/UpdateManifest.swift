import Foundation

public struct AppUpdateManifest: Codable, Equatable, Sendable {
    public var appID: String
    public var version: String
    public var build: String?
    public var channel: String
    public var minimumSystemVersion: String?
    public var downloadURL: URL
    public var sha256: String
    public var archiveSizeBytes: Int64?
    public var releaseNotesURL: URL?
    public var notes: [String]
    public var critical: Bool

    public init(
        appID: String,
        version: String,
        build: String? = nil,
        channel: String = "stable",
        minimumSystemVersion: String? = nil,
        downloadURL: URL,
        sha256: String,
        archiveSizeBytes: Int64? = nil,
        releaseNotesURL: URL? = nil,
        notes: [String] = [],
        critical: Bool = false
    ) {
        self.appID = appID
        self.version = version
        self.build = build
        self.channel = channel
        self.minimumSystemVersion = minimumSystemVersion
        self.downloadURL = downloadURL
        self.sha256 = sha256
        self.archiveSizeBytes = archiveSizeBytes
        self.releaseNotesURL = releaseNotesURL
        self.notes = notes
        self.critical = critical
    }

    private enum CodingKeys: String, CodingKey {
        case appID
        case version
        case build
        case channel
        case minimumSystemVersion
        case downloadURL
        case sha256
        case archiveSizeBytes
        case releaseNotesURL
        case notes
        case critical
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.appID = try container.decode(String.self, forKey: .appID)
        self.version = try container.decode(String.self, forKey: .version)
        self.build = try container.decodeIfPresent(String.self, forKey: .build)
        self.channel = try container.decodeIfPresent(String.self, forKey: .channel) ?? "stable"
        self.minimumSystemVersion = try container.decodeIfPresent(String.self, forKey: .minimumSystemVersion)
        self.downloadURL = try container.decode(URL.self, forKey: .downloadURL)
        self.sha256 = try container.decode(String.self, forKey: .sha256)
        self.archiveSizeBytes = try container.decodeIfPresent(Int64.self, forKey: .archiveSizeBytes)
        self.releaseNotesURL = try container.decodeIfPresent(URL.self, forKey: .releaseNotesURL)
        self.notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
        self.critical = try container.decodeIfPresent(Bool.self, forKey: .critical) ?? false
    }
}

public enum AppUpdateVersionComparator {
    public static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        compare(candidate, current) == .orderedDescending
    }

    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = normalizedComponents(lhs)
        let right = normalizedComponents(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue > rightValue { return .orderedDescending }
            if leftValue < rightValue { return .orderedAscending }
        }

        return .orderedSame
    }

    private static func normalizedComponents(_ version: String) -> [Int] {
        version
            .split(separator: "-")
            .first
            .map(String.init)?
            .split(separator: ".")
            .map { component in
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            } ?? [0]
    }
}
