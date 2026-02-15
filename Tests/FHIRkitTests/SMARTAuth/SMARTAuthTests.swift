import XCTest
@testable import FHIRkit
@testable import HL7Core
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Mock URL Session for SMART Auth Tests

/// Mock URL session that returns configurable responses for token/discovery requests
final class MockSMARTURLSession: FHIRURLSession, @unchecked Sendable {
    var requests: [URLRequest] = []
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var responseHeaders: [String: String] = [:]
    var responseError: Error?

    /// Queue of responses for sequential calls
    var responseQueue: [(Data, Int)] = []
    private var callIndex = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)

        if let error = responseError {
            throw error
        }

        let data: Data
        let statusCode: Int

        if !responseQueue.isEmpty && callIndex < responseQueue.count {
            let entry = responseQueue[callIndex]
            data = entry.0
            statusCode = entry.1
            callIndex += 1
        } else {
            data = responseData
            statusCode = responseStatusCode
        }

        let url = request.url ?? URL(string: "https://example.com")!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )!
        return (data, httpResponse)
    }

    func reset() {
        requests = []
        responseData = Data()
        responseStatusCode = 200
        responseHeaders = [:]
        responseError = nil
        responseQueue = []
        callIndex = 0
    }
}

// MARK: - Test Helpers

/// Helpers for building test fixtures
enum SMARTTestHelper {
    static let serverURL = URL(string: "https://fhir.example.org/r4")!
    static let tokenURL = URL(string: "https://auth.example.org/token")!
    static let authorizeURL = URL(string: "https://auth.example.org/authorize")!
    static let redirectURI = URL(string: "myapp://callback")!

    static func makeConfiguration(
        scopes: [SMARTScope] = [.patientAllRead, .openid, .fhirUser]
    ) -> SMARTAuthConfiguration {
        SMARTAuthConfiguration(
            clientId: "test-client",
            redirectURI: redirectURI,
            scopes: scopes,
            serverURL: serverURL,
            tokenURL: tokenURL,
            authorizeURL: authorizeURL
        )
    }

    static func makeTokenResponseJSON(
        accessToken: String = "test-access-token",
        tokenType: String = "Bearer",
        expiresIn: Int = 3600,
        refreshToken: String? = "test-refresh-token",
        scope: String? = "patient/*.read openid fhirUser",
        patient: String? = "patient-123",
        idToken: String? = nil
    ) -> Data {
        var json: [String: Any] = [
            "access_token": accessToken,
            "token_type": tokenType,
            "expires_in": expiresIn,
        ]
        if let refreshToken { json["refresh_token"] = refreshToken }
        if let scope { json["scope"] = scope }
        if let patient { json["patient"] = patient }
        if let idToken { json["id_token"] = idToken }
        return try! JSONSerialization.data(withJSONObject: json)
    }

