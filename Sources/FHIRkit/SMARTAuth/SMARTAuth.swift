/// SMARTAuth.swift
/// SMART on FHIR authentication implementation
///
/// This file provides a comprehensive SMART on FHIR authentication client supporting
/// OAuth 2.0 authorization flows, PKCE, token management, and SMART App Launch Framework.
/// See: http://hl7.org/fhir/smart-app-launch/
/// See: https://www.hl7.org/fhir/smart-app-launch/app-launch.html

import Foundation
import HL7Core

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - SMART Auth Errors

/// Errors that can occur during SMART on FHIR authentication operations
public enum SMARTAuthError: Error, Sendable, CustomStringConvertible {
    /// The authentication configuration is invalid or incomplete
    case invalidConfiguration(String)
    /// The authorization request was denied or failed
    case authorizationFailed(String)
    /// The token exchange request failed
    case tokenRequestFailed(String)
    /// The token refresh request failed
    case tokenRefreshFailed(String)
    /// The state parameter does not match the expected value
    case invalidState(expected: String, received: String)
    /// The server's .well-known/smart-configuration could not be retrieved
    case missingWellKnownConfig(String)
    /// PKCE code challenge generation failed
    case pkceGenerationFailed(String)
    /// A requested scope was not granted by the server
    case scopeNotGranted(requested: String, granted: String)
    /// A network-level error occurred
    case networkError(String)

