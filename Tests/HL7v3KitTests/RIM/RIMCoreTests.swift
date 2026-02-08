import XCTest
@testable import HL7v3Kit
@testable import HL7Core

/// Tests for HL7 v3 RIM Core Classes
final class RIMCoreTests: XCTestCase {
    
    // MARK: - Act Tests
    
    func testActBasicCreation() {
        let act = Act(
            classCode: .observation,
            moodCode: .event,
            id: [II(root: "1.2.3.4.5", extension: "OBS001")],
            code: CD(code: "test", codeSystem: "system", displayName: "Test Observation")
        )
        
        XCTAssertEqual(act.classCode, .observation)
        XCTAssertEqual(act.moodCode, .event)
        XCTAssertEqual(act.id.count, 1)
        XCTAssertEqual(act.id[0].extension, "OBS001")
        XCTAssertEqual(act.code?.code, "test")
    }
    
    func testActClassCodes() {
        let obs = Act(classCode: .observation, moodCode: .event)
        let proc = Act(classCode: .procedure, moodCode: .event)
        let enc = Act(classCode: .encounter, moodCode: .event)
        let sbadm = Act(classCode: .substanceAdministration, moodCode: .event)
        
        XCTAssertEqual(obs.classCode, .observation)
        XCTAssertEqual(proc.classCode, .procedure)
        XCTAssertEqual(enc.classCode, .encounter)
        XCTAssertEqual(sbadm.classCode, .substanceAdministration)
    }
    
    func testActMoodCodes() {
        let event = Act(classCode: .observation, moodCode: .event)
        let intent = Act(classCode: .observation, moodCode: .intent)
        let request = Act(classCode: .observation, moodCode: .request)
        let promise = Act(classCode: .observation, moodCode: .promise)
        
        XCTAssertEqual(event.moodCode, .event)
        XCTAssertEqual(intent.moodCode, .intent)
        XCTAssertEqual(request.moodCode, .request)
        XCTAssertEqual(promise.moodCode, .promise)
    }
    
    func testActWithEffectiveTime() {
        let startDate = Date()
        let low = TS(value: startDate)
        let high = TS(value: Date(timeIntervalSinceNow: 3600))
        let effectiveTime = IVL(low: low, high: high)
        
        let act = Act(
            classCode: .procedure,
            moodCode: .event,
            effectiveTime: effectiveTime
        )
        
        XCTAssertNotNil(act.effectiveTime)
        XCTAssertNotNil(act.effectiveTime?.low)
        XCTAssertNotNil(act.effectiveTime?.high)
    }
    
    func testActStatusCodes() {
        let completed = Act(classCode: .observation, moodCode: .event, statusCode: .completed)
        let active = Act(classCode: .observation, moodCode: .event, statusCode: .active)
        let aborted = Act(classCode: .observation, moodCode: .event, statusCode: .aborted)
        
        XCTAssertEqual(completed.statusCode, .completed)
        XCTAssertEqual(active.statusCode, .active)
        XCTAssertEqual(aborted.statusCode, .aborted)
    }
    
    func testActWithReasonCode() {
        let reason1 = CD(code: "R001", codeSystem: "system", displayName: "Reason 1")
        let reason2 = CD(code: "R002", codeSystem: "system", displayName: "Reason 2")
        
        let act = Act(
            classCode: .procedure,
            moodCode: .event,
            reasonCode: [reason1, reason2]
        )
        
        XCTAssertEqual(act.reasonCode?.count, 2)
        XCTAssertEqual(act.reasonCode?.first?.code, "R001")
    }
    
    // MARK: - Entity Tests
    
    func testEntityBasicCreation() {
        let entity = Entity(
            classCode: .person,
            id: [II(root: "2.16.840.1.113883.4.1", extension: "123-45-6789")]
        )
        
        XCTAssertEqual(entity.classCode, .person)
        XCTAssertEqual(entity.determinerCode, .instance)
        XCTAssertEqual(entity.id.count, 1)
        XCTAssertEqual(entity.id[0].extension, "123-45-6789")
    }
    
    func testEntityClassCodes() {
        let person = Entity(classCode: .person)
        let org = Entity(classCode: .organization)
        let place = Entity(classCode: .place)
        let device = Entity(classCode: .device)
        let material = Entity(classCode: .material)
        
        XCTAssertEqual(person.classCode, .person)
        XCTAssertEqual(org.classCode, .organization)
        XCTAssertEqual(place.classCode, .place)
        XCTAssertEqual(device.classCode, .device)
        XCTAssertEqual(material.classCode, .material)
    }
    
