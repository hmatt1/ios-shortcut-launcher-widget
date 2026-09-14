import XCTest
@testable import LauncherBoard

/// `BoardPresetQuery.defaultResult()` (Shared/LauncherIntent.swift) feeds
/// directly into what a freshly-added widget's configuration defaults to -
/// untested until now.
@MainActor
final class BoardPresetQueryTests: XCTestCase {
    func testDefaultResultFallsBackToFirstPresetWhenNothingRecorded() async {
        AppGroup.defaults?.removeObject(forKey: "lastEditedPresetId")
        let result = await BoardPresetQuery().defaultResult()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, BoardPresetStore.loadRaw().first?.id)
    }

    /// Only meaningful when there's a real container to record into - with
    /// no App Group available, `lastEditedPresetId` can never actually be
    /// set, and the query always falls through to `.first` regardless of
    /// what this test tries to record (which would make the assertion true
    /// for the wrong reason).
    func testDefaultResultReturnsTheRecordedPresetWhenItStillExists() async throws {
        guard AppGroup.defaults != nil else {
            throw XCTSkip("App Group container is unavailable in this environment - the recorded-id path isn't exercised here.")
        }
        let all = BoardPresetStore.loadRaw()
        guard all.count > 1 else {
            return XCTFail("expected more than one preset")
        }
        let target = all[1]
        AppGroup.defaults?.set(target.id.uuidString, forKey: "lastEditedPresetId")
        let result = await BoardPresetQuery().defaultResult()
        XCTAssertEqual(result?.id, target.id)
    }

    func testDefaultResultFallsBackToFirstPresetWhenRecordedIdIsUnknown() async {
        AppGroup.defaults?.set(UUID().uuidString, forKey: "lastEditedPresetId")
        let result = await BoardPresetQuery().defaultResult()
        XCTAssertEqual(result?.id, BoardPresetStore.loadRaw().first?.id)
    }

    func testSuggestedEntitiesMatchesLoadRaw() async throws {
        let suggested = try await BoardPresetQuery().suggestedEntities()
        let raw = BoardPresetStore.loadRaw()
        XCTAssertEqual(suggested.map(\.id), raw.map(\.id))
    }
}