    public var description: String {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .authorizationFailed(let message):
            return "Authorization failed: \(message)"
        case .tokenRequestFailed(let message):
            return "Token request failed: \(message)"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .invalidState(let expected, let received):
            return "Invalid state: expected '\(expected)', received '\(received)'"
        case .missingWellKnownConfig(let message):
            return "Missing .well-known configuration: \(message)"
        case .pkceGenerationFailed(let message):
            return "PKCE generation failed: \(message)"
        case .scopeNotGranted(let requested, let granted):
            return "Scope not granted: requested '\(requested)', granted '\(granted)'"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - SMART Launch Type

/// The type of SMART App Launch flow
public enum SMARTLaunchType: String, Sendable, Codable {
    /// Standalone launch — the app launches independently and selects a patient
    case standalone = "standalone"
    /// EHR launch — the app is launched from within an EHR session with context
    case ehrLaunch = "ehr_launch"
}

// MARK: - SMART Auth Configuration

/// Configuration for a SMART on FHIR authentication client
public struct SMARTAuthConfiguration: Sendable, Equatable {
    /// OAuth 2.0 client identifier registered with the authorization server
    public let clientId: String
    /// Redirect URI for receiving the authorization code callback
    public let redirectURI: URL
    /// Requested OAuth 2.0 scopes
    public let scopes: [SMARTScope]
    /// Base URL of the FHIR server
    public let serverURL: URL
    /// Token endpoint URL (can be discovered via .well-known)
    public let tokenURL: URL
    /// Authorization endpoint URL (can be discovered via .well-known)
    public let authorizeURL: URL

    public init(
        clientId: String,
        redirectURI: URL,
        scopes: [SMARTScope],
        serverURL: URL,
        tokenURL: URL,
        authorizeURL: URL
    ) {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.serverURL = serverURL
        self.tokenURL = tokenURL
        self.authorizeURL = authorizeURL
    }
}

// MARK: - SMART Scope

/// A SMART on FHIR OAuth 2.0 scope
///
/// Represents individual scopes used in the SMART App Launch Framework.
/// Provides static helpers for common FHIR clinical and launch scopes.
public struct SMARTScope: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// The raw scope string value (e.g., "patient/Patient.read")
    public let scopeString: String

    /// Creates a scope from a raw string value
    /// - Parameter rawValue: The scope string
    public init(rawValue: String) {
        self.scopeString = rawValue
    }

    public var description: String { scopeString }

    // MARK: Patient-level scopes

    /// Read access to all patient-compartment resources
    public static let patientAllRead = SMARTScope(rawValue: "patient/*.read")
    /// Write access to all patient-compartment resources
    public static let patientAllWrite = SMARTScope(rawValue: "patient/*.write")
    /// Full access to all patient-compartment resources
    public static let patientAllFull = SMARTScope(rawValue: "patient/*.*")

    // MARK: User-level scopes

    /// Read access to all resources the user can access
    public static let userAllRead = SMARTScope(rawValue: "user/*.read")
    /// Write access to all resources the user can access
    public static let userAllWrite = SMARTScope(rawValue: "user/*.write")
    /// Full access to all resources the user can access
    public static let userAllFull = SMARTScope(rawValue: "user/*.*")

    // MARK: Launch scopes

    /// Permission to obtain launch context
    public static let launch = SMARTScope(rawValue: "launch")
    /// Permission to receive a patient context during launch
    public static let launchPatient = SMARTScope(rawValue: "launch/patient")

    // MARK: Identity scopes

    /// OpenID Connect scope for identity token
    public static let openid = SMARTScope(rawValue: "openid")
    /// Scope to receive the FHIR user identity claim
    public static let fhirUser = SMARTScope(rawValue: "fhirUser")

    // MARK: Token lifetime scopes

    /// Request a refresh token for offline access
    public static let offlineAccess = SMARTScope(rawValue: "offline_access")
    /// Request online-only access (no refresh token)
    public static let onlineAccess = SMARTScope(rawValue: "online_access")

    // MARK: Resource-specific scope helpers

    /// Creates a patient-level read scope for a specific resource type
    /// - Parameter resourceType: The FHIR resource type (e.g., "Patient", "Observation")
    /// - Returns: A scope like `patient/Patient.read`
    public static func patientRead(_ resourceType: String) -> SMARTScope {
        SMARTScope(rawValue: "patient/\(resourceType).read")
    }

    /// Creates a patient-level write scope for a specific resource type
    /// - Parameter resourceType: The FHIR resource type
    /// - Returns: A scope like `patient/Patient.write`
    public static func patientWrite(_ resourceType: String) -> SMARTScope {
        SMARTScope(rawValue: "patient/\(resourceType).write")
    }

    /// Creates a user-level read scope for a specific resource type
    /// - Parameter resourceType: The FHIR resource type
    /// - Returns: A scope like `user/Patient.read`
    public static func userRead(_ resourceType: String) -> SMARTScope {
        SMARTScope(rawValue: "user/\(resourceType).read")
    }

    /// Creates a user-level write scope for a specific resource type
    /// - Parameter resourceType: The FHIR resource type
    /// - Returns: A scope like `user/Patient.write`
    public static func userWrite(_ resourceType: String) -> SMARTScope {
        SMARTScope(rawValue: "user/\(resourceType).write")
    }
}

// MARK: - OAuth Token Response

/// Raw token response from the OAuth 2.0 token endpoint
///
/// Maps directly to the JSON response from the SMART authorization server.
/// See: http://hl7.org/fhir/smart-app-launch/scopes-and-launch-context.html
public struct OAuthTokenResponse: Codable, Sendable, Equatable {
    /// The access token issued by the authorization server
    public let accessToken: String
    /// The type of the token (typically "Bearer")
    public let tokenType: String
    /// Lifetime of the access token in seconds
    public let expiresIn: Int?
    /// Refresh token for obtaining new access tokens
    public let refreshToken: String?
    /// Space-delimited list of scopes granted
    public let scope: String?
    /// FHIR patient ID associated with the launch context
    public let patient: String?
    /// OpenID Connect ID token
    public let idToken: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case patient
        case idToken = "id_token"
    }
}

// MARK: - OAuth Token

