# HL7kit Security Guide

Best practices for securing HL7 data, protecting PHI, and complying with HIPAA regulations when using HL7kit.

---

## Table of Contents

- [Overview](#overview)
- [PHI Handling and HIPAA Compliance](#phi-handling-and-hipaa-compliance)
- [Encryption Usage Guide](#encryption-usage-guide)
- [Digital Signatures](#digital-signatures)
- [Access Control Setup](#access-control-setup)
- [Audit Trail Configuration](#audit-trail-configuration)
- [Certificate Management](#certificate-management)
- [Secure Deployment Checklist](#secure-deployment-checklist)
- [Threat Model Overview](#threat-model-overview)

---

## Overview

HL7kit includes a security framework in `HL7Core` (`SecurityFramework.swift` and `CommonServices.swift`) that provides:

| Capability | Type | Description |
|------------|------|-------------|
| PHI Sanitization | `SecurityService` actor | Detect and mask SSNs, phone numbers, emails |
| Input Validation | `SecurityService` actor | Length, character safety, pattern validation |
| Encryption | `MessageEncryptor` struct | Symmetric encryption for message payloads |
| Digital Signatures | `DigitalSigner` struct | HMAC-SHA256 signing and verification |
| Certificate Mgmt | `CertificateInfo` struct | Certificate lifecycle tracking |
| Secure Random | `SecurityService` actor | Cryptographically random bytes |
| Hashing | `SecurityService` actor | SHA-256 hashing |

> **⚠️ Important**: The encryption implementation in `SecurityFramework.swift` uses a **simplified XOR-SHA256 stream cipher** intended for **demonstration and testing**. For production deployments, replace with platform-native cryptography (Apple CryptoKit / Security.framework) or a vetted cryptographic library. See [Encryption Caveats](#encryption-caveats) below.

---

## PHI Handling and HIPAA Compliance

### What is PHI?

Protected Health Information (PHI) includes any individually identifiable health information: patient names, Social Security numbers, medical record numbers, dates of birth, phone numbers, email addresses, and similar identifiers.

### Automatic PHI Detection

`SecurityService` provides automatic PHI detection and masking through regex-based pattern matching:

```swift
import HL7Core

let security = SecurityService()

let raw = "Patient John Doe, SSN: 123-45-6789, Phone: (555) 123-4567, email: john@example.com"
let sanitized = await security.sanitizePHI(in: raw)
// Result: "Patient John Doe, SSN: [REDACTED-SSN], Phone: [REDACTED-PHONE], email: [REDACTED-EMAIL]"
```

**Detected patterns:**

| Pattern | Example | Replacement |
|---------|---------|-------------|
| SSN | `123-45-6789` | `[REDACTED-SSN]` |
| Phone | `(555) 123-4567` | `[REDACTED-PHONE]` |
| Email | `user@domain.com` | `[REDACTED-EMAIL]` |

### HIPAA Best Practices with HL7kit

1. **Always sanitize PHI before logging**:
   ```swift
   let sanitized = await security.sanitizePHI(in: message.rawContent)
   await logger.log(category: "audit", level: .info, message: sanitized)
   ```

2. **Encrypt messages at rest**:
   ```swift
   let encrypted = try encryptor.encrypt(string: message.rawContent, using: key)
   try await archive.store(encryptedEntry)
   ```

3. **Validate inputs** to prevent injection or malformed data:
   ```swift
   let result = await security.validateInput(userInput)
   guard result.isValid else {
       // reject input, log errors
       return
   }
   ```

4. **Use correlation IDs** (not PHI) for tracing:
   ```swift
   let correlationID = CorrelationID.generate()
   // Use correlationID in logs instead of patient identifiers
   ```

5. **Limit data retention**: Clear caches and archives on a schedule:
   ```swift
   await cache.clear()
   await archive.clear()
   ```

---

## Encryption Usage Guide

### Generating Keys

```swift
import HL7Core

// Generate a 256-bit encryption key
let encryptionKey = EncryptionKey.generate(size: 32)

// Key properties
print(encryptionKey.keyID)       // Unique identifier
print(encryptionKey.createdAt)   // Creation timestamp
// encryptionKey.keyData          // Raw key bytes — never log this
```

### Encrypting Data

```swift
let encryptor = MessageEncryptor()

// Encrypt raw bytes
let encrypted = try encryptor.encrypt(data: messageData, using: encryptionKey)
// encrypted.ciphertext   — encrypted bytes
// encrypted.iv           — initialization vector
// encrypted.algorithm    — "XOR-SHA256-STREAM"
// encrypted.keyID        — matches the key used
// encrypted.encryptedAt  — timestamp

// Encrypt a string
let encryptedStr = try encryptor.encrypt(string: "ADT^A01 payload", using: encryptionKey)
```

### Decrypting Data

```swift
// Decrypt to Data
let plainData = try encryptor.decrypt(encrypted, using: encryptionKey)

// Decrypt to String
let plainString = try encryptor.decryptToString(encryptedStr, using: encryptionKey)
```

### Encryption Caveats

> **⚠️ The built-in encryption is for demonstration and testing only.**
>
> The `MessageEncryptor` uses a pure-Swift XOR stream cipher keyed from SHA-256 hashes. This provides:
> - Confidentiality against casual inspection
> - Cross-platform compatibility (no OS-specific crypto dependencies)
>
> It does **not** provide:
> - Authenticated encryption (no integrity check on ciphertext)
> - Resistance to chosen-plaintext attacks
> - Key derivation (keys are used directly)
> - Hardware-backed key storage
>
> **For production use**, replace with:
> - **Apple platforms**: `CryptoKit.AES.GCM` or `Security.framework`
> - **Cross-platform**: A vetted library providing AES-256-GCM or ChaCha20-Poly1305

### Production Encryption Example

```swift
// Example: wrapping Apple CryptoKit for production use
import CryptoKit

func encryptProduction(_ data: Data, key: SymmetricKey) throws -> Data {
    let sealed = try AES.GCM.seal(data, using: key)
    return sealed.combined!
}

func decryptProduction(_ data: Data, key: SymmetricKey) throws -> Data {
    let box = try AES.GCM.SealedBox(combined: data)
    return try AES.GCM.open(box, using: key)
}
```

---

## Digital Signatures

### Signing Messages

```swift
import HL7Core

let signingKey = SigningKey.generate(size: 32)
let signer = DigitalSigner()

// Sign data
let signature = signer.sign(data: messageData, using: signingKey)
// signature.signatureData    — raw HMAC bytes
// signature.signatureHex     — hex-encoded string
// signature.algorithm        — "HMAC-SHA256"

// Sign a string
let strSig = signer.sign(string: "ADT^A01 content", using: signingKey)
```

### Verifying Signatures

```swift
let isValid = signer.verify(data: messageData, signature: signature, using: signingKey)
// true if the message has not been tampered with
```

The verification uses **constant-time comparison** to prevent timing side-channel attacks.

### Use Cases

- **Message integrity**: Sign outgoing HL7 messages; verify on receipt.
- **Non-repudiation**: Attach signatures to archived messages for audit purposes.
- **Transport security**: Verify MLLP or REST payloads have not been altered in transit.

---

## Access Control Setup

### Role-Based Access Control (RBAC)

The `SecurityFramework.swift` includes access control primitives. Define roles and permissions appropriate to your organization:

```swift
// Define roles
enum AppRole: String, Sendable {
    case admin
    case clinician
    case labTech
    case readOnly
}

// Map roles to allowed operations
func canAccess(role: AppRole, resource: String, action: String) -> Bool {
    switch role {
    case .admin:
        return true
    case .clinician:
        return ["Patient", "Observation", "Encounter"].contains(resource)
    case .labTech:
        return resource == "Observation" || (resource == "Patient" && action == "read")
    case .readOnly:
        return action == "read"
    }
}
```

### Access Control with Audit

Combine access checks with audit logging:

```swift
func authorizedAction(
    user: String,
    role: AppRole,
    resource: String,
    action: String,
    logger: UnifiedLogger,
    security: SecurityService
) async -> Bool {
    let allowed = canAccess(role: role, resource: resource, action: action)

    let sanitizedUser = await security.sanitizePHI(in: user)
    await logger.log(
        category: "access-control",
        level: allowed ? .info : .warning,
        message: "\(sanitizedUser) \(action) \(resource): \(allowed ? "ALLOWED" : "DENIED")",
        metadata: LogMetadata(values: ["role": role.rawValue], module: "Security")
    )

    return allowed
}
```

---

## Audit Trail Configuration

### Setting Up an Audit Logger

```swift
import HL7Core

// Dedicated audit logger with large buffer for compliance
let auditLogger = UnifiedLogger(
    subsystem: "com.hospital.audit",
    maxBufferSize: 100_000
)
await auditLogger.setLogLevel(.info) // Capture info and above

// Persistent audit archive
let auditArchive = MessageArchive()
```

### Recording Audit Events

```swift
func recordAuditEvent(
    action: String,
    actor: String,
    resource: String,
    outcome: String
) async {
    let correlationID = CorrelationID.generate()
    let metadata = LogMetadata(
        values: [
            "action": action,
            "actor": actor,
            "resource": resource,
            "outcome": outcome
        ],
        correlationID: correlationID,
        module: "Audit"
    )

    // Log
    await auditLogger.log(
        category: "audit-event",
        level: .info,
        message: "\(actor) performed \(action) on \(resource): \(outcome)",
        metadata: metadata
    )

    // Persist
    let entry = ArchiveEntry(
        messageType: "AUDIT-EVENT",
        version: "1.0",
        source: "AuditService",
        tags: ["audit", action, outcome],
        content: "\(actor)|\(action)|\(resource)|\(outcome)|\(Date().ISO8601Format())"
    )
    try? await auditArchive.store(entry)
}
```

### Querying the Audit Trail

```swift
// Search by action
let accessEvents = await auditIndex.search(byTag: "read")

// Search by date range
let todayEvents = await auditArchive.retrieve(
    byType: "AUDIT-EVENT",
    from: Calendar.current.startOfDay(for: Date()),
    to: Date()
)

// Export for compliance review
let exporter = DataExporter()
let jsonExport = try exporter.exportJSON(from: auditArchive)
```

---

## Certificate Management

### Tracking Certificates

```swift
import HL7Core

let cert = CertificateInfo(
    subject: "CN=Hospital HIS",
    issuer: "CN=Healthcare CA",
    serialNumber: "ABC123",
    validFrom: Date(),
    validTo: Date().addingTimeInterval(365 * 24 * 3600),
    fingerprint: "SHA256:...",
    status: .valid
)

// Check status
switch cert.status {
case .valid:
    // proceed
    break
case .expired:
    // alert administrator
    break
case .revoked:
    // reject connection
    break
default:
    break
}

// Update status
let revokedCert = cert.withStatus(.revoked)
```

### Certificate Lifecycle

| Status | Action Required |
|--------|----------------|
| `.valid` | Normal operation |
| `.notYetValid` | Wait for `validFrom` date |
| `.expired` | Renew certificate |
| `.revoked` | Replace certificate immediately |
| `.untrusted` | Verify certificate chain |
| `.unknown` | Investigate and classify |

---

## Secure Deployment Checklist

Use this checklist before deploying HL7kit to production:

### Cryptography
- [ ] Replace built-in `MessageEncryptor` with production-grade encryption (CryptoKit / AES-GCM)
- [ ] Use hardware-backed key storage (Keychain / Secure Enclave on Apple platforms)
- [ ] Implement key rotation schedule
- [ ] Enable TLS 1.2+ for all network connections (MLLP, SOAP, REST)

### PHI Protection
- [ ] PHI is sanitized before any logging (use `SecurityService.sanitizePHI`)
- [ ] PHI is encrypted at rest in any persistent store
- [ ] PHI is encrypted in transit (TLS)
- [ ] Minimum necessary PHI is collected and retained
- [ ] Data retention policies are configured and enforced

### Access Control
- [ ] Role-based access control is enforced
- [ ] Authentication is required for all API access
- [ ] SMART on FHIR scopes are properly configured for FHIR endpoints
- [ ] Session tokens have appropriate expiration

### Audit
- [ ] All access to PHI is logged with correlation IDs
- [ ] Audit logs are persisted (not just in-memory)
- [ ] Audit log integrity is protected (signed / tamper-evident)
- [ ] Audit logs are reviewed regularly

### Network Security
- [ ] MLLP connections use TLS (not plain TCP)
- [ ] FHIR REST endpoints use HTTPS only
- [ ] SOAP endpoints use WS-Security
- [ ] Connection timeouts are configured
- [ ] Retry logic has maximum attempt limits

### Input Validation
- [ ] All external inputs are validated before processing
- [ ] Message size limits are enforced
- [ ] XML parser depth limits are configured (prevent billion laughs attack)
- [ ] Character encoding is validated (MSH-18 for v2.x)

### Operational
- [ ] Logs do not contain PHI, keys, or credentials
- [ ] Error messages do not leak internal details to callers
- [ ] Caches are cleared on session end or timeout
- [ ] Dependencies are audited for known vulnerabilities

---

## Threat Model Overview

### Assets

| Asset | Sensitivity | Storage |
|-------|------------|---------|
| HL7 messages (v2.x, v3.x, FHIR) | High — contains PHI | Memory, MessageArchive, transit |
| Encryption keys | Critical | Memory (should be Keychain) |
| Signing keys | Critical | Memory (should be Keychain) |
| Audit logs | Medium — may contain metadata | UnifiedLogger buffer, ArchiveIndex |
| Configuration | Low–Medium | Application config |

### Threat Actors

| Actor | Capability | Motivation |
|-------|-----------|------------|
| External attacker | Network access | Data theft, disruption |
| Insider threat | Application access | Unauthorized access to PHI |
| Misconfigured system | N/A | Accidental data exposure |

### Attack Vectors and Mitigations

| Vector | Impact | Mitigation |
|--------|--------|-----------|
| **Unencrypted transport** | PHI interception | Enable TLS on all connections |
| **Log leakage** | PHI in log files | Use `SecurityService.sanitizePHI` before logging |
| **XML entity expansion** | Denial of service | Configure XML parser depth/size limits |
| **Malformed messages** | Parser crashes, injection | Use validation engine; configure error recovery |
| **Key compromise** | Data decryption | Use hardware-backed storage; implement key rotation |
| **Unauthorized access** | PHI breach | Enforce RBAC and SMART on FHIR scopes |
| **Replay attacks** | Duplicate message processing | Use message IDs and deduplication |
| **Timing attacks** | Key/signature recovery | Constant-time comparison in `DigitalSigner` |

### Security Boundaries

```
┌─────────────────────────────────────────────────┐
│                  Application                      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │ HL7v2Kit  │  │ HL7v3Kit  │  │  FHIRkit  │    │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘    │
│        └───────────┬───┴───────────┬──┘          │
│                    ▼               │              │
│              ┌───────────┐        │              │
│              │  HL7Core  │◄───────┘              │
│              │ (Security │                        │
│              │  Service) │                        │
│              └───────────┘                        │
├─────────────────────────────────────────────────┤ ← Trust boundary
│              Network / Storage                    │
│  ┌───────┐  ┌───────┐  ┌───────┐  ┌─────────┐  │
│  │ MLLP  │  │ SOAP  │  │ REST  │  │ Archive │  │
│  │ (TLS) │  │ (WS-S)│  │(HTTPS)│  │ (Enc.)  │  │
│  └───────┘  └───────┘  └───────┘  └─────────┘  │
└─────────────────────────────────────────────────┘
```

---

## Security Audit Findings & Recommendations

### Phase 9.2 Security Assessment (February 2026)

A comprehensive security vulnerability assessment was conducted on the HL7kit security framework. This section summarizes key findings and provides guidance for production deployments.

#### Executive Summary

- **Assessment Scope**: `SecurityFramework.swift` and `CommonServices.swift`
- **Issues Identified**: 2 Critical, 4 High, 5 Medium, 4 Low severity vulnerabilities
- **Status**: Demonstration-grade security suitable for development; production hardening required

#### Critical Findings

**1. Non-Standard Encryption Algorithm (XOR-SHA256-STREAM)**

- **Issue**: Custom stream cipher provides limited security compared to industry-standard AES
- **Impact**: Vulnerable to bit-flipping attacks; no integrity protection
- **Status**: DOCUMENTED - Production deployments must use AES-256-GCM or equivalent
- **Remediation**: See [Production Encryption Requirements](#production-encryption-requirements)

**2. Missing Authenticated Encryption**

- **Issue**: Encrypted payloads lack authentication tags (not AEAD-compliant)
- **Impact**: Ciphertext can be modified without detection
- **Status**: DOCUMENTED - Production deployments must add integrity protection
- **Remediation**: Use AES-GCM or add HMAC-based authentication layer

#### High Severity Findings

**3. Timing Attack in Signature Verification**

- **Issue**: Early exit on length mismatch leaked timing information
- **Status**: ✅ FIXED (February 2026)
- **Fix**: Implemented constant-time comparison for all signature lengths
- **Test Coverage**: Added 3 test cases validating timing attack mitigation

**4. Insufficient Key Size Validation**

- **Issue**: No enforcement of minimum key size requirements
- **Status**: ✅ FIXED (February 2026)  
- **Fix**: Added preconditions enforcing 16-256 byte key sizes
- **Test Coverage**: Added 6 test cases for key size boundaries

**5. Input Validation Gaps**

- **Issue**: Missing validation for empty data and size limits
- **Status**: ✅ FIXED (February 2026)
- **Fix**: Added preconditions for non-empty data and 100MB maximum
- **Test Coverage**: Added 4 test cases for input validation

**6. HMAC vs Asymmetric Signatures**

- **Issue**: HMAC-SHA256 provides authentication but not non-repudiation
- **Status**: DOCUMENTED - Consider asymmetric signatures for legal compliance
- **Recommendation**: Implement ECDSA/RSA for scenarios requiring non-repudiation

#### Medium Severity Findings

- **IV Reuse Risk**: Random IV generation may collide under high load
- **No Key Rotation**: Keys lack expiration and versioning mechanisms
- **Certificate Validation**: No CRL/OCSP integration for real-time revocation checking
- **Access Control Logic**: Policy evaluation uses "any allows" vs. "all must allow"
- **Credential Storage**: No integration with platform Keychain/SecureEnclave

See [SECURITY_VULNERABILITY_ASSESSMENT.md](SECURITY_VULNERABILITY_ASSESSMENT.md) for complete details.

---

### Production Encryption Requirements

For production healthcare deployments, the current encryption implementation **MUST** be replaced with industry-standard cryptography:

#### Apple Platforms (iOS, macOS, tvOS, watchOS)

Use **CryptoKit** with AES-256-GCM:

```swift
import CryptoKit

// Encryption
let key = SymmetricKey(size: .bits256)
let nonce = AES.GCM.Nonce()
let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)

// Decryption with authentication
let decrypted = try AES.GCM.open(sealedBox, using: key)
```

**Benefits:**
- Hardware-accelerated encryption (SecureEnclave)
- Authenticated encryption (AEAD)
- FIPS 140-2 compliant
- Memory-safe implementation

#### Linux / Cross-Platform

Use **OpenSSL** with AES-256-GCM:

```swift
import OpenSSL

// Example using openssl wrapper
let encrypted = AES256GCM.encrypt(
    plaintext: data,
    key: key,
    authenticatedData: additionalData
)

let decrypted = try AES256GCM.decrypt(
    ciphertext: encrypted.ciphertext,
    tag: encrypted.tag,
    key: key,
    authenticatedData: additionalData
)
```

**Migration Strategy:**

1. Create `ProductionEncryptor` protocol compatible with existing API
2. Implement platform-specific versions using CryptoKit/OpenSSL
3. Use conditional compilation for platform-specific code:
   ```swift
   #if canImport(CryptoKit)
   import CryptoKit
   // iOS/macOS implementation
   #else
   import OpenSSL
   // Linux implementation
   #endif
   ```
4. Maintain demonstration implementation for testing only

---

### Production Digital Signature Requirements

For scenarios requiring **non-repudiation** (legal records, audit trails), replace HMAC-SHA256 with asymmetric signatures:

#### Recommended Approach (ECDSA with P-256)

```swift
import CryptoKit

// Key generation
let privateKey = P256.Signing.PrivateKey()
let publicKey = privateKey.publicKey

// Signing
let signature = try privateKey.signature(for: data)

// Verification
guard publicKey.isValidSignature(signature, for: data) else {
    throw SignatureError.invalid
}
```

**When to Use:**
- Legal health records requiring audit trails
- Multi-party transactions (hospital ↔ clinic ↔ pharmacy)
- Compliance requirements for digital signatures (e.g., 21 CFR Part 11)

**When HMAC is Sufficient:**
- Internal system authentication
- Message integrity checks within trusted boundaries
- Development and testing environments

---

### Security Hardening Checklist

Before deploying HL7kit in a production healthcare environment:

#### Cryptography
- [ ] Replace XOR-SHA256 cipher with AES-256-GCM
- [ ] Implement authenticated encryption (AEAD) for all encrypted data
- [ ] Add asymmetric signatures if non-repudiation required
- [ ] Integrate platform-native key storage (Keychain/SecureEnclave)
- [ ] Implement key rotation and expiration policies

#### Access Control
- [ ] Review and harden access control policy evaluation logic
- [ ] Implement role-based access control (RBAC) for all resources
- [ ] Add audit logging for all access decisions
- [ ] Enforce least privilege principle
- [ ] Test with conflicting policy scenarios

#### PHI Protection
- [ ] Extend PHI sanitization to cover all 18 HIPAA identifier types
- [ ] Validate all user inputs before processing
- [ ] Implement secure data erasure for sensitive memory
- [ ] Enable PHI sanitization in all log outputs
- [ ] Configure retention policies for archived data

#### Network Security
- [ ] Enable TLS 1.3+ for all network communications
- [ ] Validate all TLS certificates (no self-signed in production)
- [ ] Implement certificate pinning for critical endpoints
- [ ] Add network timeout and retry logic with exponential backoff
- [ ] Monitor for certificate expiration

#### Compliance
- [ ] Conduct HIPAA compliance review
- [ ] Document data flows and trust boundaries
- [ ] Implement audit trail for all PHI access
- [ ] Create incident response procedures
- [ ] Schedule regular security audits

#### Testing
- [ ] Run all security tests in CI/CD pipeline
- [ ] Perform penetration testing on deployed systems
- [ ] Conduct third-party security audit
- [ ] Test disaster recovery procedures
- [ ] Validate backup encryption

---

### Threat Model Summary

#### Assets

1. **Patient Health Information (PHI)** - Critical asset requiring confidentiality and integrity
2. **Encryption/Signing Keys** - High-value targets for attackers
3. **System Credentials** - Access to healthcare systems and databases
4. **Audit Logs** - Compliance evidence and forensic data

#### Threat Actors

1. **External Attackers** - Cybercriminals seeking PHI for financial gain
2. **Malicious Insiders** - Employees with excessive access privileges
3. **Nation-State Actors** - Advanced persistent threats targeting healthcare
4. **Accidental Disclosure** - Unintentional data leaks from misconfigurations

#### Attack Vectors

1. **Network Attacks**
   - Man-in-the-middle (MITM) interception of HL7 messages
   - TLS downgrade attacks
   - Network eavesdropping on unencrypted channels

2. **Cryptographic Attacks**
   - Known-plaintext attacks on weak ciphers
   - Timing attacks on signature verification
   - IV reuse enabling keystream recovery
   - Brute-force attacks on weak keys

3. **Application Attacks**
   - Injection attacks (HL7 message injection, SQL injection)
   - Authentication bypass
   - Authorization flaws (privilege escalation)
   - Input validation failures

4. **Physical Attacks**
   - Memory dumps to extract keys
   - Disk access to read archived data
   - Device theft or compromise

#### Mitigations

| Threat | Current Mitigation | Production Required |
|--------|-------------------|---------------------|
| Network eavesdropping | TLS support | TLS 1.3+ mandatory |
| Weak encryption | XOR cipher (demo) | AES-256-GCM required |
| Timing attacks | ✅ Fixed | Maintain constant-time |
| Weak keys | ✅ Size validation | Add key rotation |
| Key theft | In-memory storage | Use Keychain/SecureEnclave |
| PHI disclosure | Basic sanitization | Complete 18 identifiers |
| Privilege escalation | RBAC framework | Harden policy evaluation |
| Data tampering | HMAC signatures | Add AEAD/asymmetric sigs |

---

### Compliance Mapping

#### HIPAA Security Rule

| Requirement | Section | HL7kit Implementation | Status |
|-------------|---------|----------------------|---------|
| Access Control | §164.312(a)(1) | Role-based access control | ✅ Implemented |
| Audit Controls | §164.312(b) | Audit trail logging | ✅ Implemented |
| Integrity Controls | §164.312(c)(1) | Digital signatures | ⚠️ HMAC only |
| Transmission Security | §164.312(e)(1) | TLS/encryption | ⚠️ Needs hardening |
| Encryption | §164.312(a)(2)(iv) | XOR cipher | ❌ Prod upgrade needed |

#### Recommendations for HIPAA Compliance

1. **Upgrade encryption to AES-256-GCM** before handling real PHI
2. **Implement authenticated encryption** to meet integrity requirements
3. **Add asymmetric signatures** for non-repudiation where required
4. **Enable comprehensive audit logging** for all PHI access
5. **Document security policies** and incident response procedures

---

### Security Testing Requirements

All production deployments must pass:

#### Unit Tests
- [x] Timing attack mitigation tests (3 tests)
- [x] Key size validation tests (6 tests)
- [x] Input validation tests (4 tests)
- [x] Encryption/decryption round-trip tests (10+ tests)
- [x] Signature verification tests (8+ tests)
- [x] Access control tests (15+ tests)

#### Integration Tests
- [ ] End-to-end TLS communication tests
- [ ] Multi-party message exchange tests
- [ ] Key rotation and expiration tests
- [ ] Failure recovery and error handling tests

#### Security Tests
- [ ] Penetration testing by qualified security firm
- [ ] Vulnerability scanning (OWASP Top 10, CWE Top 25)
- [ ] Fuzzing of parsers and validators
- [ ] Side-channel attack testing (timing, cache)
- [ ] Compliance testing (HIPAA, HL7 conformance)

#### Performance Tests
- [ ] Encryption throughput under load
- [ ] Signature verification latency
- [ ] Concurrent access handling
- [ ] Memory usage profiling
- [ ] CPU utilization analysis

---

### Reporting Security Issues

If you discover a security vulnerability in HL7kit:

1. **DO NOT** open a public GitHub issue
2. Email security details to: security@hl7kit.example.com (or contact repository maintainers)
3. Include:
   - Vulnerability description
   - Steps to reproduce
   - Potential impact assessment
   - Suggested fixes (if available)
4. Allow 90 days for patching before public disclosure

---

### Security Updates

- **February 2026**: Phase 9.2 security audit completed
  - Fixed timing attack vulnerability in signature verification
  - Added key size validation (16-256 bytes enforced)
  - Added input validation for encryption/signing operations
  - Documented critical/high severity findings requiring production hardening

---

*See also: [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) for service usage, [ARCHITECTURE.md](ARCHITECTURE.md) for system design, [CONCURRENCY_MODEL.md](CONCURRENCY_MODEL.md) for thread safety details.*
