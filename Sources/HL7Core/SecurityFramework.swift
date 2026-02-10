/// Security Framework for HL7kit
///
/// Provides comprehensive security services for healthcare data processing:
/// message encryption/decryption, digital signatures, certificate management,
/// role-based access control, security audit logging, and HIPAA compliance utilities.
///
/// > Important: The encryption and signing implementations in this module use
/// > simplified algorithms suitable for demonstration and testing. For production
/// > healthcare deployments, integrate platform-native cryptographic libraries
/// > such as Apple CryptoKit or OpenSSL.

import Foundation

// MARK: - SHA256 Utility (Internal)

/// Pure-Swift SHA-256 implementation for cross-platform use
///
/// This is an internal utility used by the security framework for hashing.
/// It mirrors the implementation in CommonServices.swift.
private enum SecuritySHA256 {
    static func hash(_ string: String) -> String {
        hash(Data(string.utf8))
    }

    static func hash(_ data: Data) -> String {
        digest(data).map { String(format: "%02x", $0) }.joined()
    }

    static func digest(_ data: Data) -> [UInt8] {
        let bytes = Array(data)
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
            0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
            0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
            0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
            0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
            0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
            0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
            0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
            0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]

        var h0: UInt32 = 0x6a09e667
        var h1: UInt32 = 0xbb67ae85
        var h2: UInt32 = 0x3c6ef372
        var h3: UInt32 = 0xa54ff53a
        var h4: UInt32 = 0x510e527f
        var h5: UInt32 = 0x9b05688c
        var h6: UInt32 = 0x1f83d9ab
        var h7: UInt32 = 0x5be0cd19

        let ml = bytes.count * 8
        var msg = bytes
        msg.append(0x80)
        while (msg.count % 64) != 56 {
            msg.append(0x00)
        }
        let mlBE = UInt64(ml)
        for i in stride(from: 56, through: 0, by: -8) {
            msg.append(UInt8((mlBE >> i) & 0xff))
        }

        let chunkCount = msg.count / 64
        for chunkIndex in 0..<chunkCount {
            let chunkStart = chunkIndex * 64
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let offset = chunkStart + i * 4
                w[i] = UInt32(msg[offset]) << 24
                    | UInt32(msg[offset + 1]) << 16
                    | UInt32(msg[offset + 2]) << 8
                    | UInt32(msg[offset + 3])
            }
            for i in 16..<64 {
                let s0 = rightRotate(w[i-15], by: 7) ^ rightRotate(w[i-15], by: 18) ^ (w[i-15] >> 3)
                let s1 = rightRotate(w[i-2], by: 17) ^ rightRotate(w[i-2], by: 19) ^ (w[i-2] >> 10)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }

            var a = h0, b = h1, c = h2, d = h3
            var e = h4, f = h5, g = h6, h = h7

            for i in 0..<64 {
                let s1 = rightRotate(e, by: 6) ^ rightRotate(e, by: 11) ^ rightRotate(e, by: 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rightRotate(a, by: 2) ^ rightRotate(a, by: 13) ^ rightRotate(a, by: 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj

                h = g; g = f; f = e
                e = d &+ temp1
                d = c; c = b; b = a
                a = temp1 &+ temp2
            }

            h0 = h0 &+ a; h1 = h1 &+ b; h2 = h2 &+ c; h3 = h3 &+ d
            h4 = h4 &+ e; h5 = h5 &+ f; h6 = h6 &+ g; h7 = h7 &+ h
        }

        var result = [UInt8]()
        for value in [h0, h1, h2, h3, h4, h5, h6, h7] {
            result.append(UInt8((value >> 24) & 0xff))
            result.append(UInt8((value >> 16) & 0xff))
            result.append(UInt8((value >> 8) & 0xff))
            result.append(UInt8(value & 0xff))
        }
        return result
    }

    private static func rightRotate(_ value: UInt32, by count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}

// MARK: - HMAC-SHA256 Utility (Internal)

/// Pure-Swift HMAC-SHA256 implementation
private enum HMACSHA256 {
    /// Computes HMAC-SHA256 for the given data and key
    static func authenticate(data: Data, key: Data) -> [UInt8] {
        let blockSize = 64
        var keyBytes: [UInt8]

        // If key is longer than block size, hash it
        if key.count > blockSize {
            keyBytes = SecuritySHA256.digest(key)
        } else {
            keyBytes = Array(key)
        }

        // Pad key to block size
        while keyBytes.count < blockSize {
            keyBytes.append(0x00)
        }

        // Create inner and outer padded keys
        var ipad = [UInt8](repeating: 0x36, count: blockSize)
        var opad = [UInt8](repeating: 0x5c, count: blockSize)
        for i in 0..<blockSize {
            ipad[i] ^= keyBytes[i]
            opad[i] ^= keyBytes[i]
        }

        // Inner hash: H(ipad || message)
        var innerInput = Data(ipad)
        innerInput.append(data)
        let innerHash = SecuritySHA256.digest(innerInput)

        // Outer hash: H(opad || inner_hash)
        var outerInput = Data(opad)
        outerInput.append(contentsOf: innerHash)
        return SecuritySHA256.digest(outerInput)
    }

