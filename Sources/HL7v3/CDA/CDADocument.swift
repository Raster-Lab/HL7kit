import HL7Core

/// A CDA R2 (Clinical Document Architecture Release 2) document model.
public struct CDADocument: Sendable, Equatable {
    /// The document type identifier.
    public var typeId: InstanceIdentifier?
    /// The document identifier.
    public var id: InstanceIdentifier?
    /// The document type code.
    public var code: CodedValue?
    /// The document title.
    public var title: String?
    /// The effective time of the document.
    public var effectiveTime: String?
    /// The confidentiality code.
    public var confidentialityCode: CodedValue?
    /// The language code.
    public var languageCode: String?

    /// The record target (patient).
    public var recordTarget: Entity?
    /// The document author.
    public var author: Entity?
    /// The custodian organization.
    public var custodian: Entity?

    /// The structured body sections.
    public var sections: [CDASection]

    public init(
        typeId: InstanceIdentifier? = nil,
        id: InstanceIdentifier? = nil,
        code: CodedValue? = nil,
        title: String? = nil,
        effectiveTime: String? = nil,
        confidentialityCode: CodedValue? = nil,
        languageCode: String? = nil,
        recordTarget: Entity? = nil,
        author: Entity? = nil,
        custodian: Entity? = nil,
        sections: [CDASection] = []
    ) {
        self.typeId = typeId
        self.id = id
        self.code = code
        self.title = title
        self.effectiveTime = effectiveTime
        self.confidentialityCode = confidentialityCode
        self.languageCode = languageCode
        self.recordTarget = recordTarget
        self.author = author
        self.custodian = custodian
        self.sections = sections
    }
}

/// A section within a CDA document body.
public struct CDASection: Sendable, Equatable {
    /// The section code.
    public var code: CodedValue?
    /// The section title.
    public var title: String?
    /// The narrative text (human-readable).
    public var text: String?

    public init(code: CodedValue? = nil, title: String? = nil, text: String? = nil) {
        self.code = code
        self.title = title
        self.text = text
    }
}
