import HL7Core

/// A Role in the RIM — a competency of an entity playing in a particular scope.
public struct Role: Sendable, Equatable {
    /// The unique identifier.
    public var id: InstanceIdentifier?
    /// The class code (PAT, ASSIGNED, AGNT, etc.).
    public var classCode: String
    /// A coded type for this role.
    public var code: CodedValue?
    /// The entity playing this role.
    public var player: Entity?
    /// The entity scoping this role.
    public var scoper: Entity?

    public init(
        id: InstanceIdentifier? = nil,
        classCode: String = "ROL",
        code: CodedValue? = nil,
        player: Entity? = nil,
        scoper: Entity? = nil
    ) {
        self.id = id
        self.classCode = classCode
        self.code = code
        self.player = player
        self.scoper = scoper
    }
}
