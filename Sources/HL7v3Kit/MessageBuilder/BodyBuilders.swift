/// BodyBuilders.swift
/// Fluent API builders for CDA document body components
///
/// This file provides builder patterns for creating CDA document body structures
/// (StructuredBody, NonXMLBody, Section, Entry) with fluent APIs.

import Foundation
import HL7Core

// MARK: - StructuredBodyBuilder

/// Builder for constructing StructuredBody with fluent API
public final class StructuredBodyBuilder {
    private var sections: [Section] = []
    
    public init() {}
    
    /// Adds a section to the structured body
    public func addSection(builder: (SectionBuilder) -> SectionBuilder) -> Self {
        let sectionBuilder = builder(SectionBuilder())
        if let section = sectionBuilder.build() {
            self.sections.append(section)
        }
        return self
    }
    
    /// Builds the DocumentComponent with structured body
    func build() -> DocumentComponent? {
        guard !sections.isEmpty else { return nil }
        
        let bodyComponents = sections.map { BodyComponent(section: $0) }
        let structuredBody = StructuredBody(component: bodyComponents)
        return DocumentComponent(body: .structured(structuredBody))
    }
}

// MARK: - NonXMLBodyBuilder

/// Builder for constructing NonXMLBody with fluent API
/// Note: NonXMLBody requires ED (EncapsulatedData) type which is not yet implemented
public final class NonXMLBodyBuilder {
    private var confidentialityCode: CD?
    private var languageCode: CD?
    
    public init() {}
    
    /// Sets confidentiality code
    public func withConfidentiality(code: String, codeSystem: String = "2.16.840.1.113883.5.25") -> Self {
        self.confidentialityCode = CD(code: code, codeSystem: codeSystem)
        return self
    }
    
    /// Sets language code
    public func withLanguage(code: String) -> Self {
        self.languageCode = CD(code: code)
        return self
    }
    
    /// Builds the DocumentComponent with non-XML body
    /// Note: This is a placeholder until ED type is fully implemented
    func build() -> DocumentComponent? {
        // NonXMLBody requires ED type which needs to be implemented
        // For now, return nil
        return nil
    }
}

// MARK: - SectionBuilder

/// Builder for constructing Section with fluent API
public final class SectionBuilder {
    private var templateIds: [II] = []
    private var id: II?
    private var code: CD?
    private var title: ST?
    private var text: Narrative?
    private var confidentialityCode: CD?
    private var languageCode: CD?
    private var entries: [Entry] = []
    private var sections: [Section] = []
    
    public init() {}
    
