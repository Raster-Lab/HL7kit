import XCTest
@testable import HL7Core

final class SecurityFrameworkTests: XCTestCase {

    // MARK: - Message Encryption Tests

    func testEncryptionKeyGenerate() {
        let key = EncryptionKey.generate()
        XCTAssertEqual(key.keyData.count, 32)
        XCTAssertFalse(key.keyID.isEmpty)
    }

    func testEncryptionKeyCustomSize() {
        let key = EncryptionKey.generate(size: 16)
        XCTAssertEqual(key.keyData.count, 16)
    }

    func testEncryptDecryptDataRoundTrip() {
        let encryptor = MessageEncryptor()
        let key = EncryptionKey.generate()
        let plaintext = Data("Hello, HL7 Healthcare!".utf8)

        let payload = encryptor.encrypt(data: plaintext, key: key)
        let decrypted = encryptor.decrypt(payload: payload, key: key)

        XCTAssertEqual(decrypted, plaintext)
        XCTAssertNotEqual(payload.ciphertext, plaintext)
    }

    func testEncryptDecryptStringRoundTrip() {
        let encryptor = MessageEncryptor()
        let key = EncryptionKey.generate()
        let original = "Patient: John Doe, MRN: 12345"

        let payload = encryptor.encrypt(string: original, key: key)
        let decrypted = encryptor.decryptToString(payload: payload, key: key)

        XCTAssertEqual(decrypted, original)
    }

    func testEncryptedPayloadMetadata() {
        let encryptor = MessageEncryptor()
        let key = EncryptionKey.generate()
        let payload = encryptor.encrypt(data: Data("test".utf8), key: key)

        XCTAssertEqual(payload.algorithm, MessageEncryptor.algorithm)
        XCTAssertEqual(payload.keyID, key.keyID)
        XCTAssertEqual(payload.iv.count, 16)
        XCTAssertFalse(payload.ciphertext.isEmpty)
    }

    func testDecryptWithWrongKeyFails() {
        let encryptor = MessageEncryptor()
        let key1 = EncryptionKey.generate()
        let key2 = EncryptionKey.generate()
        let plaintext = Data("Sensitive PHI data".utf8)

        let payload = encryptor.encrypt(data: plaintext, key: key1)
        let decrypted = encryptor.decrypt(payload: payload, key: key2)

        XCTAssertNotEqual(decrypted, plaintext)
    }

    func testEncryptEmptyData() {
        let encryptor = MessageEncryptor()
        let key = EncryptionKey.generate()
        let payload = encryptor.encrypt(data: Data(), key: key)
        let decrypted = encryptor.decrypt(payload: payload, key: key)

        XCTAssertEqual(decrypted, Data())
    }

    func testEncryptLargeData() {
        let encryptor = MessageEncryptor()
        let key = EncryptionKey.generate()
        let largeData = Data(repeating: 0x42, count: 10000)

        let payload = encryptor.encrypt(data: largeData, key: key)
        let decrypted = encryptor.decrypt(payload: payload, key: key)

        XCTAssertEqual(decrypted, largeData)
    }

    func testDifferentEncryptionsProduceDifferentCiphertext() {
        let encryptor = MessageEncryptor()
        let key = EncryptionKey.generate()
        let plaintext = Data("Same message".utf8)

        let payload1 = encryptor.encrypt(data: plaintext, key: key)
        let payload2 = encryptor.encrypt(data: plaintext, key: key)

        // Different IVs should produce different ciphertext
        XCTAssertNotEqual(payload1.iv, payload2.iv)
    }

    // MARK: - Digital Signature Tests

    func testSigningKeyGenerate() {
        let key = SigningKey.generate()
        XCTAssertEqual(key.keyData.count, 32)
        XCTAssertFalse(key.keyID.isEmpty)
    }

    func testSignAndVerifyData() {
        let signer = DigitalSigner()
        let key = SigningKey.generate()
        let data = Data("HL7 message content".utf8)

        let signature = signer.sign(data: data, key: key)
        let isValid = signer.verify(data: data, signature: signature, key: key)

        XCTAssertTrue(isValid)
        XCTAssertEqual(signature.algorithm, DigitalSigner.algorithm)
        XCTAssertEqual(signature.keyID, key.keyID)
    }

