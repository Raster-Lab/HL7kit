/// V3toV2Transformers.swift
/// Concrete implementations of v3.x to v2.x transformers
///
/// Provides transformers for CDA R2 documents to common HL7 v2.x message types.

import Foundation
import HL7Core

#if canImport(HL7v2Kit)
import HL7v2Kit
#endif

// MARK: - CDA to ADT Transformer

#if canImport(HL7v2Kit)

/// Transforms CDA R2 Patient Summary documents to HL7 v2.x ADT messages
public actor CDAToADTTransformer: Transformer {
    public typealias Source = ClinicalDocument
    public typealias Target = ADTMessage
    
    private let metricsBuilder = TransformationMetricsBuilder()
    
    public init() {}
    
    /// Transform a CDA patient summary to an ADT message
    public func transform(
        _ source: ClinicalDocument,
        context: TransformationContext
    ) async throws -> TransformationResult<ADTMessage> {
        
        await metricsBuilder.start()
        
        var warnings: [String] = []
        var info: [String] = []
        var errors: [TransformationError] = []
        
        // Extract patient from recordTarget
        guard let recordTarget = source.recordTarget.first else {
            errors.append(TransformationError(
                code: "MISSING_RECORD_TARGET",
                message: "CDA document missing required recordTarget",
                location: "recordTarget"
            ))
            let metrics = await metricsBuilder.build()
            return .failure(errors: errors, warnings: warnings, info: info, metrics: metrics)
        }
        
        let patient = recordTarget.patientRole
        
        // Build ADT message using MessageBuilder
        do {
            let messageBuilder = MessageBuilder()
            
            // Build MSH segment
            messageBuilder.startSegment("MSH")
                .setField(1, "|")  // Field separator
                .setField(2, "^~\\&")  // Encoding characters
                .setField(3, "CDACONV")  // Sending application
                .setField(4, "FACILITY")  // Sending facility
                .setField(5, "RECEIVING")  // Receiving application
                .setField(6, "RECEIVING")  // Receiving facility
                .setField(7, formatHL7DateTime(Date()))  // Message date/time
                .setField(8, "")  // Security
                .setField(9, "ADT^A08")  // Message type (update patient info)
                .setField(10, UUID().uuidString)  // Message control ID
                .setField(11, "P")  // Processing ID
                .setField(12, "2.5")  // Version
            await metricsBuilder.recordMappedField()
            
            // Build EVN segment
            messageBuilder.startSegment("EVN")
                .setField(1, "A08")  // Event type
                .setField(2, formatHL7DateTime(Date()))  // Event date/time
            await metricsBuilder.recordMappedField()
            
            // Build PID segment
            messageBuilder.startSegment("PID")
                .setField(1, "1")  // Set ID
            
            // Patient ID from CDA
            if let patientId = patient.id.first {
                let idValue = patientId.extension ?? patientId.root
                messageBuilder.setField(3, idValue)
                await metricsBuilder.recordMappedField()
            } else {
                warnings.append("No patient identifier found in CDA document")
                await metricsBuilder.recordUnmappedField()
            }
            
            // Patient name from CDA
            if let patientPerson = patient.patient,
               let name = patientPerson.name.first {
                
                var nameComponents: [String] = []
                
                // Family name
                if let family = name.family?.first {
                    nameComponents.append(family)
                } else {
                    nameComponents.append("")
                }
                
                // Given name
                if let given = name.given?.first {
                    nameComponents.append(given)
                }
                
                messageBuilder.setField(5, nameComponents.joined(separator: "^"))
                await metricsBuilder.recordMappedField()
            } else {
                warnings.append("No patient name found in CDA document")
                await metricsBuilder.recordUnmappedField()
            }
            
            // Date of birth
            if let patientPerson = patient.patient,
               let birthTime = patientPerson.birthTime {
                messageBuilder.setField(7, birthTime.value)
                await metricsBuilder.recordMappedField()
            } else {
                await metricsBuilder.recordUnmappedField()
            }
            
            // Administrative sex
            if let patientPerson = patient.patient,
               let genderCode = patientPerson.administrativeGenderCode {
                let v2Gender = mapGenderCodeToV2(genderCode.code)
                messageBuilder.setField(8, v2Gender)
                await metricsBuilder.recordMappedField()
            } else {
                await metricsBuilder.recordUnmappedField()
            }
            
            // Build PV1 segment (patient visit)
            messageBuilder.startSegment("PV1")
                .setField(1, "1")  // Set ID
                .setField(2, "O")  // Patient class (outpatient)
            await metricsBuilder.recordMappedField()
            
            // Build message
            let rawMessage = messageBuilder.build()
            let message = try HL7v2Message.parse(rawMessage)
            let adtMessage = try ADTMessage(message: message)
            
            info.append("Successfully transformed CDA Patient Summary to ADT^A08 message")
            
            let metrics = await metricsBuilder.build()
            return .success(adtMessage, warnings: warnings, info: info, metrics: metrics)
            
        } catch {
            errors.append(TransformationError(
                code: "ADT_CREATION_FAILED",
                message: "Failed to create ADT message: \(error.localizedDescription)",
                location: "ADTMessage"
            ))
            let metrics = await metricsBuilder.build()
            return .failure(errors: errors, warnings: warnings, info: info, metrics: metrics)
        }
    }
    
    /// Map CDA gender codes to HL7 v2.x gender codes
    private func mapGenderCodeToV2(_ cdaCode: String) -> String {
        switch cdaCode.uppercased() {
        case "M": return "M"   // Male
        case "F": return "F"   // Female
        case "UN": return "U"  // Undifferentiated -> Unknown
        default: return "U"
        }
    }
    
    /// Format a Date as HL7 v2.x datetime string (YYYYMMDDHHMMSS)
    private func formatHL7DateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

// MARK: - CDA to ORU Transformer

/// Transforms CDA R2 Observation Report documents to HL7 v2.x ORU messages
public actor CDAToORUTransformer: Transformer {
    public typealias Source = ClinicalDocument
    public typealias Target = ORUMessage
    
    private let metricsBuilder = TransformationMetricsBuilder()
    
    public init() {}
    
    /// Transform a CDA observation report to an ORU message
    public func transform(
        _ source: ClinicalDocument,
        context: TransformationContext
    ) async throws -> TransformationResult<ORUMessage> {
        
        await metricsBuilder.start()
        
        var warnings: [String] = []
        var info: [String] = []
        
        info.append("CDA to ORU transformation: Analyzing document structure")
        
        // Note: This is a simplified implementation
        // A full implementation would map all CDA observations to OBX segments
        
        let metrics = await metricsBuilder.build()
        
        // For now, return a basic error indicating partial implementation
        let error = TransformationError(
            code: "NOT_FULLY_IMPLEMENTED",
            message: "CDA to ORU transformation is partially implemented",
            severity: .warning
        )
        
        return .failure(errors: [error], warnings: warnings, info: info, metrics: metrics)
    }
}

#endif // canImport(HL7v2Kit)

// MARK: - Transformation Factory

/// Factory for creating transformers
public enum TransformerFactory {
    
    #if canImport(HL7v2Kit)
    
    /// Create a transformer for v2.x to v3.x
    public static func v2ToV3<Source, Target>(
        sourceType: Source.Type,
        targetType: Target.Type
    ) -> (any Transformer)? where Source: Sendable, Target: Sendable {
        
        switch (sourceType, targetType) {
        case (is ADTMessage.Type, is ClinicalDocument.Type):
            return ADTToCDATransformer()
        case (is ORUMessage.Type, is ClinicalDocument.Type):
            return ORUToCDATransformer()
        case (is ORMMessage.Type, is ClinicalDocument.Type):
            return ORMToCDATransformer()
        default:
            return nil
        }
    }
    
    /// Create a transformer for v3.x to v2.x
    public static func v3ToV2<Source, Target>(
        sourceType: Source.Type,
        targetType: Target.Type
    ) -> (any Transformer)? where Source: Sendable, Target: Sendable {
        
        switch (sourceType, targetType) {
        case (is ClinicalDocument.Type, is ADTMessage.Type):
            return CDAToADTTransformer()
        case (is ClinicalDocument.Type, is ORUMessage.Type):
            return CDAToORUTransformer()
        default:
            return nil
        }
    }
    
    #endif
}
