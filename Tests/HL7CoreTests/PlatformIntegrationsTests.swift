import XCTest
@testable import HL7Core

/// Thread-safe box for use in Sendable closures during testing
private final class SendableBox: @unchecked Sendable {
    private var value = false
    func set(_ v: Bool) { value = v }
    func get() -> Bool { value }
}

/// Tests for PlatformIntegrations module
final class PlatformIntegrationsTests: XCTestCase {

    // MARK: - HealthMeasurement Tests

    func testHealthMeasurementInit() {
        let measurement = HealthMeasurement(
            measurementType: "heart_rate",
            value: 72.0,
            unit: "bpm"
        )
        XCTAssertEqual(measurement.measurementType, "heart_rate")
        XCTAssertEqual(measurement.value, 72.0)
        XCTAssertEqual(measurement.unit, "bpm")
        XCTAssertNil(measurement.source)
        XCTAssertNil(measurement.metadata)
        XCTAssertFalse(measurement.id.isEmpty)
    }

    func testHealthMeasurementFullInit() {
        let date = Date()
        let measurement = HealthMeasurement(
            id: "test-123",
            measurementType: "blood_pressure",
            value: 120.0,
            unit: "mmHg",
            timestamp: date,
            source: "MyDevice",
            metadata: ["position": "sitting"]
        )
        XCTAssertEqual(measurement.id, "test-123")
        XCTAssertEqual(measurement.source, "MyDevice")
        XCTAssertEqual(measurement.metadata?["position"], "sitting")
        XCTAssertEqual(measurement.timestamp, date)
    }

    func testHealthMeasurementCodable() throws {
        let measurement = HealthMeasurement(
            id: "codable-test",
            measurementType: "body_temperature",
            value: 37.0,
            unit: "°C"
        )
        let data = try JSONEncoder().encode(measurement)
        let decoded = try JSONDecoder().decode(HealthMeasurement.self, from: data)
        XCTAssertEqual(measurement, decoded)
    }