    func testSignAndVerifyString() {
        let signer = DigitalSigner()
        let key = SigningKey.generate()
        let message = "ADT^A01 message"

        let signature = signer.sign(string: message, key: key)
        let isValid = signer.verify(string: message, signature: signature, key: key)

        XCTAssertTrue(isValid)
    }

    func testVerifyWithWrongKeyFails() {
        let signer = DigitalSigner()
        let key1 = SigningKey.generate()
        let key2 = SigningKey.generate()
        let data = Data("Important data".utf8)

        let signature = signer.sign(data: data, key: key1)
        let isValid = signer.verify(data: data, signature: signature, key: key2)

        XCTAssertFalse(isValid)
    }

    func testVerifyTamperedDataFails() {
        let signer = DigitalSigner()
        let key = SigningKey.generate()
        let original = Data("Original message".utf8)
        let tampered = Data("Tampered message".utf8)

        let signature = signer.sign(data: original, key: key)
        let isValid = signer.verify(data: tampered, signature: signature, key: key)

        XCTAssertFalse(isValid)
    }

    func testSignatureConsistency() {
        let signer = DigitalSigner()
        let key = SigningKey.generate()
        let data = Data("Consistent data".utf8)

        let sig1 = signer.sign(data: data, key: key)
        let sig2 = signer.sign(data: data, key: key)

        // Same data + same key = same signature
        XCTAssertEqual(sig1.signatureHex, sig2.signatureHex)
    }

    func testSignatureHexFormat() {
        let signer = DigitalSigner()
        let key = SigningKey.generate()
        let signature = signer.sign(data: Data("test".utf8), key: key)

        // HMAC-SHA256 produces 64 hex characters (32 bytes)
        XCTAssertEqual(signature.signatureHex.count, 64)
        XCTAssertEqual(signature.signatureData.count, 32)
        // All characters should be valid hex
        let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(signature.signatureHex.unicodeScalars.allSatisfy { hexChars.contains($0) })
    }

    // MARK: - Certificate Management Tests

