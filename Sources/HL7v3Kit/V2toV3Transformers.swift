/// V2toV3Transformers.swift
/// Concrete implementations of v2.x to v3.x transformers
///
/// Provides transformers for common HL7 v2.x message types to CDA R2 documents.

import Foundation
import HL7Core

#if canImport(HL7v2Kit)
import HL7v2Kit
#endif

// MARK: - ADT to CDA Patient Summary Transformer

#if canImport(HL7v2Kit)

/// Transforms HL7 v2.x ADT messages to CDA R2 Patient Summary documents
public actor ADTToCDATransformer: Transformer {
    public typealias Source = ADTMessage
    public typealias Target = ClinicalDocument
    
    private let metricsBuilder = TransformationMetricsBuilder()
    
    public init() {}
    
    /// Transform an ADT message to a CDA patient summary document
    public func transform(
        _ source: ADTMessage,
        context: TransformationContext
    ) async throws -> TransformationResult<ClinicalDocument> {
        
        await metricsBuilder.start()
        
        var warnings: [String] = []
        var info: [String] = []
        var errors: [TransformationError] = []
        
        // Validate source message if required
        if context.configuration.validationMode != .skip {
            do {
                try source.validate()
                await metricsBuilder.recordMappedField()
            } catch {
                let transformError = TransformationError(
                    code: "SOURCE_VALIDATION_FAILED",
                    message: "Source ADT message validation failed: \(error.localizedDescription)",
                    severity: context.configuration.validationMode == .strict ? .error : .warning,
                    location: "ADT"
                )
                errors.append(transformError)
                
                if context.configuration.validationMode == .strict {
                    let metrics = await metricsBuilder.build()
                    return .failure(errors: errors, warnings: warnings, info: info, metrics: metrics)
                }
                warnings.append(transformError.message)
            }
        }
        
        // Extract patient data from ADT message
        guard let pidSegment = source.patientSegment else {
            errors.append(TransformationError(
                code: "MISSING_PID",
                message: "ADT message missing required PID segment",
                location: "PID"
            ))
            let metrics = await metricsBuilder.build()
            return .failure(errors: errors, warnings: warnings, info: info, metrics: metrics)
        }
        
        // Build CDA document
        do {
            let document = try await buildCDAFromADT(
                source: source,
                pidSegment: pidSegment,
                context: context
            )
            
            info.append("Successfully transformed ADT message (trigger: \(source.triggerEvent)) to CDA Patient Summary")
            
            let metrics = await metricsBuilder.build()
            return .success(document, warnings: warnings, info: info, metrics: metrics)
            
        } catch {
            errors.append(TransformationError(
                code: "CDA_CREATION_FAILED",
                message: "Failed to create CDA document: \(error.localizedDescription)",
                location: "ClinicalDocument"
            ))
            let metrics = await metricsBuilder.build()
            return .failure(errors: errors, warnings: warnings, info: info, metrics: metrics)
        }
    }
    
    /// Build a CDA document from ADT message components
    private func buildCDAFromADT(
        source: ADTMessage,
        pidSegment: BaseSegment,
        context: TransformationContext
    ) async throws -> ClinicalDocument {
        
        // Create patient identifier from PID-3
        let patientId = pidSegment[2].value.value.raw
        await metricsBuilder.recordMappedField()
        
        // Extract patient name from PID-5
        let patientNameField = pidSegment[4]
        let familyName = patientNameField[0].value.raw  // Family name
        let givenName = patientNameField[1].value.raw   // Given name
        await metricsBuilder.recordMappedField()
        
        // Extract date of birth from PID-7
        let dobString = pidSegment[6].value.value.raw
        await metricsBuilder.recordMappedField()
        
        // Extract administrative sex from PID-8
        let sexCode = pidSegment[7].value.value.raw
        await metricsBuilder.recordMappedField()
        
        // Create RecordTarget (patient)
        let patientName = EN(
            parts: [
                EN.NamePart(value: familyName, type: .family),
                EN.NamePart(value: givenName, type: .given),
            ],
            use: .legal
        )
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let birthDate = dateFormatter.date(from: dobString) ?? Date()
        
        let patientEntity = Patient(
            name: [patientName],
            administrativeGenderCode: CD(
                code: mapGenderCode(sexCode),
                codeSystem: "2.16.840.1.113883.5.1",
                codeSystemName: "AdministrativeGender",
                displayName: nil
            ),
            birthTime: TS(value: birthDate)
        )
        
        let patientRole = PatientRole(
            id: [II(root: "2.16.840.1.113883.19.5", extension: patientId)],
            patient: patientEntity
        )
        
        let recordTarget = RecordTarget(
            patientRole: patientRole
        )
        
        // Create Author (use system/facility from MSH)
        let msh = source.message.messageHeader
        let facilityName = msh[3].value.value.raw
        await metricsBuilder.recordMappedField()
        
        let authorPerson = Person(
            name: [EN(parts: [EN.NamePart(value: facilityName, type: .given)], use: .legal)]
        )
        
        let assignedAuthor = AssignedAuthor(
            id: [II(root: "2.16.840.1.113883.19.5", extension: "AUTO")],
            code: nil,
            addr: nil,
            telecom: nil,
            assignedPerson: authorPerson,
            representedOrganization: nil
        )
        
        let author = Author(
            time: TS(value: Date()),
            assignedAuthor: assignedAuthor
        )
        
        // Create Custodian
        let custodianOrganization = CustodianOrganization(
            id: [II(root: "2.16.840.1.113883.19.5")],
            name: EN(parts: [EN.NamePart(value: facilityName, type: .given)])
        )
        
        let assignedCustodian = AssignedCustodian(
            representedCustodianOrganization: custodianOrganization
        )
        
        let custodian = Custodian(
            assignedCustodian: assignedCustodian
        )
        
        // Create document body with a simple section
        let section = Section(
            id: II(root: UUID().uuidString),
            code: CD(
                code: "11535-2",
                codeSystem: "2.16.840.1.113883.6.1",
                codeSystemName: "LOINC",
                displayName: "Hospital Discharge Diagnosis"
            ),
            title: .value("Admission/Transfer/Discharge Summary")
        )
        
        let structuredBody = StructuredBody(
            component: [
                BodyComponent(section: section)
            ]
        )
        
        let component = DocumentComponent(
            body: .structured(structuredBody)
        )
        
        // Create ClinicalDocument
        let document = ClinicalDocument(
            realmCode: [CD(code: "US", codeSystem: "2.16.840.1.113883.5.1114", codeSystemName: "RealmCode", displayName: nil)],
            typeId: II(root: "2.16.840.1.113883.1.3", extension: "POCD_HD000040"),
            templateId: [II(root: "2.16.840.1.113883.10.20.22.1.1")],
            id: II(root: UUID().uuidString),
            code: CD(
                code: "34133-9",
                codeSystem: "2.16.840.1.113883.6.1",
                codeSystemName: "LOINC",
                displayName: "Summarization of Episode Note"
            ),
            title: .value("Patient Summary from ADT"),
            effectiveTime: TS(value: Date()),
            confidentialityCode: CD(
                code: "N",
                codeSystem: "2.16.840.1.113883.5.25",
                codeSystemName: "Confidentiality",
                displayName: "Normal"
            ),
            languageCode: CD(code: "en-US", codeSystem: nil, codeSystemName: nil, displayName: nil),
            setId: nil,
            versionNumber: nil,
            copyTime: nil,
            recordTarget: [recordTarget],
            author: [author],
            dataEnterer: nil,
            informant: nil,
            custodian: custodian,
            informationRecipient: nil,
            legalAuthenticator: nil,
            authenticator: nil,
            relatedDocument: nil,
            authorization: nil,
            component: component
        )
        
        return document
    }
    
    /// Map HL7 v2.x gender codes to CDA gender codes
    private func mapGenderCode(_ v2Code: String) -> String {
        switch v2Code.uppercased() {
        case "M": return "M"  // Male
        case "F": return "F"  // Female
        case "O": return "UN" // Other -> Undifferentiated
        case "U": return "UN" // Unknown -> Undifferentiated
        default: return "UN"
        }
    }
}

