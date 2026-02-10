import XCTest
@testable import HL7Core

/// Tests for PlatformIntegrations
final class PlatformIntegrationsTests: XCTestCase {

    // MARK: - ClinicalObservation Tests

    func testClinicalObservationCreation() {
        let date = Date()
        let obs = ClinicalObservation(
            id: "obs-1",
            code: "8867-4",
            displayName: "Heart Rate",
            value: 72.0,
            unit: "bpm",
            effectiveDate: date,
            patientID: "P001"
        )
        XCTAssertEqual(obs.id, "obs-1")
        XCTAssertEqual(obs.code, "8867-4")
        XCTAssertEqual(obs.displayName, "Heart Rate")
        XCTAssertEqual(obs.value, 72.0)
        XCTAssertEqual(obs.unit, "bpm")
        XCTAssertNil(obs.stringValue)
        XCTAssertEqual(obs.effectiveDate, date)
        XCTAssertEqual(obs.patientID, "P001")
    }

    func testClinicalObservationDefaults() {
        let obs = ClinicalObservation(code: "8310-5", displayName: "Temperature")
        XCTAssertFalse(obs.id.isEmpty)
        XCTAssertNil(obs.value)
        XCTAssertNil(obs.unit)
        XCTAssertNil(obs.stringValue)
        XCTAssertNil(obs.patientID)
    }

    func testClinicalObservationStringValue() {
        let obs = ClinicalObservation(
            code: "test",
            displayName: "Note",
            stringValue: "Patient feels better"
        )
        XCTAssertNil(obs.value)
        XCTAssertEqual(obs.stringValue, "Patient feels better")
    }