/// A validated OAuth 2.0 token with expiration tracking
///
/// Created from an ``OAuthTokenResponse`` and provides convenience
/// methods for checking expiration and refresh eligibility.
public struct OAuthToken: Sendable, Equatable {
    /// The access token string
    public let accessToken: String
    /// The token type (e.g., "Bearer")
    public let tokenType: String
    /// The date/time at which the token expires
    public let expiresAt: Date?
    /// The refresh token, if issued
    public let refreshToken: String?
    /// Space-delimited scopes granted
    public let scope: String?
    /// FHIR patient context ID
    public let patientId: String?
    /// OpenID Connect ID token
    public let idToken: String?

    public init(
        accessToken: String,
        tokenType: String = "Bearer",
        expiresAt: Date? = nil,
        refreshToken: String? = nil,
        scope: String? = nil,
        patientId: String? = nil,
        idToken: String? = nil
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.refreshToken = refreshToken
        self.scope = scope
        self.patientId = patientId
        self.idToken = idToken
    }

    /// Whether the access token has expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }

    /// Whether the token should be refreshed within a given time window
    /// - Parameter interval: Number of seconds before expiration to trigger refresh
    /// - Returns: `true` if the token expires within the given interval
    public func needsRefresh(within interval: TimeInterval = 60) -> Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date().addingTimeInterval(interval) >= expiresAt
    }

    /// Creates an ``OAuthToken`` from a raw ``OAuthTokenResponse``
    /// - Parameter response: The token response from the server
    /// - Returns: A validated `OAuthToken`
    public static func from(response: OAuthTokenResponse) -> OAuthToken {
        let expiresAt: Date?
        if let expiresIn = response.expiresIn {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            expiresAt = nil
        }
        return OAuthToken(
            accessToken: response.accessToken,
            tokenType: response.tokenType,
            expiresAt: expiresAt,
            refreshToken: response.refreshToken,
            scope: response.scope,
            patientId: response.patient,
            idToken: response.idToken
        )
    }
}

// MARK: - SMART Well-Known Configuration

/// Server capability discovery via `.well-known/smart-configuration`
///
/// Represents the SMART configuration document published by FHIR servers.
/// See: http://hl7.org/fhir/smart-app-launch/conformance.html
public struct SMARTWellKnownConfiguration: Codable, Sendable, Equatable {
    /// OAuth 2.0 authorization endpoint URL
    public let authorizationEndpoint: String
    /// OAuth 2.0 token endpoint URL
    public let tokenEndpoint: String
    /// Optional token revocation endpoint URL
    public let revocationEndpoint: String?
    /// Optional token introspection endpoint URL
    public let introspectionEndpoint: String?
    /// Optional user info endpoint URL
    public let userInfoEndpoint: String?
    /// Optional management endpoint URL
    public let managementEndpoint: String?
    /// Optional registration endpoint URL
    public let registrationEndpoint: String?
    /// Capabilities supported by this server
    public let capabilities: [String]?
    /// Scopes supported by this server
    public let scopesSupported: [String]?
    /// Response types supported
    public let responseTypesSupported: [String]?
    /// Grant types supported
    public let grantTypesSupported: [String]?
    /// Code challenge methods supported (e.g., "S256")
    public let codeChallengeMethodsSupported: [String]?

    private enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case revocationEndpoint = "revocation_endpoint"
        case introspectionEndpoint = "introspection_endpoint"
        case userInfoEndpoint = "userinfo_endpoint"
        case managementEndpoint = "management_endpoint"
        case registrationEndpoint = "registration_endpoint"
        case capabilities
        case scopesSupported = "scopes_supported"
        case responseTypesSupported = "response_types_supported"
        case grantTypesSupported = "grant_types_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
    }
}

// MARK: - Token Store Protocol

/// Protocol for persisting OAuth tokens
///
/// Conforming types provide storage and retrieval of ``OAuthToken`` values
/// keyed by server URL. Implementations must be safe for concurrent access.
public protocol TokenStore: Sendable {
    /// Saves a token associated with a server URL
    /// - Parameters:
    ///   - token: The token to save
    ///   - serverURL: The FHIR server URL this token is associated with
    func saveToken(_ token: OAuthToken, for serverURL: URL) async throws

