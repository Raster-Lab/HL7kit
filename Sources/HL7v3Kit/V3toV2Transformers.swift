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
            // Extract patient info for PID segment fields
            var pidNameField = ""
            var pidDobField = ""
            var pidSexField = ""
            var pidIdField = ""
            
            // Patient ID from CDA
            if let patientId = patient.id.first {
                pidIdField = patientId.extension ?? patientId.root
                await metricsBuilder.recordMappedField()
            } else {
                warnings.append("No patient identifier found in CDA document")
                await metricsBuilder.recordUnmappedField()
            }
            
            // Patient name from CDA
            if let patientPerson = patient.patient,
               let name = patientPerson.name?.first {
                
                var nameComponents: [String] = []
                
                // Family name
                let familyParts = name.parts.filter { $0.type == .family }
                if let family = familyParts.first?.value {
                    nameComponents.append(family)
                } else {
                    nameComponents.append("")
                }
                
                // Given name
                let givenParts = name.parts.filter { $0.type == .given }
                if let given = givenParts.first?.value {
                    nameComponents.append(given)
                }
                
                pidNameField = nameComponents.joined(separator: "^")
                await metricsBuilder.recordMappedField()
            } else {
                warnings.append("No patient name found in CDA document")
                await metricsBuilder.recordUnmappedField()
            }
            
            // Date of birth
            if let patientPerson = patient.patient,
               let birthTime = patientPerson.birthTime,
               let birthDate = birthTime.value {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                pidDobField = formatter.string(from: birthDate)
                await metricsBuilder.recordMappedField()
            } else {
                await metricsBuilder.recordUnmappedField()
            }
            
            // Administrative sex
            if let patientPerson = patient.patient,
               let genderCode = patientPerson.administrativeGenderCode,
               let genderCodeValue = genderCode.code {
                pidSexField = mapGenderCodeToV2(genderCodeValue)
                await metricsBuilder.recordMappedField()
            } else {
                await metricsBuilder.recordUnmappedField()
            }
            
            let messageControlId = UUID().uuidString
            let dateTimeStr = formatHL7DateTime(Date())
            
            let message = try HL7v2MessageBuilder()
                .msh { msh in
                    msh.sendingApplication("CDACONV")
                        .sendingFacility("FACILITY")
                        .receivingApplication("RECEIVING")
                        .receivingFacility("RECEIVING")
                        .dateTime(dateTimeStr)
                        .messageType("ADT", triggerEvent: "A08")
                        .messageControlID(messageControlId)
                        .processingID("P")
                        .version("2.5")
                }
                .segment("EVN") { evn in
                    evn.field(1, value: "A08")
                        .field(2, value: dateTimeStr)
                }
                .segment("PID") { pid in
                    pid.field(1, value: "1")
                        .field(3, value: pidIdField)
                        .field(5, value: pidNameField)
                        .field(7, value: pidDobField)
                        .field(8, value: pidSexField)
                }
                .segment("PV1") { pv1 in
                    pv1.field(1, value: "1")
                        .field(2, value: "O")
                }
                .build()
            await metricsBuilder.recordMappedField()
            
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
