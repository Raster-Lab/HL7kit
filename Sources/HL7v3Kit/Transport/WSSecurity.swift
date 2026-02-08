/// HL7v3Kit - WS-Security
///
/// Implements WS-Security (Web Services Security) for SOAP messages.
/// Provides username token authentication, timestamps, and basic signature support.

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - WS-Security

/// WS-Security header for SOAP messages
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct WSSecurity: Sendable {
    /// Username token for authentication
    public let usernameToken: UsernameToken?
    
    /// Timestamp for message expiry
    public let timestamp: SecurityTimestamp?
    
    /// Binary security token (for certificates)
    public let binarySecurityToken: BinarySecurityToken?
    
    /// Initialize WS-Security
    public init(
        usernameToken: UsernameToken? = nil,
        timestamp: SecurityTimestamp? = nil,
        binarySecurityToken: BinarySecurityToken? = nil
    ) {
        self.usernameToken = usernameToken
        self.timestamp = timestamp
        self.binarySecurityToken = binarySecurityToken
    }
    
    /// Serialize to XML
    public func toXML() -> String {
        var xml = #"<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" "#
        xml += #"xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">"#
        xml += "\n"
        
        if let timestamp = timestamp {
            xml += timestamp.toXML()
        }
        
        if let usernameToken = usernameToken {
            xml += usernameToken.toXML()
        }
        
        if let binaryToken = binarySecurityToken {
            xml += binaryToken.toXML()
        }
        
        xml += "</wsse:Security>\n"
        return xml
    }
}

// MARK: - Username Token

/// Username token for WS-Security authentication
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct UsernameToken: Sendable {
    /// Username
    public let username: String
    
    /// Password (hashed or plain)
    public let password: String
    
    /// Password type
    public let passwordType: PasswordType
    
    /// Nonce (random value for replay protection)
    public let nonce: String?
    
    /// Created timestamp
    public let created: Date?
    
    /// Initialize username token
    public init(
        username: String,
        password: String,
        passwordType: PasswordType = .digest,
        nonce: String? = nil,
        created: Date? = nil
    ) {
        self.username = username
        self.password = password
        self.passwordType = passwordType
        self.nonce = nonce
        self.created = created
    }
    
    /// Create username token with digest authentication
    public static func withDigest(username: String, password: String) -> UsernameToken {
        let nonce = generateNonce()
        let created = Date()
        let digest = computePasswordDigest(password: password, nonce: nonce, created: created)
        
        return UsernameToken(
            username: username,
            password: digest,
            passwordType: .digest,
            nonce: nonce,
            created: created
        )
    }
    
    /// Serialize to XML
    func toXML() -> String {
        var xml = "<wsse:UsernameToken>\n"
        xml += "  <wsse:Username>\(username.xmlEscaped)</wsse:Username>\n"
        xml += "  <wsse:Password Type=\"\(passwordType.typeURI)\">\(password.xmlEscaped)</wsse:Password>\n"
        
        if let nonce = nonce {
            xml += "  <wsse:Nonce EncodingType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary\">"
            xml += nonce.xmlEscaped
            xml += "</wsse:Nonce>\n"
        }
        
        if let created = created {
            let formatter = ISO8601DateFormatter()
            xml += "  <wsu:Created>\(formatter.string(from: created))</wsu:Created>\n"
        }
        
        xml += "</wsse:UsernameToken>\n"
        return xml
    }
    
    /// Generate random nonce
    private static func generateNonce() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
    }
    
    /// Compute password digest: Base64(SHA1(nonce + created + password))
    private static func computePasswordDigest(password: String, nonce: String, created: Date) -> String {
        let formatter = ISO8601DateFormatter()
        let createdString = formatter.string(from: created)
        
        guard let nonceData = Data(base64Encoded: nonce),
              let createdData = createdString.data(using: .utf8),
              let passwordData = password.data(using: .utf8)
        else {
            return ""
        }
        
        var combined = Data()
        combined.append(nonceData)
        combined.append(createdData)
        combined.append(passwordData)
        
        #if canImport(CryptoKit)
        let digest = Insecure.SHA1.hash(data: combined)
        return Data(digest).base64EncodedString()
        #else
        // Fallback for platforms without CryptoKit
        // Use CommonCrypto on platforms that support it
        return computeSHA1Fallback(combined)
        #endif
    }
}

/// Password type for username token
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public enum PasswordType: Sendable {
    case text
    case digest
    
    var typeURI: String {
        switch self {
        case .text:
            return "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText"
        case .digest:
            return "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest"
        }
    }
}

// MARK: - Security Timestamp

/// Security timestamp for message expiry
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct SecurityTimestamp: Sendable {
    /// Message creation time
    public let created: Date
    
    /// Message expiration time
    public let expires: Date
    
    /// Initialize with TTL in seconds
    public init(ttl: TimeInterval = 300) {
        self.created = Date()
        self.expires = Date(timeIntervalSinceNow: ttl)
    }
    
    /// Initialize with specific dates
    public init(created: Date, expires: Date) {
        self.created = created
        self.expires = expires
    }
    
    /// Check if timestamp is valid
    public func isValid() -> Bool {
        let now = Date()
        return now >= created && now <= expires
    }
    
    /// Serialize to XML
    func toXML() -> String {
        let formatter = ISO8601DateFormatter()
        var xml = "<wsu:Timestamp>\n"
        xml += "  <wsu:Created>\(formatter.string(from: created))</wsu:Created>\n"
        xml += "  <wsu:Expires>\(formatter.string(from: expires))</wsu:Expires>\n"
        xml += "</wsu:Timestamp>\n"
        return xml
    }
}

// MARK: - Binary Security Token

/// Binary security token (for X.509 certificates)
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct BinarySecurityToken: Sendable {
    /// Token value (Base64-encoded certificate)
    public let value: String
    
    /// Token type
    public let valueType: String
    
    /// Encoding type
    public let encodingType: String
    
    /// Initialize binary security token
    public init(
        value: String,
        valueType: String = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3",
        encodingType: String = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary"
    ) {
        self.value = value
        self.valueType = valueType
        self.encodingType = encodingType
    }
    
    /// Serialize to XML
    func toXML() -> String {
        var xml = "<wsse:BinarySecurityToken "
        xml += "ValueType=\"\(valueType)\" "
        xml += "EncodingType=\"\(encodingType)\">"
        xml += value
        xml += "</wsse:BinarySecurityToken>\n"
        return xml
    }
}

// MARK: - XML Escaping

extension String {
    /// Escape XML special characters
    var xmlEscaped: String {
        var escaped = self
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}

// MARK: - SHA1 Fallback

#if !canImport(CryptoKit)
/// Compute SHA1 hash for platforms without CryptoKit
///
/// **SECURITY WARNING**: This fallback implementation does NOT compute a proper SHA1 hash.
/// It returns a base64-encoded version of the input data, which means password digest
/// authentication will NOT be secure on platforms without CryptoKit.
///
/// For production use on Linux or other non-Apple platforms, you must:
/// 1. Use plain text password authentication (`.text`) instead of digest
/// 2. Ensure all connections use TLS/SSL to protect credentials in transit
/// 3. Implement proper SHA1 using platform-specific crypto libraries (e.g., OpenSSL)
///
/// - Parameter data: Data to hash
/// - Returns: Base64-encoded input (NOT a real hash)
private func computeSHA1Fallback(_ data: Data) -> String {
    print("WARNING: Using insecure SHA1 fallback. Password digest authentication is not secure on this platform.")
    print("         Use plain text authentication over TLS/SSL instead.")
    // Return base64-encoded input as a placeholder
    return data.base64EncodedString()
}
#endif
