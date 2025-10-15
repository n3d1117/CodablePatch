import Foundation
import Testing
@testable import CodablePatch

@Suite("CodablePatch Performance")
struct CodablePatchPerformanceTests {
    @Test("Patching large metadata stays under threshold")
    func patchLargeMetadataIsFast() throws {
        let user = Fixtures.user
        let largeMetadata = Dictionary(uniqueKeysWithValues: (0..<1_000).map { index in
            ("key\(index)", "value\(index)")
        })
        let patch: [String: Any] = ["metadata": largeMetadata]

        let iterations = 10
        let duration = try ContinuousClock().measure {
            for _ in 0..<iterations {
                _ = try user.patch(patch)
            }
        }

        #expect(duration < .milliseconds(15))
    }

    @Test("Sequential applyPatch remains performant")
    func sequentialApplyPatchIsFast() throws {
        let patchCount = 200
        let patches: [[String: Any]] = (0..<patchCount).map { index in
            [
                "profile.address.street": "Iteration \(index)",
                "profile.age": index
            ]
        }

        let iterations = 5
        let duration = try ContinuousClock().measure {
            for _ in 0..<iterations {
                var user = Fixtures.user
                for patch in patches {
                    try user.applyPatch(patch)
                }
            }
        }

        #expect(duration < .milliseconds(50))
    }
}
