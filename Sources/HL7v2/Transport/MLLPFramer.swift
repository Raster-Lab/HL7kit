import Foundation
import HL7Core

/// MLLP (Minimal Lower Layer Protocol) framing utilities.
///
/// MLLP wraps HL7 messages with:
/// - Start block: `0x0B` (vertical tab)
/// - End block: `0x1C` (file separator) followed by `0x0D` (carriage return)
public enum MLLPFramer: Sendable {
    /// Start block byte (VT, 0x0B).
    public static let startByte: UInt8 = 0x0B
    /// End block byte (FS, 0x1C).
    public static let endBlockByte: UInt8 = 0x1C
    /// Trailing carriage return byte (CR, 0x0D).
    public static let carriageReturn: UInt8 = 0x0D

    /// Frame an HL7 message for MLLP transmission.
    /// - Parameter message: The raw HL7 message string.
    /// - Returns: The MLLP-framed data.
    public static func frame(_ message: String) -> Data {
        var data = Data(capacity: message.utf8.count + 3)
        data.append(startByte)
        data.append(contentsOf: message.utf8)
        data.append(endBlockByte)
        data.append(carriageReturn)
        return data
    }

    /// Extract an HL7 message from MLLP-framed data.
    /// - Parameter data: The MLLP-framed data.
    /// - Returns: The extracted HL7 message string.
    /// - Throws: `HL7Error.invalidMLLPFrame` if the framing is invalid.
    public static func unframe(_ data: Data) throws -> String {
        guard data.count >= 3,
              data.first == startByte,
              data[data.count - 2] == endBlockByte,
              data[data.count - 1] == carriageReturn else {
            throw HL7Error.invalidMLLPFrame
        }

        let messageData = data[data.index(after: data.startIndex)..<data.index(data.endIndex, offsetBy: -2)]
        guard let message = String(data: messageData, encoding: .utf8) else {
            throw HL7Error.invalidMLLPFrame
        }
        return message
    }
}