    func testClinicalObservationEquatable() {
        let date = Date()
        let a = ClinicalObservation(id: "1", code: "C", displayName: "D", value: 1.0, effectiveDate: date)
        let b = ClinicalObservation(id: "1", code: "C", displayName: "D", value: 1.0, effectiveDate: date)
        let c = ClinicalObservation(id: "2", code: "C", displayName: "D", value: 1.0, effectiveDate: date)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testClinicalObservationCodable() throws {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let obs = ClinicalObservation(
            id: "enc-1",
            code: "8867-4",
            displayName: "Heart Rate",
            value: 80.0,
            unit: "bpm",
            effectiveDate: date
        )
        let data = try JSONEncoder().encode(obs)
        let decoded = try JSONDecoder().decode(ClinicalObservation.self, from: data)
        XCTAssertEqual(obs, decoded)
    }

    // MARK: - ClinicalDataCategory Tests

    func testClinicalDataCategoryAllCases() {
        let cases = ClinicalDataCategory.allCases
        XCTAssertEqual(cases.count, 7)
        XCTAssertTrue(cases.contains(.vitalSigns))
        XCTAssertTrue(cases.contains(.labResults))
        XCTAssertTrue(cases.contains(.medications))
        XCTAssertTrue(cases.contains(.immunizations))
        XCTAssertTrue(cases.contains(.allergies))
        XCTAssertTrue(cases.contains(.procedures))
        XCTAssertTrue(cases.contains(.conditions))
    }

    func testClinicalDataCategoryCodable() throws {
        let category = ClinicalDataCategory.vitalSigns
        let data = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(ClinicalDataCategory.self, from: data)
        XCTAssertEqual(category, decoded)
    }

    func testClinicalDataCategoryRawValues() {
        XCTAssertEqual(ClinicalDataCategory.vitalSigns.rawValue, "vitalSigns")
        XCTAssertEqual(ClinicalDataCategory.labResults.rawValue, "labResults")
        XCTAssertEqual(ClinicalDataCategory.medications.rawValue, "medications")
    }

    // MARK: - HealthKitDataMapping Tests

    func testVitalSignsMappings() {
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "8867-4"),
            "HKQuantityTypeIdentifierHeartRate"
        )
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "8310-5"),
            "HKQuantityTypeIdentifierBodyTemperature"
        )
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "8480-6"),
            "HKQuantityTypeIdentifierBloodPressureSystolic"
        )
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "8462-4"),
            "HKQuantityTypeIdentifierBloodPressureDiastolic"
        )
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "9279-1"),
            "HKQuantityTypeIdentifierRespiratoryRate"
        )
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "59408-5"),
            "HKQuantityTypeIdentifierOxygenSaturation"
        )
    }

    func testLabResultsMappings() {
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "2339-0"),
            "HKQuantityTypeIdentifierBloodGlucose"
        )
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "2093-3"),
            "HKQuantityTypeIdentifierCholesterolTotal"
        )
    }

    func testMedicationMappings() {
        XCTAssertEqual(
            HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "insulin-dose"),
            "HKQuantityTypeIdentifierInsulinDelivery"
        )
    }

    func testUnknownLOINCReturnsNil() {
        XCTAssertNil(HealthKitDataMapping.quantityTypeIdentifier(forLOINC: "unknown-code"))
    }

    func testCategoryForLOINC() {
        XCTAssertEqual(HealthKitDataMapping.category(forLOINC: "8867-4"), .vitalSigns)
        XCTAssertEqual(HealthKitDataMapping.category(forLOINC: "2339-0"), .labResults)
        XCTAssertEqual(HealthKitDataMapping.category(forLOINC: "insulin-dose"), .medications)
        XCTAssertNil(HealthKitDataMapping.category(forLOINC: "unknown"))
    }

    // MARK: - HealthKitSyncConfiguration Tests

    func testHealthKitSyncConfigurationDefaults() {
        let config = HealthKitSyncConfiguration()
        XCTAssertFalse(config.backgroundDeliveryEnabled)
        XCTAssertEqual(config.categories, ClinicalDataCategory.allCases)
        XCTAssertEqual(config.syncInterval, 900)
        XCTAssertEqual(config.batchSize, 100)
    }

    func testHealthKitSyncConfigurationCustom() {
        let config = HealthKitSyncConfiguration(
            backgroundDeliveryEnabled: true,
            categories: [.vitalSigns, .labResults],
            syncInterval: 60,
            batchSize: 50
        )
        XCTAssertTrue(config.backgroundDeliveryEnabled)
        XCTAssertEqual(config.categories.count, 2)
        XCTAssertEqual(config.syncInterval, 60)
        XCTAssertEqual(config.batchSize, 50)
    }

    func testHealthKitSyncConfigurationCodable() throws {
        let config = HealthKitSyncConfiguration(
            backgroundDeliveryEnabled: true,
            categories: [.vitalSigns],
            syncInterval: 120,
            batchSize: 25
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(HealthKitSyncConfiguration.self, from: data)
        XCTAssertEqual(config, decoded)
    }

    func testHealthKitSyncConfigurationDefault() {
        let config = HealthKitSyncConfiguration.default
        XCTAssertFalse(config.backgroundDeliveryEnabled)
        XCTAssertEqual(config.categories.count, ClinicalDataCategory.allCases.count)
    }

    // MARK: - CareTask Tests

    func testCareTaskCreation() {
        let date = Date()
        let task = CareTask(
            id: "task-1",
            title: "Take medication",
            instructions: "Take 1 pill with water",
            scheduledDate: date,
            isCompleted: false,
            carePlanID: "cp-1"
        )
        XCTAssertEqual(task.id, "task-1")
        XCTAssertEqual(task.title, "Take medication")
        XCTAssertEqual(task.instructions, "Take 1 pill with water")
        XCTAssertEqual(task.scheduledDate, date)
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(task.carePlanID, "cp-1")
    }

    func testCareTaskDefaults() {
        let task = CareTask(title: "Walk 30 minutes")
        XCTAssertFalse(task.id.isEmpty)
        XCTAssertNil(task.instructions)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.carePlanID)
    }

    func testCareTaskEquatable() {
        let date = Date()
        let a = CareTask(id: "t1", title: "A", scheduledDate: date)
        let b = CareTask(id: "t1", title: "A", scheduledDate: date)
        let c = CareTask(id: "t2", title: "A", scheduledDate: date)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCareTaskCodable() throws {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let task = CareTask(id: "t1", title: "Test", instructions: "Do it", scheduledDate: date)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(CareTask.self, from: data)
        XCTAssertEqual(task, decoded)
    }

    // MARK: - CareKitDataMapping Tests

    func testTaskCategoryMapping() {
        XCTAssertEqual(CareKitDataMapping.taskCategory(forActivityCode: "MEDS"), "Medication")
        XCTAssertEqual(CareKitDataMapping.taskCategory(forActivityCode: "VITALS"), "Vital Signs")
        XCTAssertEqual(CareKitDataMapping.taskCategory(forActivityCode: "EXERCISE"), "Physical Activity")
        XCTAssertEqual(CareKitDataMapping.taskCategory(forActivityCode: "DIET"), "Nutrition")
        XCTAssertEqual(CareKitDataMapping.taskCategory(forActivityCode: "APPT"), "Appointment")
        XCTAssertEqual(CareKitDataMapping.taskCategory(forActivityCode: "EDU"), "Education")
        XCTAssertEqual(CareKitDataMapping.taskCategory(forActivityCode: "ASSESS"), "Assessment")
        XCTAssertEqual(CareKitDataMapping.taskCategory(forActivityCode: "UNKNOWN"), "General")
    }

    func testOutcomeCodeMapping() {
        XCTAssertEqual(CareKitDataMapping.outcomeCode(isCompleted: true), "completed")
        XCTAssertEqual(CareKitDataMapping.outcomeCode(isCompleted: false), "in-progress")
    }

    // MARK: - ConsentStatus Tests

    func testConsentStatusRawValues() {
        XCTAssertEqual(ConsentStatus.consented.rawValue, "consented")
        XCTAssertEqual(ConsentStatus.declined.rawValue, "declined")
        XCTAssertEqual(ConsentStatus.withdrawn.rawValue, "withdrawn")
        XCTAssertEqual(ConsentStatus.pending.rawValue, "pending")
    }

    func testConsentStatusCodable() throws {
        let status = ConsentStatus.consented
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ConsentStatus.self, from: data)
        XCTAssertEqual(status, decoded)
    }

    // MARK: - SurveyResponse Tests

    func testSurveyResponseCreation() {
        let date = Date()
        let response = SurveyResponse(
            id: "sr-1",
            surveyID: "survey-1",
            answers: ["q1": "yes", "q2": "3"],
            completedDate: date,
            participantID: "P001"
        )
        XCTAssertEqual(response.id, "sr-1")
        XCTAssertEqual(response.surveyID, "survey-1")
        XCTAssertEqual(response.answers, ["q1": "yes", "q2": "3"])
        XCTAssertEqual(response.completedDate, date)
        XCTAssertEqual(response.participantID, "P001")
    }

    func testSurveyResponseDefaults() {
        let response = SurveyResponse(surveyID: "s1", answers: [:])
        XCTAssertFalse(response.id.isEmpty)
        XCTAssertTrue(response.answers.isEmpty)
        XCTAssertNil(response.participantID)
    }

    func testSurveyResponseCodable() throws {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let response = SurveyResponse(
            id: "sr-2",
            surveyID: "s2",
            answers: ["a": "b"],
            completedDate: date
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(SurveyResponse.self, from: data)
        XCTAssertEqual(response, decoded)
    }

    // MARK: - ResearchKitDataMapping Tests

    func testStepTypeMapping() {
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "boolean"), "booleanQuestion")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "choice"), "multipleChoice")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "open-choice"), "textChoice")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "string"), "textAnswer")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "integer"), "numericAnswer")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "decimal"), "numericAnswer")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "date"), "dateQuestion")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "dateTime"), "dateTimeQuestion")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "text"), "textAnswer")
        XCTAssertEqual(ResearchKitDataMapping.stepType(forHL7QuestionType: "unknown"), "textAnswer")
    }

    func testProvisionTypeCodeMapping() {
        XCTAssertEqual(ResearchKitDataMapping.provisionTypeCode(for: .consented), "permit")
        XCTAssertEqual(ResearchKitDataMapping.provisionTypeCode(for: .declined), "deny")
        XCTAssertEqual(ResearchKitDataMapping.provisionTypeCode(for: .withdrawn), "deny")
        XCTAssertEqual(ResearchKitDataMapping.provisionTypeCode(for: .pending), "pending")
    }

    // MARK: - CloudSyncStatus Tests

    func testCloudSyncStatusRawValues() {
        XCTAssertEqual(CloudSyncStatus.idle.rawValue, "idle")
        XCTAssertEqual(CloudSyncStatus.syncing.rawValue, "syncing")
        XCTAssertEqual(CloudSyncStatus.error.rawValue, "error")
        XCTAssertEqual(CloudSyncStatus.completed.rawValue, "completed")
    }

    func testCloudSyncStatusCodable() throws {
        for status in [CloudSyncStatus.idle, .syncing, .error, .completed] {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(CloudSyncStatus.self, from: data)
            XCTAssertEqual(status, decoded)
        }
    }

    // MARK: - ConflictResolutionStrategy Tests

    func testConflictResolutionStrategyRawValues() {
        XCTAssertEqual(ConflictResolutionStrategy.lastWriterWins.rawValue, "lastWriterWins")
        XCTAssertEqual(ConflictResolutionStrategy.serverWins.rawValue, "serverWins")
        XCTAssertEqual(ConflictResolutionStrategy.clientWins.rawValue, "clientWins")
        XCTAssertEqual(ConflictResolutionStrategy.manual.rawValue, "manual")
    }

    // MARK: - CloudSyncConfiguration Tests

    func testCloudSyncConfigurationCreation() {
        let config = CloudSyncConfiguration(
            containerIdentifier: "iCloud.com.example.hl7kit",
            automaticSyncEnabled: false,
            conflictResolution: .serverWins,
            maxRecordSizeBytes: 512_000,
            syncInterval: 600,
            allowsCellularSync: true
        )
        XCTAssertEqual(config.containerIdentifier, "iCloud.com.example.hl7kit")
        XCTAssertFalse(config.automaticSyncEnabled)
        XCTAssertEqual(config.conflictResolution, .serverWins)
        XCTAssertEqual(config.maxRecordSizeBytes, 512_000)
        XCTAssertEqual(config.syncInterval, 600)
        XCTAssertTrue(config.allowsCellularSync)
    }

    func testCloudSyncConfigurationDefaults() {
        let config = CloudSyncConfiguration(containerIdentifier: "iCloud.test")
        XCTAssertTrue(config.automaticSyncEnabled)
        XCTAssertEqual(config.conflictResolution, .lastWriterWins)
        XCTAssertEqual(config.maxRecordSizeBytes, 1_048_576)
        XCTAssertEqual(config.syncInterval, 300)
        XCTAssertFalse(config.allowsCellularSync)
    }

    func testCloudSyncConfigurationCodable() throws {
        let config = CloudSyncConfiguration(
            containerIdentifier: "iCloud.test",
            conflictResolution: .manual
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CloudSyncConfiguration.self, from: data)
        XCTAssertEqual(config, decoded)
    }

    // MARK: - CloudSyncRecord Tests

    func testCloudSyncRecordCreation() {
        let date = Date()
        let record = CloudSyncRecord(
            id: "rec-1",
            messageContent: "MSH|^~\\&|...",
            messageType: "ADT",
            lastModified: date,
            deviceID: "device-1"
        )
        XCTAssertEqual(record.id, "rec-1")
        XCTAssertEqual(record.messageContent, "MSH|^~\\&|...")
        XCTAssertEqual(record.messageType, "ADT")
        XCTAssertEqual(record.lastModified, date)
        XCTAssertEqual(record.deviceID, "device-1")
    }

    func testCloudSyncRecordDefaults() {
        let record = CloudSyncRecord(messageContent: "test", messageType: "ORM")
        XCTAssertFalse(record.id.isEmpty)
        XCTAssertEqual(record.deviceID, "")
    }

    func testCloudSyncRecordCodable() throws {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let record = CloudSyncRecord(
            id: "r1",
            messageContent: "content",
            messageType: "ORU",
            lastModified: date
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(CloudSyncRecord.self, from: data)
        XCTAssertEqual(record, decoded)
    }

    // MARK: - HandoffActivityType Tests

    func testHandoffActivityTypeAllCases() {
        let cases = HandoffActivityType.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.viewMessage))
        XCTAssertTrue(cases.contains(.editMessage))
        XCTAssertTrue(cases.contains(.validateMessage))
        XCTAssertTrue(cases.contains(.convertMessage))
        XCTAssertTrue(cases.contains(.browsePatient))
    }

    func testHandoffActivityTypeRawValues() {
        XCTAssertEqual(HandoffActivityType.viewMessage.rawValue, "com.hl7kit.viewMessage")
        XCTAssertEqual(HandoffActivityType.editMessage.rawValue, "com.hl7kit.editMessage")
        XCTAssertEqual(HandoffActivityType.validateMessage.rawValue, "com.hl7kit.validateMessage")
        XCTAssertEqual(HandoffActivityType.convertMessage.rawValue, "com.hl7kit.convertMessage")
        XCTAssertEqual(HandoffActivityType.browsePatient.rawValue, "com.hl7kit.browsePatient")
    }

    func testHandoffActivityTypeCodable() throws {
        let activityType = HandoffActivityType.viewMessage
        let data = try JSONEncoder().encode(activityType)
        let decoded = try JSONDecoder().decode(HandoffActivityType.self, from: data)
        XCTAssertEqual(activityType, decoded)
    }

    // MARK: - HandoffPayload Tests

    func testHandoffPayloadCreation() {
        let date = Date()
        let payload = HandoffPayload(
            activityType: .editMessage,
            messageContent: "MSH|test",
            messageType: "ADT^A01",
            userInfo: ["key": "value"],
            timestamp: date
        )
        XCTAssertEqual(payload.activityType, .editMessage)
        XCTAssertEqual(payload.messageContent, "MSH|test")
        XCTAssertEqual(payload.messageType, "ADT^A01")
        XCTAssertEqual(payload.userInfo, ["key": "value"])
        XCTAssertEqual(payload.timestamp, date)
    }

    func testHandoffPayloadDefaults() {
        let payload = HandoffPayload(activityType: .viewMessage, messageContent: "content")
        XCTAssertNil(payload.messageType)
        XCTAssertTrue(payload.userInfo.isEmpty)
    }

    func testHandoffPayloadCodable() throws {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let payload = HandoffPayload(
            activityType: .convertMessage,
            messageContent: "data",
            messageType: "ORM",
            timestamp: date
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(HandoffPayload.self, from: data)
        XCTAssertEqual(payload, decoded)
    }

    // MARK: - ShortcutAction Tests

    func testShortcutActionAllCases() {
        let cases = ShortcutAction.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.validateMessage))
        XCTAssertTrue(cases.contains(.convertFormat))
        XCTAssertTrue(cases.contains(.lookupPatient))
        XCTAssertTrue(cases.contains(.sendMessage))
    }

    func testShortcutActionRawValues() {
        XCTAssertEqual(ShortcutAction.validateMessage.rawValue, "validateMessage")
        XCTAssertEqual(ShortcutAction.convertFormat.rawValue, "convertFormat")
        XCTAssertEqual(ShortcutAction.lookupPatient.rawValue, "lookupPatient")
        XCTAssertEqual(ShortcutAction.sendMessage.rawValue, "sendMessage")
    }

    // MARK: - ShortcutResponse Tests

    func testShortcutResponseCreation() {
        let date = Date()
        let response = ShortcutResponse(
            success: true,
            action: .validateMessage,
            message: "Message is valid",
            resultData: "OK",
            timestamp: date
        )
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.action, .validateMessage)
        XCTAssertEqual(response.message, "Message is valid")
        XCTAssertEqual(response.resultData, "OK")
        XCTAssertEqual(response.timestamp, date)
    }

    func testShortcutResponseDefaults() {
        let response = ShortcutResponse(
            success: false,
            action: .sendMessage,
            message: "Failed"
        )
        XCTAssertFalse(response.success)
        XCTAssertNil(response.resultData)
    }

    func testShortcutResponseCodable() throws {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let response = ShortcutResponse(
            success: true,
            action: .convertFormat,
            message: "Converted",
            resultData: "result",
            timestamp: date
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ShortcutResponse.self, from: data)
        XCTAssertEqual(response, decoded)
    }

    // MARK: - PlatformIntegrationManager Tests

    func testManagerInitialState() async {
        let manager = PlatformIntegrationManager()
        let hk = await manager.healthKitBridge
        let ck = await manager.careKitBridge
        let rk = await manager.researchKitBridge
        let cs = await manager.cloudSyncProvider
        let ho = await manager.handoffProvider
        let sc = await manager.shortcutsProvider
        XCTAssertNil(hk)
        XCTAssertNil(ck)
        XCTAssertNil(rk)
        XCTAssertNil(cs)
        XCTAssertNil(ho)
        XCTAssertNil(sc)
    }

    func testManagerRegisterHealthKit() async {
        let manager = PlatformIntegrationManager()
        let mock = MockHealthKitBridge()
        await manager.register(healthKit: mock)
        let bridge = await manager.healthKitBridge
        XCTAssertNotNil(bridge)
    }

    func testManagerRegisterCareKit() async {
        let manager = PlatformIntegrationManager()
        let mock = MockCareKitBridge()
        await manager.register(careKit: mock)
        let bridge = await manager.careKitBridge
        XCTAssertNotNil(bridge)
    }

    func testManagerRegisterResearchKit() async {
        let manager = PlatformIntegrationManager()
        let mock = MockResearchKitBridge()
        await manager.register(researchKit: mock)
        let bridge = await manager.researchKitBridge
        XCTAssertNotNil(bridge)
    }

    func testManagerRegisterCloudSync() async {
        let manager = PlatformIntegrationManager()
        let mock = MockCloudSyncProvider()
        await manager.register(cloudSync: mock)
        let provider = await manager.cloudSyncProvider
        XCTAssertNotNil(provider)
    }

    func testManagerRegisterHandoff() async {
        let manager = PlatformIntegrationManager()
        let mock = MockHandoffProvider()
        await manager.register(handoff: mock)
        let provider = await manager.handoffProvider
        XCTAssertNotNil(provider)
    }

    func testManagerRegisterShortcuts() async {
        let manager = PlatformIntegrationManager()
        let mock = MockShortcutsProvider()
        await manager.register(shortcuts: mock)
        let provider = await manager.shortcutsProvider
        XCTAssertNotNil(provider)
    }

    // MARK: - Mock Bridge Protocol Usage Tests

    func testMockHealthKitBridgeExport() async throws {
        let mock = MockHealthKitBridge()
        let obs = ClinicalObservation(code: "8867-4", displayName: "HR", value: 72)
        let sampleID = try await mock.exportToHealthKit(obs)
        XCTAssertFalse(sampleID.isEmpty)
    }

    func testMockHealthKitBridgeImport() async throws {
        let mock = MockHealthKitBridge()
        let obs = try await mock.importFromHealthKit(sampleID: "sample-1")
        XCTAssertEqual(obs.code, "mock")
    }

    func testMockHealthKitBridgeQuery() async throws {
        let mock = MockHealthKitBridge()
        let results = try await mock.queryHealthKit(
            category: .vitalSigns,
            from: Date.distantPast,
            to: Date()
        )
        XCTAssertTrue(results.isEmpty)
    }

    func testMockHealthKitBridgeAuthorization() async throws {
        let mock = MockHealthKitBridge()
        let granted = try await mock.requestAuthorization(for: [.vitalSigns])
        XCTAssertTrue(granted)
    }

    func testMockCareKitBridgeImport() async throws {
        let mock = MockCareKitBridge()
        let tasks = try await mock.importCarePlan(from: "HL7 care plan")
        XCTAssertTrue(tasks.isEmpty)
    }

    func testMockCareKitBridgeExport() async throws {
        let mock = MockCareKitBridge()
        let task = CareTask(title: "Test")
        let result = try await mock.exportCarePlan(tasks: [task])
        XCTAssertFalse(result.isEmpty)
    }

    func testMockCareKitBridgeSyncOutcome() async throws {
        let mock = MockCareKitBridge()
        let task = CareTask(title: "Done", isCompleted: true)
        let result = try await mock.syncTaskOutcome(task)
        XCTAssertFalse(result.isEmpty)
    }

    func testMockCloudSyncProviderPushPull() async throws {
        let mock = MockCloudSyncProvider()
        let record = CloudSyncRecord(messageContent: "test", messageType: "ADT")
        try await mock.push(record)
        let results = try await mock.pull(since: Date.distantPast)
        XCTAssertTrue(results.isEmpty)
    }

    func testMockCloudSyncProviderStatus() async {
        let mock = MockCloudSyncProvider()
        let status = await mock.status()
        XCTAssertEqual(status, .idle)
    }

    func testMockCloudSyncProviderResolveConflict() async throws {
        let mock = MockCloudSyncProvider()
        let local = CloudSyncRecord(id: "1", messageContent: "local", messageType: "ADT")
        let remote = CloudSyncRecord(id: "1", messageContent: "remote", messageType: "ADT")
        let resolved = try await mock.resolveConflict(
            local: local,
            remote: remote,
            strategy: .lastWriterWins
        )
        XCTAssertEqual(resolved.id, "1")
    }

    func testMockShortcutsProviderExecute() async throws {
        let mock = MockShortcutsProvider()
        let response = try await mock.execute(action: .validateMessage, input: "MSH|test")
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.action, .validateMessage)
    }
}

