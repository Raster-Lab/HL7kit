/// Identifies the HL7 standard version family.
public enum HL7Version: String, Sendable, Equatable, Hashable {
    // HL7 v2.x versions
    case v21 = "2.1"
    case v22 = "2.2"
    case v23 = "2.3"
    case v231 = "2.3.1"
    case v24 = "2.4"
    case v25 = "2.5"
    case v251 = "2.5.1"
    case v26 = "2.6"
    case v27 = "2.7"
    case v271 = "2.7.1"
    case v28 = "2.8"
    case v281 = "2.8.1"
    case v282 = "2.8.2"

    // HL7 v3
    case v3 = "3.0"

    /// Whether this version belongs to the v2.x family.
    public var isV2: Bool {
        switch self {
        case .v3: return false
        default: return true
        }
    }
}