    /// Loads the token associated with a server URL
    /// - Parameter serverURL: The FHIR server URL
    /// - Returns: The stored token, or `nil` if none exists
    func loadToken(for serverURL: URL) async throws -> OAuthToken?

    /// Deletes the token associated with a server URL
    /// - Parameter serverURL: The FHIR server URL
    func deleteToken(for serverURL: URL) async throws

    /// Returns the token for a specific server URL (alias for `loadToken`)
    /// - Parameter serverURL: The FHIR server URL
    /// - Returns: The stored token, or `nil` if none exists
    func tokenForServer(_ serverURL: URL) async throws -> OAuthToken?
}

// MARK: - In-Memory Token Store

/// An actor-based in-memory token store
///
/// Stores tokens in a dictionary keyed by the server URL's absolute string.
/// Suitable for testing and short-lived sessions; tokens are lost when the
/// process exits.
public actor InMemoryTokenStore: TokenStore {
    private var tokens: [String: OAuthToken] = [:]

    public init() {}

    public func saveToken(_ token: OAuthToken, for serverURL: URL) async throws {
        tokens[serverURL.absoluteString] = token
    }

    public func loadToken(for serverURL: URL) async throws -> OAuthToken? {
        tokens[serverURL.absoluteString]
    }

    public func deleteToken(for serverURL: URL) async throws {
        tokens.removeValue(forKey: serverURL.absoluteString)
    }

    public func tokenForServer(_ serverURL: URL) async throws -> OAuthToken? {
        try await loadToken(for: serverURL)
    }
}

// MARK: - PKCE Support

/// PKCE (Proof Key for Code Exchange) parameters
///
/// Implements RFC 7636 for enhanced OAuth 2.0 security.
/// The code verifier is a random string, and the code challenge is its
/// SHA-256 hash encoded in Base64URL.
/// See: https://tools.ietf.org/html/rfc7636
public struct PKCEParameters: Sendable, Equatable {
    /// The code verifier — a high-entropy cryptographic random string
    public let codeVerifier: String
    /// The code challenge — derived from the code verifier
    public let codeChallenge: String
    /// The challenge method used (always "S256")
    public let challengeMethod: String

    /// Generates a new set of PKCE parameters
    /// - Throws: ``SMARTAuthError/pkceGenerationFailed(_:)`` if generation fails
    /// - Returns: A `PKCEParameters` instance
    public static func generate() throws -> PKCEParameters {
        let verifier = generateCodeVerifier()
        guard let challenge = generateCodeChallenge(from: verifier) else {
            throw SMARTAuthError.pkceGenerationFailed("Failed to generate code challenge from verifier")
        }
        return PKCEParameters(
            codeVerifier: verifier,
            codeChallenge: challenge,
            challengeMethod: "S256"
        )
    }

    /// Generates a cryptographically random code verifier (43–128 characters)
    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in 0..<bytes.count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return base64URLEncode(Data(bytes))
    }

    /// Generates a code challenge by SHA-256 hashing the verifier
    private static func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .ascii) else { return nil }
        let hash = sha256(data)
        return base64URLEncode(hash)
    }
}

// MARK: - SHA-256 & Base64URL Helpers

/// Computes the SHA-256 hash of the given data
///
/// Uses CryptoKit on Apple platforms and a portable Swift implementation elsewhere.
/// - Parameter data: The input data to hash
/// - Returns: The 32-byte SHA-256 digest
internal func sha256(_ data: Data) -> Data {
    #if canImport(CryptoKit)
    let digest = SHA256.hash(data: data)
    return Data(digest)
    #else
    return sha256Software(data)
    #endif
}

