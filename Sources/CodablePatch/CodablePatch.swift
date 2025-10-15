import Foundation

/// Namespace for the CodablePatch library.
public enum CodablePatch { }

// MARK: - Errors

public extension CodablePatch {
    /// Errors that can occur while applying patches to `Codable` types.
    enum PatchError: Error {
        case invalidKeyPath(String)
        case indexOutOfBounds(keyPath: String, index: Int)
        case invalidRootObject
        case encodingFailed(Error)
        case decodingFailed(Error)
        case serializationFailed(Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidKeyPath(let keyPath):
                "The key path '\(keyPath)' is not valid."
            case .indexOutOfBounds(let keyPath, let index):
                "Index \(index) is out of bounds for key path '\(keyPath)'."
            case .invalidRootObject:
                "Unable to convert the value into a JSON dictionary."
            case .encodingFailed(let error):
                "Encoding failed with error: \(error.localizedDescription)"
            case .decodingFailed(let error):
                "Decoding failed with error: \(error.localizedDescription)"
            case .serializationFailed(let error):
                "JSON serialization failed with error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Configuration

public extension CodablePatch {
    /// Configuration that controls how patches are encoded and decoded.
    struct Configuration {
        public static var `default`: Configuration { Configuration() }

        public var encoder: JSONEncoder
        public var decoder: JSONDecoder

        public init(encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
            self.encoder = encoder
            self.decoder = decoder
        }
    }
    
    static var configuration: Configuration { Configuration() }
}

// MARK: APIs

public extension Decodable where Self: Encodable {
    /// Returns a new instance with the provided patch applied.
    func patch(
        _ patch: [String: Any],
        using configuration: CodablePatch.Configuration = .default
    ) throws -> Self {
        var json = try CodablePatch.toJSONObject(self, using: configuration.encoder)
        for (keyPath, value) in patch {
            try json.setJSONValue(value, for: keyPath)
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            return try configuration.decoder.decode(Self.self, from: data)
        } catch let error as CodablePatch.PatchError {
            throw error
        } catch let error as DecodingError {
            throw CodablePatch.PatchError.decodingFailed(error)
        } catch {
            throw CodablePatch.PatchError.serializationFailed(error)
        }
    }

    /// Applies the provided patch to the receiver in-place.
    mutating func applyPatch(
        _ patch: [String: Any],
        using configuration: CodablePatch.Configuration = .default
    ) throws {
        self = try self.patch(patch, using: configuration)
    }

    /// Returns a new instance by applying a JSON patch encoded as `Data`.
    func patch(
        jsonData: Data,
        using configuration: CodablePatch.Configuration = .default
    ) throws -> Self {
        let rawObject: Any
        do {
            rawObject = try JSONSerialization.jsonObject(with: jsonData)
        } catch {
            throw CodablePatch.PatchError.serializationFailed(error)
        }

        guard let dictionary = rawObject as? [String: Any] else {
            throw CodablePatch.PatchError.invalidRootObject
        }

        return try patch(dictionary, using: configuration)
    }

    /// Returns a new instance by applying a JSON patch encoded as `String`.
    func patch(
        jsonString: String,
        encoding: String.Encoding = .utf8,
        using configuration: CodablePatch.Configuration = .default
    ) throws -> Self {
        guard let data = jsonString.data(using: encoding) else {
            throw CodablePatch.PatchError.serializationFailed(NSError(domain: "CodablePatch", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Unable to convert patch string to data using encoding \(encoding)."
            ]))
        }
        return try patch(jsonData: data, using: configuration)
    }
}


// MARK: - Implementation

private extension CodablePatch {
    enum KeyPathComponent: Equatable {
        case key(String)
        case index(Int)
    }

    static func toJSONObject<E: Encodable>(_ value: E, using encoder: JSONEncoder) throws -> [String: Any] {
        do {
            let data = try encoder.encode(value)
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw PatchError.invalidRootObject
            }
            return dictionary
        } catch let error as PatchError {
            throw error
        } catch let error as EncodingError {
            throw PatchError.encodingFailed(error)
        } catch {
            throw PatchError.serializationFailed(error)
        }
    }

