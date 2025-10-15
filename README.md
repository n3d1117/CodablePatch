# CodablePatch
A small utility that adds surgical patching to `Codable` types. Provide a dictionary of dotted key paths and values and receive a fully decoded copy of your model without having to re-create or decode the entire payload manually.

## Features

- **Zero-boilerplate patching** – Works with any `Codable` type without extra protocols or customization.
- **Nested key paths** – Update deeply nested properties using dotted notation (`profile.address.street`) and array indices (`tags[2]`).
- **Optional safe** – Supports setting optional values to `nil` by using `NSNull()` in the patch dictionary.
- **Configurable encoding** – Respect custom `JSONEncoder`/`JSONDecoder` strategies via `CodablePatch.Configuration`.
- **Multiple input styles** – Apply patches from `[String: Any]`, JSON data, or JSON strings.

## Usage

### Define a Codable model

```swift
struct User: Codable {
    var id: Int
    var name: String
    var profile: Profile
    var tags: [String]
    var lastLogin: Date?

    struct Profile: Codable {
        var address: Address
    }

    struct Address: Codable {
        var street: String
        var city: String
    }
}
```

### Apply a patch

```swift
import CodablePatch

let user = User(
    id: 42,
    name: "Taylor",
    profile: .init(address: .init(street: "1 Infinite Loop", city: "Cupertino")),
    tags: ["swift", "ios"],
    lastLogin: Date()
)

let updated = try user.patch([
    "name": "Jamie",
    "profile.address.city": "San Francisco",
    "tags[1]": "platforms"
])

print(updated.name)                 // "Jamie"
print(updated.profile.address.city) // "San Francisco"
print(updated.tags)                 // ["swift", "platforms"]
```

Note: patch dictionaries must already contain JSON-compatible values (`String`, `NSNumber`, `NSNull`, arrays, dictionaries). Encode rich Swift types (e.g. `Date`, `URL`) before patching.

### Mutate in place

```swift
var user = user
try user.applyPatch([
    "tags[2]": "server"
])
// tags becomes ["swift", "ios", "server"]
```

### Custom encoding/decoding strategies

Use `CodablePatch.configuration` to align with custom `JSONEncoder` and `JSONDecoder` strategies (for example, ISO 8601 dates).

```swift
var configuration = CodablePatch.configuration
configuration.decoder.dateDecodingStrategy = .iso8601

let patch = """
{
    "lastLogin": "2024-01-01T12:34:56Z"
}
"""

let updated = try user.patch(jsonString: patch, using: configuration)
```

### Apply patches from JSON string

```swift
let patch = """
{
    "name": "Jordan",
    "profile.address.street": "Market Street"
}
"""

let updated = try user.patch(jsonString: patch)
```

### Error handling

All APIs throw `CodablePatch.PatchError`. The most common cases are:

- `invalidKeyPath` – The key path does not describe a valid location (for example, indexing a non-array).
- `indexOutOfBounds` – Attempting to insert beyond the next appendable index.
- `encodingFailed` / `decodingFailed` – Underlying `JSONEncoder` or `JSONDecoder` issues.
- `serializationFailed` – The intermediate JSON object could not be serialized (for example, a patch value isn't JSON-compatible).

## Installation

### Swift Package Manager

Simply copy `CodablePatch.swift` to your project. Or, add CodablePatch as a dependency in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/n3d1117/CodablePatch.git", from: "1.0.0")
]
```

And then add `CodablePatch` to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "CodablePatch", package: "CodablePatch")
    ]
)
```

## Testing

Run the test suite with:

```bash
swift test
```
