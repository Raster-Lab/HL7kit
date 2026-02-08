/// CDADocumentBuilder.swift
/// Fluent API for constructing CDA R2 Clinical Documents
///
/// This file provides a builder pattern for creating CDA documents with a fluent,
/// type-safe API that ensures required elements are present and properly structured.

import Foundation
import HL7Core

// MARK: - CDADocumentBuilder

/// Builder for constructing CDA R2 Clinical Documents with fluent API
///
/// Example usage:
/// ```swift
/// let document = try CDADocumentBuilder()
///     .withTitle("Progress Note")
///     .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Progress note")
///     .withEffectiveTime(Date())
///     .withConfidentiality("N")
///     .withRecordTarget(builder: { target in
///         target.withPatientId(root: "2.16.840.1.113883.19.5", extension: "12345")
///             .withPatientName(given: "John", family: "Doe")
///     })
///     .withAuthor(builder: { author in
///         author.withTime(Date())
///             .withAuthorId(root: "2.16.840.1.113883.19.5", extension: "999")
///             .withAuthorName(given: "Jane", family: "Smith")
///     })
///     .withCustodian(builder: { custodian in
///         custodian.withOrganizationId(root: "2.16.840.1.113883.19.5")
///             .withOrganizationName("Good Health Clinic")
///     })
///     .withStructuredBody(builder: { body in
///         body.addSection(builder: { section in
///             section.withTitle("Chief Complaint")
///                 .withCode(code: "10154-3", codeSystem: "2.16.840.1.113883.6.1")
///                 .withText("<paragraph>Patient reports headache.</paragraph>")
///         })
///     })
///     .build()
/// ```
public final class CDADocumentBuilder {
    // Required fields
    private let typeId: II
    private var templateIds: [II] = []
    private var id: II?
    private var code: CD?
    private var title: ST?
    private var effectiveTime: TS?
    private var confidentialityCode: CD?
    
    // Optional fields
    private var realmCodes: [CD] = []
    private var languageCode: CD?
    private var setId: II?
    private var versionNumber: INT?
    private var copyTime: TS?
    
    // Participants
    private var recordTargets: [RecordTarget] = []
    private var authors: [Author] = []
    private var dataEnterer: DataEnterer?
    private var informants: [Informant] = []
    private var custodian: Custodian?
    private var informationRecipients: [InformationRecipient] = []
    private var legalAuthenticator: LegalAuthenticator?
    private var authenticators: [Authenticator] = []
    private var relatedDocuments: [RelatedDocument] = []
    private var authorizations: [Authorization] = []
    
    // Body
    private var component: DocumentComponent?
    
    /// Creates a new CDA document builder with default CDA R2 type identifier
    public init() {
        // Default CDA R2 type identifier
        self.typeId = II(root: "2.16.840.1.113883.1.3", extension: "POCD_HD000040")
    }
    
    // MARK: - Basic Properties
    
    /// Sets the document identifier
    /// - Parameters:
    ///   - root: The OID identifying the assigning authority
    ///   - extension: The local identifier
    /// - Returns: Self for chaining
    public func withId(root: String, extension: String? = nil) -> Self {
        self.id = II(root: root, extension: `extension`)
        return self
    }
    