// MARK: - ORU to CDA Observation Report Transformer

/// Transforms HL7 v2.x ORU messages to CDA R2 Observation Report documents
public actor ORUToCDATransformer: Transformer {
    public typealias Source = ORUMessage
    public typealias Target = ClinicalDocument
    
    private let metricsBuilder = TransformationMetricsBuilder()
    
    public init() {}
    
    /// Transform an ORU message to a CDA observation report document
    public func transform(
        _ source: ORUMessage,
        context: TransformationContext
    ) async throws -> TransformationResult<ClinicalDocument> {
        
        await metricsBuilder.start()
        
        var warnings: [String] = []
        var info: [String] = []
        
        info.append("ORU to CDA transformation: \(source.observationSegments.count) observations found")
        
        // Note: This is a simplified implementation
        // A full implementation would map all OBX segments to CDA observations
        
        let metrics = await metricsBuilder.build()
        
        // For now, return a basic error indicating partial implementation
        let error = TransformationError(
            code: "NOT_FULLY_IMPLEMENTED",
            message: "ORU to CDA transformation is partially implemented",
            severity: .warning
        )
        
        return .failure(errors: [error], warnings: warnings, info: info, metrics: metrics)
    }
}

// MARK: - ORM to CDA Order Document Transformer

/// Transforms HL7 v2.x ORM messages to CDA R2 Order documents
public actor ORMToCDATransformer: Transformer {
    public typealias Source = ORMMessage
    public typealias Target = ClinicalDocument
    
    private let metricsBuilder = TransformationMetricsBuilder()
    
    public init() {}
    
    /// Transform an ORM message to a CDA order document
    public func transform(
        _ source: ORMMessage,
        context: TransformationContext
    ) async throws -> TransformationResult<ClinicalDocument> {
        
        await metricsBuilder.start()
        
        var warnings: [String] = []
        var info: [String] = []
        
        info.append("ORM to CDA transformation: Processing order message")
        
        // Note: This is a simplified implementation
        // A full implementation would map ORC and OBR segments to CDA orders
        
        let metrics = await metricsBuilder.build()
        
        // For now, return a basic error indicating partial implementation
        let error = TransformationError(
            code: "NOT_FULLY_IMPLEMENTED",
            message: "ORM to CDA transformation is partially implemented",
            severity: .warning
        )
        
        return .failure(errors: [error], warnings: warnings, info: info, metrics: metrics)
    }
}

#endif // canImport(HL7v2Kit)