    func testAddAndFindCertificate() async {
        let manager = CertificateManager()
        let cert = makeCertificate(subject: "Test CA", serial: "001")

        await manager.addCertificate(cert)
        let found = await manager.findBySerial("001")

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.subject, "Test CA")
    }

    func testFindBySubject() async {
        let manager = CertificateManager()
        await manager.addCertificate(makeCertificate(subject: "Hospital Root CA", serial: "001"))
        await manager.addCertificate(makeCertificate(subject: "Hospital Intermediate CA", serial: "002"))
        await manager.addCertificate(makeCertificate(subject: "External CA", serial: "003"))

        let results = await manager.findBySubject("Hospital")
        XCTAssertEqual(results.count, 2)
    }

    func testRemoveCertificate() async {
        let manager = CertificateManager()
        await manager.addCertificate(makeCertificate(subject: "Test", serial: "001"))

        let removed = await manager.removeCertificate(serialNumber: "001")
        XCTAssertNotNil(removed)

        let found = await manager.findBySerial("001")
        XCTAssertNil(found)
    }

    func testValidateCertificateValid() async {
        let manager = CertificateManager()
        await manager.addTrustedIssuer("Trusted CA")

        let cert = makeCertificate(
            subject: "Server",
            issuer: "Trusted CA",
            serial: "001",
            validFrom: Date().addingTimeInterval(-86400),
            validTo: Date().addingTimeInterval(86400)
        )

        let status = await manager.validateCertificate(cert)
        XCTAssertEqual(status, .valid)
    }

    func testValidateCertificateExpired() async {
        let manager = CertificateManager()
        let cert = makeCertificate(
            subject: "Expired Server",
            serial: "002",
            validFrom: Date().addingTimeInterval(-172800),
            validTo: Date().addingTimeInterval(-86400)
        )

        let status = await manager.validateCertificate(cert)
        XCTAssertEqual(status, .expired)
    }

    func testValidateCertificateNotYetValid() async {
        let manager = CertificateManager()
        let cert = makeCertificate(
            subject: "Future Server",
            serial: "003",
            validFrom: Date().addingTimeInterval(86400),
            validTo: Date().addingTimeInterval(172800)
        )

        let status = await manager.validateCertificate(cert)
        XCTAssertEqual(status, .notYetValid)
    }

    func testValidateCertificateRevoked() async {
        let manager = CertificateManager()
        let cert = makeCertificate(subject: "Revoked Server", serial: "004")

        await manager.addCertificate(cert)
        await manager.revokeCertificate(serialNumber: "004")

        let status = await manager.validateCertificate(cert)
        XCTAssertEqual(status, .revoked)

        // Stored cert should also have revoked status
        let stored = await manager.findBySerial("004")
        XCTAssertEqual(stored?.status, .revoked)
    }

    func testValidateCertificateUntrusted() async {
        let manager = CertificateManager()
        await manager.addTrustedIssuer("Trusted CA")

        let cert = makeCertificate(
            subject: "Server",
            issuer: "Unknown CA",
            serial: "005",
            validFrom: Date().addingTimeInterval(-86400),
            validTo: Date().addingTimeInterval(86400)
        )

        let status = await manager.validateCertificate(cert)
        XCTAssertEqual(status, .untrusted)
    }

    func testCertificateCount() async {
        let manager = CertificateManager()
        await manager.addCertificate(makeCertificate(subject: "A", serial: "001"))
        await manager.addCertificate(makeCertificate(subject: "B", serial: "002"))

        let count = await manager.count()
        XCTAssertEqual(count, 2)
    }

    func testCertificateClear() async {
        let manager = CertificateManager()
        await manager.addCertificate(makeCertificate(subject: "A", serial: "001"))
        await manager.clear()

        let count = await manager.count()
        XCTAssertEqual(count, 0)
    }

    func testCertificateFingerprint() {
        let cert = makeCertificate(subject: "Test", serial: "001")
        XCTAssertFalse(cert.fingerprint.isEmpty)
    }

    func testCertificateWithStatus() {
        let cert = makeCertificate(subject: "Test", serial: "001")
        let updated = cert.withStatus(.valid)
        XCTAssertEqual(updated.status, .valid)
        XCTAssertEqual(updated.subject, cert.subject)
        XCTAssertEqual(updated.fingerprint, cert.fingerprint)
    }

    // MARK: - Access Control Tests

    func testAddPrincipalAndCheckAccess() async {
        let acm = AccessControlManager()
        await acm.addPrincipal("dr.smith", roles: [.editor])
        await acm.addPolicy(AccessPolicy(
            resourcePattern: "patient/*",
            requiredPermissions: [.read, .write]
        ))

        let readResult = await acm.checkAccess(principal: "dr.smith", resource: "patient/123", action: .read)
        XCTAssertEqual(readResult, .allowed)

        let writeResult = await acm.checkAccess(principal: "dr.smith", resource: "patient/123", action: .write)
        XCTAssertEqual(writeResult, .allowed)
    }

    func testAccessDeniedInsufficientPermissions() async {
        let acm = AccessControlManager()
        await acm.addPrincipal("nurse.jones", roles: [.viewer])
        await acm.addPolicy(AccessPolicy(
            resourcePattern: "patient/*",
            requiredPermissions: [.read, .write]
        ))

        let readResult = await acm.checkAccess(principal: "nurse.jones", resource: "patient/123", action: .read)
        XCTAssertEqual(readResult, .allowed)

        let writeResult = await acm.checkAccess(principal: "nurse.jones", resource: "patient/123", action: .write)
        XCTAssertEqual(writeResult, .denied)
    }

    func testAdminBypassesPermissionCheck() async {
        let acm = AccessControlManager()
        await acm.addPrincipal("admin", roles: [.administrator])
        await acm.addPolicy(AccessPolicy(
            resourcePattern: "system/*",
            requiredPermissions: [.admin]
        ))

        let result = await acm.checkAccess(principal: "admin", resource: "system/config", action: .delete)
        XCTAssertEqual(result, .allowed)
    }

    func testNoPolicyReturnsNoPolicy() async {
        let acm = AccessControlManager()
        await acm.addPrincipal("user", roles: [.viewer])

        let result = await acm.checkAccess(principal: "user", resource: "unknown/resource", action: .read)
        XCTAssertEqual(result, .noPolicy)
    }

    func testUnknownPrincipalDenied() async {
        let acm = AccessControlManager()
        await acm.addPolicy(AccessPolicy(
            resourcePattern: "patient/*",
            requiredPermissions: [.read]
        ))

        let result = await acm.checkAccess(principal: "unknown", resource: "patient/123", action: .read)
        XCTAssertEqual(result, .denied)
    }

    func testRemovePrincipal() async {
        let acm = AccessControlManager()
        await acm.addPrincipal("user", roles: [.viewer])
        await acm.removePrincipal("user")

        let roles = await acm.getRoles(for: "user")
        XCTAssertTrue(roles.isEmpty)
    }

    func testUpdateRoles() async {
        let acm = AccessControlManager()
        await acm.addPrincipal("user", roles: [.viewer])
        await acm.updateRoles(for: "user", roles: [.editor])

        let roles = await acm.getRoles(for: "user")
        XCTAssertTrue(roles.contains(.editor))
        XCTAssertFalse(roles.contains(.viewer))
    }

    func testEffectivePermissions() async {
        let acm = AccessControlManager()
        let customRole = Role(name: "custom", permissions: [.read, .export])
        await acm.addPrincipal("user", roles: [.viewer, customRole])

        let perms = await acm.getEffectivePermissions(for: "user")
        XCTAssertTrue(perms.contains(.read))
        XCTAssertTrue(perms.contains(.export))
        XCTAssertFalse(perms.contains(.write))
    }

    func testAccessPolicyWildcard() {
        let policy = AccessPolicy(resourcePattern: "*", requiredPermissions: [.read])
        XCTAssertTrue(policy.matches(resource: "anything"))
        XCTAssertTrue(policy.matches(resource: "patient/123"))
    }

    func testAccessPolicyPrefixMatch() {
        let policy = AccessPolicy(resourcePattern: "patient/*", requiredPermissions: [.read])
        XCTAssertTrue(policy.matches(resource: "patient/123"))
        XCTAssertTrue(policy.matches(resource: "patient/123/vitals"))
        XCTAssertTrue(policy.matches(resource: "patient"))
        XCTAssertFalse(policy.matches(resource: "observation/456"))
    }

    func testAccessPolicyExactMatch() {
        let policy = AccessPolicy(resourcePattern: "patient/123", requiredPermissions: [.read])
        XCTAssertTrue(policy.matches(resource: "patient/123"))
        XCTAssertFalse(policy.matches(resource: "patient/456"))
    }

    func testRemovePolicy() async {
        let acm = AccessControlManager()
        let policy = AccessPolicy(
            resourcePattern: "test/*",
            requiredPermissions: [.read],
            policyID: "policy-1"
        )
        await acm.addPolicy(policy)
        await acm.removePolicy(policyID: "policy-1")

        let policies = await acm.allPolicies()
        XCTAssertTrue(policies.isEmpty)
    }

    func testPredefinedRoles() {
        XCTAssertEqual(Role.viewer.permissions, [.read])
        XCTAssertEqual(Role.editor.permissions, [.read, .write])
        XCTAssertEqual(Role.administrator.permissions, Set(Permission.allCases))
        XCTAssertEqual(Role.auditor.permissions, [.read, .audit])
    }

    // MARK: - Security Audit Logging Tests

    func testLogSecurityEvent() async {
        let logger = SecurityAuditLogger()
        let event = SecurityEvent(
            eventType: .login,
            principal: "dr.smith",
            action: "authenticate",
            resource: "system",
            outcome: .success
        )

        await logger.log(event)
        let count = await logger.count()
        XCTAssertEqual(count, 1)
    }

    func testFilterEventsByType() async {
        let logger = SecurityAuditLogger()
        await logger.log(SecurityEvent(eventType: .login, principal: "user1", action: "login", resource: "system"))
        await logger.log(SecurityEvent(eventType: .accessDenied, principal: "user2", action: "read", resource: "patient/123"))
        await logger.log(SecurityEvent(eventType: .login, principal: "user3", action: "login", resource: "system"))

        let loginEvents = await logger.events(ofType: .login)
        XCTAssertEqual(loginEvents.count, 2)

        let deniedEvents = await logger.events(ofType: .accessDenied)
        XCTAssertEqual(deniedEvents.count, 1)
    }

    func testFilterEventsByPrincipal() async {
        let logger = SecurityAuditLogger()
        await logger.log(SecurityEvent(eventType: .login, principal: "dr.smith", action: "login", resource: "system"))
        await logger.log(SecurityEvent(eventType: .dataAccess, principal: "dr.smith", action: "read", resource: "patient/1"))
        await logger.log(SecurityEvent(eventType: .login, principal: "nurse.jones", action: "login", resource: "system"))

        let smithEvents = await logger.events(forPrincipal: "dr.smith")
        XCTAssertEqual(smithEvents.count, 2)
    }

    func testFilterEventsByResource() async {
        let logger = SecurityAuditLogger()
        await logger.log(SecurityEvent(eventType: .dataAccess, principal: "user1", action: "read", resource: "patient/123"))
        await logger.log(SecurityEvent(eventType: .dataModification, principal: "user2", action: "update", resource: "patient/123"))
        await logger.log(SecurityEvent(eventType: .dataAccess, principal: "user1", action: "read", resource: "patient/456"))

        let events = await logger.events(forResource: "patient/123")
        XCTAssertEqual(events.count, 2)
    }

    func testFilterEventsByOutcome() async {
        let logger = SecurityAuditLogger()
        await logger.log(SecurityEvent(eventType: .login, principal: "user1", action: "login", resource: "system", outcome: .success))
        await logger.log(SecurityEvent(eventType: .login, principal: "user2", action: "login", resource: "system", outcome: .failure))

        let failures = await logger.events(withOutcome: .failure)
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.principal, "user2")
    }

    func testClearEvents() async {
        let logger = SecurityAuditLogger()
        await logger.log(SecurityEvent(eventType: .login, principal: "user", action: "login", resource: "system"))
        await logger.clear()

        let count = await logger.count()
        XCTAssertEqual(count, 0)
    }

    func testAuditTrailIntegration() async {
        let trail = AuditTrail()
        let logger = SecurityAuditLogger(auditTrail: trail)

        await logger.log(SecurityEvent(
            eventType: .dataAccess,
            principal: "dr.smith",
            action: "read",
            resource: "patient/123"
        ))

        let trailCount = await trail.count()
        XCTAssertEqual(trailCount, 1)
    }

    func testSecurityEventMetadata() {
        let event = SecurityEvent(
            eventType: .dataAccess,
            principal: "dr.smith",
            action: "read",
            resource: "patient/123",
            outcome: .success,
            details: ["reason": "treatment"],
            source: "192.168.1.1"
        )

        XCTAssertFalse(event.eventID.isEmpty)
        XCTAssertEqual(event.eventType, .dataAccess)
        XCTAssertEqual(event.principal, "dr.smith")
        XCTAssertEqual(event.details["reason"], "treatment")
        XCTAssertEqual(event.source, "192.168.1.1")
    }

    // MARK: - HIPAA Compliance Tests

    func testDeidentifySSN() {
        let hipaa = HIPAACompliance()
        let text = "Patient SSN: 123-45-6789"
        let result = hipaa.deidentify(text)

        XCTAssertFalse(result.contains("123-45-6789"))
        XCTAssertTrue(result.contains("[SSN-REDACTED]"))
    }

    func testDeidentifyPhone() {
        let hipaa = HIPAACompliance()
        let text = "Call 555-123-4567 or (555) 987-6543"
        let result = hipaa.deidentify(text)

        XCTAssertFalse(result.contains("555-123-4567"))
        XCTAssertFalse(result.contains("(555) 987-6543"))
        XCTAssertTrue(result.contains("[PHONE-REDACTED]"))
    }

    func testDeidentifyEmail() {
        let hipaa = HIPAACompliance()
        let text = "Contact: patient@hospital.com"
        let result = hipaa.deidentify(text)

        XCTAssertFalse(result.contains("patient@hospital.com"))
        XCTAssertTrue(result.contains("[EMAIL-REDACTED]"))
    }

    func testDeidentifyIPAddress() {
        let hipaa = HIPAACompliance()
        let text = "From IP: 192.168.1.100"
        let result = hipaa.deidentify(text)

        XCTAssertFalse(result.contains("192.168.1.100"))
        XCTAssertTrue(result.contains("[IP-REDACTED]"))
    }

    func testDeidentifyDates() {
        let hipaa = HIPAACompliance()
        let text = "DOB: 01/15/1990, Admitted: 12-25-2023"
        let result = hipaa.deidentify(text)

        XCTAssertFalse(result.contains("01/15/1990"))
        XCTAssertFalse(result.contains("12-25-2023"))
        XCTAssertTrue(result.contains("[DATE-REDACTED]"))
    }

    func testDeidentifyMRN() {
        let hipaa = HIPAACompliance()
        let text = "MRN: ABC12345"
        let result = hipaa.deidentify(text)

        XCTAssertFalse(result.contains("MRN: ABC12345"))
        XCTAssertTrue(result.contains("[MRN-REDACTED]"))
    }

    func testDeidentifyURL() {
        let hipaa = HIPAACompliance()
        let text = "Portal: https://patient.hospital.com/records"
        let result = hipaa.deidentify(text)

        XCTAssertFalse(result.contains("https://patient.hospital.com/records"))
        XCTAssertTrue(result.contains("[URL-REDACTED]"))
    }

    func testDeidentifyMultiplePHI() {
        let hipaa = HIPAACompliance()
        let text = "SSN: 123-45-6789, Email: test@test.com, IP: 10.0.0.1"
        let result = hipaa.deidentify(text)

        XCTAssertTrue(result.contains("[SSN-REDACTED]"))
        XCTAssertTrue(result.contains("[EMAIL-REDACTED]"))
        XCTAssertTrue(result.contains("[IP-REDACTED]"))
    }

    func testDeidentifyCleanText() {
        let hipaa = HIPAACompliance()
        let text = "Normal clinical note without identifiers"
        let result = hipaa.deidentify(text)

        XCTAssertEqual(result, text)
    }

    func testDetectPHI() {
        let hipaa = HIPAACompliance()
        let text = "SSN: 123-45-6789, Email: test@test.com"
        let detected = hipaa.detectPHI(in: text)

        XCTAssertTrue(detected.contains(.socialSecurityNumber))
        XCTAssertTrue(detected.contains(.emailAddress))
        XCTAssertFalse(detected.contains(.phoneNumber))
    }

    func testValidateComplianceWithPHI() {
        let hipaa = HIPAACompliance()
        let text = "Patient SSN: 123-45-6789"
        let results = hipaa.validateCompliance(text)

        let ssnCheck = results.first { $0.checkName == "SSN Check" }
        XCTAssertNotNil(ssnCheck)
        XCTAssertFalse(ssnCheck!.passed)
    }

    func testValidateComplianceClean() {
        let hipaa = HIPAACompliance()
        let text = "Normal clinical text"
        let results = hipaa.validateCompliance(text)

        XCTAssertTrue(results.allSatisfy { $0.passed })
    }

    func testMinimumNecessaryPass() {
        let hipaa = HIPAACompliance()
        let result = hipaa.checkMinimumNecessary(
            requestedFields: Set(["name", "dob"]),
            allowedFields: Set(["name", "dob", "mrn"])
        )
        XCTAssertTrue(result.passed)
    }

    func testMinimumNecessaryFail() {
        let hipaa = HIPAACompliance()
        let result = hipaa.checkMinimumNecessary(
            requestedFields: Set(["name", "ssn", "dob"]),
            allowedFields: Set(["name", "dob"])
        )
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.details.contains("ssn"))
    }

    func testMaskValue() {
        let hipaa = HIPAACompliance()

        XCTAssertEqual(hipaa.maskValue("123-45-6789", visibleCount: 4), "*******6789")
        XCTAssertEqual(hipaa.maskValue("AB", visibleCount: 4), "**")
        XCTAssertEqual(hipaa.maskValue("test@example.com", visibleCount: 4), "************.com")
    }

    func testPHIIdentifierTypesCount() {
        // HIPAA defines 18 identifier types
        XCTAssertEqual(PHIIdentifierType.allCases.count, 18)
    }

    // MARK: - Edge Cases

    func testEncryptionWithCustomKeyID() {
        let key = EncryptionKey(keyData: Data(repeating: 0xAB, count: 32), keyID: "custom-key-1")
        XCTAssertEqual(key.keyID, "custom-key-1")
        XCTAssertEqual(key.keyData.count, 32)
    }

    func testSigningEmptyData() {
        let signer = DigitalSigner()
        let key = SigningKey.generate()
        let sig = signer.sign(data: Data(), key: key)

        XCTAssertFalse(sig.signatureHex.isEmpty)
        XCTAssertTrue(signer.verify(data: Data(), signature: sig, key: key))
    }

    func testCertificateStatusEnum() {
        XCTAssertEqual(CertificateStatus.allCases.count, 6)
        XCTAssertEqual(CertificateStatus.valid.rawValue, "valid")
        XCTAssertEqual(CertificateStatus.expired.rawValue, "expired")
    }

    func testPermissionEnum() {
        XCTAssertEqual(Permission.allCases.count, 6)
    }

    func testSecurityEventTypeEnum() {
        XCTAssertEqual(SecurityEventType.allCases.count, 10)
    }

    func testAllCertificates() async {
        let manager = CertificateManager()
        await manager.addCertificate(makeCertificate(subject: "A", serial: "001"))
        await manager.addCertificate(makeCertificate(subject: "B", serial: "002"))

        let all = await manager.allCertificates()
        XCTAssertEqual(all.count, 2)
    }

    func testAllPrincipals() async {
        let acm = AccessControlManager()
        await acm.addPrincipal("user1", roles: [.viewer])
        await acm.addPrincipal("user2", roles: [.editor])

        let principals = await acm.allPrincipals()
        XCTAssertEqual(principals.count, 2)
        XCTAssertTrue(principals.contains("user1"))
        XCTAssertTrue(principals.contains("user2"))
    }

    func testFilterEventsByDateRange() async {
        let logger = SecurityAuditLogger()
        let now = Date()
        await logger.log(SecurityEvent(eventType: .login, principal: "user", action: "login", resource: "system"))

        let events = await logger.events(
            from: now.addingTimeInterval(-1),
            to: now.addingTimeInterval(1)
        )
        XCTAssertEqual(events.count, 1)

        let noEvents = await logger.events(
            from: now.addingTimeInterval(-100),
            to: now.addingTimeInterval(-50)
        )
        XCTAssertEqual(noEvents.count, 0)
    }

    func testTrustedIssuerManagement() async {
        let manager = CertificateManager()
        await manager.addTrustedIssuer("Trusted CA")

        let cert = makeCertificate(
            subject: "Server",
            issuer: "Trusted CA",
            serial: "001",
            validFrom: Date().addingTimeInterval(-86400),
            validTo: Date().addingTimeInterval(86400)
        )
        let status1 = await manager.validateCertificate(cert)
        XCTAssertEqual(status1, .valid)

        await manager.removeTrustedIssuer("Trusted CA")
        await manager.addTrustedIssuer("Other CA")
        // After replacing issuer, cert from the original issuer is untrusted
        let status2 = await manager.validateCertificate(cert)
        XCTAssertEqual(status2, .untrusted)
    }

    // MARK: - Helpers

    private func makeCertificate(
        subject: String,
        issuer: String = "Test CA",
        serial: String,
        validFrom: Date = Date().addingTimeInterval(-86400),
        validTo: Date = Date().addingTimeInterval(86400)
    ) -> CertificateInfo {
        CertificateInfo(
            subject: subject,
            issuer: issuer,
            serialNumber: serial,
            validFrom: validFrom,
            validTo: validTo
        )
    }
}