    /// Adds a template identifier
    public func withTemplateId(root: String, extension: String? = nil) -> Self {
        self.templateIds.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Sets section identifier
    public func withId(root: String, extension: String? = nil) -> Self {
        self.id = II(root: root, extension: `extension`)
        return self
    }
    
    /// Sets section code
    public func withCode(
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
    
    /// Sets section title
    public func withTitle(_ title: String) -> Self {
        self.title = .value(title)
        return self
    }
    
    /// Sets section narrative text
    public func withText(_ text: String) -> Self {
        self.text = Narrative.text(text)
        return self
    }
    
    /// Sets confidentiality code
    public func withConfidentiality(code: String, codeSystem: String = "2.16.840.1.113883.5.25") -> Self {
        self.confidentialityCode = CD(code: code, codeSystem: codeSystem)
        return self
    }
    
    /// Sets language code
    public func withLanguage(code: String) -> Self {
        self.languageCode = CD(code: code)
        return self
    }
    
    /// Adds an observation entry
    public func addObservation(builder: (ObservationBuilder) -> ObservationBuilder) -> Self {
        let observationBuilder = builder(ObservationBuilder())
        if let observation = observationBuilder.build() {
            self.entries.append(Entry(clinicalStatement: .observation(observation)))
        }
        return self
    }
    
    /// Adds a procedure entry
    public func addProcedure(builder: (ProcedureBuilder) -> ProcedureBuilder) -> Self {
        let procedureBuilder = builder(ProcedureBuilder())
        if let procedure = procedureBuilder.build() {
            self.entries.append(Entry(clinicalStatement: .procedure(procedure)))
        }
        return self
    }
    
    /// Adds a substance administration entry
    public func addSubstanceAdministration(builder: (SubstanceAdministrationBuilder) -> SubstanceAdministrationBuilder) -> Self {
        let builder = builder(SubstanceAdministrationBuilder())
        if let substanceAdmin = builder.build() {
            self.entries.append(Entry(clinicalStatement: .substanceAdministration(substanceAdmin)))
        }
        return self
    }
    
    /// Adds a subsection
    public func addSubsection(builder: (SectionBuilder) -> SectionBuilder) -> Self {
        let sectionBuilder = builder(SectionBuilder())
        if let section = sectionBuilder.build() {
            self.sections.append(section)
        }
        return self
    }
    
    /// Builds the Section
    func build() -> Section? {
        // At least title or code should be present
        guard title != nil || code != nil else { return nil }
        
        let sectionComponents = sections.isEmpty ? nil : sections.map { SectionComponent(section: $0) }
        
        return Section(
            templateId: templateIds.isEmpty ? nil : templateIds,
            id: id,
            code: code,
            title: title,
            text: text,
            confidentialityCode: confidentialityCode,
            languageCode: languageCode,
            entry: entries.isEmpty ? nil : entries,
            component: sectionComponents
        )
    }
}

// MARK: - ObservationBuilder

/// Builder for constructing ClinicalObservation entry with fluent API
public final class ObservationBuilder {
    private var templateIds: [II] = []
    private var id: [II] = []
    private var code: CD?
    private var statusCode: ActStatusCode?
    private var effectiveTime: IVL<TS>?
    private var value: ObservationValue?
    
    public init() {}
    
    /// Adds a template identifier
    public func withTemplateId(root: String, extension: String? = nil) -> Self {
        self.templateIds.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Adds an observation identifier
    public func withId(root: String, extension: String? = nil) -> Self {
        self.id.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Sets observation code
    public func withCode(
        code: String,
        codeSystem: String,
        displayName: String? = nil
    ) -> Self {
        self.code = CD(code: code, codeSystem: codeSystem, displayName: displayName)
        return self
    }
    
    /// Sets status code
    public func withStatus(_ status: ActStatusCode = .completed) -> Self {
        self.statusCode = status
        return self
    }
    
    /// Sets effective time
    public func withEffectiveTime(_ date: Date) -> Self {
        let ts = TS(value: date)
        self.effectiveTime = IVL(low: ts, high: ts)
        return self
    }
    
    /// Sets a coded value
    public func withCodedValue(
        code: String,
        codeSystem: String,
        displayName: String? = nil
    ) -> Self {
        let cd = CD(code: code, codeSystem: codeSystem, displayName: displayName)
        self.value = .codedValue(cd)
        return self
    }
    
    /// Sets a string value
    public func withStringValue(_ value: String) -> Self {
        self.value = .stringValue(.value(value))
        return self
    }
    
    /// Sets a physical quantity value
    public func withQuantityValue(value: Double, unit: String) -> Self {
        self.value = .physicalQuantity(PQ(value: value, unit: unit))
        return self
    }
    
    /// Builds the ClinicalObservation
    func build() -> ClinicalObservation? {
        guard let code = self.code else { return nil }
        
        return ClinicalObservation(
            moodCode: .event,
            id: id.isEmpty ? nil : id,
            code: code,
            statusCode: statusCode ?? .completed,
            effectiveTime: effectiveTime,
            value: value.map { [$0] }
        )
    }
}

// MARK: - ProcedureBuilder

/// Builder for constructing Procedure entry with fluent API
public final class ProcedureBuilder {
    private var templateIds: [II] = []
    private var id: [II] = []
    private var code: CD?
    private var statusCode: ActStatusCode?
    private var effectiveTime: IVL<TS>?
    
    public init() {}
    
    /// Adds a template identifier
    public func withTemplateId(root: String, extension: String? = nil) -> Self {
        self.templateIds.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Adds a procedure identifier
    public func withId(root: String, extension: String? = nil) -> Self {
        self.id.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Sets procedure code
    public func withCode(
        code: String,
        codeSystem: String,
        displayName: String? = nil
    ) -> Self {
        self.code = CD(code: code, codeSystem: codeSystem, displayName: displayName)
        return self
    }
    
    /// Sets status code
    public func withStatus(_ status: ActStatusCode = .completed) -> Self {
        self.statusCode = status
        return self
    }
    
    /// Sets effective time
    public func withEffectiveTime(_ date: Date) -> Self {
        let ts = TS(value: date)
        self.effectiveTime = IVL(low: ts, high: ts)
        return self
    }
    
    /// Builds the Procedure
    func build() -> Procedure? {
        guard let code = self.code else { return nil }
        
        return Procedure(
            moodCode: .event,
            id: id.isEmpty ? nil : id,
            code: code,
            statusCode: statusCode,
            effectiveTime: effectiveTime
        )
    }
}

// MARK: - SubstanceAdministrationBuilder

/// Builder for constructing SubstanceAdministration entry with fluent API
public final class SubstanceAdministrationBuilder {
    private var templateIds: [II] = []
    private var id: [II] = []
    private var statusCode: ActStatusCode?
    private var effectiveTime: IVL<TS>?
    private var doseQuantity: IVL<PQ>?
    private var consumable: Consumable?
    
    public init() {}
    
    /// Adds a template identifier
    public func withTemplateId(root: String, extension: String? = nil) -> Self {
        self.templateIds.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Adds an identifier
    public func withId(root: String, extension: String? = nil) -> Self {
        self.id.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Sets status code
    public func withStatus(_ status: ActStatusCode = .completed) -> Self {
        self.statusCode = status
        return self
    }
    
    /// Sets effective time
    public func withEffectiveTime(_ date: Date) -> Self {
        let ts = TS(value: date)
        self.effectiveTime = IVL(low: ts, high: ts)
        return self
    }
    
    /// Sets dose quantity
    public func withDose(value: Double, unit: String) -> Self {
        let pq = PQ(value: value, unit: unit)
        self.doseQuantity = IVL(low: pq, high: pq)
        return self
    }
    
    /// Sets consumable (medication)
    public func withMedication(
        code: String,
        codeSystem: String,
        displayName: String? = nil
    ) -> Self {
        let manufacturedProduct = ManufacturedProduct(
            manufacturedMaterial: ManufacturedMaterial(
                code: CD(code: code, codeSystem: codeSystem, displayName: displayName)
            )
        )
        self.consumable = Consumable(manufacturedProduct: manufacturedProduct)
        return self
    }
    
    /// Builds the SubstanceAdministration
    func build() -> SubstanceAdministration? {
        guard let consumable = self.consumable else { return nil }
        
        return SubstanceAdministration(
            moodCode: .event,
            id: id.isEmpty ? nil : id,
            statusCode: statusCode,
            effectiveTime: effectiveTime.map { [$0] },
            doseQuantity: doseQuantity,
            consumable: consumable
        )
    }
}