    func testEntityDeterminerCodes() {
        let instance = Entity(classCode: .person, determinerCode: .instance)
        let kind = Entity(classCode: .person, determinerCode: .kind)
        let quantified = Entity(classCode: .material, determinerCode: .quantified)
        
        XCTAssertEqual(instance.determinerCode, .instance)
        XCTAssertEqual(kind.determinerCode, .kind)
        XCTAssertEqual(quantified.determinerCode, .quantified)
    }
    
    func testEntityWithName() {
        let familyName = EN.NamePart(value: "Smith", type: .family)
        let givenName = EN.NamePart(value: "John", type: .given)
        let name = EN(parts: [familyName, givenName])
        
        let entity = Entity(
            classCode: .person,
            name: [name]
        )
        
        XCTAssertEqual(entity.name?.count, 1)
        XCTAssertEqual(entity.name?.first?.parts.count, 2)
    }
    
    func testEntityWithTelecomAndAddress() {
        let tel = TEL(value: "tel:+1-555-1234", use: .home)
        let street = AD.AddressPart(value: "123 Main St", type: .streetAddressLine)
        let city = AD.AddressPart(value: "Springfield", type: .city)
        let addr = AD(parts: [street, city], use: .home)
        
        let entity = Entity(
            classCode: .person,
            telecom: [tel],
            addr: [addr]
        )
        
        XCTAssertEqual(entity.telecom?.count, 1)
        XCTAssertEqual(entity.addr?.count, 1)
        XCTAssertEqual(entity.telecom?.first?.value, "tel:+1-555-1234")
    }
    
    func testEntityWithQuantity() {
        let quantity = PQ(value: 100.0, unit: "mL")
        let entity = Entity(
            classCode: .material,
            determinerCode: .quantified,
            quantity: quantity
        )
        
        XCTAssertEqual(entity.quantity?.value, 100.0)
        XCTAssertEqual(entity.quantity?.unit, "mL")
    }
    
    // MARK: - Role Tests
    
    func testRoleBasicCreation() {
        let role = Role(
            classCode: .patient,
            id: [II(root: "hospital.patients", extension: "PAT-12345")]
        )
        
        XCTAssertEqual(role.classCode, .patient)
        XCTAssertEqual(role.id.count, 1)
        XCTAssertEqual(role.id[0].extension, "PAT-12345")
    }
    
    func testRoleClassCodes() {
        let patient = Role(classCode: .patient)
        let provider = Role(classCode: .provider)
        let employee = Role(classCode: .employee)
        let guardian = Role(classCode: .guardian)
        
        XCTAssertEqual(patient.classCode, .patient)
        XCTAssertEqual(provider.classCode, .provider)
        XCTAssertEqual(employee.classCode, .employee)
        XCTAssertEqual(guardian.classCode, .guardian)
    }
    
    func testRoleWithPlayerAndScoper() {
        let player = Entity(classCode: .person)
        let scoper = Entity(classCode: .organization)
        
        let role = Role(
            classCode: .provider,
            player: player,
            scoper: scoper
        )
        
        XCTAssertEqual(role.player?.classCode, .person)
        XCTAssertEqual(role.scoper?.classCode, .organization)
    }
    
    func testRoleWithEffectiveTime() {
        let low = TS(value: Date())
        let high = TS(value: Date(timeIntervalSinceNow: 31536000)) // 1 year
        let effectiveTime = IVL(low: low, high: high)
        
        let role = Role(
            classCode: .employee,
            effectiveTime: effectiveTime
        )
        
        XCTAssertNotNil(role.effectiveTime)
        XCTAssertNotNil(role.effectiveTime?.low)
        XCTAssertNotNil(role.effectiveTime?.high)
    }
    
    // MARK: - Participation Tests
    
    func testParticipationBasicCreation() {
        let participation = Participation(
            typeCode: .performer
        )
        
        XCTAssertEqual(participation.typeCode, .performer)
        XCTAssertNil(participation.time)
        XCTAssertNil(participation.modeCode)
    }
    
    func testParticipationTypeCodes() {
        let author = Participation(typeCode: .author)
        let performer = Participation(typeCode: .performer)
        let subject = Participation(typeCode: .subject)
        let informant = Participation(typeCode: .informant)
        let location = Participation(typeCode: .location)
        
        XCTAssertEqual(author.typeCode, .author)
        XCTAssertEqual(performer.typeCode, .performer)
        XCTAssertEqual(subject.typeCode, .subject)
        XCTAssertEqual(informant.typeCode, .informant)
        XCTAssertEqual(location.typeCode, .location)
    }
    
