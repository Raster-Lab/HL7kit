/// ParticipantBuilders.swift
/// Fluent API builders for CDA document participants
///
/// This file provides builder patterns for creating CDA document participants
/// (RecordTarget, Author, Custodian, etc.) with fluent, type-safe APIs.

import Foundation
import HL7Core

// MARK: - RecordTargetBuilder

/// Builder for constructing RecordTarget (patient) with fluent API
public final class RecordTargetBuilder {
    private var patientIds: [II] = []
    private var addresses: [AD] = []
    private var telecoms: [TEL] = []
    private var patientNames: [EN] = []
    private var administrativeGenderCode: CD?
    private var birthTime: TS?
    private var providerOrganization: Organization?
    
    public init() {}
    
    /// Adds a patient identifier
    public func withPatientId(root: String, extension: String? = nil) -> Self {
        self.patientIds.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Adds a patient name
    public func withPatientName(given: String, family: String, prefix: String? = nil, suffix: String? = nil) -> Self {
        var parts: [EN.NamePart] = []
        if let prefix = prefix {
            parts.append(EN.NamePart(value: prefix, type: .prefix))
        }
        parts.append(EN.NamePart(value: given, type: .given))
        parts.append(EN.NamePart(value: family, type: .family))
        if let suffix = suffix {
            parts.append(EN.NamePart(value: suffix, type: .suffix))
        }
        self.patientNames.append(EN(parts: parts))
        return self
    }
    
    /// Sets patient gender
    public func withGender(code: String, codeSystem: String = "2.16.840.1.113883.5.1") -> Self {
        self.administrativeGenderCode = CD(code: code, codeSystem: codeSystem)
        return self
    }
    
    /// Sets patient birth date
    public func withBirthDate(_ date: Date) -> Self {
        self.birthTime = TS(value: date)
        return self
    }
    
    /// Adds patient address
    public func withAddress(
        street: String? = nil,
        city: String? = nil,
        state: String? = nil,
        postalCode: String? = nil,
        country: String? = nil
    ) -> Self {
        var parts: [AD.AddressPart] = []
        if let street = street {
            parts.append(AD.AddressPart(value: street, type: .streetAddressLine))
        }
        if let city = city {
            parts.append(AD.AddressPart(value: city, type: .city))
        }
        if let state = state {
            parts.append(AD.AddressPart(value: state, type: .state))
        }
        if let postalCode = postalCode {
            parts.append(AD.AddressPart(value: postalCode, type: .postalCode))
        }
        if let country = country {
            parts.append(AD.AddressPart(value: country, type: .country))
        }
        self.addresses.append(AD(parts: parts, use: .home))
        return self
    }
    
    /// Adds patient telecom
    public func withTelecom(value: String, use: TEL.TelecommunicationUse? = nil) -> Self {
        self.telecoms.append(TEL(value: value, use: use))
        return self
    }
    
    /// Sets provider organization
    public func withProviderOrganization(
        id: String,
        idRoot: String,
        name: String
    ) -> Self {
        let namePart = EN.NamePart(value: name, type: .given)
        self.providerOrganization = Organization(
            id: [II(root: idRoot, extension: id)],
            name: [EN(parts: [namePart])]
        )
        return self
    }
    
    /// Builds the RecordTarget
    func build() -> RecordTarget? {
        guard !patientIds.isEmpty else { return nil }
        
        let patient = !patientNames.isEmpty || administrativeGenderCode != nil || birthTime != nil
            ? Patient(
                name: patientNames.isEmpty ? nil : patientNames,
                administrativeGenderCode: administrativeGenderCode,
                birthTime: birthTime
            )
            : nil
        
        let patientRole = PatientRole(
            id: patientIds,
            addr: addresses.isEmpty ? nil : addresses,
            telecom: telecoms.isEmpty ? nil : telecoms,
            patient: patient,
            providerOrganization: providerOrganization
        )
        
        return RecordTarget(patientRole: patientRole)
    }
}

// MARK: - AuthorBuilder

/// Builder for constructing Author with fluent API
public final class AuthorBuilder {
    private var time: TS?
    private var authorIds: [II] = []
    private var authorNames: [EN] = []
    private var telecoms: [TEL] = []
    private var addresses: [AD] = []
    private var authoringDevice: AuthoringDevice?
    private var representedOrganization: Organization?
    
    public init() {}
    
    /// Sets author participation time
    public func withTime(_ date: Date) -> Self {
        self.time = TS(value: date)
        return self
    }
    