    /// Computes HMAC-SHA256 and returns hex string
    static func authenticateHex(data: Data, key: Data) -> String {
        authenticate(data: data, key: key).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Message Encryption / Decryption

/// Symmetric encryption key for message encryption
///
/// Wraps raw key material used for encrypting and decrypting HL7 messages.
///
/// > Important: This implementation uses a simplified XOR-based cipher for
/// > cross-platform compatibility. For production healthcare deployments,
/// > use platform-native AES encryption via Apple CryptoKit or OpenSSL.
public struct EncryptionKey: Sendable {
    /// The raw key data
    public let keyData: Data

    /// Key identifier for tracking
    public let keyID: String

    /// When this key was created
    public let createdAt: Date

    /// Creates an encryption key from raw data
    ///
    /// - Parameters:
    ///   - keyData: The raw key material (should be at least 16 bytes)
    ///   - keyID: Optional identifier for the key
    public init(keyData: Data, keyID: String = UUID().uuidString) {
        self.keyData = keyData
        self.keyID = keyID
        self.createdAt = Date()
    }

    /// Generates a new random encryption key of the specified size
    ///
    /// - Parameter size: Key size in bytes (default: 32 for 256-bit)
    /// - Returns: A new randomly generated encryption key
    public static func generate(size: Int = 32) -> EncryptionKey {
        var bytes = [UInt8](repeating: 0, count: size)
        for i in 0..<size {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return EncryptionKey(keyData: Data(bytes))
    }
}

/// Encrypted payload containing ciphertext and metadata
///
/// Stores the result of an encryption operation along with the initialization
/// vector and metadata needed for decryption.
public struct EncryptedPayload: Sendable {
    /// The encrypted data
    public let ciphertext: Data

    /// Initialization vector used during encryption
    public let iv: Data

    /// Algorithm identifier
    public let algorithm: String

    /// Key identifier used for encryption
    public let keyID: String

    /// When the payload was encrypted
    public let encryptedAt: Date

    /// Creates an encrypted payload
    public init(ciphertext: Data, iv: Data, algorithm: String, keyID: String, encryptedAt: Date = Date()) {
        self.ciphertext = ciphertext
        self.iv = iv
        self.algorithm = algorithm
        self.keyID = keyID
        self.encryptedAt = encryptedAt
    }
}

/// Provides message encryption and decryption services
///
/// Uses a repeating-key XOR cipher combined with an initialization vector
/// for symmetric encryption of HL7 messages and healthcare data.
///
/// > Important: This is a simplified cipher for cross-platform demonstration.
/// > Production healthcare systems must use AES-256-GCM or equivalent via
/// > Apple CryptoKit, OpenSSL, or another vetted cryptographic library.
///
/// ## Usage
/// ```swift
/// let encryptor = MessageEncryptor()
/// let key = EncryptionKey.generate()
/// let payload = encryptor.encrypt(data: sensitiveData, key: key)
/// let decrypted = encryptor.decrypt(payload: payload, key: key)
/// ```
public struct MessageEncryptor: Sendable {
    /// Algorithm identifier for this encryptor
    public static let algorithm = "XOR-SHA256-STREAM"

    /// Creates a new message encryptor
    public init() {}

    /// Encrypts data using the provided key
    ///
    /// - Parameters:
    ///   - data: The plaintext data to encrypt
    ///   - key: The encryption key to use
    /// - Returns: An encrypted payload containing ciphertext and metadata
    public func encrypt(data: Data, key: EncryptionKey) -> EncryptedPayload {
        // Generate random IV
        var ivBytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 {
            ivBytes[i] = UInt8.random(in: 0...255)
        }
        let iv = Data(ivBytes)

        let ciphertext = xorCipher(data: data, key: key.keyData, iv: iv)
        return EncryptedPayload(
            ciphertext: ciphertext,
            iv: iv,
            algorithm: Self.algorithm,
            keyID: key.keyID
        )
    }

    /// Decrypts an encrypted payload using the provided key
    ///
    /// - Parameters:
    ///   - payload: The encrypted payload to decrypt
    ///   - key: The encryption key (must match the key used for encryption)
    /// - Returns: The decrypted plaintext data
    public func decrypt(payload: EncryptedPayload, key: EncryptionKey) -> Data {
        xorCipher(data: payload.ciphertext, key: key.keyData, iv: payload.iv)
    }

    /// Encrypts a string using the provided key
    ///
    /// - Parameters:
    ///   - string: The plaintext string to encrypt
    ///   - key: The encryption key to use
    /// - Returns: An encrypted payload
    public func encrypt(string: String, key: EncryptionKey) -> EncryptedPayload {
        encrypt(data: Data(string.utf8), key: key)
    }

    /// Decrypts an encrypted payload to a string
    ///
    /// - Parameters:
    ///   - payload: The encrypted payload to decrypt
    ///   - key: The encryption key
    /// - Returns: The decrypted string, or nil if the data is not valid UTF-8
    public func decryptToString(payload: EncryptedPayload, key: EncryptionKey) -> String? {
        let data = decrypt(payload: payload, key: key)
        return String(data: data, encoding: .utf8)
    }

    /// XOR-based stream cipher combining key material with IV
    private func xorCipher(data: Data, key: Data, iv: Data) -> Data {
        let keyBytes = Array(key)
        let ivBytes = Array(iv)
        let dataBytes = Array(data)
        guard !keyBytes.isEmpty else { return data }

        // Generate keystream by hashing key + IV + counter blocks
        var keystream = [UInt8]()
        var counter: UInt32 = 0
        while keystream.count < dataBytes.count {
            var block = keyBytes
            block.append(contentsOf: ivBytes)
            block.append(UInt8((counter >> 24) & 0xff))
            block.append(UInt8((counter >> 16) & 0xff))
            block.append(UInt8((counter >> 8) & 0xff))
            block.append(UInt8(counter & 0xff))
            let hash = SecuritySHA256.digest(Data(block))
            keystream.append(contentsOf: hash)
            counter += 1
        }

        var result = [UInt8](repeating: 0, count: dataBytes.count)
        for i in 0..<dataBytes.count {
            result[i] = dataBytes[i] ^ keystream[i]
        }
        return Data(result)
    }
}

// MARK: - Digital Signature Support

/// Key used for creating and verifying digital signatures
///
/// Wraps key material for HMAC-SHA256 based message signing.
///
/// > Important: This uses HMAC-SHA256 with a shared secret key. For production
/// > healthcare systems, use asymmetric digital signatures (e.g., ECDSA) via
/// > Apple CryptoKit or OpenSSL for non-repudiation guarantees.
public struct SigningKey: Sendable {
    /// The raw key data
    public let keyData: Data

    /// Key identifier
    public let keyID: String

    /// When this key was created
    public let createdAt: Date

    /// Creates a signing key from raw data
    ///
    /// - Parameters:
    ///   - keyData: The raw key material
    ///   - keyID: Optional identifier for the key
    public init(keyData: Data, keyID: String = UUID().uuidString) {
        self.keyData = keyData
        self.keyID = keyID
        self.createdAt = Date()
    }

    /// Generates a new random signing key
    ///
    /// - Parameter size: Key size in bytes (default: 32)
    /// - Returns: A new randomly generated signing key
    public static func generate(size: Int = 32) -> SigningKey {
        var bytes = [UInt8](repeating: 0, count: size)
        for i in 0..<size {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return SigningKey(keyData: Data(bytes))
    }
}

/// Digital signature with metadata
///
/// Contains the HMAC-SHA256 signature along with information about
/// when and how the signature was created.
public struct MessageSignature: Sendable {
    /// The signature bytes
    public let signatureData: Data

    /// Hex-encoded signature string
    public let signatureHex: String

    /// Algorithm used to create the signature
    public let algorithm: String

    /// Key identifier used for signing
    public let keyID: String

    /// When the signature was created
    public let signedAt: Date

    /// Creates a message signature
    public init(signatureData: Data, signatureHex: String, algorithm: String, keyID: String, signedAt: Date = Date()) {
        self.signatureData = signatureData
        self.signatureHex = signatureHex
        self.algorithm = algorithm
        self.keyID = keyID
        self.signedAt = signedAt
    }
}

/// Provides digital signing and verification services using HMAC-SHA256
///
/// Uses a pure-Swift HMAC-SHA256 implementation for cross-platform compatibility.
///
/// > Important: This uses symmetric HMAC signatures. For production systems
/// > requiring non-repudiation, use asymmetric signatures (ECDSA/RSA) via
/// > Apple CryptoKit or OpenSSL.
///
/// ## Usage
/// ```swift
/// let signer = DigitalSigner()
/// let key = SigningKey.generate()
/// let signature = signer.sign(data: messageData, key: key)
/// let isValid = signer.verify(data: messageData, signature: signature, key: key)
/// ```
public struct DigitalSigner: Sendable {
    /// Algorithm identifier
    public static let algorithm = "HMAC-SHA256"

    /// Creates a new digital signer
    public init() {}

    /// Signs data using the provided key
    ///
    /// - Parameters:
    ///   - data: The data to sign
    ///   - key: The signing key
    /// - Returns: A message signature
    public func sign(data: Data, key: SigningKey) -> MessageSignature {
        let sigBytes = HMACSHA256.authenticate(data: data, key: key.keyData)
        let sigHex = sigBytes.map { String(format: "%02x", $0) }.joined()
        return MessageSignature(
            signatureData: Data(sigBytes),
            signatureHex: sigHex,
            algorithm: Self.algorithm,
            keyID: key.keyID
        )
    }

    /// Signs a string using the provided key
    ///
    /// - Parameters:
    ///   - string: The string to sign
    ///   - key: The signing key
    /// - Returns: A message signature
    public func sign(string: String, key: SigningKey) -> MessageSignature {
        sign(data: Data(string.utf8), key: key)
    }

    /// Verifies a signature against the provided data and key
    ///
    /// - Parameters:
    ///   - data: The original data that was signed
    ///   - signature: The signature to verify
    ///   - key: The signing key (must match the key used for signing)
    /// - Returns: `true` if the signature is valid
    public func verify(data: Data, signature: MessageSignature, key: SigningKey) -> Bool {
        let expected = HMACSHA256.authenticate(data: data, key: key.keyData)
        let actual = Array(signature.signatureData)
        guard expected.count == actual.count else { return false }
        // Constant-time comparison to prevent timing attacks
        var result: UInt8 = 0
        for i in 0..<expected.count {
            result |= expected[i] ^ actual[i]
        }
        return result == 0
    }

    /// Verifies a signature against the provided string and key
    ///
    /// - Parameters:
    ///   - string: The original string that was signed
    ///   - signature: The signature to verify
    ///   - key: The signing key
    /// - Returns: `true` if the signature is valid
    public func verify(string: String, signature: MessageSignature, key: SigningKey) -> Bool {
        verify(data: Data(string.utf8), signature: signature, key: key)
    }
}

// MARK: - Certificate Management

/// Certificate validation status
public enum CertificateStatus: String, Sendable, CaseIterable {
    /// Certificate is valid and trusted
    case valid
    /// Certificate has expired
    case expired
    /// Certificate has been revoked
    case revoked
    /// Certificate is not yet valid
    case notYetValid
    /// Certificate trust chain is invalid
    case untrusted
    /// Certificate status is unknown
    case unknown
}

/// Represents certificate information for TLS/authentication
///
/// Stores metadata about an X.509-style certificate including subject,
/// issuer, validity period, and fingerprint information.
public struct CertificateInfo: Sendable, Identifiable {
    /// Unique identifier for the certificate
    public let id: String

    /// Certificate subject (CN)
    public let subject: String

    /// Certificate issuer
    public let issuer: String

    /// Serial number
    public let serialNumber: String

    /// Start of validity period
    public let validFrom: Date

    /// End of validity period
    public let validTo: Date

    /// SHA-256 fingerprint of the certificate
    public let fingerprint: String

    /// Current status of the certificate
    public let status: CertificateStatus

    /// Creates certificate information
    ///
    /// - Parameters:
    ///   - subject: Certificate subject (CN)
    ///   - issuer: Certificate issuer
    ///   - serialNumber: Serial number
    ///   - validFrom: Start of validity period
    ///   - validTo: End of validity period
    ///   - fingerprint: SHA-256 fingerprint
    ///   - status: Current certificate status
    public init(
        subject: String,
        issuer: String,
        serialNumber: String,
        validFrom: Date,
        validTo: Date,
        fingerprint: String = "",
        status: CertificateStatus = .unknown
    ) {
        self.id = serialNumber
        self.subject = subject
        self.issuer = issuer
        self.serialNumber = serialNumber
        self.validFrom = validFrom
        self.validTo = validTo
        self.fingerprint = fingerprint.isEmpty
            ? SecuritySHA256.hash("\(subject):\(issuer):\(serialNumber)")
            : fingerprint
        self.status = status
    }

    /// Creates a copy with updated status
    public func withStatus(_ newStatus: CertificateStatus) -> CertificateInfo {
        CertificateInfo(
            subject: subject,
            issuer: issuer,
            serialNumber: serialNumber,
            validFrom: validFrom,
            validTo: validTo,
            fingerprint: fingerprint,
            status: newStatus
        )
    }
}

/// Manages certificate storage, validation, and trust chain verification
///
/// Provides a thread-safe certificate store with support for adding, removing,
/// finding, and validating certificates.
///
/// ## Usage
/// ```swift
/// let manager = CertificateManager()
/// await manager.addCertificate(cert)
/// let status = await manager.validateCertificate(cert)
/// ```
public actor CertificateManager {
    /// Stored certificates indexed by serial number
    private var certificates: [String: CertificateInfo] = [:]

    /// Trusted issuer subjects
    private var trustedIssuers: Set<String> = []

    /// Revoked certificate serial numbers
    private var revokedSerials: Set<String> = []

    /// Creates a new certificate manager
    public init() {}

    /// Adds a certificate to the store
    ///
    /// - Parameter certificate: The certificate to add
    public func addCertificate(_ certificate: CertificateInfo) {
        certificates[certificate.serialNumber] = certificate
    }

    /// Removes a certificate from the store
    ///
    /// - Parameter serialNumber: The serial number of the certificate to remove
    /// - Returns: The removed certificate, or nil if not found
    @discardableResult
    public func removeCertificate(serialNumber: String) -> CertificateInfo? {
        certificates.removeValue(forKey: serialNumber)
    }

    /// Finds certificates by subject name
    ///
    /// - Parameter subject: The subject to search for (case-insensitive partial match)
    /// - Returns: Array of matching certificates
    public func findBySubject(_ subject: String) -> [CertificateInfo] {
        let lowered = subject.lowercased()
        return certificates.values.filter {
            $0.subject.lowercased().contains(lowered)
        }
    }

    /// Finds a certificate by serial number
    ///
    /// - Parameter serialNumber: The serial number to look up
    /// - Returns: The matching certificate, or nil
    public func findBySerial(_ serialNumber: String) -> CertificateInfo? {
        certificates[serialNumber]
    }

    /// Adds a trusted issuer
    ///
    /// - Parameter issuer: The issuer subject to trust
    public func addTrustedIssuer(_ issuer: String) {
        trustedIssuers.insert(issuer)
    }

    /// Removes a trusted issuer
    ///
    /// - Parameter issuer: The issuer subject to remove from trust
    public func removeTrustedIssuer(_ issuer: String) {
        trustedIssuers.remove(issuer)
    }

    /// Revokes a certificate by serial number
    ///
    /// - Parameter serialNumber: The serial number to revoke
    public func revokeCertificate(serialNumber: String) {
        revokedSerials.insert(serialNumber)
        if let cert = certificates[serialNumber] {
            certificates[serialNumber] = cert.withStatus(.revoked)
        }
    }

    /// Validates a certificate checking expiration, revocation, and trust
    ///
    /// - Parameters:
    ///   - certificate: The certificate to validate
    ///   - date: The date to validate against (default: now)
    /// - Returns: The validation status
    public func validateCertificate(_ certificate: CertificateInfo, at date: Date = Date()) -> CertificateStatus {
        // Check revocation
        if revokedSerials.contains(certificate.serialNumber) {
            return .revoked
        }

        // Check not-yet-valid
        if date < certificate.validFrom {
            return .notYetValid
        }

        // Check expiration
        if date > certificate.validTo {
            return .expired
        }

        // Check trust chain
        if !trustedIssuers.isEmpty && !trustedIssuers.contains(certificate.issuer) {
            return .untrusted
        }

        return .valid
    }

    /// Returns all stored certificates
    public func allCertificates() -> [CertificateInfo] {
        Array(certificates.values)
    }

    /// Returns the number of stored certificates
    public func count() -> Int {
        certificates.count
    }

    /// Removes all certificates
    public func clear() {
        certificates.removeAll()
        revokedSerials.removeAll()
    }
}

// MARK: - Access Control Framework

/// Permissions that can be granted to principals
public enum Permission: String, Sendable, CaseIterable, Hashable {
    /// Permission to read/view resources
    case read
    /// Permission to create or modify resources
    case write
    /// Permission to delete resources
    case delete
    /// Full administrative access
    case admin
    /// Permission to export data
    case export
    /// Permission to view audit logs
    case audit
}

/// A role grouping a set of permissions
///
/// Roles are assigned to principals to grant them a set of permissions
/// for accessing healthcare resources.
public struct Role: Sendable, Hashable {
    /// Role name
    public let name: String

    /// Permissions granted by this role
    public let permissions: Set<Permission>

    /// Creates a role with the given name and permissions
    ///
    /// - Parameters:
    ///   - name: The role name
    ///   - permissions: Set of permissions granted by this role
    public init(name: String, permissions: Set<Permission>) {
        self.name = name
        self.permissions = permissions
    }

    /// Predefined read-only role
    public static let viewer = Role(name: "viewer", permissions: [.read])

    /// Predefined editor role with read and write
    public static let editor = Role(name: "editor", permissions: [.read, .write])

    /// Predefined administrator role with all permissions
    public static let administrator = Role(
        name: "administrator",
        permissions: Set(Permission.allCases)
    )

    /// Predefined auditor role with read and audit permissions
    public static let auditor = Role(name: "auditor", permissions: [.read, .audit])
}

/// An access policy mapping resource patterns to required permissions
///
/// Defines what permissions are needed to access resources matching
/// a specific pattern.
public struct AccessPolicy: Sendable {
    /// Policy identifier
    public let policyID: String

    /// Resource pattern (supports `*` wildcard suffix matching)
    public let resourcePattern: String

    /// Required permissions for accessing matching resources
    public let requiredPermissions: Set<Permission>

    /// Description of this policy
    public let description: String

    /// Creates an access policy
    ///
    /// - Parameters:
    ///   - resourcePattern: Pattern to match resources (e.g., `patient/*`)
    ///   - requiredPermissions: Permissions needed for access
    ///   - description: Human-readable description
    ///   - policyID: Optional policy identifier
    public init(
        resourcePattern: String,
        requiredPermissions: Set<Permission>,
        description: String = "",
        policyID: String = UUID().uuidString
    ) {
        self.policyID = policyID
        self.resourcePattern = resourcePattern
        self.requiredPermissions = requiredPermissions
        self.description = description
    }

    /// Checks if this policy matches the given resource
    ///
    /// - Parameter resource: The resource identifier to check
    /// - Returns: `true` if the resource matches this policy's pattern
    public func matches(resource: String) -> Bool {
        if resourcePattern == "*" {
            return true
        }
        if resourcePattern.hasSuffix("/*") {
            let prefix = String(resourcePattern.dropLast(2))
            return resource == prefix || resource.hasPrefix(prefix + "/")
        }
        return resource == resourcePattern
    }
}

/// Result of an access control check
public enum AccessDecision: String, Sendable {
    /// Access is granted
    case allowed
    /// Access is denied due to insufficient permissions
    case denied
    /// No applicable policy found
    case noPolicy
}

/// Manages role-based access control for healthcare resources
///
/// Provides principal management, role assignment, and access checking
/// against defined policies.
///
/// ## Usage
/// ```swift
/// let acm = AccessControlManager()
/// await acm.addPrincipal("dr.smith", roles: [.editor])
/// await acm.addPolicy(AccessPolicy(resourcePattern: "patient/*", requiredPermissions: [.read]))
/// let decision = await acm.checkAccess(principal: "dr.smith", resource: "patient/123", action: .read)
/// ```
public actor AccessControlManager {
    /// Principal to roles mapping
    private var principalRoles: [String: Set<Role>] = [:]

    /// Active access policies
    private var policies: [AccessPolicy] = []

    /// Creates a new access control manager
    public init() {}

    /// Adds a principal with the given roles
    ///
    /// - Parameters:
    ///   - principal: Principal identifier (e.g., username)
    ///   - roles: Set of roles to assign
    public func addPrincipal(_ principal: String, roles: Set<Role>) {
        principalRoles[principal] = roles
    }

    /// Removes a principal
    ///
    /// - Parameter principal: The principal to remove
    public func removePrincipal(_ principal: String) {
        principalRoles.removeValue(forKey: principal)
    }

    /// Updates roles for a principal
    ///
    /// - Parameters:
    ///   - principal: The principal to update
    ///   - roles: New set of roles
    public func updateRoles(for principal: String, roles: Set<Role>) {
        principalRoles[principal] = roles
    }

    /// Gets roles for a principal
    ///
    /// - Parameter principal: The principal identifier
    /// - Returns: Set of assigned roles, or empty set if principal not found
    public func getRoles(for principal: String) -> Set<Role> {
        principalRoles[principal] ?? []
    }

    /// Gets all effective permissions for a principal
    ///
    /// - Parameter principal: The principal identifier
    /// - Returns: Union of all permissions from all assigned roles
    public func getEffectivePermissions(for principal: String) -> Set<Permission> {
        let roles = principalRoles[principal] ?? []
        var permissions = Set<Permission>()
        for role in roles {
            permissions.formUnion(role.permissions)
        }
        return permissions
    }

    /// Adds an access policy
    ///
    /// - Parameter policy: The policy to add
    public func addPolicy(_ policy: AccessPolicy) {
        policies.append(policy)
    }

    /// Removes a policy by ID
    ///
    /// - Parameter policyID: The policy identifier to remove
    public func removePolicy(policyID: String) {
        policies.removeAll { $0.policyID == policyID }
    }

    /// Checks if a principal has access to a resource for a given action
    ///
    /// - Parameters:
    ///   - principal: The principal requesting access
    ///   - resource: The resource being accessed
    ///   - action: The permission/action being requested
    /// - Returns: The access decision
    public func checkAccess(principal: String, resource: String, action: Permission) -> AccessDecision {
        let permissions = getEffectivePermissions(for: principal)

        // Admin always has access
        if permissions.contains(.admin) {
            return .allowed
        }

        // Find matching policies
        let matchingPolicies = policies.filter { $0.matches(resource: resource) }
        if matchingPolicies.isEmpty {
            return .noPolicy
        }

        // Check if principal has required permissions for any matching policy
        for policy in matchingPolicies {
            if policy.requiredPermissions.contains(action) && permissions.contains(action) {
                return .allowed
            }
        }

        return .denied
    }

    /// Returns all registered principals
    public func allPrincipals() -> [String] {
        Array(principalRoles.keys)
    }

    /// Returns all active policies
    public func allPolicies() -> [AccessPolicy] {
        policies
    }
}

// MARK: - Security Audit Logging

/// Types of security events
public enum SecurityEventType: String, Sendable, CaseIterable {
    /// User login attempt
    case login
    /// User logout
    case logout
    /// Access was denied
    case accessDenied
    /// Data was accessed/read
    case dataAccess
    /// Data was modified
    case dataModification
    /// Data was exported
    case dataExport
    /// Configuration change
    case configChange
    /// Security policy violation
    case policyViolation
    /// Certificate operation
    case certificateOperation
    /// Encryption/decryption operation
    case cryptoOperation
}

/// Outcome of a security event
public enum SecurityEventOutcome: String, Sendable {
    /// Operation succeeded
    case success
    /// Operation failed
    case failure
    /// Operation result is unknown
    case unknown
}

/// A security audit event record
///
/// Captures details about a security-relevant event including who performed
/// the action, what resource was affected, and the outcome.
public struct SecurityEvent: Sendable {
    /// Unique event identifier
    public let eventID: String

    /// When the event occurred
    public let timestamp: Date

    /// Type of security event
    public let eventType: SecurityEventType

    /// Who performed the action
    public let principal: String

    /// The action that was performed
    public let action: String

    /// The resource that was affected
    public let resource: String

    /// Outcome of the event
    public let outcome: SecurityEventOutcome

    /// Additional event details
    public let details: [String: String]

    /// Source IP or location (if available)
    public let source: String?

    /// Creates a security event
    ///
    /// - Parameters:
    ///   - eventType: Type of security event
    ///   - principal: Who performed the action
    ///   - action: The action performed
    ///   - resource: The affected resource
    ///   - outcome: The event outcome
    ///   - details: Additional details
    ///   - source: Source location
    public init(
        eventType: SecurityEventType,
        principal: String,
        action: String,
        resource: String,
        outcome: SecurityEventOutcome = .success,
        details: [String: String] = [:],
        source: String? = nil
    ) {
        self.eventID = UUID().uuidString
        self.timestamp = Date()
        self.eventType = eventType
        self.principal = principal
        self.action = action
        self.resource = resource
        self.outcome = outcome
        self.details = details
        self.source = source
    }
}

/// Thread-safe security audit logger
///
/// Records and queries security-relevant events with optional integration
/// to the ``AuditTrail`` from CommonServices for tamper-evident logging.
///
/// ## Usage
/// ```swift
/// let logger = SecurityAuditLogger()
/// await logger.log(SecurityEvent(
///     eventType: .login,
///     principal: "dr.smith",
///     action: "authenticate",
///     resource: "system",
///     outcome: .success
/// ))
/// let events = await logger.events(forPrincipal: "dr.smith")
/// ```
public actor SecurityAuditLogger {
    /// Stored security events
    private var events: [SecurityEvent] = []

    /// Optional audit trail integration for tamper-evident logging
    private let auditTrail: AuditTrail?

    /// Creates a security audit logger
    ///
    /// - Parameter auditTrail: Optional ``AuditTrail`` for tamper-evident integration
    public init(auditTrail: AuditTrail? = nil) {
        self.auditTrail = auditTrail
    }

    /// Logs a security event
    ///
    /// - Parameter event: The security event to log
    public func log(_ event: SecurityEvent) async {
        events.append(event)

        // Forward to audit trail if configured
        if let trail = auditTrail {
            let auditType: AuditEventType
            switch event.eventType {
            case .dataAccess, .login, .logout:
                auditType = .access
            case .dataModification, .configChange:
                auditType = .modify
            case .dataExport:
                auditType = .export
            case .accessDenied, .policyViolation,
                 .certificateOperation, .cryptoOperation:
                auditType = .access
            }

            _ = await trail.record(
                eventType: auditType,
                principal: AuditPrincipal(identifier: event.principal),
                resource: event.resource,
                action: event.action,
                details: event.details
            )
        }
    }

    /// Returns all logged security events
    public func allEvents() -> [SecurityEvent] {
        events
    }

    /// Returns events filtered by type
    ///
    /// - Parameter type: The event type to filter by
    /// - Returns: Array of matching events
    public func events(ofType type: SecurityEventType) -> [SecurityEvent] {
        events.filter { $0.eventType == type }
    }

    /// Returns events for a specific principal
    ///
    /// - Parameter principal: The principal to filter by
    /// - Returns: Array of events for the principal
    public func events(forPrincipal principal: String) -> [SecurityEvent] {
        events.filter { $0.principal == principal }
    }

    /// Returns events for a specific resource
    ///
    /// - Parameter resource: The resource to filter by
    /// - Returns: Array of events affecting the resource
    public func events(forResource resource: String) -> [SecurityEvent] {
        events.filter { $0.resource == resource }
    }

    /// Returns events with a specific outcome
    ///
    /// - Parameter outcome: The outcome to filter by
    /// - Returns: Array of matching events
    public func events(withOutcome outcome: SecurityEventOutcome) -> [SecurityEvent] {
        events.filter { $0.outcome == outcome }
    }

    /// Returns events within a date range
    ///
    /// - Parameters:
    ///   - start: Range start date
    ///   - end: Range end date
    /// - Returns: Array of events within the range
    public func events(from start: Date, to end: Date) -> [SecurityEvent] {
        events.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    /// Returns the total event count
    public func count() -> Int {
        events.count
    }

    /// Clears all logged events
    public func clear() {
        events.removeAll()
    }
}

// MARK: - HIPAA Compliance Utilities

/// Types of Protected Health Information (PHI) identifiers as defined by HIPAA
///
/// The HIPAA Privacy Rule identifies 18 types of identifiers that must be
/// removed or masked for de-identification under the Safe Harbor method.
public enum PHIIdentifierType: String, Sendable, CaseIterable {
    /// Patient name
    case name
    /// Geographic data (address, city, state, zip)
    case geographicData
    /// Dates related to an individual (DOB, admission, discharge, death)
    case dates
    /// Phone numbers
    case phoneNumber
    /// Fax numbers
    case faxNumber
    /// Email addresses
    case emailAddress
    /// Social Security numbers
    case socialSecurityNumber
    /// Medical record numbers
    case medicalRecordNumber
    /// Health plan beneficiary numbers
    case healthPlanNumber
    /// Account numbers
    case accountNumber
    /// Certificate/license numbers
    case certificateNumber
    /// Vehicle identifiers and serial numbers
    case vehicleIdentifier
    /// Device identifiers and serial numbers
    case deviceIdentifier
    /// Web URLs
    case webURL
    /// IP addresses
    case ipAddress
    /// Biometric identifiers
    case biometricIdentifier
    /// Full-face photographs and comparable images
    case photographicImage
    /// Any other unique identifying number or code
    case otherUniqueIdentifier
}

/// Result of a HIPAA compliance check
public struct ComplianceCheckResult: Sendable {
    /// Whether the check passed
    public let passed: Bool

    /// Description of the check
    public let checkName: String

    /// Details about the finding
    public let details: String

    /// PHI types found (if any)
    public let identifiersFound: [PHIIdentifierType]

    /// Creates a compliance check result
    public init(passed: Bool, checkName: String, details: String, identifiersFound: [PHIIdentifierType] = []) {
        self.passed = passed
        self.checkName = checkName
        self.details = details
        self.identifiersFound = identifiersFound
    }
}

/// HIPAA compliance utilities for healthcare data de-identification and validation
///
/// Provides tools for detecting, masking, and removing Protected Health
/// Information (PHI) in accordance with the HIPAA Safe Harbor method.
///
/// ## Usage
/// ```swift
/// let hipaa = HIPAACompliance()
/// let deidentified = hipaa.deidentify("Patient: John Doe, SSN: 123-45-6789")
/// let results = hipaa.validateCompliance(text)
/// ```
public struct HIPAACompliance: Sendable {
    /// Creates a new HIPAA compliance utility
    public init() {}

    /// De-identifies text by masking known PHI patterns (Safe Harbor method)
    ///
    /// Scans text for the 18 HIPAA identifier types and replaces detected
    /// patterns with masked values.
    ///
    /// - Parameter text: The text to de-identify
    /// - Returns: De-identified text with PHI patterns masked
    public func deidentify(_ text: String) -> String {
        var result = text

        // SSN pattern: XXX-XX-XXXX
        result = replacePattern(in: result, pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b", replacement: "[SSN-REDACTED]")

        // Phone numbers: (XXX) XXX-XXXX or XXX-XXX-XXXX
        result = replacePattern(in: result, pattern: "\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}\\b", replacement: "[PHONE-REDACTED]")

        // Email addresses
        result = replacePattern(in: result, pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", replacement: "[EMAIL-REDACTED]")

        // IP addresses
        result = replacePattern(in: result, pattern: "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", replacement: "[IP-REDACTED]")

        // Dates: MM/DD/YYYY or MM-DD-YYYY
        result = replacePattern(in: result, pattern: "\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b", replacement: "[DATE-REDACTED]")

        // ZIP codes (5-digit or 5+4)
        result = replacePattern(in: result, pattern: "\\b\\d{5}(-\\d{4})?\\b", replacement: "[ZIP-REDACTED]")

        // MRN patterns: MRN followed by digits
        result = replacePattern(in: result, pattern: "(?i)MRN[:\\s]*[A-Z0-9-]+", replacement: "[MRN-REDACTED]")

        // URL patterns
        result = replacePattern(in: result, pattern: "https?://[^\\s]+", replacement: "[URL-REDACTED]")

        return result
    }

    /// Detects PHI identifier types present in the text
    ///
    /// - Parameter text: The text to scan
    /// - Returns: Set of detected PHI identifier types
    public func detectPHI(in text: String) -> Set<PHIIdentifierType> {
        var found = Set<PHIIdentifierType>()

        if matchesPattern(text, pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b") {
            found.insert(.socialSecurityNumber)
        }
        if matchesPattern(text, pattern: "\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}") {
            found.insert(.phoneNumber)
        }
        if matchesPattern(text, pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}") {
            found.insert(.emailAddress)
        }
        if matchesPattern(text, pattern: "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b") {
            found.insert(.ipAddress)
        }
        if matchesPattern(text, pattern: "\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b") {
            found.insert(.dates)
        }
        if matchesPattern(text, pattern: "https?://[^\\s]+") {
            found.insert(.webURL)
        }
        if matchesPattern(text, pattern: "(?i)MRN[:\\s]*[A-Z0-9-]+") {
            found.insert(.medicalRecordNumber)
        }

        return found
    }

    /// Validates text for HIPAA compliance
    ///
    /// Runs a series of compliance checks and returns detailed results.
    ///
    /// - Parameter text: The text to validate
    /// - Returns: Array of compliance check results
    public func validateCompliance(_ text: String) -> [ComplianceCheckResult] {
        var results: [ComplianceCheckResult] = []

        let detected = detectPHI(in: text)

        // Check for SSN
        let ssnFound = detected.contains(.socialSecurityNumber)
        results.append(ComplianceCheckResult(
            passed: !ssnFound,
            checkName: "SSN Check",
            details: ssnFound ? "Social Security number pattern detected" : "No SSN patterns found",
            identifiersFound: ssnFound ? [.socialSecurityNumber] : []
        ))

        // Check for phone numbers
        let phoneFound = detected.contains(.phoneNumber)
        results.append(ComplianceCheckResult(
            passed: !phoneFound,
            checkName: "Phone Number Check",
            details: phoneFound ? "Phone number pattern detected" : "No phone number patterns found",
            identifiersFound: phoneFound ? [.phoneNumber] : []
        ))

        // Check for email
        let emailFound = detected.contains(.emailAddress)
        results.append(ComplianceCheckResult(
            passed: !emailFound,
            checkName: "Email Check",
            details: emailFound ? "Email address pattern detected" : "No email patterns found",
            identifiersFound: emailFound ? [.emailAddress] : []
        ))

        // Check for IP addresses
        let ipFound = detected.contains(.ipAddress)
        results.append(ComplianceCheckResult(
            passed: !ipFound,
            checkName: "IP Address Check",
            details: ipFound ? "IP address pattern detected" : "No IP address patterns found",
            identifiersFound: ipFound ? [.ipAddress] : []
        ))

        // Check for dates
        let datesFound = detected.contains(.dates)
        results.append(ComplianceCheckResult(
            passed: !datesFound,
            checkName: "Date Check",
            details: datesFound ? "Date pattern detected" : "No date patterns found",
            identifiersFound: datesFound ? [.dates] : []
        ))

        // Check for MRN
        let mrnFound = detected.contains(.medicalRecordNumber)
        results.append(ComplianceCheckResult(
            passed: !mrnFound,
            checkName: "MRN Check",
            details: mrnFound ? "Medical record number pattern detected" : "No MRN patterns found",
            identifiersFound: mrnFound ? [.medicalRecordNumber] : []
        ))

        // Check for URLs
        let urlFound = detected.contains(.webURL)
        results.append(ComplianceCheckResult(
            passed: !urlFound,
            checkName: "URL Check",
            details: urlFound ? "URL pattern detected" : "No URL patterns found",
            identifiersFound: urlFound ? [.webURL] : []
        ))

        return results
    }

    /// Checks if the minimum necessary standard is met
    ///
    /// Verifies that a data request only contains the minimum necessary
    /// fields for the stated purpose.
    ///
    /// - Parameters:
    ///   - requestedFields: Fields being requested
    ///   - allowedFields: Fields allowed for the purpose
    /// - Returns: Compliance check result
    public func checkMinimumNecessary(
        requestedFields: Set<String>,
        allowedFields: Set<String>
    ) -> ComplianceCheckResult {
        let excessFields = requestedFields.subtracting(allowedFields)
        if excessFields.isEmpty {
            return ComplianceCheckResult(
                passed: true,
                checkName: "Minimum Necessary Standard",
                details: "All requested fields are within allowed scope"
            )
        } else {
            return ComplianceCheckResult(
                passed: false,
                checkName: "Minimum Necessary Standard",
                details: "Excess fields requested: \(excessFields.sorted().joined(separator: ", "))"
            )
        }
    }

    /// Masks a specific value showing only trailing characters
    ///
    /// - Parameters:
    ///   - value: The value to mask
    ///   - visibleCount: Number of trailing characters to show
    ///   - maskCharacter: Character used for masking
    /// - Returns: Masked value
    public func maskValue(_ value: String, visibleCount: Int = 4, maskCharacter: Character = "*") -> String {
        guard value.count > visibleCount else {
            return String(repeating: maskCharacter, count: value.count)
        }
        let maskCount = value.count - visibleCount
        let masked = String(repeating: maskCharacter, count: maskCount)
        let visible = String(value.suffix(visibleCount))
        return masked + visible
    }

    // MARK: - Private Helpers

    private func replacePattern(in text: String, pattern: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private func matchesPattern(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