    func testHealthMeasurementHashable() {
        let date = Date()
        let m1 = HealthMeasurement(id: "h1", measurementType: "heart_rate", value: 72, unit: "bpm", timestamp: date)
        let m2 = HealthMeasurement(id: "h1", measurementType: "heart_rate", value: 72, unit: "bpm", timestamp: date)
        let m3 = HealthMeasurement(id: "h2", measurementType: "heart_rate", value: 80, unit: "bpm", timestamp: date)
        XCTAssertEqual(m1, m2)
        XCTAssertNotEqual(m1, m3)

        let set: Set<HealthMeasurement> = [m1, m2, m3]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - VitalSign Tests

    func testVitalSignInit() {
        let vs = VitalSign(
            type: .heartRate,
            primaryValue: 72.0,
            unit: "bpm"
        )
        XCTAssertEqual(vs.type, .heartRate)
        XCTAssertEqual(vs.primaryValue, 72.0)
        XCTAssertNil(vs.secondaryValue)
        XCTAssertEqual(vs.status, .final)
    }

    func testVitalSignWithSecondaryValue() {
        let vs = VitalSign(
            type: .bloodPressure,
            primaryValue: 120.0,
            secondaryValue: 80.0,
            unit: "mmHg",
            status: .preliminary
        )
        XCTAssertEqual(vs.secondaryValue, 80.0)
        XCTAssertEqual(vs.status, .preliminary)
    }

    func testVitalSignCodable() throws {
        let vs = VitalSign(
            id: "vs-1",
            type: .oxygenSaturation,
            primaryValue: 98.0,
            unit: "%"
        )
        let data = try JSONEncoder().encode(vs)
        let decoded = try JSONDecoder().decode(VitalSign.self, from: data)
        XCTAssertEqual(vs, decoded)
    }

    // MARK: - VitalSignType Tests

    func testVitalSignTypeCaseIterable() {
        XCTAssertEqual(VitalSignType.allCases.count, 10)
    }

    func testVitalSignTypeRawValues() {
        XCTAssertEqual(VitalSignType.heartRate.rawValue, "heart_rate")
        XCTAssertEqual(VitalSignType.bloodPressure.rawValue, "blood_pressure")
        XCTAssertEqual(VitalSignType.bodyTemperature.rawValue, "body_temperature")
        XCTAssertEqual(VitalSignType.respiratoryRate.rawValue, "respiratory_rate")
        XCTAssertEqual(VitalSignType.oxygenSaturation.rawValue, "oxygen_saturation")
        XCTAssertEqual(VitalSignType.bodyWeight.rawValue, "body_weight")
        XCTAssertEqual(VitalSignType.bodyHeight.rawValue, "body_height")
        XCTAssertEqual(VitalSignType.bodyMassIndex.rawValue, "bmi")
        XCTAssertEqual(VitalSignType.bloodGlucose.rawValue, "blood_glucose")
        XCTAssertEqual(VitalSignType.stepCount.rawValue, "step_count")
    }

    // MARK: - MeasurementStatus Tests

    func testMeasurementStatusRawValues() {
        XCTAssertEqual(MeasurementStatus.preliminary.rawValue, "preliminary")
        XCTAssertEqual(MeasurementStatus.final.rawValue, "final")
        XCTAssertEqual(MeasurementStatus.amended.rawValue, "amended")
        XCTAssertEqual(MeasurementStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(MeasurementStatus.enteredInError.rawValue, "entered_in_error")
    }

    // MARK: - PlatformObservationToken Tests

    func testObservationTokenCancel() {
        let box = SendableBox()
        let token = PlatformObservationToken(
            observedType: "heart_rate",
            cancelHandler: { box.set(true) }
        )
        XCTAssertEqual(token.observedType, "heart_rate")
        XCTAssertFalse(box.get())
        token.cancel()
        XCTAssertTrue(box.get())
    }

    func testObservationTokenId() {
        let token = PlatformObservationToken(
            id: "token-1",
            observedType: "blood_pressure",
            cancelHandler: {}
        )
        XCTAssertEqual(token.id, "token-1")
    }

    // MARK: - CareTask Tests

    func testCareTaskInit() {
        let task = CareTask(title: "Take medication")
        XCTAssertEqual(task.title, "Take medication")
        XCTAssertNil(task.instructions)
        XCTAssertEqual(task.category, .other)
        XCTAssertTrue(task.isActive)
        XCTAssertNil(task.patientId)
        XCTAssertNil(task.carePlanId)
    }

    func testCareTaskFullInit() {
        let task = CareTask(
            id: "task-1",
            title: "Blood pressure check",
            instructions: "Measure twice daily",
            category: .monitoring,
            isActive: true,
            patientId: "patient-1",
            carePlanId: "plan-1"
        )
        XCTAssertEqual(task.id, "task-1")
        XCTAssertEqual(task.instructions, "Measure twice daily")
        XCTAssertEqual(task.category, .monitoring)
        XCTAssertEqual(task.patientId, "patient-1")
    }

    func testCareTaskCodable() throws {
        let task = CareTask(
            id: "ct-1",
            title: "Exercise",
            category: .exercise
        )
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(CareTask.self, from: data)
        XCTAssertEqual(task, decoded)
    }

    // MARK: - CareTaskCategory Tests

    func testCareTaskCategoryRawValues() {
        XCTAssertEqual(CareTaskCategory.medication.rawValue, "medication")
        XCTAssertEqual(CareTaskCategory.exercise.rawValue, "exercise")
        XCTAssertEqual(CareTaskCategory.nutrition.rawValue, "nutrition")
        XCTAssertEqual(CareTaskCategory.monitoring.rawValue, "monitoring")
        XCTAssertEqual(CareTaskCategory.appointment.rawValue, "appointment")
        XCTAssertEqual(CareTaskCategory.education.rawValue, "education")
        XCTAssertEqual(CareTaskCategory.other.rawValue, "other")
    }

    // MARK: - TaskSchedule Tests

    func testTaskScheduleDefaults() {
        let schedule = TaskSchedule()
        XCTAssertNil(schedule.startDate)
        XCTAssertNil(schedule.endDate)
        XCTAssertEqual(schedule.frequencyPerDay, 1)
        XCTAssertNil(schedule.timesOfDay)
        XCTAssertNil(schedule.daysOfWeek)
    }

    func testTaskScheduleCustom() {
        let schedule = TaskSchedule(
            frequencyPerDay: 3,
            timesOfDay: [8, 14, 20],
            daysOfWeek: [2, 3, 4, 5, 6]
        )
        XCTAssertEqual(schedule.frequencyPerDay, 3)
        XCTAssertEqual(schedule.timesOfDay, [8, 14, 20])
        XCTAssertEqual(schedule.daysOfWeek, [2, 3, 4, 5, 6])
    }

    func testTaskScheduleCodable() throws {
        let schedule = TaskSchedule(frequencyPerDay: 2, timesOfDay: [9, 21])
        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(TaskSchedule.self, from: data)
        XCTAssertEqual(schedule, decoded)
    }

    // MARK: - CareOutcome Tests

    func testCareOutcomeInit() {
        let outcome = CareOutcome(taskId: "task-1")
        XCTAssertEqual(outcome.taskId, "task-1")
        XCTAssertTrue(outcome.values.isEmpty)
        XCTAssertNil(outcome.note)
    }

    func testCareOutcomeWithValues() {
        let values = [
            OutcomeValue(kind: "systolic", numericValue: 120, unit: "mmHg"),
            OutcomeValue(kind: "diastolic", numericValue: 80, unit: "mmHg")
        ]
        let outcome = CareOutcome(
            taskId: "task-bp",
            values: values,
            note: "Measured after rest"
        )
        XCTAssertEqual(outcome.values.count, 2)
        XCTAssertEqual(outcome.note, "Measured after rest")
    }

    func testCareOutcomeCodable() throws {
        let outcome = CareOutcome(
            id: "co-1",
            taskId: "task-1",
            values: [OutcomeValue(kind: "completed", booleanValue: true)]
        )
        let data = try JSONEncoder().encode(outcome)
        let decoded = try JSONDecoder().decode(CareOutcome.self, from: data)
        XCTAssertEqual(outcome, decoded)
    }

    // MARK: - OutcomeValue Tests

    func testOutcomeValueNumeric() {
        let val = OutcomeValue(kind: "temperature", numericValue: 37.5, unit: "°C")
        XCTAssertEqual(val.kind, "temperature")
        XCTAssertEqual(val.numericValue, 37.5)
        XCTAssertNil(val.textValue)
        XCTAssertNil(val.booleanValue)
    }

    func testOutcomeValueText() {
        let val = OutcomeValue(kind: "notes", textValue: "Feeling good")
        XCTAssertEqual(val.textValue, "Feeling good")
        XCTAssertNil(val.numericValue)
    }

    func testOutcomeValueBoolean() {
        let val = OutcomeValue(kind: "taken", booleanValue: true)
        XCTAssertEqual(val.booleanValue, true)
    }

    // MARK: - SurveyQuestion Tests

    func testSurveyQuestionDefaults() {
        let q = SurveyQuestion(text: "How are you feeling?")
        XCTAssertEqual(q.text, "How are you feeling?")
        XCTAssertEqual(q.answerType, .text)
        XCTAssertTrue(q.isRequired)
        XCTAssertNil(q.choices)
        XCTAssertNil(q.minimumValue)
        XCTAssertNil(q.maximumValue)
    }

    func testSurveyQuestionMultipleChoice() {
        let q = SurveyQuestion(
            text: "Rate your pain",
            answerType: .singleChoice,
            choices: ["None", "Mild", "Moderate", "Severe"]
        )
        XCTAssertEqual(q.answerType, .singleChoice)
        XCTAssertEqual(q.choices?.count, 4)
    }

    func testSurveyQuestionNumeric() {
        let q = SurveyQuestion(
            text: "Pain level",
            answerType: .scale,
            minimumValue: 0,
            maximumValue: 10
        )
        XCTAssertEqual(q.minimumValue, 0)
        XCTAssertEqual(q.maximumValue, 10)
    }

    func testSurveyQuestionCodable() throws {
        let q = SurveyQuestion(id: "q-1", text: "Test", answerType: .boolean)
        let data = try JSONEncoder().encode(q)
        let decoded = try JSONDecoder().decode(SurveyQuestion.self, from: data)
        XCTAssertEqual(q, decoded)
    }

    // MARK: - AnswerType Tests

    func testAnswerTypeRawValues() {
        XCTAssertEqual(AnswerType.text.rawValue, "text")
        XCTAssertEqual(AnswerType.numeric.rawValue, "numeric")
        XCTAssertEqual(AnswerType.boolean.rawValue, "boolean")
        XCTAssertEqual(AnswerType.date.rawValue, "date")
        XCTAssertEqual(AnswerType.singleChoice.rawValue, "single_choice")
        XCTAssertEqual(AnswerType.multipleChoice.rawValue, "multiple_choice")
        XCTAssertEqual(AnswerType.scale.rawValue, "scale")
    }

    // MARK: - ResearchSurvey Tests

    func testResearchSurveyInit() {
        let survey = ResearchSurvey(title: "Health Survey")
        XCTAssertEqual(survey.title, "Health Survey")
        XCTAssertNil(survey.description)
        XCTAssertTrue(survey.questions.isEmpty)
        XCTAssertEqual(survey.version, "1.0")
    }

    func testResearchSurveyWithQuestions() {
        let questions = [
            SurveyQuestion(text: "Q1"),
            SurveyQuestion(text: "Q2")
        ]
        let survey = ResearchSurvey(
            title: "Test Survey",
            description: "A test",
            questions: questions,
            version: "2.0"
        )
        XCTAssertEqual(survey.questions.count, 2)
        XCTAssertEqual(survey.version, "2.0")
    }

    func testResearchSurveyCodable() throws {
        let survey = ResearchSurvey(id: "s-1", title: "Survey")
        let data = try JSONEncoder().encode(survey)
        let decoded = try JSONDecoder().decode(ResearchSurvey.self, from: data)
        XCTAssertEqual(survey, decoded)
    }

    // MARK: - SurveyAnswer Tests

    func testSurveyAnswerText() {
        let answer = SurveyAnswer(questionId: "q1", textValue: "Good")
        XCTAssertEqual(answer.questionId, "q1")
        XCTAssertEqual(answer.textValue, "Good")
        XCTAssertNil(answer.numericValue)
    }

    func testSurveyAnswerNumeric() {
        let answer = SurveyAnswer(questionId: "q2", numericValue: 7.5)
        XCTAssertEqual(answer.numericValue, 7.5)
    }

    func testSurveyAnswerBoolean() {
        let answer = SurveyAnswer(questionId: "q3", booleanValue: true)
        XCTAssertEqual(answer.booleanValue, true)
    }

    func testSurveyAnswerDate() {
        let date = Date()
        let answer = SurveyAnswer(questionId: "q4", dateValue: date)
        XCTAssertEqual(answer.dateValue, date)
    }

    func testSurveyAnswerChoices() {
        let answer = SurveyAnswer(questionId: "q5", selectedChoices: ["A", "C"])
        XCTAssertEqual(answer.selectedChoices, ["A", "C"])
    }

    func testSurveyAnswerCodable() throws {
        let answer = SurveyAnswer(questionId: "q1", textValue: "Test")
        let data = try JSONEncoder().encode(answer)
        let decoded = try JSONDecoder().decode(SurveyAnswer.self, from: data)
        XCTAssertEqual(answer, decoded)
    }

    // MARK: - SurveyResponse Tests

    func testSurveyResponseInit() {
        let response = SurveyResponse(
            surveyId: "s1",
            participantId: "p1"
        )
        XCTAssertEqual(response.surveyId, "s1")
        XCTAssertEqual(response.participantId, "p1")
        XCTAssertTrue(response.answers.isEmpty)
    }

    func testSurveyResponseWithAnswers() {
        let answers = [
            SurveyAnswer(questionId: "q1", textValue: "Yes"),
            SurveyAnswer(questionId: "q2", numericValue: 5)
        ]
        let response = SurveyResponse(
            surveyId: "s1",
            participantId: "p1",
            answers: answers
        )
        XCTAssertEqual(response.answers.count, 2)
    }

    func testSurveyResponseCodable() throws {
        let response = SurveyResponse(
            id: "r-1",
            surveyId: "s1",
            participantId: "p1"
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(SurveyResponse.self, from: data)
        XCTAssertEqual(response, decoded)
    }

    // MARK: - ConsentStatus Tests

    func testConsentStatusRawValues() {
        XCTAssertEqual(ConsentStatus.pending.rawValue, "pending")
        XCTAssertEqual(ConsentStatus.consented.rawValue, "consented")
        XCTAssertEqual(ConsentStatus.declined.rawValue, "declined")
        XCTAssertEqual(ConsentStatus.withdrawn.rawValue, "withdrawn")
        XCTAssertEqual(ConsentStatus.expired.rawValue, "expired")
    }

    // MARK: - ResearchConsent Tests

    func testResearchConsentInit() {
        let consent = ResearchConsent(
            studyId: "study-1",
            participantId: "p-1"
        )
        XCTAssertEqual(consent.studyId, "study-1")
        XCTAssertEqual(consent.status, .pending)
        XCTAssertEqual(consent.consentVersion, "1.0")
        XCTAssertNil(consent.signature)
    }

    func testResearchConsentFull() {
        let consent = ResearchConsent(
            id: "c-1",
            studyId: "study-1",
            participantId: "p-1",
            status: .consented,
            consentVersion: "2.0",
            signature: "sig-data"
        )
        XCTAssertEqual(consent.status, .consented)
        XCTAssertEqual(consent.signature, "sig-data")
    }

    func testResearchConsentCodable() throws {
        let consent = ResearchConsent(
            id: "c-1",
            studyId: "s1",
            participantId: "p1",
            status: .consented
        )
        let data = try JSONEncoder().encode(consent)
        let decoded = try JSONDecoder().decode(ResearchConsent.self, from: data)
        XCTAssertEqual(consent, decoded)
    }

    // MARK: - SyncState Tests

    func testSyncStateRawValues() {
        XCTAssertEqual(SyncState.pending.rawValue, "pending")
        XCTAssertEqual(SyncState.syncing.rawValue, "syncing")
        XCTAssertEqual(SyncState.synced.rawValue, "synced")
        XCTAssertEqual(SyncState.conflict.rawValue, "conflict")
        XCTAssertEqual(SyncState.failed.rawValue, "failed")
    }

    // MARK: - SyncRecord Tests

    func testSyncRecordInit() {
        let payload = Data("test".utf8)
        let record = SyncRecord(
            recordType: "message",
            payload: payload
        )
        XCTAssertEqual(record.recordType, "message")
        XCTAssertEqual(record.payload, payload)
        XCTAssertEqual(record.syncState, .pending)
        XCTAssertEqual(record.version, 1)
        XCTAssertNil(record.zoneId)
    }

    func testSyncRecordFull() {
        let record = SyncRecord(
            id: "sr-1",
            recordType: "patient",
            payload: Data("data".utf8),
            syncState: .synced,
            version: 3,
            zoneId: "zone-1"
        )
        XCTAssertEqual(record.syncState, .synced)
        XCTAssertEqual(record.version, 3)
        XCTAssertEqual(record.zoneId, "zone-1")
    }

    func testSyncRecordCodable() throws {
        let record = SyncRecord(
            id: "sr-1",
            recordType: "msg",
            payload: Data("payload".utf8)
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(SyncRecord.self, from: data)
        XCTAssertEqual(record, decoded)
    }

    // MARK: - ConflictResolutionStrategy Tests

    func testConflictResolutionStrategyRawValues() {
        XCTAssertEqual(ConflictResolutionStrategy.localWins.rawValue, "local_wins")
        XCTAssertEqual(ConflictResolutionStrategy.remoteWins.rawValue, "remote_wins")
        XCTAssertEqual(ConflictResolutionStrategy.mostRecent.rawValue, "most_recent")
        XCTAssertEqual(ConflictResolutionStrategy.manual.rawValue, "manual")
    }

    // MARK: - SyncConflict Tests

    func testSyncConflictInit() {
        let local = SyncRecord(recordType: "msg", payload: Data("local".utf8), version: 1)
        let remote = SyncRecord(recordType: "msg", payload: Data("remote".utf8), version: 2)
        let conflict = SyncConflict(localRecord: local, remoteRecord: remote)
        XCTAssertEqual(conflict.localRecord.version, 1)
        XCTAssertEqual(conflict.remoteRecord.version, 2)
    }

    func testSyncConflictCodable() throws {
        let local = SyncRecord(id: "l1", recordType: "msg", payload: Data("l".utf8))
        let remote = SyncRecord(id: "r1", recordType: "msg", payload: Data("r".utf8))
        let conflict = SyncConflict(localRecord: local, remoteRecord: remote)
        let data = try JSONEncoder().encode(conflict)
        let decoded = try JSONDecoder().decode(SyncConflict.self, from: data)
        XCTAssertEqual(conflict, decoded)
    }

    // MARK: - HandoffActivity Tests

    func testHandoffActivityInit() {
        let activity = HandoffActivity(
            activityType: "com.myapp.viewPatient",
            title: "View Patient"
        )
        XCTAssertEqual(activity.activityType, "com.myapp.viewPatient")
        XCTAssertEqual(activity.title, "View Patient")
        XCTAssertTrue(activity.userInfo.isEmpty)
        XCTAssertTrue(activity.isEligibleForHandoff)
        XCTAssertFalse(activity.isEligibleForSearch)
        XCTAssertFalse(activity.isEligibleForPublicIndexing)
        XCTAssertTrue(activity.keywords.isEmpty)
        XCTAssertNil(activity.webpageURL)
    }

    func testHandoffActivityFull() {
        let activity = HandoffActivity(
            activityType: "com.myapp.viewPatient",
            title: "View Patient",
            userInfo: ["patientId": "123"],
            isEligibleForHandoff: true,
            isEligibleForSearch: true,
            isEligibleForPublicIndexing: false,
            keywords: ["patient", "health"],
            webpageURL: "https://example.com/patient/123"
        )
        XCTAssertEqual(activity.userInfo["patientId"], "123")
        XCTAssertTrue(activity.isEligibleForSearch)
        XCTAssertEqual(activity.keywords.count, 2)
        XCTAssertEqual(activity.webpageURL, "https://example.com/patient/123")
    }

    func testHandoffActivityCodable() throws {
        let activity = HandoffActivity(
            activityType: "com.test",
            title: "Test"
        )
        let data = try JSONEncoder().encode(activity)
        let decoded = try JSONDecoder().decode(HandoffActivity.self, from: data)
        XCTAssertEqual(activity, decoded)
    }

    // MARK: - ShortcutAction Tests

    func testShortcutActionInit() {
        let action = ShortcutAction(
            intentIdentifier: "com.myapp.lookup",
            title: "Lookup Patient"
        )
        XCTAssertEqual(action.intentIdentifier, "com.myapp.lookup")
        XCTAssertEqual(action.title, "Lookup Patient")
        XCTAssertNil(action.suggestedPhrase)
        XCTAssertNil(action.shortcutDescription)
        XCTAssertTrue(action.parameters.isEmpty)
    }

    func testShortcutActionFull() {
        let params = [
            ShortcutParameter(name: "patientId", type: .string),
            ShortcutParameter(name: "includeHistory", type: .boolean, isRequired: false, defaultValue: "false")
        ]
        let action = ShortcutAction(
            id: "sa-1",
            intentIdentifier: "com.myapp.lookup",
            title: "Lookup",
            suggestedPhrase: "Look up patient",
            shortcutDescription: "Looks up a patient",
            parameters: params
        )
        XCTAssertEqual(action.parameters.count, 2)
        XCTAssertEqual(action.suggestedPhrase, "Look up patient")
    }

    func testShortcutActionCodable() throws {
        let action = ShortcutAction(
            id: "sa-1",
            intentIdentifier: "com.test",
            title: "Test"
        )
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(ShortcutAction.self, from: data)
        XCTAssertEqual(action, decoded)
    }

    // MARK: - ShortcutParameter Tests

    func testShortcutParameterDefaults() {
        let param = ShortcutParameter(name: "query")
        XCTAssertEqual(param.name, "query")
        XCTAssertEqual(param.type, .string)
        XCTAssertTrue(param.isRequired)
        XCTAssertNil(param.defaultValue)
    }

    func testShortcutParameterFull() {
        let param = ShortcutParameter(
            name: "count",
            type: .integer,
            isRequired: false,
            defaultValue: "10"
        )
        XCTAssertEqual(param.type, .integer)
        XCTAssertFalse(param.isRequired)
        XCTAssertEqual(param.defaultValue, "10")
    }

    // MARK: - ShortcutParameterType Tests

    func testShortcutParameterTypeRawValues() {
        XCTAssertEqual(ShortcutParameterType.string.rawValue, "string")
        XCTAssertEqual(ShortcutParameterType.integer.rawValue, "integer")
        XCTAssertEqual(ShortcutParameterType.decimal.rawValue, "decimal")
        XCTAssertEqual(ShortcutParameterType.boolean.rawValue, "boolean")
        XCTAssertEqual(ShortcutParameterType.date.rawValue, "date")
        XCTAssertEqual(ShortcutParameterType.url.rawValue, "url")
    }

    // MARK: - ShortcutResult Tests

    func testShortcutResultSuccess() {
        let result = ShortcutResult(
            success: true,
            responseMessage: "Patient found"
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.responseMessage, "Patient found")
        XCTAssertNil(result.outputData)
    }

    func testShortcutResultWithOutput() {
        let result = ShortcutResult(
            success: true,
            responseMessage: "Found",
            outputData: ["name": "John Doe", "mrn": "12345"]
        )
        XCTAssertEqual(result.outputData?["name"], "John Doe")
    }

    func testShortcutResultCodable() throws {
        let result = ShortcutResult(success: false, responseMessage: "Error")
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ShortcutResult.self, from: data)
        XCTAssertEqual(result, decoded)
    }

    // MARK: - PlatformIntegrationManager Tests

    func testManagerInit() async {
        let manager = PlatformIntegrationManager()
        let providers = await manager.registeredProviders()
        XCTAssertTrue(providers.isEmpty)
    }

    func testManagerRegisteredProviders() async {
        let manager = PlatformIntegrationManager()
        let providers = await manager.registeredProviders()
        XCTAssertEqual(providers.count, 0)
    }

    func testManagerNoProviderErrors() async {
        let manager = PlatformIntegrationManager()

        do {
            _ = try await manager.readHealthMeasurements(ofType: "heart_rate", from: Date(), to: Date())
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }

        do {
            let m = HealthMeasurement(measurementType: "hr", value: 72, unit: "bpm")
            try await manager.writeHealthMeasurement(m)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }

        do {
            _ = try await manager.fetchCareTasks(forPatient: "p1")
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }

        do {
            let r = SurveyResponse(surveyId: "s1", participantId: "p1")
            try await manager.submitSurveyResponse(r)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }

        do {
            try await manager.pushToCloud([])
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }

        do {
            let a = HandoffActivity(activityType: "com.test", title: "Test")
            try await manager.registerHandoffActivity(a)
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }

        do {
            _ = try await manager.executeShortcut(withIdentifier: "test")
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }

        do {
            _ = try await manager.startObservingHealth(forType: "hr", handler: { _ in })
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testManagerGetProvidersNilByDefault() async {
        let manager = PlatformIntegrationManager()
        let health = await manager.getHealthDataProvider()
        let care = await manager.getCareDataProvider()
        let research = await manager.getResearchDataProvider()
        let cloud = await manager.getCloudSyncProvider()
        let handoff = await manager.getHandoffProvider()
        let shortcuts = await manager.getShortcutsProvider()
        XCTAssertNil(health)
        XCTAssertNil(care)
        XCTAssertNil(research)
        XCTAssertNil(cloud)
        XCTAssertNil(handoff)
        XCTAssertNil(shortcuts)
    }

    func testManagerObservationManagement() async {
        let manager = PlatformIntegrationManager()
        let count = await manager.activeObservationCount()
        XCTAssertEqual(count, 0)

        await manager.stopObservation(withId: "nonexistent")
        await manager.stopAllObservations()
        let countAfter = await manager.activeObservationCount()
        XCTAssertEqual(countAfter, 0)
    }

    // MARK: - HealthDataMapper Tests

    func testLoincCodes() {
        XCTAssertEqual(HealthDataMapper.loincCode(for: .heartRate), "8867-4")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .bloodPressure), "85354-9")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .bodyTemperature), "8310-5")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .respiratoryRate), "9279-1")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .oxygenSaturation), "2708-6")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .bodyWeight), "29463-7")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .bodyHeight), "8302-2")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .bodyMassIndex), "39156-5")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .bloodGlucose), "2345-7")
        XCTAssertEqual(HealthDataMapper.loincCode(for: .stepCount), "55423-8")
    }

    func testDisplayNames() {
        XCTAssertEqual(HealthDataMapper.displayName(for: .heartRate), "Heart Rate")
        XCTAssertEqual(HealthDataMapper.displayName(for: .bloodPressure), "Blood Pressure")
        XCTAssertEqual(HealthDataMapper.displayName(for: .bodyTemperature), "Body Temperature")
        XCTAssertEqual(HealthDataMapper.displayName(for: .respiratoryRate), "Respiratory Rate")
        XCTAssertEqual(HealthDataMapper.displayName(for: .oxygenSaturation), "Oxygen Saturation")
        XCTAssertEqual(HealthDataMapper.displayName(for: .bodyWeight), "Body Weight")
        XCTAssertEqual(HealthDataMapper.displayName(for: .bodyHeight), "Body Height")
        XCTAssertEqual(HealthDataMapper.displayName(for: .bodyMassIndex), "Body Mass Index")
        XCTAssertEqual(HealthDataMapper.displayName(for: .bloodGlucose), "Blood Glucose")
        XCTAssertEqual(HealthDataMapper.displayName(for: .stepCount), "Step Count")
    }

    func testStandardUnits() {
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .heartRate), "bpm")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .bloodPressure), "mmHg")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .bodyTemperature), "°C")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .respiratoryRate), "breaths/min")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .oxygenSaturation), "%")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .bodyWeight), "kg")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .bodyHeight), "cm")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .bodyMassIndex), "kg/m2")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .bloodGlucose), "mg/dL")
        XCTAssertEqual(HealthDataMapper.standardUnit(for: .stepCount), "steps")
    }

    func testUcumCodes() {
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .heartRate), "/min")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .bloodPressure), "mm[Hg]")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .bodyTemperature), "Cel")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .respiratoryRate), "/min")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .oxygenSaturation), "%")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .bodyWeight), "kg")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .bodyHeight), "cm")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .bodyMassIndex), "kg/m2")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .bloodGlucose), "mg/dL")
        XCTAssertEqual(HealthDataMapper.ucumCode(for: .stepCount), "{steps}")
    }

    func testToVitalSignSuccess() {
        let measurement = HealthMeasurement(
            id: "m1",
            measurementType: "heart_rate",
            value: 72,
            unit: "bpm"
        )
        let vitalSign = HealthDataMapper.toVitalSign(measurement)
        XCTAssertNotNil(vitalSign)
        XCTAssertEqual(vitalSign?.type, .heartRate)
        XCTAssertEqual(vitalSign?.primaryValue, 72)
        XCTAssertEqual(vitalSign?.id, "m1")
    }

    func testToVitalSignInvalidType() {
        let measurement = HealthMeasurement(
            measurementType: "unknown_type",
            value: 42,
            unit: "units"
        )
        let vitalSign = HealthDataMapper.toVitalSign(measurement)
        XCTAssertNil(vitalSign)
    }

    func testToHealthMeasurement() {
        let vs = VitalSign(
            id: "vs-1",
            type: .bodyTemperature,
            primaryValue: 37.0,
            unit: "°C"
        )
        let measurement = HealthDataMapper.toHealthMeasurement(vs)
        XCTAssertEqual(measurement.id, "vs-1")
        XCTAssertEqual(measurement.measurementType, "body_temperature")
        XCTAssertEqual(measurement.value, 37.0)
        XCTAssertEqual(measurement.unit, "°C")
        XCTAssertNil(measurement.source)
        XCTAssertNil(measurement.metadata)
    }

    func testToHealthMeasurementWithSecondary() {
        let vs = VitalSign(
            id: "vs-bp",
            type: .bloodPressure,
            primaryValue: 120,
            secondaryValue: 80,
            unit: "mmHg"
        )
        let measurement = HealthDataMapper.toHealthMeasurement(vs)
        XCTAssertEqual(measurement.metadata?["secondaryValue"], "80.0")
    }

    func testRoundTripConversion() {
        let original = HealthMeasurement(
            id: "rt-1",
            measurementType: "oxygen_saturation",
            value: 98.0,
            unit: "%"
        )
        let vitalSign = HealthDataMapper.toVitalSign(original)
        XCTAssertNotNil(vitalSign)
        let converted = HealthDataMapper.toHealthMeasurement(vitalSign!)
        XCTAssertEqual(converted.id, original.id)
        XCTAssertEqual(converted.measurementType, original.measurementType)
        XCTAssertEqual(converted.value, original.value)
        XCTAssertEqual(converted.unit, original.unit)
    }

    // MARK: - All VitalSignType Mapper Coverage

    func testAllVitalSignTypesHaveLoincCodes() {
        for type in VitalSignType.allCases {
            let code = HealthDataMapper.loincCode(for: type)
            XCTAssertFalse(code.isEmpty, "LOINC code for \(type) should not be empty")
        }
    }

    func testAllVitalSignTypesHaveDisplayNames() {
        for type in VitalSignType.allCases {
            let name = HealthDataMapper.displayName(for: type)
            XCTAssertFalse(name.isEmpty, "Display name for \(type) should not be empty")
        }
    }

    func testAllVitalSignTypesHaveStandardUnits() {
        for type in VitalSignType.allCases {
            let unit = HealthDataMapper.standardUnit(for: type)
            XCTAssertFalse(unit.isEmpty, "Standard unit for \(type) should not be empty")
        }
    }

    func testAllVitalSignTypesHaveUcumCodes() {
        for type in VitalSignType.allCases {
            let code = HealthDataMapper.ucumCode(for: type)
            XCTAssertFalse(code.isEmpty, "UCUM code for \(type) should not be empty")
        }
    }

    // MARK: - Hashable/Equatable Additional Tests

    func testVitalSignHashable() {
        let date = Date()
        let vs1 = VitalSign(id: "v1", type: .heartRate, primaryValue: 72, unit: "bpm", timestamp: date)
        let vs2 = VitalSign(id: "v1", type: .heartRate, primaryValue: 72, unit: "bpm", timestamp: date)
        XCTAssertEqual(vs1, vs2)

        let set: Set<VitalSign> = [vs1, vs2]
        XCTAssertEqual(set.count, 1)
    }

    func testSyncRecordHashable() {
        let date = Date()
        let r1 = SyncRecord(id: "s1", recordType: "msg", payload: Data("a".utf8), lastModified: date)
        let r2 = SyncRecord(id: "s1", recordType: "msg", payload: Data("a".utf8), lastModified: date)
        XCTAssertEqual(r1, r2)
    }

    func testHandoffActivityHashable() {
        let a1 = HandoffActivity(activityType: "com.test", title: "T", userInfo: ["k": "v"])
        let a2 = HandoffActivity(activityType: "com.test", title: "T", userInfo: ["k": "v"])
        XCTAssertEqual(a1, a2)
    }

    func testShortcutResultHashable() {
        let r1 = ShortcutResult(success: true, responseMessage: "OK")
        let r2 = ShortcutResult(success: true, responseMessage: "OK")
        XCTAssertEqual(r1, r2)
        let r3 = ShortcutResult(success: false, responseMessage: "Fail")
        XCTAssertNotEqual(r1, r3)
    }
}