    static func makeWellKnownJSON() -> Data {
        let json: [String: Any] = [
            "authorization_endpoint": "https://auth.example.org/authorize",
            "token_endpoint": "https://auth.example.org/token",
            "revocation_endpoint": "https://auth.example.org/revoke",
            "capabilities": ["launch-standalone", "launch-ehr", "client-public"],
            "scopes_supported": ["openid", "fhirUser", "patient/*.read", "launch"],
            "code_challenge_methods_supported": ["S256"],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
}

// MARK: - SMARTAuthError Tests

final class SMARTAuthErrorTests: XCTestCase {
    func testErrorDescriptions() {
        let errors: [SMARTAuthError] = [
            .invalidConfiguration("bad config"),
            .authorizationFailed("denied"),
            .tokenRequestFailed("http error"),
            .tokenRefreshFailed("no refresh"),
            .invalidState(expected: "abc", received: "xyz"),
            .missingWellKnownConfig("not found"),
            .pkceGenerationFailed("hash failed"),
            .scopeNotGranted(requested: "patient/*.read", granted: "openid"),
            .networkError("timeout"),
        ]

        for error in errors {
            XCTAssertFalse(error.description.isEmpty, "Error description should not be empty")
        }

        XCTAssertTrue(SMARTAuthError.invalidState(expected: "a", received: "b").description.contains("a"))
    }
}

// MARK: - SMARTScope Tests

final class SMARTScopeTests: XCTestCase {
    func testStaticScopes() {
        XCTAssertEqual(SMARTScope.patientAllRead.scopeString, "patient/*.read")
        XCTAssertEqual(SMARTScope.patientAllWrite.scopeString, "patient/*.write")
        XCTAssertEqual(SMARTScope.patientAllFull.scopeString, "patient/*.*")
        XCTAssertEqual(SMARTScope.userAllRead.scopeString, "user/*.read")
        XCTAssertEqual(SMARTScope.userAllWrite.scopeString, "user/*.write")
        XCTAssertEqual(SMARTScope.userAllFull.scopeString, "user/*.*")
        XCTAssertEqual(SMARTScope.launch.scopeString, "launch")
        XCTAssertEqual(SMARTScope.launchPatient.scopeString, "launch/patient")
        XCTAssertEqual(SMARTScope.openid.scopeString, "openid")
        XCTAssertEqual(SMARTScope.fhirUser.scopeString, "fhirUser")
        XCTAssertEqual(SMARTScope.offlineAccess.scopeString, "offline_access")
        XCTAssertEqual(SMARTScope.onlineAccess.scopeString, "online_access")
    }

    func testResourceSpecificScopes() {
        XCTAssertEqual(SMARTScope.patientRead("Patient").scopeString, "patient/Patient.read")
        XCTAssertEqual(SMARTScope.patientWrite("Observation").scopeString, "patient/Observation.write")
        XCTAssertEqual(SMARTScope.userRead("Encounter").scopeString, "user/Encounter.read")
        XCTAssertEqual(SMARTScope.userWrite("MedicationRequest").scopeString, "user/MedicationRequest.write")
    }

    func testScopeEquality() {
        let a = SMARTScope(rawValue: "patient/Patient.read")
        let b = SMARTScope.patientRead("Patient")
        XCTAssertEqual(a, b)
    }

    func testScopeDescription() {
        let scope = SMARTScope.openid
        XCTAssertEqual(scope.description, "openid")
    }

    func testScopeHashable() {
        let set: Set<SMARTScope> = [.openid, .fhirUser, .openid]
        XCTAssertEqual(set.count, 2)
    }
}

// MARK: - SMARTAuthConfiguration Tests

final class SMARTAuthConfigurationTests: XCTestCase {
    func testConfigurationCreation() {
        let config = SMARTTestHelper.makeConfiguration()
        XCTAssertEqual(config.clientId, "test-client")
        XCTAssertEqual(config.redirectURI, SMARTTestHelper.redirectURI)
        XCTAssertEqual(config.scopes.count, 3)
        XCTAssertEqual(config.serverURL, SMARTTestHelper.serverURL)
        XCTAssertEqual(config.tokenURL, SMARTTestHelper.tokenURL)
        XCTAssertEqual(config.authorizeURL, SMARTTestHelper.authorizeURL)
    }

    func testConfigurationEquality() {
        let a = SMARTTestHelper.makeConfiguration()
        let b = SMARTTestHelper.makeConfiguration()
        XCTAssertEqual(a, b)
    }
}

// MARK: - OAuthTokenResponse Tests

final class OAuthTokenResponseTests: XCTestCase {
    func testDecoding() throws {
        let json = SMARTTestHelper.makeTokenResponseJSON()
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: json)

        XCTAssertEqual(response.accessToken, "test-access-token")
        XCTAssertEqual(response.tokenType, "Bearer")
        XCTAssertEqual(response.expiresIn, 3600)
        XCTAssertEqual(response.refreshToken, "test-refresh-token")
        XCTAssertEqual(response.scope, "patient/*.read openid fhirUser")
        XCTAssertEqual(response.patient, "patient-123")
    }

    func testDecodingMinimal() throws {
        let json = """
        {"access_token": "tok", "token_type": "Bearer"}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: json)

        XCTAssertEqual(response.accessToken, "tok")
        XCTAssertNil(response.expiresIn)
        XCTAssertNil(response.refreshToken)
        XCTAssertNil(response.scope)
        XCTAssertNil(response.patient)
        XCTAssertNil(response.idToken)
    }

    func testEncoding() throws {
        let response = OAuthTokenResponse(
            accessToken: "tok",
            tokenType: "Bearer",
            expiresIn: 60,
            refreshToken: nil,
            scope: "openid",
            patient: nil,
            idToken: nil
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        XCTAssertEqual(response, decoded)
    }
}

// MARK: - OAuthToken Tests

final class OAuthTokenTests: XCTestCase {
    func testTokenNotExpired() {
        let token = OAuthToken(
            accessToken: "tok",
            expiresAt: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(token.isExpired)
    }

    func testTokenExpired() {
        let token = OAuthToken(
            accessToken: "tok",
            expiresAt: Date().addingTimeInterval(-1)
        )
        XCTAssertTrue(token.isExpired)
    }

    func testTokenNoExpiry() {
        let token = OAuthToken(accessToken: "tok", expiresAt: nil)
        XCTAssertFalse(token.isExpired)
        XCTAssertFalse(token.needsRefresh())
    }

    func testNeedsRefresh() {
        let token = OAuthToken(
            accessToken: "tok",
            expiresAt: Date().addingTimeInterval(30)
        )
        XCTAssertTrue(token.needsRefresh(within: 60))
        XCTAssertFalse(token.needsRefresh(within: 10))
    }

    func testFromResponse() {
        let response = OAuthTokenResponse(
            accessToken: "at",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: "rt",
            scope: "openid",
            patient: "p1",
            idToken: "id1"
        )
        let token = OAuthToken.from(response: response)
        XCTAssertEqual(token.accessToken, "at")
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.refreshToken, "rt")
        XCTAssertEqual(token.scope, "openid")
        XCTAssertEqual(token.patientId, "p1")
        XCTAssertEqual(token.idToken, "id1")
        XCTAssertNotNil(token.expiresAt)
        XCTAssertFalse(token.isExpired)
    }

    func testFromResponseWithoutExpiry() {
        let response = OAuthTokenResponse(
            accessToken: "at",
            tokenType: "Bearer",
            expiresIn: nil,
            refreshToken: nil,
            scope: nil,
            patient: nil,
            idToken: nil
        )
        let token = OAuthToken.from(response: response)
        XCTAssertNil(token.expiresAt)
    }
}

// MARK: - PKCE Tests

final class PKCEParametersTests: XCTestCase {
    func testGenerate() throws {
        let pkce = try PKCEParameters.generate()
        XCTAssertFalse(pkce.codeVerifier.isEmpty)
        XCTAssertFalse(pkce.codeChallenge.isEmpty)
        XCTAssertEqual(pkce.challengeMethod, "S256")
        // Verifier and challenge should differ
        XCTAssertNotEqual(pkce.codeVerifier, pkce.codeChallenge)
    }

    func testGenerateUniqueness() throws {
        let a = try PKCEParameters.generate()
        let b = try PKCEParameters.generate()
        XCTAssertNotEqual(a.codeVerifier, b.codeVerifier)
        XCTAssertNotEqual(a.codeChallenge, b.codeChallenge)
    }

    func testVerifierLength() throws {
        let pkce = try PKCEParameters.generate()
        // Base64URL of 32 bytes = 43 characters (no padding)
        XCTAssertGreaterThanOrEqual(pkce.codeVerifier.count, 43)
    }
}

// MARK: - SHA-256 Tests

final class SHA256Tests: XCTestCase {
    func testKnownHash() {
        // SHA-256 of empty string
        let data = Data()
        let hash = sha256(data)
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testKnownHashHello() {
        let data = "hello".data(using: .utf8)!
        let hash = sha256(data)
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testBase64URLEncoding() {
        // Test that base64URL has no +, /, or = characters
        let data = Data([0xFF, 0xFE, 0xFD, 0xFC, 0xFB])
        let encoded = base64URLEncode(data)
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
    }

    func testSoftwareSHA256() {
        // Directly test the software implementation
        let data = "test".data(using: .utf8)!
        let hash = sha256Software(data)
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08")
    }
}

// MARK: - InMemoryTokenStore Tests

final class InMemoryTokenStoreTests: XCTestCase {
    func testSaveAndLoad() async throws {
        let store = InMemoryTokenStore()
        let url = URL(string: "https://fhir.example.org")!
        let token = OAuthToken(accessToken: "tok1")

        try await store.saveToken(token, for: url)
        let loaded = try await store.loadToken(for: url)
        XCTAssertEqual(loaded?.accessToken, "tok1")
    }

    func testLoadMissing() async throws {
        let store = InMemoryTokenStore()
        let url = URL(string: "https://fhir.example.org")!
        let loaded = try await store.loadToken(for: url)
        XCTAssertNil(loaded)
    }

    func testDelete() async throws {
        let store = InMemoryTokenStore()
        let url = URL(string: "https://fhir.example.org")!
        let token = OAuthToken(accessToken: "tok1")

        try await store.saveToken(token, for: url)
        try await store.deleteToken(for: url)
        let loaded = try await store.loadToken(for: url)
        XCTAssertNil(loaded)
    }

    func testTokenForServer() async throws {
        let store = InMemoryTokenStore()
        let url = URL(string: "https://fhir.example.org")!
        let token = OAuthToken(accessToken: "tok2")

        try await store.saveToken(token, for: url)
        let loaded = try await store.tokenForServer(url)
        XCTAssertEqual(loaded?.accessToken, "tok2")
    }

    func testMultipleServers() async throws {
        let store = InMemoryTokenStore()
        let url1 = URL(string: "https://server1.example.org")!
        let url2 = URL(string: "https://server2.example.org")!

        try await store.saveToken(OAuthToken(accessToken: "a"), for: url1)
        try await store.saveToken(OAuthToken(accessToken: "b"), for: url2)

        let token1 = try await store.loadToken(for: url1)
        let token2 = try await store.loadToken(for: url2)
        XCTAssertEqual(token1?.accessToken, "a")
        XCTAssertEqual(token2?.accessToken, "b")
    }
}

// MARK: - SMARTScopeParser Tests

final class SMARTScopeParserTests: XCTestCase {
    let parser = SMARTScopeParser()

    func testParseScopes() {
        let scopes = parser.parseScopes("patient/*.read openid fhirUser")
        XCTAssertEqual(scopes.count, 3)
        XCTAssertEqual(scopes[0].scopeString, "patient/*.read")
        XCTAssertEqual(scopes[1].scopeString, "openid")
        XCTAssertEqual(scopes[2].scopeString, "fhirUser")
    }

    func testCombinedScopeString() {
        let scopes: [SMARTScope] = [.openid, .fhirUser, .patientAllRead]
        let combined = parser.combinedScopeString(scopes)
        XCTAssertEqual(combined, "openid fhirUser patient/*.read")
    }

    func testMissingScopes() {
        let requested: [SMARTScope] = [.openid, .fhirUser, .patientAllRead]
        let missing = parser.missingScopes(requested: requested, granted: "openid fhirUser")
        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing[0].scopeString, "patient/*.read")
    }

    func testValidateScopesSuccess() {
        let requested: [SMARTScope] = [.openid, .fhirUser]
        XCTAssertNoThrow(try parser.validateScopes(requested: requested, granted: "openid fhirUser launch"))
    }

    func testValidateScopesFailure() {
        let requested: [SMARTScope] = [.openid, .patientAllRead]
        XCTAssertThrowsError(try parser.validateScopes(requested: requested, granted: "openid")) { error in
            guard case SMARTAuthError.scopeNotGranted = error else {
                XCTFail("Expected scopeNotGranted error")
                return
            }
        }
    }

    func testIsClinicalScope() {
        XCTAssertTrue(parser.isClinicalScope("patient/Patient.read"))
        XCTAssertTrue(parser.isClinicalScope("user/Observation.write"))
        XCTAssertTrue(parser.isClinicalScope("patient/*.read"))
        XCTAssertTrue(parser.isClinicalScope("user/*.*"))
        XCTAssertFalse(parser.isClinicalScope("openid"))
        XCTAssertFalse(parser.isClinicalScope("launch"))
        XCTAssertFalse(parser.isClinicalScope("launch/patient"))
        XCTAssertFalse(parser.isClinicalScope("fhirUser"))
    }

    func testParseEmptyString() {
        // Swift's split(separator:) omits empty subsequences by default,
        // so splitting an empty string returns an empty array
        let scopes = parser.parseScopes("")
        XCTAssertEqual(scopes.count, 0)
    }
}

// MARK: - SMARTWellKnownConfiguration Tests

final class SMARTWellKnownConfigurationTests: XCTestCase {
    func testDecoding() throws {
        let data = SMARTTestHelper.makeWellKnownJSON()
        let config = try JSONDecoder().decode(SMARTWellKnownConfiguration.self, from: data)

        XCTAssertEqual(config.authorizationEndpoint, "https://auth.example.org/authorize")
        XCTAssertEqual(config.tokenEndpoint, "https://auth.example.org/token")
        XCTAssertEqual(config.revocationEndpoint, "https://auth.example.org/revoke")
        XCTAssertNotNil(config.capabilities)
        XCTAssertEqual(config.capabilities?.count, 3)
        XCTAssertNotNil(config.codeChallengeMethodsSupported)
    }

    func testDecodingMinimal() throws {
        let json = """
        {"authorization_endpoint": "https://a.com/auth", "token_endpoint": "https://a.com/token"}
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(SMARTWellKnownConfiguration.self, from: json)

        XCTAssertEqual(config.authorizationEndpoint, "https://a.com/auth")
        XCTAssertNil(config.revocationEndpoint)
        XCTAssertNil(config.capabilities)
    }
}

// MARK: - SMARTLaunchType Tests

final class SMARTLaunchTypeTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(SMARTLaunchType.standalone.rawValue, "standalone")
        XCTAssertEqual(SMARTLaunchType.ehrLaunch.rawValue, "ehr_launch")
    }

    func testCodable() throws {
        let data = try JSONEncoder().encode(SMARTLaunchType.standalone)
        let decoded = try JSONDecoder().decode(SMARTLaunchType.self, from: data)
        XCTAssertEqual(decoded, .standalone)
    }
}