    static func apply(
        _ rawValue: Any,
        to root: [String: Any],
        components: [KeyPathComponent],
        keyPath: String
    ) throws -> [String: Any] {
        let result = try applyValue(
            rawValue,
            to: root as Any,
            components: ArraySlice(components),
            keyPath: keyPath
        )
        guard let dictionary = result as? [String: Any] else {
            throw PatchError.invalidRootObject
        }
        return dictionary
    }

    static func applyValue(
        _ rawValue: Any,
        to current: Any?,
        components: ArraySlice<KeyPathComponent>,
        keyPath: String
    ) throws -> Any {
        guard let component = components.first else {
            return sanitizeValue(rawValue, existing: current)
        }

        let remaining = components.dropFirst()

        switch component {
        case .key(let key):
            let existingDictionary: [String: Any]
            if let dictionary = current as? [String: Any] {
                existingDictionary = dictionary
            } else if current == nil || current is NSNull {
                existingDictionary = [:]
            } else {
                throw PatchError.invalidKeyPath(keyPath)
            }

            var dictionary = existingDictionary
            let existingValue = dictionary[key]
            dictionary[key] = try applyValue(
                rawValue,
                to: existingValue,
                components: remaining,
                keyPath: keyPath
            )
            return dictionary

        case .index(let index):
            guard index >= 0 else {
                throw PatchError.invalidKeyPath(keyPath)
            }

            let existingArray: [Any]
            if let array = current as? [Any] {
                existingArray = array
            } else if current == nil || current is NSNull {
                existingArray = []
            } else {
                throw PatchError.invalidKeyPath(keyPath)
            }

            var array = existingArray
            if index > array.count {
                throw PatchError.indexOutOfBounds(keyPath: keyPath, index: index)
            }

            let existingValue = index < array.count ? array[index] : nil
            let updatedValue = try applyValue(
                rawValue,
                to: existingValue,
                components: remaining,
                keyPath: keyPath
            )

            if index == array.count {
                array.append(updatedValue)
            } else {
                array[index] = updatedValue
            }
            return array
        }
    }

    static func sanitizeValue(
        _ value: Any,
        existing: Any?
    ) -> Any {
        if let existing = existing,
           (existing is String || existing is NSString),
           !(value is String),
           !(value is NSNull) {
            return String(describing: value)
        }

        return value
    }

    static func parseKeyPath(_ keyPath: String) throws -> [KeyPathComponent] {
        guard !keyPath.isEmpty else {
            throw PatchError.invalidKeyPath(keyPath)
        }

        var components: [KeyPathComponent] = []
        var currentKey = ""
        var currentIndex = ""
        var parsingIndex = false

        func flushCurrentKey() throws {
            guard !currentKey.isEmpty else {
                throw PatchError.invalidKeyPath(keyPath)
            }
            components.append(.key(currentKey))
            currentKey.removeAll(keepingCapacity: false)
        }

        for character in keyPath {
            switch character {
            case ".":
                guard !parsingIndex else {
                    throw PatchError.invalidKeyPath(keyPath)
                }
                try flushCurrentKey()
            case "[":
                guard !parsingIndex else {
                    throw PatchError.invalidKeyPath(keyPath)
                }
                if !currentKey.isEmpty {
                    components.append(.key(currentKey))
                    currentKey.removeAll(keepingCapacity: false)
                }
                parsingIndex = true
            case "]":
                guard parsingIndex, let index = Int(currentIndex) else {
                    throw PatchError.invalidKeyPath(keyPath)
                }
                components.append(.index(index))
                currentIndex.removeAll(keepingCapacity: false)
                parsingIndex = false
            default:
                if parsingIndex {
                    guard character.isNumber else {
                        throw PatchError.invalidKeyPath(keyPath)
                    }
                    currentIndex.append(character)
                } else {
                    currentKey.append(character)
                }
            }
        }

        if parsingIndex {
            throw PatchError.invalidKeyPath(keyPath)
        }
        if !currentKey.isEmpty {
            components.append(.key(currentKey))
        }
        guard !components.isEmpty, case .key = components.first else {
            throw PatchError.invalidKeyPath(keyPath)
        }

        return components
    }
}

private extension Dictionary where Key == String, Value == Any {
    mutating func setJSONValue(_ value: Any, for keyPath: String) throws {
        let components = try CodablePatch.parseKeyPath(keyPath)
        self = try CodablePatch.apply(value, to: self, components: components, keyPath: keyPath)
    }
}
