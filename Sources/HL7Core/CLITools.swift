/// CLI Tools for HL7kit
///
/// This module provides reusable command-line tool types for validating,
/// converting, testing, and batch-processing HL7 messages. All types are
/// `public` and `Sendable`, suitable for embedding in any executable target.

import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Message Validator CLI

/// Validates HL7 v2.x messages and produces structured reports
public struct MessageValidatorCLI: Sendable {

    /// Creates a new message validator
    public init() {}

    /// Validates an HL7 v2.x message string
    /// - Parameter input: The raw HL7 message using `\r` segment delimiters
    /// - Returns: A `ValidationReport` describing the result
    /// - Throws: `HL7Error` when the input cannot be parsed at all
    public func validate(input: String) async throws -> ValidationReport {
        var errors: [ValidationReportIssue] = []
        var warnings: [ValidationReportIssue] = []

        let segments = splitSegments(input)
        guard !segments.isEmpty else {
            throw HL7Error.invalidFormat("Empty message")
        }

        // MSH segment checks
        guard let msh = segments.first, msh.hasPrefix("MSH") else {
            throw HL7Error.invalidFormat("Message must start with MSH segment")
        }

        let mshFields = msh.components(separatedBy: "|")

        // Encoding characters (MSH-2)
        let encodingChars = mshFields.count > 1 ? mshFields[1] : ""
        if encodingChars != "^~\\&" {
            if encodingChars.isEmpty {
                errors.append(ValidationReportIssue(
                    description: "Missing encoding characters in MSH-2",
                    location: "MSH-2"
                ))
            } else {
                warnings.append(ValidationReportIssue(
                    description: "Non-standard encoding characters: \(encodingChars)",
                    location: "MSH-2"
                ))
            }
        }

        // Message type (MSH-9)
        var messageType = ""
        if mshFields.count > 8 {
            messageType = mshFields[8]
            if messageType.isEmpty {
                errors.append(ValidationReportIssue(
                    description: "Missing message type in MSH-9",
                    location: "MSH-9"
                ))
            }
        } else {
            errors.append(ValidationReportIssue(
                description: "MSH segment missing message type field (MSH-9)",
                location: "MSH"
            ))
        }

        // Message control ID (MSH-10)
        if mshFields.count > 9 {
            if mshFields[9].isEmpty {
                errors.append(ValidationReportIssue(
                    description: "Missing message control ID in MSH-10",
                    location: "MSH-10"
                ))
            }
        } else {
            errors.append(ValidationReportIssue(
                description: "MSH segment missing control ID field (MSH-10)",
                location: "MSH"
            ))
        }

        // Processing ID (MSH-11)
        if mshFields.count > 10 {
            let pid = mshFields[10]
            let validPIDs: Set<String> = ["P", "D", "T"]
            if !validPIDs.contains(pid) && !pid.isEmpty {
                warnings.append(ValidationReportIssue(
                    description: "Non-standard processing ID '\(pid)' in MSH-11",
                    location: "MSH-11"
                ))
            }
        }

        // Version (MSH-12)
        var version = ""
        if mshFields.count > 11 {
            version = mshFields[11]
            let validVersions: Set<String> = ["2.1", "2.2", "2.3", "2.3.1", "2.4", "2.5", "2.5.1", "2.6", "2.7", "2.8"]
            if !validVersions.contains(version) && !version.isEmpty {
                warnings.append(ValidationReportIssue(
                    description: "Unrecognized HL7 version '\(version)' in MSH-12",
                    location: "MSH-12"
                ))
            }
        }

        // Check required segments for ADT messages
        let segmentNames = segments.map { seg -> String in
            let idx = seg.index(seg.startIndex, offsetBy: min(3, seg.count))
            return String(seg[seg.startIndex..<idx])
        }

        if messageType.hasPrefix("ADT") {
            if !segmentNames.contains("EVN") {
                warnings.append(ValidationReportIssue(
                    description: "ADT message missing recommended EVN segment",
                    location: "Message"
                ))
            }
            if !segmentNames.contains("PID") {
                errors.append(ValidationReportIssue(
                    description: "ADT message missing required PID segment",
                    location: "Message"
                ))
            }
            if !segmentNames.contains("PV1") {
                warnings.append(ValidationReportIssue(
                    description: "ADT message missing recommended PV1 segment",
                    location: "Message"
                ))
            }
        }

        // Validate segment names (3 uppercase letters)
        for (index, name) in segmentNames.enumerated() {
            if name.count < 3 || !name.allSatisfy({ $0.isUpperCase || $0.isNumber }) {
                errors.append(ValidationReportIssue(
                    description: "Invalid segment name '\(name)' at position \(index + 1)",
                    location: "Segment \(index + 1)"
                ))
            }
        }

        let isValid = errors.isEmpty
        return ValidationReport(
            isValid: isValid,
            errors: errors,
            warnings: warnings,
            segmentCount: segments.count,
            messageType: messageType,
            version: version
        )
    }

