/// HL7v2Kit - HL7 v2.x message processing toolkit
///
/// This module provides parsing, validation, and generation of HL7 v2.x messages
/// with support for versions 2.1 through 2.8.

import Foundation
import HL7Core

/// Version information for HL7v2Kit
public struct HL7v2KitVersion {
    /// The current version of HL7v2Kit
    public static let version = "0.1.0"
}

/// HL7 v2.x message representation
public struct HL7v2Message: HL7Message {
    public let messageID: String
    public let timestamp: Date
    public let rawData: String
    
    public init(messageID: String, timestamp: Date = Date(), rawData: String) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.rawData = rawData
    }
    
    public func validate() throws {
        // Basic validation - will be expanded in future phases
        guard !rawData.isEmpty else {
            throw HL7Error.validationError("Empty message")
        }
    }
}
