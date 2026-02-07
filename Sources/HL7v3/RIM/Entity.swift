import HL7Core

/// A physical entity (person, place, organisation, device, material) in the RIM.
public struct Entity: Sendable, Equatable {
    /// The unique identifier.
    public var id: InstanceIdentifier?
    /// The class code (PSN, ORG, DEV, PLC, MAT, etc.).
    public var classCode: String
    /// The determiner code (INSTANCE, KIND).
    public var determinerCode: String
    /// A coded type for this entity.
    public var code: CodedValue?
    /// The name(s) of the entity.
    public var name: String?

    public init(
        id: InstanceIdentifier? = nil,
        classCode: String = "ENT",
        determinerCode: String = "INSTANCE",
        code: CodedValue? = nil,
        name: String? = nil
    ) {
        self.id = id
        self.classCode = classCode
        self.determinerCode = determinerCode
        self.code = code
        self.name = name
    }
}