    /// Adds a template identifier
    /// - Parameters:
    ///   - root: The template OID
    ///   - extension: Optional template extension
    /// - Returns: Self for chaining
    public func withTemplateId(root: String, extension: String? = nil) -> Self {
        self.templateIds.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Sets the document code (type of clinical document)
    /// - Parameters:
    ///   - code: The code value (e.g., LOINC code)
    ///   - codeSystem: The code system OID
    ///   - codeSystemName: Optional name of the code system
    ///   - displayName: Human-readable display name
    /// - Returns: Self for chaining
    public func withDocumentCode(
        code: String,
        codeSystem: String,
        codeSystemName: String? = nil,
        displayName: String? = nil
    ) -> Self {
        self.code = CD(
            code: code,
            codeSystem: codeSystem,
            codeSystemName: codeSystemName,
            displayName: displayName
        )
        return self
    }
    
    /// Sets the document title
    /// - Parameter title: Human-readable title
    /// - Returns: Self for chaining
    public func withTitle(_ title: String) -> Self {
        self.title = .value(title)
        return self
    }
    
    /// Sets the effective time (creation time)
    /// - Parameter date: The document creation date
    /// - Returns: Self for chaining
    public func withEffectiveTime(_ date: Date) -> Self {
        self.effectiveTime = TS(value: date)
        return self
    }
    
    /// Sets the confidentiality code
    /// - Parameters:
    ///   - code: Confidentiality code (e.g., "N" for normal)
    ///   - codeSystem: Code system OID (defaults to HL7 Confidentiality)
    /// - Returns: Self for chaining
    public func withConfidentiality(
        _ code: String,
        codeSystem: String = "2.16.840.1.113883.5.25"
    ) -> Self {
        self.confidentialityCode = CD(code: code, codeSystem: codeSystem)
        return self
    }
    
    /// Sets the language code
    /// - Parameter code: Language code (e.g., "en-US")
    /// - Returns: Self for chaining
    public func withLanguage(_ code: String) -> Self {
        self.languageCode = CD(code: code)
        return self
    }
    
    /// Sets the realm code
    /// - Parameter code: Realm code (e.g., "US")
    /// - Returns: Self for chaining
    public func withRealmCode(_ code: String) -> Self {
        self.realmCodes.append(CD(code: code))
        return self
    }
    
    // MARK: - Participants
    
    /// Adds a record target (patient)
    /// - Parameter builder: Closure to configure the record target
    /// - Returns: Self for chaining
    public func withRecordTarget(
        builder: (RecordTargetBuilder) -> RecordTargetBuilder
    ) -> Self {
        let recordTargetBuilder = builder(RecordTargetBuilder())
        if let recordTarget = recordTargetBuilder.build() {
            self.recordTargets.append(recordTarget)
        }
        return self
    }
    
    /// Adds an author
    /// - Parameter builder: Closure to configure the author
    /// - Returns: Self for chaining
    public func withAuthor(
        builder: (AuthorBuilder) -> AuthorBuilder
    ) -> Self {
        let authorBuilder = builder(AuthorBuilder())
        if let author = authorBuilder.build() {
            self.authors.append(author)
        }
        return self
    }
    
    /// Sets the custodian (required)
    /// - Parameter builder: Closure to configure the custodian
    /// - Returns: Self for chaining
    public func withCustodian(
        builder: (CustodianBuilder) -> CustodianBuilder
    ) -> Self {
        let custodianBuilder = builder(CustodianBuilder())
        self.custodian = custodianBuilder.build()
        return self
    }
    
    /// Sets the legal authenticator
    /// - Parameter builder: Closure to configure the legal authenticator
    /// - Returns: Self for chaining
    public func withLegalAuthenticator(
        builder: (LegalAuthenticatorBuilder) -> LegalAuthenticatorBuilder
    ) -> Self {
        let authenticatorBuilder = builder(LegalAuthenticatorBuilder())
        self.legalAuthenticator = authenticatorBuilder.build()
        return self
    }
    
    // MARK: - Body
    
    /// Sets a structured body
    /// - Parameter builder: Closure to configure the structured body
    /// - Returns: Self for chaining
    public func withStructuredBody(
        builder: (StructuredBodyBuilder) -> StructuredBodyBuilder
    ) -> Self {
        let bodyBuilder = builder(StructuredBodyBuilder())
        self.component = bodyBuilder.build()
        return self
    }
    
    /// Sets a non-XML body
    /// - Parameter builder: Closure to configure the non-XML body
    /// - Returns: Self for chaining
    public func withNonXMLBody(
        builder: (NonXMLBodyBuilder) -> NonXMLBodyBuilder
    ) -> Self {
        let bodyBuilder = builder(NonXMLBodyBuilder())
        self.component = bodyBuilder.build()
        return self
    }
    
    // MARK: - Build
    
    /// Builds the CDA document
    /// - Returns: A configured ClinicalDocument
    /// - Throws: BuilderError if required fields are missing
    public func build() throws -> ClinicalDocument {
        // Validate required fields
        guard let id = self.id else {
            throw BuilderError.missingRequiredField("id")
        }
        guard let code = self.code else {
            throw BuilderError.missingRequiredField("code")
        }
        guard let effectiveTime = self.effectiveTime else {
            throw BuilderError.missingRequiredField("effectiveTime")
        }
        guard let confidentialityCode = self.confidentialityCode else {
            throw BuilderError.missingRequiredField("confidentialityCode")
        }
        guard !recordTargets.isEmpty else {
            throw BuilderError.missingRequiredField("recordTarget (at least one required)")
        }
        guard !authors.isEmpty else {
            throw BuilderError.missingRequiredField("author (at least one required)")
        }
        guard let custodian = self.custodian else {
            throw BuilderError.missingRequiredField("custodian")
        }
        guard let component = self.component else {
            throw BuilderError.missingRequiredField("component (body)")
        }
        
        return ClinicalDocument(
            realmCode: realmCodes.isEmpty ? nil : realmCodes,
            typeId: typeId,
            templateId: templateIds,
            id: id,
            code: code,
            title: title,
            effectiveTime: effectiveTime,
            confidentialityCode: confidentialityCode,
            languageCode: languageCode,
            setId: setId,
            versionNumber: versionNumber,
            copyTime: copyTime,
            recordTarget: recordTargets,
            author: authors,
            dataEnterer: dataEnterer,
            informant: informants.isEmpty ? nil : informants,
            custodian: custodian,
            informationRecipient: informationRecipients.isEmpty ? nil : informationRecipients,
            legalAuthenticator: legalAuthenticator,
            authenticator: authenticators.isEmpty ? nil : authenticators,
            relatedDocument: relatedDocuments.isEmpty ? nil : relatedDocuments,
            authorization: authorizations.isEmpty ? nil : authorizations,
            component: component
        )
    }
}

// MARK: - BuilderError

/// Errors that can occur during document building
public enum BuilderError: Error, CustomStringConvertible {
    case missingRequiredField(String)
    case invalidConfiguration(String)
    
    public var description: String {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}