// MARK: - SMARTAuthClient Tests

final class SMARTAuthClientTests: XCTestCase {
    var mockSession: MockSMARTURLSession!
    var config: SMARTAuthConfiguration!

    override func setUp() {
        super.setUp()
        mockSession = MockSMARTURLSession()
        config = SMARTTestHelper.makeConfiguration()
    }

    // MARK: Authorization URL

    func testBuildAuthorizationURLStandalone() async throws {
        let client = SMARTAuthClient(configuration: config, session: mockSession)
        let url = try await client.buildAuthorizationURL(
            launchType: .standalone,
            state: "test-state"
        )

        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        let queryItems = components.queryItems ?? []
        let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })

        XCTAssertEqual(queryDict["response_type"], "code")
        XCTAssertEqual(queryDict["client_id"], "test-client")
        XCTAssertEqual(queryDict["redirect_uri"], SMARTTestHelper.redirectURI.absoluteString)
        XCTAssertEqual(queryDict["state"], "test-state")
        XCTAssertEqual(queryDict["aud"], SMARTTestHelper.serverURL.absoluteString)
        XCTAssertNotNil(queryDict["scope"])
    }

    func testBuildAuthorizationURLWithPKCE() async throws {
        let client = SMARTAuthClient(configuration: config, session: mockSession)
        let pkce = try PKCEParameters.generate()
        let url = try await client.buildAuthorizationURL(
            launchType: .standalone,
            pkce: pkce
        )

        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        let queryItems = components.queryItems ?? []
        let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })

        XCTAssertEqual(queryDict["code_challenge"], pkce.codeChallenge)
        XCTAssertEqual(queryDict["code_challenge_method"], "S256")
    }

    func testBuildAuthorizationURLEHRLaunch() async throws {
        let client = SMARTAuthClient(configuration: config, session: mockSession)
        let url = try await client.buildAuthorizationURL(
            launchType: .ehrLaunch,
            launchContext: "launch-token-123"
        )

        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        let queryItems = components.queryItems ?? []
        let queryDict = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })

        XCTAssertEqual(queryDict["launch"], "launch-token-123")
    }

    // MARK: Token Exchange

    func testExchangeCodeForToken() async throws {
        mockSession.responseData = SMARTTestHelper.makeTokenResponseJSON()
        let client = SMARTAuthClient(configuration: config, session: mockSession)

        let token = try await client.exchangeCodeForToken(
            authorizationCode: "auth-code-123",
            codeVerifier: "verifier"
        )

        XCTAssertEqual(token.accessToken, "test-access-token")
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.refreshToken, "test-refresh-token")
        XCTAssertEqual(token.patientId, "patient-123")
        XCTAssertFalse(token.isExpired)

        // Verify request was sent to token URL
        XCTAssertEqual(mockSession.requests.count, 1)
        XCTAssertEqual(mockSession.requests[0].url, config.tokenURL)
        XCTAssertEqual(mockSession.requests[0].httpMethod, "POST")
    }

    func testExchangeCodeForTokenFailure() async {
        mockSession.responseStatusCode = 400
        mockSession.responseData = "Bad Request".data(using: .utf8)!
        let client = SMARTAuthClient(configuration: config, session: mockSession)

        do {
            _ = try await client.exchangeCodeForToken(authorizationCode: "bad-code")
            XCTFail("Expected error")
        } catch {
            guard case SMARTAuthError.tokenRequestFailed = error else {
                XCTFail("Expected tokenRequestFailed, got \(error)")
                return
            }
        }
    }

    func testExchangeCodeNetworkError() async {
        mockSession.responseError = NSError(domain: "test", code: -1)
        let client = SMARTAuthClient(configuration: config, session: mockSession)

        do {
            _ = try await client.exchangeCodeForToken(authorizationCode: "code")
            XCTFail("Expected error")
        } catch {
            guard case SMARTAuthError.networkError = error else {
                XCTFail("Expected networkError, got \(error)")
                return
            }
        }
    }

    // MARK: Token Refresh

    func testRefreshToken() async throws {
        let newTokenJSON = SMARTTestHelper.makeTokenResponseJSON(
            accessToken: "new-access-token",
            refreshToken: "new-refresh-token"
        )
        mockSession.responseData = newTokenJSON
        let client = SMARTAuthClient(configuration: config, session: mockSession)

        let oldToken = OAuthToken(
            accessToken: "old",
            refreshToken: "old-refresh"
        )
        let newToken = try await client.refreshToken(oldToken)

        XCTAssertEqual(newToken.accessToken, "new-access-token")
        XCTAssertEqual(newToken.refreshToken, "new-refresh-token")
    }

    func testRefreshTokenWithoutRefreshToken() async {
        let client = SMARTAuthClient(configuration: config, session: mockSession)
        let token = OAuthToken(accessToken: "tok", refreshToken: nil)

        do {
            _ = try await client.refreshToken(token)
            XCTFail("Expected error")
        } catch {
            guard case SMARTAuthError.tokenRefreshFailed = error else {
                XCTFail("Expected tokenRefreshFailed, got \(error)")
                return
            }
        }
    }

    // MARK: Get Valid Token

    func testGetValidTokenWithCurrent() async throws {
        // Set up a valid token via exchange
        mockSession.responseData = SMARTTestHelper.makeTokenResponseJSON()
        let client = SMARTAuthClient(configuration: config, session: mockSession)
        _ = try await client.exchangeCodeForToken(authorizationCode: "code")

        // Should return the current token without making another request
        let token = try await client.getValidToken()
        XCTAssertEqual(token.accessToken, "test-access-token")
        // Only 1 request (the exchange), no additional refresh
        XCTAssertEqual(mockSession.requests.count, 1)
    }

    func testGetValidTokenNoToken() async {
        let client = SMARTAuthClient(configuration: config, session: mockSession)
        do {
            _ = try await client.getValidToken()
            XCTFail("Expected error")
        } catch {
            guard case SMARTAuthError.authorizationFailed = error else {
                XCTFail("Expected authorizationFailed, got \(error)")
                return
            }
        }
    }

    // MARK: Configuration Discovery

    func testDiscoverConfiguration() async throws {
        mockSession.responseData = SMARTTestHelper.makeWellKnownJSON()
        let client = SMARTAuthClient(configuration: config, session: mockSession)

        let wellKnown = try await client.discoverConfiguration()

        XCTAssertEqual(wellKnown.authorizationEndpoint, "https://auth.example.org/authorize")
        XCTAssertEqual(wellKnown.tokenEndpoint, "https://auth.example.org/token")
        XCTAssertEqual(wellKnown.revocationEndpoint, "https://auth.example.org/revoke")

        // Verify request URL
        let requestURL = mockSession.requests[0].url!.absoluteString
        XCTAssertTrue(requestURL.contains(".well-known/smart-configuration"))
    }

    func testDiscoverConfigurationNotFound() async {
        mockSession.responseStatusCode = 404
        mockSession.responseData = Data()
        let client = SMARTAuthClient(configuration: config, session: mockSession)

        do {
            _ = try await client.discoverConfiguration()
            XCTFail("Expected error")
        } catch {
            guard case SMARTAuthError.missingWellKnownConfig = error else {
                XCTFail("Expected missingWellKnownConfig, got \(error)")
                return
            }
        }
    }

    func testDiscoverConfigurationNetworkError() async {
        mockSession.responseError = NSError(domain: "net", code: -1)
        let client = SMARTAuthClient(configuration: config, session: mockSession)

        do {
            _ = try await client.discoverConfiguration()
            XCTFail("Expected error")
        } catch {
            guard case SMARTAuthError.missingWellKnownConfig = error else {
                XCTFail("Expected missingWellKnownConfig, got \(error)")
                return
            }
        }
    }

    // MARK: Token Revocation

    func testRevokeToken() async throws {
        // Queue: first call returns well-known, second returns revocation success
        mockSession.responseQueue = [
            (SMARTTestHelper.makeWellKnownJSON(), 200),
            (Data(), 200),
        ]
        let client = SMARTAuthClient(configuration: config, session: mockSession)

        let token = OAuthToken(accessToken: "tok-to-revoke")
        try await client.revokeToken(token)

        // Should have made 2 requests: discovery + revocation
        XCTAssertEqual(mockSession.requests.count, 2)
        XCTAssertEqual(mockSession.requests[1].httpMethod, "POST")
    }

    func testRevokeTokenNoEndpoint() async {
        // Well-known without revocation endpoint
        let json: [String: Any] = [
            "authorization_endpoint": "https://a.com/auth",
            "token_endpoint": "https://a.com/token",
        ]
        mockSession.responseData = try! JSONSerialization.data(withJSONObject: json)

        let client = SMARTAuthClient(configuration: config, session: mockSession)

        do {
            _ = try await client.revokeToken(OAuthToken(accessToken: "tok"))
            XCTFail("Expected error")
        } catch {
            guard case SMARTAuthError.invalidConfiguration = error else {
                XCTFail("Expected invalidConfiguration, got \(error)")
                return
            }
        }
    }

    // MARK: Token Store Integration

    func testTokenStorePersistence() async throws {
        let store = InMemoryTokenStore()
        mockSession.responseData = SMARTTestHelper.makeTokenResponseJSON()
        let client = SMARTAuthClient(configuration: config, tokenStore: store, session: mockSession)

        _ = try await client.exchangeCodeForToken(authorizationCode: "code")

        // Verify token was saved to store
        let stored = try await store.loadToken(for: config.serverURL)
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.accessToken, "test-access-token")
    }
}
