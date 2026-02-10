/// FHIRSubscriptionsTests.swift
/// Tests for FHIR Subscriptions & Real-time (Phase 6.4)

import XCTest
import Foundation
@testable import FHIRkit
@testable import HL7Core

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Mock URL Session

/// Mock URL session for subscription tests
private final class MockSubscriptionSession: FHIRURLSession, @unchecked Sendable {
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var shouldThrowError: Bool = false
    var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if shouldThrowError {
            throw URLError(.notConnectedToInternet)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: responseStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }

    func reset() {
        responseData = Data()
        responseStatusCode = 200
        shouldThrowError = false
        requests = []
    }
}

// MARK: - FHIRSubscriptionError Tests

final class FHIRSubscriptionErrorTests: XCTestCase {
    func testErrorDescriptions() {
        let errors: [(FHIRSubscriptionError, String)] = [
            (.invalidConfiguration("bad config"), "Invalid subscription configuration: bad config"),
            (.connectionFailed("timeout"), "Subscription connection failed: timeout"),
            (.subscriptionRejected("denied"), "Subscription rejected: denied"),
            (.channelError("closed"), "Channel error: closed"),
            (.handshakeFailed("mismatch"), "Handshake failed: mismatch"),
            (.notificationError("bad payload"), "Notification error: bad payload"),
            (.reconnectionFailed("exhausted"), "Reconnection failed: exhausted"),
            (.eventFilterError("invalid"), "Event filter error: invalid"),
            (.serverError(statusCode: 500, data: nil), "Server error: HTTP 500"),
            (.networkError("offline"), "Network error: offline"),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.description, expected)
        }
    }

    func testErrorConformsToErrorProtocol() {
        let error: Error = FHIRSubscriptionError.networkError("test")
        XCTAssertNotNil(error)
    }
}

// MARK: - SubscriptionStatus Tests

final class SubscriptionStatusTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(SubscriptionStatus.requested.rawValue, "requested")
        XCTAssertEqual(SubscriptionStatus.active.rawValue, "active")
        XCTAssertEqual(SubscriptionStatus.error.rawValue, "error")
        XCTAssertEqual(SubscriptionStatus.off.rawValue, "off")
    }

    func testAllCases() {
        XCTAssertEqual(SubscriptionStatus.allCases.count, 4)
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for status in SubscriptionStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(SubscriptionStatus.self, from: data)
            XCTAssertEqual(status, decoded)
        }
    }
}

// MARK: - SubscriptionPayloadContent Tests

final class SubscriptionPayloadContentTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(SubscriptionPayloadContent.empty.rawValue, "empty")
        XCTAssertEqual(SubscriptionPayloadContent.idOnly.rawValue, "id-only")
        XCTAssertEqual(SubscriptionPayloadContent.fullResource.rawValue, "full-resource")
    }

    func testAllCases() {
        XCTAssertEqual(SubscriptionPayloadContent.allCases.count, 3)
    }
}

// MARK: - SubscriptionChannelType Tests

final class SubscriptionChannelTypeTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(SubscriptionChannelType.restHook.rawValue, "rest-hook")
        XCTAssertEqual(SubscriptionChannelType.websocket.rawValue, "websocket")
        XCTAssertEqual(SubscriptionChannelType.email.rawValue, "email")
        XCTAssertEqual(SubscriptionChannelType.message.rawValue, "message")
    }

    func testAllCases() {
        XCTAssertEqual(SubscriptionChannelType.allCases.count, 4)
    }
}

// MARK: - FHIRSubscriptionTopic Tests

final class FHIRSubscriptionTopicTests: XCTestCase {
    func testTopicCreation() {
        let trigger = TopicResourceTrigger(
            description: "Patient changes",
            resource: "Patient",
            supportedInteraction: [.create, .update],
            queryCriteria: nil
        )
        let topic = FHIRSubscriptionTopic(
            id: "topic-1",
            url: "http://example.org/topic/patient-changes",
            title: "Patient Changes",
            description: "Notifications for patient resource changes",
            status: .active,
            resourceTriggers: [trigger]
        )

        XCTAssertEqual(topic.id, "topic-1")
        XCTAssertEqual(topic.url, "http://example.org/topic/patient-changes")
        XCTAssertEqual(topic.title, "Patient Changes")
        XCTAssertEqual(topic.status, .active)
        XCTAssertEqual(topic.resourceTriggers.count, 1)
        XCTAssertEqual(topic.resourceTriggers[0].resource, "Patient")
        XCTAssertEqual(topic.resourceTriggers[0].supportedInteraction, [.create, .update])
    }

