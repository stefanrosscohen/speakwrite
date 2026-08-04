import Foundation

// MARK: - CBOR Value

enum CBORValue {
    case unsignedInt(UInt64)
    case negativeInt(UInt64)
    case byteString(Data)
    case textString(String)
    case array([CBORValue])
    case map([(CBORValue, CBORValue)])
    case bool(Bool)
    case null

    subscript(key: String) -> CBORValue? {
        guard case .map(let pairs) = self else { return nil }
        for (k, v) in pairs {
            if case .textString(let s) = k, s == key { return v }
        }
        return nil
    }

    var dataValue: Data? {
        if case .byteString(let d) = self { return d }
        return nil
    }

    var stringValue: String? {
        if case .textString(let s) = self { return s }
        return nil
    }

    var arrayValue: [CBORValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var uint64Value: UInt64? {
        if case .unsignedInt(let n) = self { return n }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}

// MARK: - CBOR Decoder

enum CBORError: Error {
    case unexpectedEnd
    case unsupportedType(UInt8)
    case invalidUTF8
    case lengthOverflow
    case nestingTooDeep
}

struct CBORDecoder {
    private var data: Data
    private var offset: Int

    /// Maximum nesting depth for arrays/maps. Prevents stack overflow from
    /// maliciously deep structures in attacker-supplied proof records.
    private static let maxDepth = 64

    init(data: Data) {
        self.data = data
        self.offset = 0
    }

    static func decode(_ data: Data) throws -> CBORValue {
        var decoder = CBORDecoder(data: data)
        return try decoder.decodeItem(depth: 0)
    }

    private mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw CBORError.unexpectedEnd }
        let byte = data[data.startIndex + offset]
        offset += 1
        return byte
    }

    private mutating func readBytes(_ count: Int) throws -> Data {
        // Overflow-safe bounds check: offset is always <= data.count, so
        // (data.count - offset) never underflows; comparing against it avoids
        // computing offset + count, which could overflow for huge counts.
        guard count >= 0, count <= data.count - offset else { throw CBORError.unexpectedEnd }
        let start = data.startIndex + offset
        let result = data[start..<start + count]
        offset += count
        return Data(result)
    }

    /// Read a length/count argument and convert it to Int without trapping.
    /// Values that do not fit in Int, or that exceed the number of bytes
    /// remaining in the input, are rejected (any real length/count is bounded
    /// by the remaining input size, since each item occupies at least 1 byte).
    private mutating func readLength(_ additional: UInt8) throws -> Int {
        let raw = try readArgument(additional)
        guard let length = Int(exactly: raw) else { throw CBORError.lengthOverflow }
        guard length <= data.count - offset else { throw CBORError.unexpectedEnd }
        return length
    }

    private mutating func readArgument(_ additional: UInt8) throws -> UInt64 {
        if additional < 24 { return UInt64(additional) }
        switch additional {
        case 24:
            return UInt64(try readByte())
        case 25:
            let bytes = try readBytes(2)
            return UInt64(bytes[0]) << 8 | UInt64(bytes[1])
        case 26:
            let bytes = try readBytes(4)
            return UInt64(bytes[0]) << 24 | UInt64(bytes[1]) << 16 | UInt64(bytes[2]) << 8 | UInt64(bytes[3])
        case 27:
            let bytes = try readBytes(8)
            var result: UInt64 = 0
            for i in 0..<8 { result = result << 8 | UInt64(bytes[i]) }
            return result
        default:
            throw CBORError.unsupportedType(additional)
        }
    }

    private mutating func decodeItem(depth: Int) throws -> CBORValue {
        guard depth < Self.maxDepth else { throw CBORError.nestingTooDeep }

        let initial = try readByte()
        let majorType = initial >> 5
        let additional = initial & 0x1F

        switch majorType {
        case 0: // unsigned integer
            return .unsignedInt(try readArgument(additional))
        case 1: // negative integer
            return .negativeInt(try readArgument(additional))
        case 2: // byte string
            let length = try readLength(additional)
            return .byteString(try readBytes(length))
        case 3: // text string
            let length = try readLength(additional)
            let bytes = try readBytes(length)
            guard let str = String(data: bytes, encoding: .utf8) else { throw CBORError.invalidUTF8 }
            return .textString(str)
        case 4: // array
            let count = try readLength(additional)
            var items: [CBORValue] = []
            // Never trust an attacker-chosen count for a large up-front
            // allocation — reserve a bounded amount and let the array grow.
            items.reserveCapacity(min(count, 4096))
            for _ in 0..<count { items.append(try decodeItem(depth: depth + 1)) }
            return .array(items)
        case 5: // map
            let count = try readLength(additional)
            var pairs: [(CBORValue, CBORValue)] = []
            pairs.reserveCapacity(min(count, 4096))
            for _ in 0..<count {
                let key = try decodeItem(depth: depth + 1)
                let value = try decodeItem(depth: depth + 1)
                pairs.append((key, value))
            }
            return .map(pairs)
        case 7: // simple values and floats
            switch additional {
            case 20: return .bool(false)
            case 21: return .bool(true)
            case 22, 23: return .null // null / undefined — no payload
            case 24: // simple value in the next byte
                _ = try readByte()
                return .null
            case 25: // half-precision float — 2 payload bytes
                _ = try readBytes(2)
                return .null
            case 26: // single-precision float — 4 payload bytes
                _ = try readBytes(4)
                return .null
            case 27: // double-precision float — 8 payload bytes
                _ = try readBytes(8)
                return .null
            default:
                // 28-30 are reserved, 31 is the indefinite-length "break" —
                // neither is valid here.
                throw CBORError.unsupportedType(initial)
            }
        default:
            // Major type 6 (tags) and indefinite lengths are not supported.
            throw CBORError.unsupportedType(initial)
        }
    }
}
