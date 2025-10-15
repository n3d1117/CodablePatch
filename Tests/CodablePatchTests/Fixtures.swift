import Foundation

enum Fixtures {
    static var date: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    static var user: User {
        User(
            id: 42,
            name: "Taylor",
            profile: Profile(age: 34, address: Address(street: "1 Infinite Loop", city: "Cupertino")),
            tags: ["swift", "ios"],
            metadata: ["role": "admin"],
            lastLogin: date,
            website: URL(string: "https://example.com")!
        )
    }
}

struct User: Codable, Equatable {
    var id: Int
    var name: String
    var profile: Profile
    var tags: [String]
    var metadata: [String: String]?
    var lastLogin: Date?
    var website: URL?
}

struct Profile: Codable, Equatable {
    var age: Int
    var address: Address?
}

struct Address: Codable, Equatable {
    var street: String
    var city: String
}
