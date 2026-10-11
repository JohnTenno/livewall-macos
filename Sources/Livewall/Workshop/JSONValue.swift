import Foundation

/// Any JSON scalar, array or object; used for Wallpaper Engine property values of unknown shape.
enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    var foundationValue: Any? {
        switch self {
        case .string(let value): value
        case .number(let value): value
        case .bool(let value): value
        case .array(let values): values.map { $0.foundationValue ?? NSNull() }
        case .object(let values): values.mapValues { $0.foundationValue ?? NSNull() }
        case .null: nil
        }
    }
}