    /// Splits a raw HL7 message into segments by `\r`, `\n`, or `\r\n`
    func splitSegments(_ input: String) -> [String] {
        input
            .replacingOccurrences(of: "\r\n", with: "\r")
            .replacingOccurrences(of: "\n", with: "\r")
            .split(separator: "\r", omittingEmptySubsequences: true)
            .map(String.init)
    }
}

// MARK: - Validation Report

/// Report produced by `MessageValidatorCLI`
public struct ValidationReport: Sendable {
    /// Whether the message is valid (no errors)
    public let isValid: Bool
    /// Errors found during validation
    public let errors: [ValidationReportIssue]
    /// Warnings found during validation
    public let warnings: [ValidationReportIssue]
    /// Number of segments in the message
    public let segmentCount: Int
    /// Message type from MSH-9 (e.g. "ADT^A01")
    public let messageType: String
    /// HL7 version from MSH-12 (e.g. "2.5")
    public let version: String

    public init(
        isValid: Bool,
        errors: [ValidationReportIssue],
        warnings: [ValidationReportIssue],
        segmentCount: Int,
        messageType: String,
        version: String
    ) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.segmentCount = segmentCount
        self.messageType = messageType
        self.version = version
    }
}

/// A single issue found during CLI validation
public struct ValidationReportIssue: Sendable {
    /// Human-readable description of the issue
    public let description: String
    /// Location in the message where the issue was found
    public let location: String

    public init(description: String, location: String) {
        self.description = description
        self.location = location
    }
}

// MARK: - Format Converter CLI

/// Converts HL7 messages between formats (HL7 v2 pipe, JSON, XML, pretty-print)
public struct FormatConverterCLI: Sendable {

    /// Supported input formats
    public enum InputFormat: String, Sendable, CaseIterable {
        case hl7v2
        case xml
        case json
    }

    /// Supported output formats
    public enum OutputFormat: String, Sendable, CaseIterable {
        case hl7v2
        case xml
        case json
        case prettyPrint
    }

    /// Creates a new format converter
    public init() {}

    /// Converts a message string between formats
    /// - Parameters:
    ///   - input: The source message
    ///   - from: The input format
    ///   - to: The desired output format
    /// - Returns: The converted message string
    /// - Throws: `HL7Error` if conversion fails
    public func convert(input: String, from: InputFormat, to: OutputFormat) async throws -> String {
        let segments: [[String]]
        switch from {
        case .hl7v2:
            segments = parseHL7v2(input)
        case .json:
            segments = try parseJSON(input)
        case .xml:
            segments = try parseXML(input)
        }

        guard !segments.isEmpty else {
            throw HL7Error.invalidFormat("No segments found in input")
        }

        switch to {
        case .hl7v2:
            return segments.map { $0.joined(separator: "|") }.joined(separator: "\r")
        case .json:
            return formatAsJSON(segments)
        case .xml:
            return formatAsXML(segments)
        case .prettyPrint:
            return formatAsPrettyPrint(segments)
        }
    }

    // MARK: - Parsers

    /// Parses HL7 v2 pipe-delimited text into an array of field arrays
    func parseHL7v2(_ input: String) -> [[String]] {
        let rawSegments = input
            .replacingOccurrences(of: "\r\n", with: "\r")
            .replacingOccurrences(of: "\n", with: "\r")
            .split(separator: "\r", omittingEmptySubsequences: true)
            .map(String.init)
        return rawSegments.map { $0.components(separatedBy: "|") }
    }