    func testTopicCodable() throws {
        let trigger = TopicResourceTrigger(
            description: "Observation created",
            resource: "Observation",
            supportedInteraction: [.create],
            queryCriteria: QueryCriteria(
                resultForCreate: .testPasses,
                current: "status = 'final'"
            )
        )
        let topic = FHIRSubscriptionTopic(
            id: "topic-2",
            url: "http://example.org/topic/observations",
            title: "Observations",
            status: .active,
            resourceTriggers: [trigger]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(topic)
        let decoded = try decoder.decode(FHIRSubscriptionTopic.self, from: data)

        XCTAssertEqual(topic, decoded)
    }

    func testTopicDefaultValues() {
        let topic = FHIRSubscriptionTopic(
            id: "t1",
            url: "http://example.org/t1"
        )
        XCTAssertNil(topic.title)
        XCTAssertNil(topic.description)
        XCTAssertEqual(topic.status, .active)
        XCTAssertTrue(topic.resourceTriggers.isEmpty)
    }
}

// MARK: - TopicResourceTrigger Tests

final class TopicResourceTriggerTests: XCTestCase {
    func testTriggerCreation() {
        let trigger = TopicResourceTrigger(
            description: "Encounter updates",
            resource: "Encounter",
            supportedInteraction: [.create, .update, .delete]
        )
        XCTAssertEqual(trigger.resource, "Encounter")
        XCTAssertEqual(trigger.supportedInteraction.count, 3)
        XCTAssertNil(trigger.queryCriteria)
    }

    func testTriggerWithQueryCriteria() {
        let criteria = QueryCriteria(
            previous: "status = 'active'",
            resultForCreate: .testPasses,
            current: "status = 'finished'",
            resultForDelete: .testFails,
            requireBoth: true
        )
        let trigger = TopicResourceTrigger(
            resource: "Encounter",
            supportedInteraction: [.update],
            queryCriteria: criteria
        )
        XCTAssertNotNil(trigger.queryCriteria)
        XCTAssertEqual(trigger.queryCriteria?.previous, "status = 'active'")
        XCTAssertEqual(trigger.queryCriteria?.current, "status = 'finished'")
        XCTAssertEqual(trigger.queryCriteria?.requireBoth, true)
        XCTAssertEqual(trigger.queryCriteria?.resultForCreate, .testPasses)
        XCTAssertEqual(trigger.queryCriteria?.resultForDelete, .testFails)
    }
}

// MARK: - QueryCriteria Tests

final class QueryCriteriaTests: XCTestCase {
    func testQueryCriteriaCodable() throws {
        let criteria = QueryCriteria(
            previous: "status = 'draft'",
            resultForCreate: .testPasses,
            current: "status = 'active'",
            resultForDelete: .testFails,
            requireBoth: false
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(criteria)
        let decoded = try decoder.decode(QueryCriteria.self, from: data)

        XCTAssertEqual(criteria, decoded)
    }

    func testQueryResultBehaviorRawValues() {
        XCTAssertEqual(QueryResultBehavior.testPasses.rawValue, "test-passes")
        XCTAssertEqual(QueryResultBehavior.testFails.rawValue, "test-fails")
    }
}

// MARK: - FilterCriteria Tests

final class FilterCriteriaTests: XCTestCase {
    func testFilterCriteriaCreation() {
        let filter = FilterCriteria(
            resourceType: "Patient",
            filterParameter: "address-state",
            comparator: "eq",
            modifier: nil,
            value: "CA"
        )

        XCTAssertEqual(filter.resourceType, "Patient")
        XCTAssertEqual(filter.filterParameter, "address-state")
        XCTAssertEqual(filter.comparator, "eq")
        XCTAssertNil(filter.modifier)
        XCTAssertEqual(filter.value, "CA")
    }

