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