    /// Adds author identifier
    public func withAuthorId(root: String, extension: String? = nil) -> Self {
        self.authorIds.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Adds author name
    public func withAuthorName(given: String, family: String, prefix: String? = nil) -> Self {
        var parts: [EN.NamePart] = []
        if let prefix = prefix {
            parts.append(EN.NamePart(value: prefix, type: .prefix))
        }
        parts.append(EN.NamePart(value: given, type: .given))
        parts.append(EN.NamePart(value: family, type: .family))
        self.authorNames.append(EN(parts: parts))
        return self
    }
    
    /// Adds author telecom
    public func withTelecom(value: String, use: TEL.TelecommunicationUse? = nil) -> Self {
        self.telecoms.append(TEL(value: value, use: use))
        return self
    }
    
    /// Adds author address
    public func withAddress(
        street: String? = nil,
        city: String? = nil,
        state: String? = nil,
        postalCode: String? = nil
    ) -> Self {
        var parts: [AD.AddressPart] = []
        if let street = street {
            parts.append(AD.AddressPart(value: street, type: .streetAddressLine))
        }
        if let city = city {
            parts.append(AD.AddressPart(value: city, type: .city))
        }
        if let state = state {
            parts.append(AD.AddressPart(value: state, type: .state))
        }
        if let postalCode = postalCode {
            parts.append(AD.AddressPart(value: postalCode, type: .postalCode))
        }
        self.addresses.append(AD(parts: parts, use: .work))
        return self
    }
    
    /// Sets authoring device
    public func withDevice(manufacturerModelName: String, softwareName: String) -> Self {
        self.authoringDevice = AuthoringDevice(
            manufacturerModelName: .value(manufacturerModelName),
            softwareName: .value(softwareName)
        )
        return self
    }
    
    /// Sets represented organization
    public func withOrganization(id: String, idRoot: String, name: String) -> Self {
        let namePart = EN.NamePart(value: name, type: .given)
        self.representedOrganization = Organization(
            id: [II(root: idRoot, extension: id)],
            name: [EN(parts: [namePart])]
        )
        return self
    }
    
    /// Builds the Author
    func build() -> Author? {
        guard let time = self.time else { return nil }
        guard !authorIds.isEmpty else { return nil }
        
        let assignedPerson = !authorNames.isEmpty
            ? Person(name: authorNames)
            : nil
        
        let assignedAuthor = AssignedAuthor(
            id: authorIds,
            addr: addresses.isEmpty ? nil : addresses,
            telecom: telecoms.isEmpty ? nil : telecoms,
            assignedPerson: assignedPerson,
            assignedAuthoringDevice: authoringDevice,
            representedOrganization: representedOrganization
        )
        
        return Author(time: time, assignedAuthor: assignedAuthor)
    }
}

// MARK: - CustodianBuilder

/// Builder for constructing Custodian with fluent API
public final class CustodianBuilder {
    private var organizationId: II?
    private var organizationName: String?
    private var telecom: TEL?
    private var address: AD?
    
    public init() {}
    
    /// Sets organization identifier
    public func withOrganizationId(root: String, extension: String? = nil) -> Self {
        self.organizationId = II(root: root, extension: `extension`)
        return self
    }
    
    /// Sets organization name
    public func withOrganizationName(_ name: String) -> Self {
        self.organizationName = name
        return self
    }
    
    /// Sets organization telecom
    public func withTelecom(value: String, use: TEL.TelecommunicationUse? = nil) -> Self {
        self.telecom = TEL(value: value, use: use)
        return self
    }
    
    /// Sets organization address
    public func withAddress(
        street: String? = nil,
        city: String? = nil,
        state: String? = nil,
        postalCode: String? = nil
    ) -> Self {
        var parts: [AD.AddressPart] = []
        if let street = street {
            parts.append(AD.AddressPart(value: street, type: .streetAddressLine))
        }
        if let city = city {
            parts.append(AD.AddressPart(value: city, type: .city))
        }
        if let state = state {
            parts.append(AD.AddressPart(value: state, type: .state))
        }
        if let postalCode = postalCode {
            parts.append(AD.AddressPart(value: postalCode, type: .postalCode))
        }
        self.address = AD(parts: parts, use: .work)
        return self
    }
    
    /// Builds the Custodian
    func build() -> Custodian? {
        guard let organizationId = self.organizationId else { return nil }
        
        let organizationNameEN = organizationName.map { name in
            EN(parts: [EN.NamePart(value: name, type: .given)])
        }
        
        let custodianOrganization = CustodianOrganization(
            id: [organizationId],
            name: organizationNameEN,
            telecom: telecom,
            addr: address
        )
        
        return Custodian(assignedCustodian: AssignedCustodian(representedCustodianOrganization: custodianOrganization))
    }
}

// MARK: - LegalAuthenticatorBuilder

/// Builder for constructing LegalAuthenticator with fluent API
public final class LegalAuthenticatorBuilder {
    private var time: TS?
    private var signatureCode: CD?
    private var authenticatorIds: [II] = []
    private var authenticatorNames: [EN] = []
    
    public init() {}
    
    /// Sets authentication time
    public func withTime(_ date: Date) -> Self {
        self.time = TS(value: date)
        return self
    }
    
    /// Sets signature code
    public func withSignature(code: String = "S", codeSystem: String = "2.16.840.1.113883.5.89") -> Self {
        self.signatureCode = CD(code: code, codeSystem: codeSystem)
        return self
    }
    
    /// Adds authenticator identifier
    public func withAuthenticatorId(root: String, extension: String? = nil) -> Self {
        self.authenticatorIds.append(II(root: root, extension: `extension`))
        return self
    }
    
    /// Adds authenticator name
    public func withAuthenticatorName(given: String, family: String, prefix: String? = nil) -> Self {
        var parts: [EN.NamePart] = []
        if let prefix = prefix {
            parts.append(EN.NamePart(value: prefix, type: .prefix))
        }
        parts.append(EN.NamePart(value: given, type: .given))
        parts.append(EN.NamePart(value: family, type: .family))
        self.authenticatorNames.append(EN(parts: parts))
        return self
    }
    
    /// Builds the LegalAuthenticator
    func build() -> LegalAuthenticator? {
        guard let signatureCode = self.signatureCode else { return nil }
        guard let time = self.time else { return nil }
        guard !authenticatorIds.isEmpty else { return nil }
        
        let assignedPerson = !authenticatorNames.isEmpty
            ? Person(name: authenticatorNames)
            : nil
        
        let assignedEntity = AssignedEntity(
            id: authenticatorIds,
            assignedPerson: assignedPerson
        )
        
        return LegalAuthenticator(
            signatureCode: signatureCode,
            time: time,
            assignedEntity: assignedEntity
        )
    }
}