// MARK: - Mock Implementations

private struct MockHealthKitBridge: HealthKitBridge {
    func exportToHealthKit(_ observation: ClinicalObservation) async throws -> String {
        return UUID().uuidString
    }

    func importFromHealthKit(sampleID: String) async throws -> ClinicalObservation {
        ClinicalObservation(code: "mock", displayName: "Mock")
    }

    func queryHealthKit(
        category: ClinicalDataCategory,
        from start: Date,
        to end: Date
    ) async throws -> [ClinicalObservation] {
        []
    }

    func requestAuthorization(for categories: Set<ClinicalDataCategory>) async throws -> Bool {
        true
    }
}

private struct MockCareKitBridge: CareKitBridge {
    func importCarePlan(from hl7Message: String) async throws -> [CareTask] {
        []
    }

    func exportCarePlan(tasks: [CareTask]) async throws -> String {
        "MOCK_CARE_PLAN"
    }

    func syncTaskOutcome(_ task: CareTask) async throws -> String {
        "MOCK_OUTCOME"
    }
}

private struct MockResearchKitBridge: ResearchKitBridge {
    func importQuestionnaire(from hl7Questionnaire: String) async throws -> String {
        "mock-survey-id"
    }

    func exportSurveyResponse(_ response: SurveyResponse) async throws -> String {
        "MOCK_RESPONSE"
    }

