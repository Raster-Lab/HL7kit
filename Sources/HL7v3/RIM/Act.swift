import HL7Core

/// Base class for HL7 v3 RIM Act hierarchy.
///
/// An Act represents an intentional action — an entry in a patient record, a clinical
/// observation, a procedure, a substance administration, etc.
public struct Act: Sendable, Equatable {
    /// The unique identifier for this act.
    public var id: InstanceIdentifier?
    /// The type code classifying this act.
    public var classCode: String
    /// The mood of the act (event, intent, request, etc.).
    public var moodCode: String
    /// A coded value describing the act.
    public var code: CodedValue?
    /// The status of the act.
    public var statusCode: String?
    /// The clinically relevant time.
    public var effectiveTime: String?
    /// Free-text description.
    public var text: String?

    public init(
        id: InstanceIdentifier? = nil,
        classCode: String = "ACT",
        moodCode: String = "EVN",
        code: CodedValue? = nil,
        statusCode: String? = nil,
        effectiveTime: String? = nil,
        text: String? = nil
    ) {
        self.id = id
        self.classCode = classCode
        self.moodCode = moodCode
        self.code = code
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.text = text
    }
}