    func testFilterCriteriaCodable() throws {
        let filter = FilterCriteria(
            resourceType: "Observation",
            filterParameter: "code",
            comparator: "eq",
            modifier: "exact",
            value: "8867-4"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(filter)
        let decoded = try decoder.decode(FilterCriteria.self, from: data)

        XCTAssertEqual(filter, decoded)
    }

    func testFilterCriteriaEquality() {
        let f1 = FilterCriteria(filterParameter: "code", value: "123")
        let f2 = FilterCriteria(filterParameter: "code", value: "123")
        let f3 = FilterCriteria(filterParameter: "code", value: "456")

        XCTAssertEqual(f1, f2)
        XCTAssertNotEqual(f1, f3)
    }
}

// MARK: - FHIRSubscription Tests

final class FHIRSubscriptionTests: XCTestCase {
    func testSubscriptionCreation() {
        let subscription = FHIRSubscription(
            id: "sub-1",
            status: .requested,
            topic: URL(string: "http://example.org/topic/patient")!,
            reason: "Monitor patient changes",
            filterBy: [FilterCriteria(filterParameter: "address-state", value: "CA")],
            channelType: .restHook,
            endpoint: URL(string: "https://my-app.example.org/notifications")!,
            heartbeatPeriod: 60,
            timeout: 3600,
            contentType: "application/fhir+json",
            content: .fullResource
        )

        XCTAssertEqual(subscription.id, "sub-1")
        XCTAssertEqual(subscription.status, .requested)
        XCTAssertEqual(subscription.topic.absoluteString, "http://example.org/topic/patient")
        XCTAssertEqual(subscription.reason, "Monitor patient changes")
        XCTAssertEqual(subscription.filterBy.count, 1)
        XCTAssertEqual(subscription.channelType, .restHook)
        XCTAssertNotNil(subscription.endpoint)
        XCTAssertEqual(subscription.heartbeatPeriod, 60)
        XCTAssertEqual(subscription.timeout, 3600)
        XCTAssertEqual(subscription.content, .fullResource)
    }

    func testSubscriptionCodable() throws {
        let subscription = FHIRSubscription(
            id: "sub-2",
            status: .active,
            topic: URL(string: "http://example.org/topic/encounter")!,
            channelType: .websocket,
            endpoint: URL(string: "wss://fhir.example.org/ws")!,
            content: .idOnly
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(subscription)
        let decoded = try decoder.decode(FHIRSubscription.self, from: data)

        XCTAssertEqual(subscription, decoded)
    }

    func testSubscriptionDefaultValues() {
        let subscription = FHIRSubscription(
            topic: URL(string: "http://example.org/topic")!
        )

        XCTAssertNil(subscription.id)
        XCTAssertEqual(subscription.status, .requested)
        XCTAssertTrue(subscription.filterBy.isEmpty)
        XCTAssertEqual(subscription.channelType, .restHook)
        XCTAssertNil(subscription.endpoint)
        XCTAssertNil(subscription.heartbeatPeriod)
        XCTAssertNil(subscription.timeout)
        XCTAssertNil(subscription.contentType)
        XCTAssertEqual(subscription.content, .idOnly)
    }
}

// MARK: - WebSocketMessage Tests

final class WebSocketMessageTests: XCTestCase {
    func testTextMessage() {
        let message = WebSocketMessage.text("hello")
        if case .text(let text) = message {
            XCTAssertEqual(text, "hello")
        } else {
            XCTFail("Expected text message")
        }
    }

    func testDataMessage() {
        let payload = Data([0x01, 0x02, 0x03])
        let message = WebSocketMessage.data(payload)
        if case .data(let data) = message {
            XCTAssertEqual(data, payload)
        } else {
            XCTFail("Expected data message")
        }
    }

