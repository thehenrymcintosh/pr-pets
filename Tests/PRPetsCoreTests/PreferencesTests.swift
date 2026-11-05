import Foundation
import PRPetsCore
import Testing

@Suite("Preferences")
struct PreferencesTests {
    @Test func anOldSettingsFileGetsDefaultsForNewSettings() throws {
        let old = Data(#"{"scale": 4, "labelStyle": "repository"}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: old)
        #expect(preferences.scale == 4)
        #expect(preferences.labelStyle == .repository)
        #expect(preferences.petLanes == [.needsMyReview])
        #expect(preferences.checkForUpdatesAutomatically)
        #expect(preferences.hideDuringFullScreen)
    }

    @Test func unreadableValuesFallBackInsteadOfFailing() throws {
        let odd = Data(#"{"scale": "huge", "petLanes": ["needsMyAction", "somethingNew"], "roamingArea": "moon"}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: odd)
        #expect(preferences.scale == Preferences.default.scale)
        #expect(preferences.roamingArea == .nearDoghouse)
    }

    @Test func roundTrips() throws {
        var preferences = Preferences()
        preferences.petLanes = [.needsMyReview, .needsMyAction]
        preferences.scale = 5
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded == preferences)
    }
}

@Suite("Repository filtering preferences")
struct RepositoryFilteringPreferencesTests {
    @Test func nothingIsIgnoredByDefault() {
        let query = Preferences.default.pullRequestQuery
        #expect(query.excludedRepositories.isEmpty)
        #expect(query.owners.isEmpty)
    }

    @Test func ignoredRepositoriesAndOwnersReachTheQuery() {
        var preferences = Preferences()
        preferences.excludedRepositories = ["acme/legacy", "acme/sandbox"]
        preferences.onlyOwners = ["acme"]

        let query = preferences.pullRequestQuery

        #expect(query.excludedRepositories == ["acme/legacy", "acme/sandbox"], "order is kept")
        #expect(query.owners == ["acme"])
    }

    @Test func changingTheIgnoredRepositoriesChangesTheQuery() {
        // AppModel compares queries to decide whether a settings change needs a re-fetch.
        var preferences = Preferences()
        let before = preferences.pullRequestQuery
        preferences.excludedRepositories = ["acme/legacy"]
        #expect(preferences.pullRequestQuery != before)
    }

    @Test func ignoredRepositoriesSurviveSavingAndLoading() throws {
        var preferences = Preferences()
        preferences.excludedRepositories = ["acme/legacy", "someone/else"]
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded.excludedRepositories == ["acme/legacy", "someone/else"])
        #expect(decoded.pullRequestQuery == preferences.pullRequestQuery)
    }

    @Test func aSettingsFileWithoutTheListIgnoresNothing() throws {
        let old = Data(#"{"scale": 4}"#.utf8)
        #expect(try JSONDecoder().decode(Preferences.self, from: old).excludedRepositories.isEmpty)
    }

    @Test func aMalformedListIgnoresNothingInsteadOfFailingTheWholeFile() throws {
        let odd = Data(#"{"scale": 4, "excludedRepositories": "acme/legacy"}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: odd)
        #expect(preferences.excludedRepositories.isEmpty)
        #expect(preferences.scale == 4)
    }
}

@Suite("Doghouse colour")
struct DoghouseColourTests {
    @Test func theDoghouseIsRedByDefault() {
        #expect(Preferences.default.doghouseColour == DoghouseColour(style: .solid, primary: 0xd8333a))
    }

    @Test func aSolidDoghouseIsOneColourTopToBottom() {
        let colour = DoghouseColour(style: .solid, primary: 0x336699)
        #expect(colour.hex(atFraction: 0) == 0x336699)
        #expect(colour.hex(atFraction: 1) == 0x336699)
    }

    @Test func anOmbreDoghouseFadesFromTheRoofToTheGround() {
        let colour = DoghouseColour(style: .ombre, primary: 0xff0000, secondary: 0x0000ff)
        #expect(colour.hex(atFraction: 0) == 0xff0000)
        #expect(colour.hex(atFraction: 1) == 0x0000ff)
        #expect(colour.hex(atFraction: 0.5) == 0x800080)
    }

    @Test func aRainbowDoghouseChangesColourAtEveryStageAndIgnoresThePicks() {
        let rainbow = DoghouseColour(style: .rainbow, primary: 0x000000, secondary: 0x000000)
        let stripes = (0...10).map { rainbow.hex(atFraction: Double($0) / 10) }
        #expect(Set(stripes).count == stripes.count)
        #expect(stripes.first != 0x000000)
    }

    @Test func fractionsOutsideTheDoghouseAreClamped() {
        let colour = DoghouseColour(style: .ombre, primary: 0xff0000, secondary: 0x0000ff)
        #expect(colour.hex(atFraction: -1) == 0xff0000)
        #expect(colour.hex(atFraction: 2) == 0x0000ff)
    }

    @Test func theChoiceSurvivesSavingAndLoading() throws {
        var preferences = Preferences()
        preferences.doghouseColour = DoghouseColour(style: .ombre, primary: 0x112233, secondary: 0x445566)
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded.doghouseColour == preferences.doghouseColour)
    }

    @Test func anOldSettingsFileGetsTheRedDoghouse() throws {
        let old = Data(#"{"scale": 4}"#.utf8)
        #expect(try JSONDecoder().decode(Preferences.self, from: old).doghouseColour == .default)
    }

    @Test func anUnreadablePartFallsBackWithoutLosingTheRest() throws {
        let odd = Data(#"{"doghouseColour": {"style": "plaid", "primary": 4660}}"#.utf8)
        let colour = try JSONDecoder().decode(Preferences.self, from: odd).doghouseColour
        #expect(colour.style == .solid)
        #expect(colour.primary == 4660)
    }
}
