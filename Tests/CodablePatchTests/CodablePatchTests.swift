import Foundation
import Testing
@testable import CodablePatch

@Suite("CodablePatch")
struct CodablePatchTests {
    @Test("Patch root property")
    func patchRootProperty() throws {
        let patched = try Fixtures.user.patch(["name": "Jamie"])
        #expect(patched.name == "Jamie")
        #expect(patched.id == Fixtures.user.id)
    }

    @Test("Patch nested property")
    func patchNestedProperty() throws {
        let patched = try Fixtures.user.patch(["profile.address.city": "Cupertino"])
        #expect(patched.profile.address?.city == "Cupertino")
        #expect(patched.profile.address?.street == Fixtures.user.profile.address?.street)
    }

    @Test("Patch array element")
    func patchArrayElement() throws {
        let patched = try Fixtures.user.patch(["tags[1]": "platforms"])
        #expect(patched.tags == ["swift", "platforms"])
    }

    @Test("Append array element")
    func patchArrayAppend() throws {
        let patched = try Fixtures.user.patch(["tags[2]": "server"])
        #expect(patched.tags == ["swift", "ios", "server"])
    }

    @Test("Apply patch mutating")
    func applyPatchMutating() throws {
        var user = Fixtures.user
        try user.applyPatch(["profile.address.street": "Market Street"])
        #expect(user.profile.address?.street == "Market Street")
    }

    @Test("Patch with null removes optionals")
    func patchWithNullRemovesOptionals() throws {
        let patched = try Fixtures.user.patch([
            "metadata": NSNull(),
            "website": NSNull()
        ])
        #expect(patched.metadata == nil)
        #expect(patched.website == nil)
    }

    @Test("Patch respects custom coder configuration")
    func patchDateRespectsCoderStrategy() throws {
        var configuration = CodablePatch.configuration
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        configuration.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        configuration.decoder = decoder

        let expectedDate = try #require(ISO8601DateFormatter().date(from: "2024-01-01T12:34:56Z"))
        let isoString = ISO8601DateFormatter().string(from: expectedDate)
        let patched = try Fixtures.user.patch(["lastLogin": isoString], using: configuration)

        #expect(patched.lastLogin == expectedDate)
    }

    @Test("Patch from JSON string")
    func patchFromJSONString() throws {
        let patch = """
        {
            "name": "Jordan",
            "profile.address.city": "San Francisco"
        }
        """
        let patched = try Fixtures.user.patch(jsonString: patch)
        #expect(patched.name == "Jordan")
        #expect(patched.profile.address?.city == "San Francisco")
    }

    @Test("Invalid key path throws")
    func invalidKeyPathThrows() {
        let error = #expect(throws: CodablePatch.PatchError.self) {
            try Fixtures.user.patch(["profile.age.years": 35])
        }
        guard let error else {
            return
        }

        guard case let CodablePatch.PatchError.invalidKeyPath(keyPath) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }

        #expect(keyPath == "profile.age.years")
    }

    @Test("Index out of bounds throws")
    func indexOutOfBoundsThrows() {
        let error = #expect(throws: CodablePatch.PatchError.self) {
            try Fixtures.user.patch(["tags[5]": "backend"])
        }
        guard let error else {
            return
        }

        guard case let CodablePatch.PatchError.indexOutOfBounds(keyPath, index) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }

        #expect(keyPath == "tags[5]")
        #expect(index == 5)
    }

    @Test("Patch from JSON data")
    func patchJSONData() throws {
        let data = """
        {
            "profile.address.street": "Elm Street"
        }
        """.data(using: .utf8)

        let patched = try Fixtures.user.patch(jsonData: try #require(data))
        #expect(patched.profile.address?.street == "Elm Street")
    }
}