    func testEquality() {
        XCTAssertEqual(WebSocketMessage.text("a"), WebSocketMessage.text("a"))
        XCTAssertNotEqual(WebSocketMessage.text("a"), WebSocketMessage.text("b"))
        XCTAssertEqual(WebSocketMessage.data(Data([1])), WebSocketMessage.data(Data([1])))
        XCTAssertNotEqual(WebSocketMessage.text("a"), WebSocketMessage.data(Data()))
    }
}

// MARK: - ConnectionState Tests

final class ConnectionStateTests: XCTestCase {
    func testAllCases() {
        let expected: Set<ConnectionState> = [
            .disconnected, .connecting, .connected, .reconnecting, .failed
        ]
        XCTAssertEqual(Set(ConnectionState.allCases), expected)
    }

    func testRawValues() {
        XCTAssertEqual(ConnectionState.disconnected.rawValue, "disconnected")
        XCTAssertEqual(ConnectionState.connecting.rawValue, "connecting")
        XCTAssertEqual(ConnectionState.connected.rawValue, "connected")
        XCTAssertEqual(ConnectionState.reconnecting.rawValue, "reconnecting")
        XCTAssertEqual(ConnectionState.failed.rawValue, "failed")
    }
}

// MARK: - ReconnectionStrategy Tests

final class ReconnectionStrategyTests: XCTestCase {
    func testDefaultStrategy() {
        let strategy = ReconnectionStrategy.default
        XCTAssertEqual(strategy.maxAttempts, 5)
        XCTAssertEqual(strategy.initialDelay, 1.0)
        XCTAssertEqual(strategy.maxDelay, 60.0)
        XCTAssertEqual(strategy.backoffMultiplier, 2.0)
        XCTAssertTrue(strategy.jitter)
    }

    func testAggressiveStrategy() {
        let strategy = ReconnectionStrategy.aggressive
        XCTAssertEqual(strategy.maxAttempts, 10)
        XCTAssertEqual(strategy.initialDelay, 0.5)
        XCTAssertEqual(strategy.maxDelay, 30.0)
        XCTAssertEqual(strategy.backoffMultiplier, 1.5)
    }

    func testConservativeStrategy() {
        let strategy = ReconnectionStrategy.conservative
        XCTAssertEqual(strategy.maxAttempts, 3)
        XCTAssertEqual(strategy.initialDelay, 5.0)
        XCTAssertEqual(strategy.maxDelay, 120.0)
        XCTAssertEqual(strategy.backoffMultiplier, 3.0)
    }

    func testNoRetryStrategy() {
        let strategy = ReconnectionStrategy.noRetry
        XCTAssertEqual(strategy.maxAttempts, 0)
        XCTAssertEqual(strategy.initialDelay, 0)
        XCTAssertEqual(strategy.maxDelay, 0)
    }

    func testDelayForAttemptWithoutJitter() {
        let strategy = ReconnectionStrategy(
            maxAttempts: 5,
            initialDelay: 1.0,
            maxDelay: 60.0,
            backoffMultiplier: 2.0,
            jitter: false
        )

        XCTAssertEqual(strategy.delayForAttempt(0), 1.0)
        XCTAssertEqual(strategy.delayForAttempt(1), 2.0)
        XCTAssertEqual(strategy.delayForAttempt(2), 4.0)
        XCTAssertEqual(strategy.delayForAttempt(3), 8.0)
        XCTAssertEqual(strategy.delayForAttempt(4), 16.0)
    }

    func testDelayClampedToMaxDelay() {
        let strategy = ReconnectionStrategy(
            maxAttempts: 10,
            initialDelay: 1.0,
            maxDelay: 10.0,
            backoffMultiplier: 2.0,
            jitter: false
        )

        XCTAssertEqual(strategy.delayForAttempt(5), 10.0) // 2^5 = 32, clamped to 10
        XCTAssertEqual(strategy.delayForAttempt(10), 10.0)
    }

    func testDelayWithJitterInRange() {
        let strategy = ReconnectionStrategy(
            maxAttempts: 5,
            initialDelay: 10.0,
            maxDelay: 100.0,
            backoffMultiplier: 2.0,
            jitter: true
        )

        // Run multiple times to verify jitter stays in range
        for _ in 0..<20 {
            let delay = strategy.delayForAttempt(0)
            // base = 10.0, jitter range = 2.5, so delay should be in [7.5, 12.5]
            XCTAssertGreaterThanOrEqual(delay, 7.5)
            XCTAssertLessThanOrEqual(delay, 12.5)
        }
    }

