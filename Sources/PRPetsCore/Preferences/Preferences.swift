import Foundation

/// How far pets wander from the doghouse.
public enum RoamingArea: String, CaseIterable, Hashable, Codable, Sendable {
    /// A strip either side of the doghouse, `roamingWidth` points wide.
    case nearDoghouse
    /// The full width of the screen the doghouse is on.
    case screenWidth
}

public enum DataSourceKind: String, CaseIterable, Hashable, Codable, Sendable {
    case github
    /// Scripted fake PRs, for trying the app out or taking screenshots.
    case demo
}

/// Every user-facing setting, with its default. Decoding tolerates missing keys so old preferences files
/// keep working as preferences are added.
public struct Preferences: Hashable, Codable, Sendable {
    // Data
    public var dataSource: DataSourceKind = .github
    public var pollIntervalMinutes: Double = 3
    /// Path to `gh`. Empty means search the usual install locations.
    public var ghExecutablePath: String = ""
    /// GitHub host for Enterprise Server installs. Empty means github.com.
    public var githubHost: String = ""
    public var includeTeamReviewRequests: Bool = true
    public var onlyOwners: [String] = []
    public var excludedRepositories: [String] = []
    public var showStackContext: Bool = true

    // Pets
    public var hideWhenApprovedByOthers: Bool = true
    public var maximumPets: Int = 12
    public var labelStyle: PetLabelStyle = .authorLogin
    public var showHoverCards: Bool = true
    public var allowedSpecies: [Species] = Species.allCases
    public var petsAreInside: Bool = false
    public var petLanes: Set<Lane> = PetPresencePolicy.defaultPetLanes

    // Placement
    /// Points per art pixel.
    public var scale: Double = 3
    public var roamingArea: RoamingArea = .nearDoghouse
    /// Width of the roaming strip in points when `roamingArea` is `.nearDoghouse`.
    public var roamingWidth: Double = 520
    public var placement: DoghousePlacement = .default

    // App
    public var showMenuBarIcon: Bool = true
    public var launchAtLogin: Bool = false
    public var checkForUpdatesAutomatically: Bool = true

    public init() {}

    public static let `default` = Preferences()

    public static let scaleRange: ClosedRange<Double> = 1...8
    public static let pollIntervalRange: ClosedRange<Double> = 1...60

    public var pullRequestQuery: PullRequestQuery {
        PullRequestQuery(owners: onlyOwners, excludedRepositories: excludedRepositories, includeStackContext: showStackContext)
    }

    public var queuePolicy: QueuePolicy {
        QueuePolicy(includeTeamReviewRequests: includeTeamReviewRequests)
    }

    public var presencePolicy: PetPresencePolicy {
        PetPresencePolicy(
            hideWhenApprovedByOthers: hideWhenApprovedByOthers,
            maximumPets: maximumPets,
            labelStyle: labelStyle,
            allowedSpecies: allowedSpecies,
            petLanes: petLanes
        )
    }

    public var pollInterval: Duration {
        .seconds(Self.pollIntervalRange.clamp(pollIntervalMinutes) * 60)
    }
}

/// Where the doghouse sits, as fractions of the screen's visible frame so it survives resolution changes.
public struct DoghousePlacement: Hashable, Codable, Sendable {
    /// Identifies the display (CGDirectDisplayID's localized name is not unique, so we store the number).
    public var displayID: UInt32?
    /// 0 = left edge, 1 = right edge; refers to the doghouse centre.
    public var horizontalFraction: Double
    /// 0 = bottom of the visible frame (just above the Dock), 1 = top; refers to the ground line.
    public var verticalFraction: Double

    public init(displayID: UInt32? = nil, horizontalFraction: Double, verticalFraction: Double) {
        self.displayID = displayID
        self.horizontalFraction = horizontalFraction
        self.verticalFraction = verticalFraction
    }

    public static let `default` = DoghousePlacement(horizontalFraction: 0.85, verticalFraction: 0)
}

extension Preferences {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Preferences()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        self.init()
        dataSource = value(.dataSource, defaults.dataSource)
        pollIntervalMinutes = value(.pollIntervalMinutes, defaults.pollIntervalMinutes)
        ghExecutablePath = value(.ghExecutablePath, defaults.ghExecutablePath)
        githubHost = value(.githubHost, defaults.githubHost)
        includeTeamReviewRequests = value(.includeTeamReviewRequests, defaults.includeTeamReviewRequests)
        onlyOwners = value(.onlyOwners, defaults.onlyOwners)
        excludedRepositories = value(.excludedRepositories, defaults.excludedRepositories)
        showStackContext = value(.showStackContext, defaults.showStackContext)
        hideWhenApprovedByOthers = value(.hideWhenApprovedByOthers, defaults.hideWhenApprovedByOthers)
        maximumPets = value(.maximumPets, defaults.maximumPets)
        labelStyle = value(.labelStyle, defaults.labelStyle)
        showHoverCards = value(.showHoverCards, defaults.showHoverCards)
        allowedSpecies = value(.allowedSpecies, defaults.allowedSpecies)
        petsAreInside = value(.petsAreInside, defaults.petsAreInside)
        petLanes = value(.petLanes, defaults.petLanes)
        scale = Self.scaleRange.clamp(value(.scale, defaults.scale))
        roamingArea = value(.roamingArea, defaults.roamingArea)
        roamingWidth = value(.roamingWidth, defaults.roamingWidth)
        placement = value(.placement, defaults.placement)
        showMenuBarIcon = value(.showMenuBarIcon, defaults.showMenuBarIcon)
        launchAtLogin = value(.launchAtLogin, defaults.launchAtLogin)
        checkForUpdatesAutomatically = value(.checkForUpdatesAutomatically, defaults.checkForUpdatesAutomatically)
    }
}

extension ClosedRange where Bound: Comparable {
    public func clamp(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