    func testParticipationWithTime() {
        let now = Date()
        let time = IVL(low: TS(value: now))
        
        let participation = Participation(
            typeCode: .performer,
            time: time
        )
        
        XCTAssertNotNil(participation.time)
        XCTAssertNotNil(participation.time?.low)
    }
    
    func testParticipationModeCodes() {
        let physical = Participation(typeCode: .performer, modeCode: .physical)
        let verbal = Participation(typeCode: .informant, modeCode: .verbal)
        let written = Participation(typeCode: .author, modeCode: .written)
        let electronic = Participation(typeCode: .author, modeCode: .electronic)
        
        XCTAssertEqual(physical.modeCode, .physical)
        XCTAssertEqual(verbal.modeCode, .verbal)
        XCTAssertEqual(written.modeCode, .written)
        XCTAssertEqual(electronic.modeCode, .electronic)
    }
    
    func testParticipationWithRole() {
        let role = Role(classCode: .provider)
        let participation = Participation(
            typeCode: .performer,
            role: role
        )
        
        XCTAssertEqual(participation.role?.classCode, .provider)
    }
    
    // MARK: - ActRelationship Tests
    
    func testActRelationshipBasicCreation() {
        let relationship = ActRelationship(typeCode: .component)
        
        XCTAssertEqual(relationship.typeCode, .component)
        XCTAssertNil(relationship.inversionInd)
        XCTAssertNil(relationship.source)
        XCTAssertNil(relationship.target)
    }
    
    func testActRelationshipTypeCodes() {
        let component = ActRelationship(typeCode: .component)
        let subject = ActRelationship(typeCode: .subject)
        let causative = ActRelationship(typeCode: .causative)
        let reason = ActRelationship(typeCode: .reason)
        let fulfills = ActRelationship(typeCode: .fulfills)
        
        XCTAssertEqual(component.typeCode, .component)
        XCTAssertEqual(subject.typeCode, .subject)
        XCTAssertEqual(causative.typeCode, .causative)
        XCTAssertEqual(reason.typeCode, .reason)
        XCTAssertEqual(fulfills.typeCode, .fulfills)
    }
    
    func testActRelationshipWithSourceAndTarget() {
        let source = Act(classCode: .observation, moodCode: .intent)
        let target = Act(classCode: .observation, moodCode: .event)
        
        let relationship = ActRelationship(
            typeCode: .fulfills,
            source: source,
            target: target
        )
        
        XCTAssertEqual(relationship.source?.classCode, .observation)
        XCTAssertEqual(relationship.target?.classCode, .observation)
        XCTAssertEqual(relationship.source?.moodCode, .intent)
        XCTAssertEqual(relationship.target?.moodCode, .event)
    }
    
    func testActRelationshipWithSequence() {
        let relationship = ActRelationship(
            typeCode: .sequel,
            sequenceNumber: .value(1),
            priorityNumber: .value(10)
        )
        
        XCTAssertEqual(relationship.sequenceNumber?.intValue, 1)
        XCTAssertEqual(relationship.priorityNumber?.intValue, 10)
    }
    
    // MARK: - RoleLink Tests
    
    func testRoleLinkBasicCreation() {
        let roleLink = RoleLink(typeCode: .related)
        
        XCTAssertEqual(roleLink.typeCode, .related)
        XCTAssertNil(roleLink.effectiveTime)
        XCTAssertNil(roleLink.source)
        XCTAssertNil(roleLink.target)
    }
    
    func testRoleLinkTypeCodes() {
        let related = RoleLink(typeCode: .related)
        let backup = RoleLink(typeCode: .backup)
        let part = RoleLink(typeCode: .part)
        
        XCTAssertEqual(related.typeCode, .related)
        XCTAssertEqual(backup.typeCode, .backup)
        XCTAssertEqual(part.typeCode, .part)
    }
    
    func testRoleLinkWithSourceAndTarget() {
        let source = Role(classCode: .provider)
        let target = Role(classCode: .provider)
        
        let roleLink = RoleLink(
            typeCode: .backup,
            source: source,
            target: target
        )
        
        XCTAssertEqual(roleLink.source?.classCode, .provider)
        XCTAssertEqual(roleLink.target?.classCode, .provider)
    }
    
