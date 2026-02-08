/// String interning utilities for HL7 v2.x performance optimization
///
/// Provides thread-safe string interning for commonly used segment identifiers
/// and field values to reduce memory allocations and improve parsing performance.

import Foundation
import HL7Core

// MARK: - String Interning

/// Thread-safe string interning actor for common HL7 v2.x strings
///
/// String interning reduces memory usage by storing only one copy of each
/// unique string. This is particularly effective for segment IDs and common
/// field values that appear repeatedly in HL7 messages.
public actor StringInterner {
    private var internedStrings: [String: String]
    private var hitCount: Int
    private var missCount: Int
    
    /// Creates a new string interner
    public init() {
        self.internedStrings = [:]
        self.hitCount = 0
        self.missCount = 0
    }
    
    /// Interns a string, returning the canonical copy
    /// - Parameter string: The string to intern
    /// - Returns: The interned string (may be same instance or canonical copy)
    public func intern(_ string: String) -> String {
        if let existing = internedStrings[string] {
            hitCount += 1
            return existing
        } else {
            internedStrings[string] = string
            missCount += 1
            return string
        }
    }
    
    /// Gets statistics about interning performance
    public func statistics() -> InternStatistics {
        InternStatistics(
            internedCount: internedStrings.count,
            hitCount: hitCount,
            missCount: missCount
        )
    }
    
    /// Clears all interned strings and resets statistics
    public func clear() {
        internedStrings.removeAll()
        hitCount = 0
        missCount = 0
    }
}

/// Statistics about string interning performance
public struct InternStatistics: Sendable {
    /// Number of unique strings interned
    public let internedCount: Int
    /// Number of cache hits
    public let hitCount: Int
    /// Number of cache misses
    public let missCount: Int
    
    /// Hit rate (0.0 to 1.0)
    public var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0.0 }
        return Double(hitCount) / Double(total)
    }
}

// MARK: - Pre-interned Segment IDs

/// Pre-interned segment identifiers for common HL7 v2.x segments
///
/// Using pre-allocated constant strings for common segment IDs avoids
/// repeated allocations and enables efficient string comparison.
public enum InternedSegmentID {
    /// Common segment IDs as pre-allocated constants
    public static let MSH = "MSH"
    public static let EVN = "EVN"
    public static let PID = "PID"
    public static let PD1 = "PD1"
    public static let NK1 = "NK1"
    public static let PV1 = "PV1"
    public static let PV2 = "PV2"
    public static let OBR = "OBR"
    public static let OBX = "OBX"
    public static let ORC = "ORC"
    public static let RXA = "RXA"
    public static let RXE = "RXE"
    public static let RXO = "RXO"
    public static let RXR = "RXR"
    public static let DG1 = "DG1"
    public static let PR1 = "PR1"
    public static let GT1 = "GT1"
    public static let IN1 = "IN1"
    public static let IN2 = "IN2"
    public static let IN3 = "IN3"
    public static let AL1 = "AL1"
    public static let ACC = "ACC"
    public static let AIG = "AIG"
    public static let AIL = "AIL"
    public static let AIP = "AIP"
    public static let AIS = "AIS"
    public static let BHS = "BHS"
    public static let BTS = "BTS"
    public static let FHS = "FHS"
    public static let FTS = "FTS"
    public static let DSC = "DSC"
    public static let DSP = "DSP"
    public static let ERR = "ERR"
    public static let ERQ = "ERQ"
    public static let MFI = "MFI"
    public static let MFE = "MFE"
    public static let MSA = "MSA"
    public static let QAK = "QAK"
    public static let QPD = "QPD"
    public static let QRD = "QRD"
    public static let QRF = "QRF"
    public static let RGS = "RGS"
    public static let SCH = "SCH"
    public static let TXA = "TXA"
    public static let NTE = "NTE"
    public static let ROL = "ROL"
    public static let SPM = "SPM"
    public static let SAC = "SAC"
    public static let TQ1 = "TQ1"
    public static let TQ2 = "TQ2"
    public static let SFT = "SFT"
    public static let UAC = "UAC"
    public static let STF = "STF"
    public static let ARQ = "ARQ"
    public static let APR = "APR"
    
    /// Lookup table for segment ID interning
    private static let lookupTable: [String: String] = [
        "MSH": MSH, "EVN": EVN, "PID": PID, "PD1": PD1, "NK1": NK1,
        "PV1": PV1, "PV2": PV2, "OBR": OBR, "OBX": OBX, "ORC": ORC,
        "RXA": RXA, "RXE": RXE, "RXO": RXO, "RXR": RXR, "DG1": DG1,
        "PR1": PR1, "GT1": GT1, "IN1": IN1, "IN2": IN2, "IN3": IN3,
        "AL1": AL1, "ACC": ACC, "AIG": AIG, "AIL": AIL, "AIP": AIP,
        "AIS": AIS, "BHS": BHS, "BTS": BTS, "FHS": FHS, "FTS": FTS,
        "DSC": DSC, "DSP": DSP, "ERR": ERR, "ERQ": ERQ, "MFI": MFI,
        "MFE": MFE, "MSA": MSA, "QAK": QAK, "QPD": QPD, "QRD": QRD,
        "QRF": QRF, "RGS": RGS, "SCH": SCH, "TXA": TXA, "NTE": NTE,
        "ROL": ROL, "SPM": SPM, "SAC": SAC, "TQ1": TQ1, "TQ2": TQ2,
        "SFT": SFT, "UAC": UAC, "STF": STF, "ARQ": ARQ, "APR": APR
    ]
    
    /// Returns the interned version of a segment ID if it's a common segment
    /// - Parameter segmentID: The segment ID to intern
    /// - Returns: Interned segment ID, or the original if not in the common set
    public static func intern(_ segmentID: String) -> String {
        return lookupTable[segmentID] ?? segmentID
    }
    
    /// Checks if a segment ID is a well-known common segment
    /// - Parameter segmentID: The segment ID to check
    /// - Returns: true if the segment is in the common set
    public static func isCommon(_ segmentID: String) -> Bool {
        return lookupTable[segmentID] != nil
    }
}

// MARK: - Global String Interner

/// Shared string interner for the HL7v2Kit module
///
/// This global interner can be used across the module for interning
/// segment IDs and common field values. It's particularly useful for
/// custom segments and field values that aren't pre-interned.
public let sharedInterner = StringInterner()