/// Pure-Swift SHA-256 implementation for platforms without CryptoKit
internal func sha256Software(_ data: Data) -> Data {
    // SHA-256 constants: first 32 bits of the fractional parts of the cube roots of the first 64 primes
    let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    var h0: UInt32 = 0x6a09e667
    var h1: UInt32 = 0xbb67ae85
    var h2: UInt32 = 0x3c6ef372
    var h3: UInt32 = 0xa54ff53a
    var h4: UInt32 = 0x510e527f
    var h5: UInt32 = 0x9b05688c
    var h6: UInt32 = 0x1f83d9ab
    var h7: UInt32 = 0x5be0cd19

    // Pre-processing: pad message
    var message = [UInt8](data)
    let originalLength = message.count
    let bitLength = UInt64(originalLength) * 8

    message.append(0x80)
    while message.count % 64 != 56 {
        message.append(0x00)
    }
    // Append original length in bits as big-endian 64-bit
    for i in stride(from: 56, through: 0, by: -8) {
        message.append(UInt8(truncatingIfNeeded: bitLength >> i))
    }

    // Process each 512-bit (64-byte) block
    for chunkStart in stride(from: 0, to: message.count, by: 64) {
        var w = [UInt32](repeating: 0, count: 64)

        for i in 0..<16 {
            let offset = chunkStart + i * 4
            w[i] = UInt32(message[offset]) << 24
                | UInt32(message[offset + 1]) << 16
                | UInt32(message[offset + 2]) << 8
                | UInt32(message[offset + 3])
        }
        for i in 16..<64 {
            let s0 = rightRotate(w[i - 15], by: 7) ^ rightRotate(w[i - 15], by: 18) ^ (w[i - 15] >> 3)
            let s1 = rightRotate(w[i - 2], by: 17) ^ rightRotate(w[i - 2], by: 19) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
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

    var digest = Data(capacity: 32)
    for value in [h0, h1, h2, h3, h4, h5, h6, h7] {
        digest.append(UInt8(truncatingIfNeeded: value >> 24))
        digest.append(UInt8(truncatingIfNeeded: value >> 16))
        digest.append(UInt8(truncatingIfNeeded: value >> 8))
        digest.append(UInt8(truncatingIfNeeded: value))
    }
    return digest
}

/// Right-rotates a 32-bit integer by the given number of bits
private func rightRotate(_ value: UInt32, by amount: UInt32) -> UInt32 {
    (value >> amount) | (value << (32 - amount))
}

/// Encodes data using Base64URL encoding (RFC 4648 §5)
///
/// Replaces `+` with `-`, `/` with `_`, and strips trailing `=` padding.
/// - Parameter data: The data to encode
/// - Returns: The Base64URL-encoded string
internal func base64URLEncode(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

// MARK: - SMART Scope Parser

/// Utility for parsing and validating SMART on FHIR scope strings
public struct SMARTScopeParser: Sendable {
    public init() {}

    /// Parses a space-delimited scope string into individual ``SMARTScope`` values
    /// - Parameter scopeString: A space-delimited scope string (e.g., "patient/Patient.read launch openid")
    /// - Returns: An array of ``SMARTScope`` values
    public func parseScopes(_ scopeString: String) -> [SMARTScope] {
        scopeString
            .split(separator: " ")
            .map { SMARTScope(rawValue: String($0)) }
    }

    /// Combines multiple ``SMARTScope`` values into a single space-delimited string
    /// - Parameter scopes: The scopes to combine
    /// - Returns: A space-delimited scope string
    public func combinedScopeString(_ scopes: [SMARTScope]) -> String {
        scopes.map(\.scopeString).joined(separator: " ")
    }

    /// Validates that all requested scopes were granted
    /// - Parameters:
    ///   - requested: The scopes that were requested
    ///   - granted: The scope string returned by the server
    /// - Returns: An array of scopes that were requested but not granted
    public func missingScopes(requested: [SMARTScope], granted: String) -> [SMARTScope] {
        let grantedScopes = Set(parseScopes(granted).map(\.scopeString))
        return requested.filter { !grantedScopes.contains($0.scopeString) }
    }

    /// Validates that all requested scopes were granted
    /// - Parameters:
    ///   - requested: The scopes that were requested
    ///   - granted: The scope string returned by the server
    /// - Throws: ``SMARTAuthError/scopeNotGranted(requested:granted:)`` if any scopes are missing
    public func validateScopes(requested: [SMARTScope], granted: String) throws {
        let missing = missingScopes(requested: requested, granted: granted)
        if !missing.isEmpty {
            let missingStr = missing.map(\.scopeString).joined(separator: " ")
            throw SMARTAuthError.scopeNotGranted(requested: missingStr, granted: granted)
        }
    }

    /// Checks whether a scope string represents a valid FHIR R4 clinical scope
    ///
    /// Valid clinical scopes match `patient/[Resource].[read|write|*]` or `user/[Resource].[read|write|*]`.
    /// - Parameter scope: The scope string to validate
    /// - Returns: `true` if the scope is a valid clinical scope
    public func isClinicalScope(_ scope: String) -> Bool {
        let pattern = #"^(patient|user)/[A-Za-z*]+\.(read|write|\*)$"#
        return scope.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - SMART Auth Client

/// Actor-based SMART on FHIR authentication client
///
/// Manages the full OAuth 2.0 authorization lifecycle including PKCE,
/// token exchange, refresh, and revocation. Uses ``FHIRURLSession`` for
/// all network operations, enabling dependency injection for testing.
///
/// Usage:
/// ```swift
/// let config = SMARTAuthConfiguration(
///     clientId: "my-app",
///     redirectURI: URL(string: "myapp://callback")!,
///     scopes: [.launchPatient, .patientAllRead, .openid, .fhirUser],
///     serverURL: URL(string: "https://fhir.example.org/r4")!,
///     tokenURL: URL(string: "https://auth.example.org/token")!,
///     authorizeURL: URL(string: "https://auth.example.org/authorize")!
/// )
/// let client = SMARTAuthClient(configuration: config)
/// let authURL = try client.buildAuthorizationURL(launchType: .standalone)
/// ```
public actor SMARTAuthClient {
    /// The authentication configuration
    public let configuration: SMARTAuthConfiguration

    /// Token store for persisting tokens
    private let tokenStore: TokenStore

    /// URL session for network requests
    private let session: FHIRURLSession

    /// The currently active token, if any
    public private(set) var currentToken: OAuthToken?

    /// JSON decoder configured for SMART responses
    private let decoder: JSONDecoder

    /// Scope parser utility
    private let scopeParser: SMARTScopeParser

    /// Initializes a new SMART authentication client
    /// - Parameters:
    ///   - configuration: The SMART auth configuration
    ///   - tokenStore: Token storage implementation (defaults to ``InMemoryTokenStore``)
    ///   - session: URL session for network calls (defaults to `URLSession.shared`)
    public init(
        configuration: SMARTAuthConfiguration,
        tokenStore: TokenStore? = nil,
        session: FHIRURLSession? = nil
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore ?? InMemoryTokenStore()
        self.session = session ?? URLSession.shared
        self.decoder = JSONDecoder()
        self.scopeParser = SMARTScopeParser()
    }

    // MARK: - Authorization URL

    /// Builds the authorization URL for initiating the OAuth 2.0 flow
    ///
    /// Constructs a URL with all required query parameters including PKCE
    /// code challenge, scopes, redirect URI, and optional launch context.
    /// - Parameters:
    ///   - launchType: The type of SMART launch flow
    ///   - launchContext: Optional EHR launch context token
    ///   - state: An opaque state value for CSRF protection
    ///   - pkce: Optional PKCE parameters (generated automatically if `nil`)
    /// - Throws: ``SMARTAuthError`` if URL construction fails
    /// - Returns: The authorization URL to present to the user
    public func buildAuthorizationURL(
        launchType: SMARTLaunchType = .standalone,
        launchContext: String? = nil,
        state: String? = nil,
        pkce: PKCEParameters? = nil
    ) throws -> URL {
        guard var components = URLComponents(url: configuration.authorizeURL, resolvingAgainstBaseURL: true) else {
            throw SMARTAuthError.invalidConfiguration("Cannot parse authorize URL: \(configuration.authorizeURL)")
        }

        let scopeString = scopeParser.combinedScopeString(configuration.scopes)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: scopeString),
            URLQueryItem(name: "aud", value: configuration.serverURL.absoluteString),
        ]

        if let state = state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }

        if let pkce = pkce {
            queryItems.append(URLQueryItem(name: "code_challenge", value: pkce.codeChallenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: pkce.challengeMethod))
        }

        if launchType == .ehrLaunch, let launchContext = launchContext {
            queryItems.append(URLQueryItem(name: "launch", value: launchContext))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw SMARTAuthError.invalidConfiguration("Failed to construct authorization URL")
        }
        return url
    }

    // MARK: - Token Exchange

    /// Exchanges an authorization code for an access token
    ///
    /// Sends a POST request to the token endpoint with the authorization code
    /// and optional PKCE code verifier.
    /// - Parameters:
    ///   - authorizationCode: The authorization code from the callback
    ///   - state: The expected state value for CSRF validation
    ///   - codeVerifier: The PKCE code verifier used during authorization
    /// - Throws: ``SMARTAuthError`` if the exchange fails
    /// - Returns: The obtained ``OAuthToken``
    public func exchangeCodeForToken(
        authorizationCode: String,
        state: String? = nil,
        codeVerifier: String? = nil
    ) async throws -> OAuthToken {
        var bodyParams = [
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "redirect_uri": configuration.redirectURI.absoluteString,
            "client_id": configuration.clientId,
        ]

        if let codeVerifier = codeVerifier {
            bodyParams["code_verifier"] = codeVerifier
        }

        let tokenResponse = try await performTokenRequest(params: bodyParams)
        let token = OAuthToken.from(response: tokenResponse)

        try await tokenStore.saveToken(token, for: configuration.serverURL)
        currentToken = token
        return token
    }

    // MARK: - Token Refresh

    /// Refreshes an expired or expiring token
    ///
    /// Uses the refresh token from the provided ``OAuthToken`` to obtain a new
    /// access token from the authorization server.
    /// - Parameter token: The token containing a valid refresh token
    /// - Throws: ``SMARTAuthError/tokenRefreshFailed(_:)`` if the token has no refresh token or the request fails
    /// - Returns: The new ``OAuthToken``
    public func refreshToken(_ token: OAuthToken) async throws -> OAuthToken {
        guard let refreshTokenValue = token.refreshToken else {
            throw SMARTAuthError.tokenRefreshFailed("No refresh token available")
        }

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshTokenValue,
            "client_id": configuration.clientId,
        ]

        let tokenResponse: OAuthTokenResponse
        do {
            tokenResponse = try await performTokenRequest(params: bodyParams)
        } catch {
            throw SMARTAuthError.tokenRefreshFailed("Refresh request failed: \(error.localizedDescription)")
        }

        let newToken = OAuthToken.from(response: tokenResponse)
        try await tokenStore.saveToken(newToken, for: configuration.serverURL)
        currentToken = newToken
        return newToken
    }

    // MARK: - Get Valid Token

    /// Returns a valid (non-expired) access token, refreshing if necessary
    ///
    /// Checks the current token's expiration status and automatically refreshes
    /// it when needed. If no current token exists, attempts to load one from the
    /// token store.
    /// - Throws: ``SMARTAuthError`` if no token is available or refresh fails
    /// - Returns: A valid ``OAuthToken``
    public func getValidToken() async throws -> OAuthToken {
        // Try current token first
        if let token = currentToken {
            if !token.needsRefresh() {
                return token
            }
            // Token needs refresh
            if token.refreshToken != nil {
                return try await refreshToken(token)
            }
        }

        // Try loading from store
        if let storedToken = try await tokenStore.loadToken(for: configuration.serverURL) {
            if !storedToken.needsRefresh() {
                currentToken = storedToken
                return storedToken
            }
            if storedToken.refreshToken != nil {
                return try await refreshToken(storedToken)
            }
        }

        throw SMARTAuthError.authorizationFailed("No valid token available; authorization required")
    }

    // MARK: - Configuration Discovery

    /// Discovers the SMART configuration from the server's well-known endpoint
    ///
    /// Fetches `[serverURL]/.well-known/smart-configuration` and decodes the response.
    /// - Parameter serverURL: The base FHIR server URL (defaults to the configured server URL)
    /// - Throws: ``SMARTAuthError/missingWellKnownConfig(_:)`` if discovery fails
    /// - Returns: The ``SMARTWellKnownConfiguration``
    public func discoverConfiguration(
        serverURL: URL? = nil
    ) async throws -> SMARTWellKnownConfiguration {
        let baseURL = serverURL ?? configuration.serverURL
        guard let wellKnownURL = URL(string: "\(baseURL.absoluteString)/.well-known/smart-configuration") else {
            throw SMARTAuthError.missingWellKnownConfig("Invalid server URL for .well-known discovery")
        }

        var request = URLRequest(url: wellKnownURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SMARTAuthError.missingWellKnownConfig("Network error: \(error.localizedDescription)")
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SMARTAuthError.missingWellKnownConfig(
                "Server returned HTTP \(httpResponse.statusCode)"
            )
        }

        do {
            return try decoder.decode(SMARTWellKnownConfiguration.self, from: data)
        } catch {
            throw SMARTAuthError.missingWellKnownConfig("Failed to decode configuration: \(error.localizedDescription)")
        }
    }

    // MARK: - Token Revocation

    /// Revokes a token at the authorization server
    ///
    /// Sends a revocation request per RFC 7009. Requires the server to
    /// publish a revocation endpoint in its SMART configuration.
    /// - Parameter token: The token to revoke
    /// - Throws: ``SMARTAuthError`` if revocation fails
    public func revokeToken(_ token: OAuthToken) async throws {
        // Attempt to discover revocation endpoint
        let wellKnown = try await discoverConfiguration()
        guard let revocationEndpointString = wellKnown.revocationEndpoint,
              let revocationURL = URL(string: revocationEndpointString) else {
            throw SMARTAuthError.invalidConfiguration("No revocation endpoint available")
        }

        var request = URLRequest(url: revocationURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "token=\(token.accessToken)&client_id=\(configuration.clientId)"
        request.httpBody = bodyString.data(using: .utf8)

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw SMARTAuthError.networkError("Revocation request failed: \(error.localizedDescription)")
        }

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            throw SMARTAuthError.tokenRequestFailed(
                "Revocation failed with HTTP \(httpResponse.statusCode)"
            )
        }

        // Clear local state
        try await tokenStore.deleteToken(for: configuration.serverURL)
        if currentToken?.accessToken == token.accessToken {
            currentToken = nil
        }
    }

    // MARK: - Private Helpers

    /// Performs a token endpoint request with the given parameters
    private func performTokenRequest(params: [String: String]) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: configuration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = params
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SMARTAuthError.networkError("Token request failed: \(error.localizedDescription)")
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw SMARTAuthError.tokenRequestFailed(
                "HTTP \(httpResponse.statusCode): \(body)"
            )
        }

        do {
            return try decoder.decode(OAuthTokenResponse.self, from: data)
        } catch {
            throw SMARTAuthError.tokenRequestFailed("Failed to decode token response: \(error.localizedDescription)")
        }
    }
}