    // MARK: - Complex Scenario Tests
    
    func testPatientObservationScenario() {
        // Create patient entity
        let patientName = EN(parts: [
            EN.NamePart(value: "Doe", type: .family),
            EN.NamePart(value: "John", type: .given)
        ])
        let patientEntity = Entity(
            classCode: .person,
            name: [patientName]
        )
        
        // Create patient role
        let patientRole = Role(
            classCode: .patient,
            player: patientEntity
        )
        
        // Create observation act
        let observationCode = CD(
            code: "8867-4",
            codeSystem: "2.16.840.1.113883.6.1",
            displayName: "Heart rate"
        )
        let observation = Act(
            classCode: .observation,
            moodCode: .event,
            code: observationCode,
            statusCode: .completed
        )
        
        // Create participation (patient is subject of observation)
        let participation = Participation(
            typeCode: .subject,
            role: patientRole
        )
        
        XCTAssertEqual(observation.classCode, .observation)
        XCTAssertEqual(participation.role?.player?.name?.first?.parts.first?.value, "Doe")
    }
    
    func testProviderPerformsProcedureScenario() {
        // Create provider entity
        let providerName = EN(parts: [
            EN.NamePart(value: "Dr.", type: .prefix),
            EN.NamePart(value: "Smith", type: .family),
            EN.NamePart(value: "Jane", type: .given)
        ])
        let providerEntity = Entity(
            classCode: .person,
            name: [providerName]
        )
        
        // Create provider role
        let providerRole = Role(
            classCode: .provider,
            player: providerEntity
        )
        
        // Create procedure act
        let procedureCode = CD(
            code: "80146002",
            codeSystem: "2.16.840.1.113883.6.96",
            displayName: "Appendectomy"
        )
        let procedure = Act(
            classCode: .procedure,
            moodCode: .event,
            code: procedureCode,
            statusCode: .completed
        )
        
        // Create participation (provider performs procedure)
        let participation = Participation(
            typeCode: .performer,
            modeCode: .physical,
            role: providerRole
        )
        
        XCTAssertEqual(procedure.code?.code, "80146002")
        XCTAssertEqual(participation.typeCode, .performer)
        XCTAssertEqual(participation.role?.player?.name?.first?.parts[1].value, "Smith")
    }
    
    // MARK: - Codable Tests
    
    func testActCodable() throws {
        let original = Act(
            classCode: .observation,
            moodCode: .event,
            id: [II(root: "test", extension: "123")]
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Act.self, from: encoded)
        
        XCTAssertEqual(decoded.classCode, original.classCode)
        XCTAssertEqual(decoded.moodCode, original.moodCode)
        XCTAssertEqual(decoded.id.count, original.id.count)
    }
    
    func testEntityCodable() throws {
        let original = Entity(
            classCode: .person,
            id: [II(root: "test", extension: "123")]
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Entity.self, from: encoded)
        
        XCTAssertEqual(decoded.classCode, original.classCode)
        XCTAssertEqual(decoded.id.count, original.id.count)
    }
    
    func testRoleCodable() throws {
        let original = Role(
            classCode: .patient,
            id: [II(root: "test", extension: "123")]
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Role.self, from: encoded)
        
        XCTAssertEqual(decoded.classCode, original.classCode)
        XCTAssertEqual(decoded.id.count, original.id.count)
    }
    
    // MARK: - Sendable Tests
    
    func testSendableConformance() async {
        let act = Act(classCode: .observation, moodCode: .event)
        let entity = Entity(classCode: .person)
        let role = Role(classCode: .patient)
        let participation = Participation(typeCode: .subject)
        
        await Task {
            XCTAssertEqual(act.classCode, .observation)
            XCTAssertEqual(entity.classCode, .person)
            XCTAssertEqual(role.classCode, .patient)
            XCTAssertEqual(participation.typeCode, .subject)
        }.value
    }
    
    // MARK: - Performance Tests
    
    func testRIMClassCreationPerformance() {
        measure {
            for i in 0..<1000 {
                _ = Act(classCode: .observation, moodCode: .event,
                       id: [II(root: "test", extension: "\(i)")])
                _ = Entity(classCode: .person,
                          id: [II(root: "test", extension: "\(i)")])
                _ = Role(classCode: .patient,
                        id: [II(root: "test", extension: "\(i)")])
                _ = Participation(typeCode: .performer)
            }
        }
    }
}