    /// Parses a JSON representation produced by `formatAsJSON` back into segments
    func parseJSON(_ input: String) throws -> [[String]] {
        guard let data = input.data(using: .utf8) else {
            throw HL7Error.parsingError("Invalid UTF-8 in JSON input")
        }
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw HL7Error.parsingError("Invalid JSON: \(error.localizedDescription)")
        }
        guard let root = jsonObject as? [String: Any],
              let segs = root["segments"] as? [[String: Any]] else {
            throw HL7Error.parsingError("Expected JSON object with 'segments' array")
        }
        var result: [[String]] = []
        for seg in segs {
            guard let name = seg["name"] as? String,
                  let fields = seg["fields"] as? [String] else {
                throw HL7Error.parsingError("Invalid segment entry in JSON")
            }
            result.append([name] + fields)
        }
        return result
    }

    /// Minimal XML parser for the format produced by `formatAsXML`
    func parseXML(_ input: String) throws -> [[String]] {
        var segments: [[String]] = []
        let segmentPattern = "<segment name=\"([^\"]+)\">"
        let fieldPattern = "<field>([^<]*)</field>"
        guard let segRegex = try? NSRegularExpression(pattern: segmentPattern),
              let fieldRegex = try? NSRegularExpression(pattern: fieldPattern) else {
            throw HL7Error.parsingError("Failed to compile XML regex")
        }
        let range = NSRange(input.startIndex..., in: input)
        let segMatches = segRegex.matches(in: input, range: range)
        for segMatch in segMatches {
            guard let nameRange = Range(segMatch.range(at: 1), in: input) else { continue }
            let name = String(input[nameRange])

            let segStart = segMatch.range.location
            let segEnd: Int
            if let closeRange = input.range(of: "</segment>",
                                            range: input.index(input.startIndex, offsetBy: segStart)..<input.endIndex) {
                segEnd = input.distance(from: input.startIndex, to: closeRange.upperBound)
            } else {
                segEnd = input.count
            }
            let segBody = NSRange(location: segStart, length: segEnd - segStart)
            let fieldMatches = fieldRegex.matches(in: input, range: segBody)
            var fields: [String] = []
            for fm in fieldMatches {
                guard let fr = Range(fm.range(at: 1), in: input) else { continue }
                fields.append(String(input[fr]))
            }
            segments.append([name] + fields)
        }
        if segments.isEmpty {
            throw HL7Error.parsingError("No segments found in XML input")
        }
        return segments
    }

    // MARK: - Formatters

    /// Formats segments as a JSON string
    func formatAsJSON(_ segments: [[String]]) -> String {
        var entries: [String] = []
        for fields in segments {
            let name = fields.first ?? ""
            let rest = fields.dropFirst().map { escaped in
                let s = escaped
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(s)\""
            }
            entries.append("    {\"name\": \"\(name)\", \"fields\": [\(rest.joined(separator: ", "))]}")
        }
        return "{\n  \"segments\": [\n\(entries.joined(separator: ",\n"))\n  ]\n}"
    }

    /// Formats segments as an XML string
    func formatAsXML(_ segments: [[String]]) -> String {
        var lines: [String] = ["<hl7message>"]
        for fields in segments {
            let name = fields.first ?? ""
            lines.append("  <segment name=\"\(name)\">")
            for field in fields.dropFirst() {
                let escaped = field
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                lines.append("    <field>\(escaped)</field>")
            }
            lines.append("  </segment>")
        }
        lines.append("</hl7message>")
        return lines.joined(separator: "\n")
    }

    /// Formats segments as human-readable pretty-printed text
    func formatAsPrettyPrint(_ segments: [[String]]) -> String {
        var lines: [String] = []
        for fields in segments {
            let name = fields.first ?? ""
            lines.append("── \(name) ──")
            for (index, field) in fields.dropFirst().enumerated() {
                if !field.isEmpty {
                    lines.append("  \(name)-\(index + 1): \(field)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Network Test CLI

/// Tests MLLP network connectivity and message exchange
public struct NetworkTestCLI: Sendable {

    /// Creates a new network test tool
    public init() {}

    /// Tests whether a host/port combination is reachable
    /// - Parameters:
    ///   - host: The target hostname or IP
    ///   - port: The target port number
    ///   - timeout: Maximum time to wait for a response
    /// - Returns: A `ConnectionTestResult` describing the outcome
    /// - Throws: `HL7Error.networkError` on failure
    public func testConnection(host: String, port: Int, timeout: TimeInterval = 5.0) async throws -> ConnectionTestResult {
        guard !host.isEmpty else {
            throw HL7Error.networkError("Host must not be empty")
        }
        guard port > 0 && port <= 65535 else {
            throw HL7Error.networkError("Port must be between 1 and 65535")
        }

        let start = Date()

        let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        guard fd >= 0 else {
            throw HL7Error.networkError("Failed to create socket")
        }
        defer { close(fd) }

        // Set non-blocking
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian

        // Resolve host
        if inet_pton(AF_INET, host, &addr.sin_addr) != 1 {
            // Try DNS resolution
            guard let hostEntry = gethostbyname(host),
                  hostEntry.pointee.h_length > 0,
                  let addrList = hostEntry.pointee.h_addr_list,
                  let firstAddr = addrList[0] else {
                return ConnectionTestResult(reachable: false, responseTime: Date().timeIntervalSince(start), tlsAvailable: false)
            }
            memcpy(&addr.sin_addr, firstAddr, Int(hostEntry.pointee.h_length))
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var reachable = false
        if connectResult == 0 {
            reachable = true
        } else if errno == EINPROGRESS {
            // Wait for connection with poll
            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let pollResult = poll(&pfd, 1, Int32(timeout * 1000))
            if pollResult > 0 && (pfd.revents & Int16(POLLOUT)) != 0 {
                var optError: Int32 = 0
                var optLen = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(fd, SOL_SOCKET, SO_ERROR, &optError, &optLen)
                reachable = (optError == 0)
            }
        }

        let responseTime = Date().timeIntervalSince(start)

        return ConnectionTestResult(
            reachable: reachable,
            responseTime: responseTime,
            tlsAvailable: false
        )
    }

    /// Sends an HL7 message using MLLP framing and returns the result
    /// - Parameters:
    ///   - message: The HL7 message to send
    ///   - host: The target hostname or IP
    ///   - port: The target port number
    /// - Returns: A `NetworkTestResult` describing the exchange
    /// - Throws: `HL7Error.networkError` on failure
    public func sendMessage(message: String, host: String, port: Int) async throws -> NetworkTestResult {
        guard !message.isEmpty else {
            throw HL7Error.networkError("Message must not be empty")
        }
        guard !host.isEmpty else {
            throw HL7Error.networkError("Host must not be empty")
        }
        guard port > 0 && port <= 65535 else {
            throw HL7Error.networkError("Port must be between 1 and 65535")
        }

        // MLLP framing: VT (0x0B) + message + FS (0x1C) + CR (0x0D)
        let mllpStart = "\u{0B}"
        let mllpEnd = "\u{1C}\r"
        let framedMessage = mllpStart + message + mllpEnd

        guard let data = framedMessage.data(using: .utf8) else {
            throw HL7Error.encodingError("Failed to encode message as UTF-8")
        }

        let start = Date()

        let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        guard fd >= 0 else {
            throw HL7Error.networkError("Failed to create socket")
        }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian

        if inet_pton(AF_INET, host, &addr.sin_addr) != 1 {
            guard let hostEntry = gethostbyname(host),
                  hostEntry.pointee.h_length > 0,
                  let addrList = hostEntry.pointee.h_addr_list,
                  let firstAddr = addrList[0] else {
                return NetworkTestResult(success: false, responseMessage: nil, roundTripTime: Date().timeIntervalSince(start))
            }
            memcpy(&addr.sin_addr, firstAddr, Int(hostEntry.pointee.h_length))
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard connectResult == 0 else {
            return NetworkTestResult(
                success: false,
                responseMessage: nil,
                roundTripTime: Date().timeIntervalSince(start)
            )
        }

        // Write
        let bytes = [UInt8](data)
        let written = send(fd, bytes, bytes.count, 0)
        guard written > 0 else {
            return NetworkTestResult(
                success: false,
                responseMessage: nil,
                roundTripTime: Date().timeIntervalSince(start)
            )
        }

        // Read response with poll
        var buffer = [UInt8](repeating: 0, count: 4096)
        var rpfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        var responseMessage: String? = nil
        let pollResult = poll(&rpfd, 1, 5000)
        if pollResult > 0 && (rpfd.revents & Int16(POLLIN)) != 0 {
            let bytesRead = recv(fd, &buffer, buffer.count, 0)
            if bytesRead > 0 {
                responseMessage = String(bytes: buffer[0..<bytesRead], encoding: .utf8)
            }
        }

        let roundTripTime = Date().timeIntervalSince(start)

        return NetworkTestResult(
            success: true,
            responseMessage: responseMessage,
            roundTripTime: roundTripTime
        )
    }
}

/// Result of a connection test
public struct ConnectionTestResult: Sendable {
    /// Whether the host was reachable
    public let reachable: Bool
    /// Time taken to establish the connection in seconds
    public let responseTime: TimeInterval
    /// Whether TLS is available on the connection
    public let tlsAvailable: Bool

    public init(reachable: Bool, responseTime: TimeInterval, tlsAvailable: Bool) {
        self.reachable = reachable
        self.responseTime = responseTime
        self.tlsAvailable = tlsAvailable
    }
}

/// Result of sending a message over the network
public struct NetworkTestResult: Sendable {
    /// Whether the send/receive succeeded
    public let success: Bool
    /// Response message received (if any)
    public let responseMessage: String?
    /// Round-trip time in seconds
    public let roundTripTime: TimeInterval

    public init(success: Bool, responseMessage: String?, roundTripTime: TimeInterval) {
        self.success = success
        self.responseMessage = responseMessage
        self.roundTripTime = roundTripTime
    }
}

// MARK: - Conformance Checker CLI

/// Checks HL7 messages against conformance profiles
public struct ConformanceCheckerCLI: Sendable {

    /// Creates a new conformance checker
    public init() {}

    /// Checks a message against a conformance profile
    /// - Parameters:
    ///   - message: The HL7 v2.x message to check
    ///   - profile: Optional profile name (defaults to "HL7v2-Base")
    /// - Returns: A `CLIConformanceReport` with the results
    /// - Throws: `HL7Error` if the message cannot be parsed
    public func checkConformance(message: String, profile: String? = nil) async throws -> CLIConformanceReport {
        let profileName = profile ?? "HL7v2-Base"
        var violations: [ConformanceViolation] = []
        var warnings: [ConformanceViolation] = []

        let segments = splitSegments(message)
        guard !segments.isEmpty else {
            throw HL7Error.invalidFormat("Empty message")
        }

        guard let msh = segments.first, msh.hasPrefix("MSH") else {
            throw HL7Error.invalidFormat("Message must start with MSH segment")
        }

        let mshFields = msh.components(separatedBy: "|")

        // Encoding characters check
        if mshFields.count > 1 && mshFields[1] != "^~\\&" {
            violations.append(ConformanceViolation(
                rule: "MSH-2 Encoding Characters",
                description: "Expected '^~\\&' but found '\(mshFields[1])'",
                severity: .error
            ))
        }

        // Sending application (MSH-3)
        if mshFields.count > 2 && mshFields[2].isEmpty {
            warnings.append(ConformanceViolation(
                rule: "MSH-3 Sending Application",
                description: "Sending application should be populated",
                severity: .warning
            ))
        }

        // Sending facility (MSH-4)
        if mshFields.count > 3 && mshFields[3].isEmpty {
            warnings.append(ConformanceViolation(
                rule: "MSH-4 Sending Facility",
                description: "Sending facility should be populated",
                severity: .warning
            ))
        }

        // Date/time (MSH-7)
        if mshFields.count > 6 {
            let dt = mshFields[6]
            if dt.isEmpty {
                violations.append(ConformanceViolation(
                    rule: "MSH-7 Date/Time",
                    description: "Message date/time is required",
                    severity: .error
                ))
            } else if dt.count < 8 {
                warnings.append(ConformanceViolation(
                    rule: "MSH-7 Date/Time",
                    description: "Date/time should be at least 8 characters (YYYYMMDD)",
                    severity: .warning
                ))
            }
        }

        // Message type (MSH-9)
        if mshFields.count > 8 {
            let mt = mshFields[8]
            if mt.isEmpty {
                violations.append(ConformanceViolation(
                    rule: "MSH-9 Message Type",
                    description: "Message type is required",
                    severity: .error
                ))
            } else if !mt.contains("^") {
                warnings.append(ConformanceViolation(
                    rule: "MSH-9 Message Type",
                    description: "Message type should include trigger event (e.g. ADT^A01)",
                    severity: .warning
                ))
            }
        }

        // Version (MSH-12)
        if mshFields.count > 11 {
            let ver = mshFields[11]
            if ver.isEmpty {
                violations.append(ConformanceViolation(
                    rule: "MSH-12 Version",
                    description: "Version ID is required",
                    severity: .error
                ))
            }
        }

        // Segment-level checks
        let segmentNames = segments.map { seg -> String in
            let idx = seg.index(seg.startIndex, offsetBy: min(3, seg.count))
            return String(seg[seg.startIndex..<idx])
        }

        // PID checks
        if let pidIdx = segmentNames.firstIndex(of: "PID") {
            let pidFields = segments[pidIdx].components(separatedBy: "|")
            // PID-3 Patient Identifier
            if pidFields.count > 3 && pidFields[3].isEmpty {
                violations.append(ConformanceViolation(
                    rule: "PID-3 Patient Identifier",
                    description: "Patient identifier list is required",
                    severity: .error
                ))
            }
            // PID-5 Patient Name
            if pidFields.count > 5 && pidFields[5].isEmpty {
                violations.append(ConformanceViolation(
                    rule: "PID-5 Patient Name",
                    description: "Patient name is required",
                    severity: .error
                ))
            }
        }

        // Calculate score (0-100)
        let totalChecks = 10
        let errorWeight = 2
        let warningWeight = 1
        let deductions = violations.count * errorWeight + warnings.count * warningWeight
        let score = max(0, 100 - (deductions * 100 / (totalChecks * errorWeight)))

        return CLIConformanceReport(
            conformant: violations.isEmpty,
            violations: violations,
            warnings: warnings,
            profileName: profileName,
            score: score
        )
    }

    /// Splits a raw HL7 message into segments
    func splitSegments(_ input: String) -> [String] {
        input
            .replacingOccurrences(of: "\r\n", with: "\r")
            .replacingOccurrences(of: "\n", with: "\r")
            .split(separator: "\r", omittingEmptySubsequences: true)
            .map(String.init)
    }
}

/// Report produced by `ConformanceCheckerCLI`
public struct CLIConformanceReport: Sendable {
    /// Whether the message is fully conformant (no violations)
    public let conformant: Bool
    /// Violations found during conformance checking
    public let violations: [ConformanceViolation]
    /// Warnings found during conformance checking
    public let warnings: [ConformanceViolation]
    /// The profile name checked against
    public let profileName: String
    /// Conformance score (0–100)
    public let score: Int

    public init(
        conformant: Bool,
        violations: [ConformanceViolation],
        warnings: [ConformanceViolation],
        profileName: String,
        score: Int
    ) {
        self.conformant = conformant
        self.violations = violations
        self.warnings = warnings
        self.profileName = profileName
        self.score = score
    }
}

/// A single conformance violation
public struct ConformanceViolation: Sendable {
    /// The conformance rule that was violated
    public let rule: String
    /// Human-readable description
    public let description: String
    /// Severity of the violation
    public let severity: ValidationSeverity

    public init(rule: String, description: String, severity: ValidationSeverity) {
        self.rule = rule
        self.description = description
        self.severity = severity
    }
}

// MARK: - Batch Processor CLI

/// Processes batches of HL7 messages from file content
public struct BatchProcessorCLI: Sendable {

    /// Operations that can be performed on a batch
    public enum BatchOperation: String, Sendable, CaseIterable {
        case validate
        case convert
        case statistics
    }

    /// Creates a new batch processor
    public init() {}

    /// Processes file content containing one or more HL7 messages
    /// - Parameters:
    ///   - content: Raw file content potentially containing multiple messages
    ///   - operation: The batch operation to perform
    /// - Returns: A `BatchReport` summarizing the results
    /// - Throws: `HL7Error` if the content cannot be processed
    public func processFile(content: String, operation: BatchOperation) async throws -> BatchReport {
        let start = Date()
        let messages = splitMessages(content)

        guard !messages.isEmpty else {
            throw HL7Error.invalidFormat("No HL7 messages found in content")
        }

        var processed = 0
        var passed = 0
        var failed = 0
        var errors: [BatchError] = []

        let validator = MessageValidatorCLI()
        let converter = FormatConverterCLI()

        for (index, msg) in messages.enumerated() {
            processed += 1
            do {
                switch operation {
                case .validate:
                    let report = try await validator.validate(input: msg)
                    if report.isValid {
                        passed += 1
                    } else {
                        failed += 1
                        for err in report.errors {
                            errors.append(BatchError(
                                messageIndex: index,
                                description: err.description,
                                location: err.location
                            ))
                        }
                    }
                case .convert:
                    _ = try await converter.convert(input: msg, from: .hl7v2, to: .json)
                    passed += 1
                case .statistics:
                    // Statistics always succeeds — just counts segments
                    _ = try await validator.validate(input: msg)
                    passed += 1
                }
            } catch {
                failed += 1
                errors.append(BatchError(
                    messageIndex: index,
                    description: error.localizedDescription,
                    location: nil
                ))
            }
        }

        let duration = Date().timeIntervalSince(start)

        return BatchReport(
            totalMessages: messages.count,
            processed: processed,
            passed: passed,
            failed: failed,
            errors: errors,
            duration: duration
        )
    }

    /// Splits content into individual messages by looking for MSH segment headers
    func splitMessages(_ content: String) -> [String] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\r")
            .replacingOccurrences(of: "\n", with: "\r")

        var messages: [String] = []
        var current = ""

        for segment in normalized.split(separator: "\r", omittingEmptySubsequences: true) {
            let seg = String(segment)
            if seg.hasPrefix("MSH") && !current.isEmpty {
                messages.append(current)
                current = ""
            }
            if !current.isEmpty {
                current += "\r"
            }
            current += seg
        }
        if !current.isEmpty {
            messages.append(current)
        }
        return messages
    }
}

/// Report produced by `BatchProcessorCLI`
public struct BatchReport: Sendable {
    /// Total number of messages found
    public let totalMessages: Int
    /// Number of messages processed
    public let processed: Int
    /// Number of messages that passed the operation
    public let passed: Int
    /// Number of messages that failed the operation
    public let failed: Int
    /// Errors encountered during processing
    public let errors: [BatchError]
    /// Total processing duration in seconds
    public let duration: TimeInterval

    public init(
        totalMessages: Int,
        processed: Int,
        passed: Int,
        failed: Int,
        errors: [BatchError],
        duration: TimeInterval
    ) {
        self.totalMessages = totalMessages
        self.processed = processed
        self.passed = passed
        self.failed = failed
        self.errors = errors
        self.duration = duration
    }
}

/// A single error from batch processing
public struct BatchError: Sendable {
    /// Index of the message in the batch (0-based)
    public let messageIndex: Int
    /// Description of the error
    public let description: String
    /// Location in the message
    public let location: String?

    public init(messageIndex: Int, description: String, location: String?) {
        self.messageIndex = messageIndex
        self.description = description
        self.location = location
    }
}

// MARK: - CLI Output Formatter

/// Formats CLI tool reports as text or JSON for display
public struct CLIOutputFormatter: Sendable {

    /// Creates a new output formatter
    public init() {}

    /// Formats a `ValidationReport` as human-readable text
    /// - Parameter report: The validation report
    /// - Returns: Formatted text
    public func formatText(_ report: ValidationReport) -> String {
        var lines: [String] = []
        lines.append("=== Validation Report ===")
        lines.append("Status: \(report.isValid ? "VALID" : "INVALID")")
        lines.append("Message Type: \(report.messageType.isEmpty ? "Unknown" : report.messageType)")
        lines.append("Version: \(report.version.isEmpty ? "Unknown" : report.version)")
        lines.append("Segments: \(report.segmentCount)")
        if !report.errors.isEmpty {
            lines.append("Errors (\(report.errors.count)):")
            for err in report.errors {
                lines.append("  ✗ [\(err.location)] \(err.description)")
            }
        }
        if !report.warnings.isEmpty {
            lines.append("Warnings (\(report.warnings.count)):")
            for w in report.warnings {
                lines.append("  ⚠ [\(w.location)] \(w.description)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Formats a `ValidationReport` as JSON
    /// - Parameter report: The validation report
    /// - Returns: JSON string
    public func formatJSON(_ report: ValidationReport) -> String {
        let errorsJSON = report.errors.map { e in
            "    {\"location\": \"\(e.location)\", \"description\": \"\(jsonEscape(e.description))\"}"
        }.joined(separator: ",\n")
        let warningsJSON = report.warnings.map { w in
            "    {\"location\": \"\(w.location)\", \"description\": \"\(jsonEscape(w.description))\"}"
        }.joined(separator: ",\n")
        return """
        {
          "isValid": \(report.isValid),
          "messageType": "\(report.messageType)",
          "version": "\(report.version)",
          "segmentCount": \(report.segmentCount),
          "errors": [
        \(errorsJSON)
          ],
          "warnings": [
        \(warningsJSON)
          ]
        }
        """
    }

    /// Formats a `CLIConformanceReport` as human-readable text
    /// - Parameter report: The conformance report
    /// - Returns: Formatted text
    public func formatText(_ report: CLIConformanceReport) -> String {
        var lines: [String] = []
        lines.append("=== Conformance Report ===")
        lines.append("Profile: \(report.profileName)")
        lines.append("Conformant: \(report.conformant ? "YES" : "NO")")
        lines.append("Score: \(report.score)/100")
        if !report.violations.isEmpty {
            lines.append("Violations (\(report.violations.count)):")
            for v in report.violations {
                lines.append("  ✗ [\(v.rule)] \(v.description)")
            }
        }
        if !report.warnings.isEmpty {
            lines.append("Warnings (\(report.warnings.count)):")
            for w in report.warnings {
                lines.append("  ⚠ [\(w.rule)] \(w.description)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Formats a `CLIConformanceReport` as JSON
    /// - Parameter report: The conformance report
    /// - Returns: JSON string
    public func formatJSON(_ report: CLIConformanceReport) -> String {
        let violationsJSON = report.violations.map { v in
            "    {\"rule\": \"\(jsonEscape(v.rule))\", \"description\": \"\(jsonEscape(v.description))\", \"severity\": \"\(v.severity.rawValue)\"}"
        }.joined(separator: ",\n")
        let warningsJSON = report.warnings.map { w in
            "    {\"rule\": \"\(jsonEscape(w.rule))\", \"description\": \"\(jsonEscape(w.description))\", \"severity\": \"\(w.severity.rawValue)\"}"
        }.joined(separator: ",\n")
        return """
        {
          "conformant": \(report.conformant),
          "profileName": "\(report.profileName)",
          "score": \(report.score),
          "violations": [
        \(violationsJSON)
          ],
          "warnings": [
        \(warningsJSON)
          ]
        }
        """
    }

    /// Formats a `BatchReport` as human-readable text
    /// - Parameter report: The batch report
    /// - Returns: Formatted text
    public func formatText(_ report: BatchReport) -> String {
        var lines: [String] = []
        lines.append("=== Batch Report ===")
        lines.append("Total Messages: \(report.totalMessages)")
        lines.append("Processed: \(report.processed)")
        lines.append("Passed: \(report.passed)")
        lines.append("Failed: \(report.failed)")
        lines.append("Duration: \(String(format: "%.3f", report.duration))s")
        if !report.errors.isEmpty {
            lines.append("Errors (\(report.errors.count)):")
            for e in report.errors {
                let loc = e.location.map { " [\($0)]" } ?? ""
                lines.append("  ✗ Message \(e.messageIndex + 1)\(loc): \(e.description)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Formats a `BatchReport` as JSON
    /// - Parameter report: The batch report
    /// - Returns: JSON string
    public func formatJSON(_ report: BatchReport) -> String {
        let errorsJSON = report.errors.map { e in
            "    {\"messageIndex\": \(e.messageIndex), \"description\": \"\(jsonEscape(e.description))\", \"location\": \(e.location.map { "\"\($0)\"" } ?? "null")}"
        }.joined(separator: ",\n")
        return """
        {
          "totalMessages": \(report.totalMessages),
          "processed": \(report.processed),
          "passed": \(report.passed),
          "failed": \(report.failed),
          "duration": \(String(format: "%.3f", report.duration)),
          "errors": [
        \(errorsJSON)
          ]
        }
        """
    }

    /// Formats a `ConnectionTestResult` as human-readable text
    /// - Parameter result: The connection test result
    /// - Returns: Formatted text
    public func formatText(_ result: ConnectionTestResult) -> String {
        var lines: [String] = []
        lines.append("=== Connection Test ===")
        lines.append("Reachable: \(result.reachable ? "YES" : "NO")")
        lines.append("Response Time: \(String(format: "%.3f", result.responseTime))s")
        lines.append("TLS Available: \(result.tlsAvailable ? "YES" : "NO")")
        return lines.joined(separator: "\n")
    }

    /// Formats a `NetworkTestResult` as human-readable text
    /// - Parameter result: The network test result
    /// - Returns: Formatted text
    public func formatText(_ result: NetworkTestResult) -> String {
        var lines: [String] = []
        lines.append("=== Network Test ===")
        lines.append("Success: \(result.success ? "YES" : "NO")")
        lines.append("Round Trip: \(String(format: "%.3f", result.roundTripTime))s")
        if let resp = result.responseMessage {
            lines.append("Response: \(resp)")
        }
        return lines.joined(separator: "\n")
    }

    /// Escapes a string for safe JSON embedding
    func jsonEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

// MARK: - Private Helpers

extension Character {
    /// Whether this character is an uppercase ASCII letter
    var isUpperCase: Bool {
        self >= "A" && self <= "Z"
    }
}