    func recordConsent(
        participantID: String,
        status: ConsentStatus,
        studyID: String
    ) async throws -> String {
        "MOCK_CONSENT"
    }
}

private struct MockCloudSyncProvider: CloudSyncProvider {
    func push(_ record: CloudSyncRecord) async throws {}

    func pull(since: Date) async throws -> [CloudSyncRecord] {
        []
    }

    func delete(recordID: String) async throws {}

    func resolveConflict(
        local: CloudSyncRecord,
        remote: CloudSyncRecord,
        strategy: ConflictResolutionStrategy
    ) async throws -> CloudSyncRecord {
        switch strategy {
        case .lastWriterWins:
            return local.lastModified > remote.lastModified ? local : remote
        case .clientWins:
            return local
        case .serverWins:
            return remote
        case .manual:
            return local
        }
    }

    func status() async -> CloudSyncStatus {
        .idle
    }
}

private struct MockHandoffProvider: HandoffProvider {
    func beginActivity(with payload: HandoffPayload) async throws -> String {
        UUID().uuidString
    }

    func updateActivity(activityID: String, with payload: HandoffPayload) async throws {}

    func endActivity(activityID: String) async throws {}

    func handleIncomingActivity(userInfo: [String: String]) async throws -> HandoffPayload {
        HandoffPayload(activityType: .viewMessage, messageContent: "")
    }
}

private struct MockShortcutsProvider: ShortcutsProvider {
    func execute(action: ShortcutAction, input: String) async throws -> ShortcutResponse {
        ShortcutResponse(success: true, action: action, message: "OK")
    }

    func registerShortcuts(_ actions: [ShortcutAction]) async throws {}

    func donateInteraction(for response: ShortcutResponse) async throws {}
}