    func testDelayForNegativeAttempt() {
        let strategy = ReconnectionStrategy(jitter: false)
        XCTAssertEqual(strategy.delayForAttempt(-1), 0)
    }

    func testDelayForNoRetryStrategy() {
        let strategy = ReconnectionStrategy.noRetry
        XCTAssertEqual(strategy.delayForAttempt(0), 0)
    }

    func testEquality() {
        let s1 = ReconnectionStrategy.default
        let s2 = ReconnectionStrategy.default
        XCTAssertEqual(s1, s2)
        XCTAssertNotEqual(ReconnectionStrategy.default, ReconnectionStrategy.aggressive)
    }
}

// MARK: - SubscriptionNotification Tests

final class SubscriptionNotificationTests: XCTestCase {
    func testNotificationCreation() {
        let entry = NotificationEntry(
            fullUrl: "http://example.org/Patient/123",
            resourceData: "{}".data(using: .utf8),
            method: "PUT"
        )
        let notification = SubscriptionNotification(
            subscriptionId: "sub-1",
            topic: "http://example.org/topic/patient",
            type: .eventNotification,
            eventsSinceSubscriptionStart: 5,
            eventsInNotification: 1,
            focus: [entry]
        )

        XCTAssertEqual(notification.subscriptionId, "sub-1")
        XCTAssertEqual(notification.topic, "http://example.org/topic/patient")
        XCTAssertEqual(notification.type, .eventNotification)
        XCTAssertEqual(notification.eventsSinceSubscriptionStart, 5)
        XCTAssertEqual(notification.eventsInNotification, 1)
        XCTAssertEqual(notification.focus.count, 1)
        XCTAssertEqual(notification.focus[0].fullUrl, "http://example.org/Patient/123")
        XCTAssertEqual(notification.focus[0].method, "PUT")
    }

    func testNotificationTypeRawValues() {
        XCTAssertEqual(SubscriptionNotificationType.handshake.rawValue, "handshake")
        XCTAssertEqual(SubscriptionNotificationType.heartbeat.rawValue, "heartbeat")
        XCTAssertEqual(SubscriptionNotificationType.eventNotification.rawValue, "event-notification")
        XCTAssertEqual(SubscriptionNotificationType.queryStatus.rawValue, "query-status")
        XCTAssertEqual(SubscriptionNotificationType.queryEvent.rawValue, "query-event")
    }

    func testNotificationDefaults() {
        let notification = SubscriptionNotification(
            subscriptionId: "sub-2",
            type: .heartbeat
        )
        XCTAssertNil(notification.topic)
        XCTAssertEqual(notification.eventsSinceSubscriptionStart, 0)
        XCTAssertEqual(notification.eventsInNotification, 0)
        XCTAssertTrue(notification.focus.isEmpty)
    }
}

// MARK: - RESTHookHandler Tests

final class RESTHookHandlerTests: XCTestCase {
    func testRegisterAndUnregisterHandler() async {
        let handler = RESTHookHandler()
        await handler.registerHandler(subscriptionId: "sub-1") { _ in }
        let handlers = await handler.registeredHandlers
        XCTAssertTrue(handlers.keys.contains("sub-1"))

        await handler.unregisterHandler(subscriptionId: "sub-1")
        let updatedHandlers = await handler.registeredHandlers
        XCTAssertFalse(updatedHandlers.keys.contains("sub-1"))
    }

