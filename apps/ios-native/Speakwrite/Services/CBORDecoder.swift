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
}

struct CBORDecoder {
    private var data: Data
    private var offset: Int

    init(data: Data) {
        self.data = data
        self.offset = 0
    }

    static func decode(_ data: Data) throws -> CBORValue {
        var decoder = CBORDecoder(data: data)
        return try decoder.decodeItem()
    }

    private mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw CBORError.unexpectedEnd }
        let byte = data[data.startIndex + offset]
        offset += 1
        return byte
    }

    private mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else { throw CBORError.unexpectedEnd }
        let start = data.startIndex + offset
        let result = data[start..<start + count]
        offset += count
        return Data(result)
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

    private mutating func decodeItem() throws -> CBORValue {
        let initial = try readByte()
        let majorType = initial >> 5
        let additional = initial & 0x1F

        switch majorType {
        case 0: // unsigned integer
            return .unsignedInt(try readArgument(additional))
        case 1: // negative integer
            return .negativeInt(try readArgument(additional))
        case 2: // byte string
            let length = Int(try readArgument(additional))
            return .byteString(try readBytes(length))
        case 3: // text string
            let length = Int(try readArgument(additional))
            let bytes = try readBytes(length)
            guard let str = String(data: bytes, encoding: .utf8) else { throw CBORError.invalidUTF8 }
            return .textString(str)
        case 4: // array
            let count = Int(try readArgument(additional))
            var items: [CBORValue] = []
            items.reserveCapacity(count)
            for _ in 0..<count { items.append(try decodeItem()) }
            return .array(items)
        case 5: // map
            let count = Int(try readArgument(additional))
            var pairs: [(CBORValue, CBORValue)] = []
            pairs.reserveCapacity(count)
            for _ in 0..<count {
                let key = try decodeItem()
                let value = try decodeItem()
                pairs.append((key, value))
            }
            return .map(pairs)
        case 7: // simple values and floats
            switch additional {
            case 20: return .bool(false)
            case 21: return .bool(true)
            case 22: return .null
            default: return .null // skip floats and other simple values
            }
        default:
            throw CBORError.unsupportedType(initial)
        }
    }
}