    func testProcessNotificationWithoutHandler() async {
        let handler = RESTHookHandler()
        let data = "{}".data(using: .utf8)!

        do {
            try await handler.processNotification(subscriptionId: "unknown", payload: data)
            XCTFail("Should throw error")
        } catch let error as FHIRSubscriptionError {
            if case .notificationError(let message) = error {
                XCTAssertTrue(message.contains("No handler registered"))
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testProcessNotificationBundle() async throws {
        let handler = RESTHookHandler()
        let bundleJSON = """
        {
            "resourceType": "Bundle",
            "type": "subscription-notification",
            "entry": [
                {
                    "resource": {
                        "resourceType": "SubscriptionStatus",
                        "type": "event-notification",
                        "subscription": {
                            "reference": "Subscription/sub-123"
                        },
                        "topic": "http://example.org/topic/patient",
                        "eventsSinceSubscriptionStart": 10
                    }
                },
                {
                    "fullUrl": "http://example.org/Patient/456",
                    "resource": {
                        "resourceType": "Patient",
                        "id": "456"
                    },
                    "request": {
                        "method": "PUT",
                        "url": "Patient/456"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let notification = try await handler.processNotificationBundle(data: bundleJSON)

        XCTAssertEqual(notification.subscriptionId, "sub-123")
        XCTAssertEqual(notification.topic, "http://example.org/topic/patient")
        XCTAssertEqual(notification.type, .eventNotification)
        XCTAssertEqual(notification.eventsSinceSubscriptionStart, 10)
        XCTAssertEqual(notification.eventsInNotification, 1)
        XCTAssertEqual(notification.focus.count, 1)
        XCTAssertEqual(notification.focus[0].fullUrl, "http://example.org/Patient/456")
        XCTAssertEqual(notification.focus[0].method, "PUT")
        XCTAssertNotNil(notification.focus[0].resourceData)
    }

    func testProcessInvalidNotificationBundle() async {
        let handler = RESTHookHandler()
        let badData = "not json".data(using: .utf8)!

        do {
            _ = try await handler.processNotificationBundle(data: badData)
            XCTFail("Should throw error")
        } catch let error as FHIRSubscriptionError {
            if case .notificationError(let message) = error {
                XCTAssertTrue(message.contains("Invalid notification JSON"))
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

// MARK: - SubscriptionEventFilter Tests

final class SubscriptionEventFilterTests: XCTestCase {
    func testEmptyFilterMatchesAll() {
        let filter = SubscriptionEventFilter()
        let notification = SubscriptionNotification(
            subscriptionId: "sub-1",
            type: .eventNotification,
            focus: [NotificationEntry(fullUrl: "http://example.org/Patient/123")]
        )
        XCTAssertTrue(filter.matches(notification: notification))
    }

    func testFilterMatchesHeartbeat() {
        let filter = SubscriptionEventFilter(resourceTypes: ["Patient"])
        let notification = SubscriptionNotification(
            subscriptionId: "sub-1",
            type: .heartbeat
        )
        XCTAssertTrue(filter.matches(notification: notification))
    }

    func testFilterMatchesHandshake() {
        let filter = SubscriptionEventFilter(resourceTypes: ["Patient"])
        let notification = SubscriptionNotification(
            subscriptionId: "sub-1",
            type: .handshake
        )
        XCTAssertTrue(filter.matches(notification: notification))
    }

    func testFilterMatchesResourceType() {
        let filter = SubscriptionEventFilter(resourceTypes: ["Patient"])
        let matching = SubscriptionNotification(
            subscriptionId: "sub-1",
            type: .eventNotification,
            focus: [NotificationEntry(fullUrl: "http://example.org/Patient/123")]
        )
        let nonMatching = SubscriptionNotification(
            subscriptionId: "sub-1",
            type: .eventNotification,
            focus: [NotificationEntry(fullUrl: "http://example.org/Observation/456")]
        )

        XCTAssertTrue(filter.matches(notification: matching))
        XCTAssertFalse(filter.matches(notification: nonMatching))
    }

    func testMatchesResourceType() {
        let filter = SubscriptionEventFilter(resourceTypes: ["Patient", "Observation"])
        XCTAssertTrue(filter.matchesResourceType("Patient"))
        XCTAssertTrue(filter.matchesResourceType("Observation"))
        XCTAssertFalse(filter.matchesResourceType("Encounter"))
    }

    func testEmptyResourceTypesMatchesAll() {
        let filter = SubscriptionEventFilter()
        XCTAssertTrue(filter.matchesResourceType("AnyType"))
    }

    func testAddCriteria() {
        let filter = SubscriptionEventFilter(resourceTypes: ["Patient"])
        let criteria = FilterCriteria(filterParameter: "code", value: "123")
        let newFilter = filter.addCriteria(criteria)

        XCTAssertEqual(newFilter.criteria.count, 1)
        XCTAssertEqual(newFilter.criteria[0].filterParameter, "code")
        XCTAssertEqual(newFilter.resourceTypes, ["Patient"])
    }

    func testWithResourceTypes() {
        let filter = SubscriptionEventFilter(
            criteria: [FilterCriteria(filterParameter: "code", value: "123")]
        )
        let newFilter = filter.withResourceTypes(["Encounter"])

        XCTAssertEqual(newFilter.resourceTypes, ["Encounter"])
        XCTAssertEqual(newFilter.criteria.count, 1)
    }
}

// MARK: - EventFilterBuilder Tests

final class EventFilterBuilderTests: XCTestCase {
    func testBuildEmptyFilter() {
        let filter = EventFilterBuilder().build()
        XCTAssertTrue(filter.resourceTypes.isEmpty)
        XCTAssertTrue(filter.criteria.isEmpty)
    }

    func testBuildWithResourceType() {
        let filter = EventFilterBuilder()
            .forResourceType("Patient")
            .forResourceType("Observation")
            .build()

        XCTAssertEqual(filter.resourceTypes, ["Patient", "Observation"])
    }

    func testBuildWithCriteria() {
        let criteria = FilterCriteria(filterParameter: "status", value: "active")
        let filter = EventFilterBuilder()
            .forResourceType("Patient")
            .withCriteria(criteria)
            .build()

        XCTAssertEqual(filter.resourceTypes, ["Patient"])
        XCTAssertEqual(filter.criteria.count, 1)
        XCTAssertEqual(filter.criteria[0].value, "active")
    }
}

// MARK: - FHIRSubscriptionManager Tests

final class FHIRSubscriptionManagerTests: XCTestCase {
    private var mockSession: MockSubscriptionSession!
    private var manager: FHIRSubscriptionManager!

    override func setUp() {
        super.setUp()
        mockSession = MockSubscriptionSession()
        manager = FHIRSubscriptionManager(
            session: mockSession,
            baseURL: URL(string: "https://fhir.example.org/r5")!
        )
    }

    func testCreateSubscription() async throws {
        let responseSubscription = FHIRSubscription(
            id: "sub-created",
            status: .active,
            topic: URL(string: "http://example.org/topic")!,
            channelType: .restHook,
            content: .idOnly
        )
        mockSession.responseData = try JSONEncoder().encode(responseSubscription)
        mockSession.responseStatusCode = 201

        let subscription = FHIRSubscription(
            status: .requested,
            topic: URL(string: "http://example.org/topic")!,
            channelType: .restHook
        )
        let created = try await manager.createSubscription(subscription)

        XCTAssertEqual(created.id, "sub-created")
        XCTAssertEqual(created.status, .active)
        XCTAssertEqual(mockSession.requests.count, 1)
        XCTAssertEqual(mockSession.requests[0].httpMethod, "POST")
        XCTAssertTrue(mockSession.requests[0].url!.absoluteString.contains("Subscription"))
    }

    func testGetSubscription() async throws {
        let sub = FHIRSubscription(
            id: "sub-get",
            status: .active,
            topic: URL(string: "http://example.org/topic")!,
            content: .fullResource
        )
        mockSession.responseData = try JSONEncoder().encode(sub)

        let result = try await manager.getSubscription(id: "sub-get")
        XCTAssertEqual(result.id, "sub-get")
        XCTAssertEqual(result.status, .active)
        XCTAssertTrue(mockSession.requests[0].url!.absoluteString.contains("Subscription/sub-get"))
    }

    func testDeleteSubscription() async throws {
        mockSession.responseData = Data()
        mockSession.responseStatusCode = 204

        // First create so it's tracked
        let sub = FHIRSubscription(
            id: "sub-del",
            status: .active,
            topic: URL(string: "http://example.org/topic")!,
            content: .idOnly
        )
        mockSession.responseData = try JSONEncoder().encode(sub)
        mockSession.responseStatusCode = 201
        _ = try await manager.createSubscription(sub)

        mockSession.responseData = Data()
        mockSession.responseStatusCode = 204
        try await manager.deleteSubscription(id: "sub-del")

        let active = await manager.activeSubscriptions
        XCTAssertNil(active["sub-del"])
    }

    func testStopAll() async throws {
        let sub = FHIRSubscription(
            id: "sub-stop",
            status: .active,
            topic: URL(string: "http://example.org/topic")!,
            content: .idOnly
        )
        mockSession.responseData = try JSONEncoder().encode(sub)
        mockSession.responseStatusCode = 201
        _ = try await manager.createSubscription(sub)

        await manager.stopAll()
        let active = await manager.activeSubscriptions
        XCTAssertTrue(active.isEmpty)
    }

    func testGetSubscriptionStatus() async throws {
        let sub = FHIRSubscription(
            id: "sub-status",
            status: .error,
            topic: URL(string: "http://example.org/topic")!,
            content: .idOnly
        )
        mockSession.responseData = try JSONEncoder().encode(sub)

        let status = try await manager.getSubscriptionStatus(id: "sub-status")
        XCTAssertEqual(status, .error)
    }

    func testServerErrorThrows() async {
        mockSession.responseStatusCode = 500
        mockSession.responseData = Data()

        do {
            _ = try await manager.getSubscription(id: "bad")
            XCTFail("Should throw")
        } catch let error as FHIRSubscriptionError {
            if case .serverError(let code, _) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testAuthorizationErrorThrows() async {
        mockSession.responseStatusCode = 401
        mockSession.responseData = Data()

        do {
            _ = try await manager.getSubscription(id: "auth-fail")
            XCTFail("Should throw")
        } catch let error as FHIRSubscriptionError {
            if case .subscriptionRejected = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

// MARK: - WebSocketTransport Tests

final class WebSocketTransportTests: XCTestCase {
    func testInitialState() async {
        let transport = WebSocketTransport(
            url: URL(string: "wss://example.org/ws")!,
            maxReconnectAttempts: 3,
            reconnectDelay: 2.0
        )
        let isConnected = await transport.isConnected
        let state = await transport.connectionState
        let attempts = await transport.reconnectAttempts

        XCTAssertFalse(isConnected)
        XCTAssertEqual(state, .disconnected)
        XCTAssertEqual(attempts, 0)
    }

    func testDisconnect() async {
        let transport = WebSocketTransport(url: URL(string: "wss://example.org/ws")!)
        await transport.disconnect()
        let isConnected = await transport.isConnected
        let state = await transport.connectionState

        XCTAssertFalse(isConnected)
        XCTAssertEqual(state, .disconnected)
    }

    func testSendWithoutConnectionThrows() async {
        let transport = WebSocketTransport(url: URL(string: "wss://example.org/ws")!)
        do {
            try await transport.send(message: .text("hello"))
            XCTFail("Should throw")
        } catch let error as FHIRSubscriptionError {
            if case .channelError(let msg) = error {
                XCTAssertEqual(msg, "Not connected")
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testReceiveReturnsStream() async {
        let transport = WebSocketTransport(url: URL(string: "wss://example.org/ws")!)
        let stream = await transport.receive()
        XCTAssertNotNil(stream)
    }
}

// MARK: - TopicInteraction Tests

final class TopicInteractionTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(TopicInteraction.create.rawValue, "create")
        XCTAssertEqual(TopicInteraction.update.rawValue, "update")
        XCTAssertEqual(TopicInteraction.delete.rawValue, "delete")
    }

    func testAllCases() {
        XCTAssertEqual(TopicInteraction.allCases.count, 3)
    }
}

// MARK: - NotificationEntry Tests

final class NotificationEntryTests: XCTestCase {
    func testEntryCodable() throws {
        let entry = NotificationEntry(
            fullUrl: "http://example.org/Patient/123",
            resourceData: "{\"id\":\"123\"}".data(using: .utf8),
            method: "POST"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(entry)
        let decoded = try decoder.decode(NotificationEntry.self, from: data)

        XCTAssertEqual(entry, decoded)
    }

    func testEntryDefaults() {
        let entry = NotificationEntry()
        XCTAssertNil(entry.fullUrl)
        XCTAssertNil(entry.resourceData)
        XCTAssertNil(entry.method)
    }
}
