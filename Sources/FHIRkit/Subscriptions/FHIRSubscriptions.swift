/// FHIRSubscriptions.swift
/// FHIR Subscriptions & Real-time implementation (Phase 6.4)
///
/// Provides R5 topic-based subscription management, WebSocket transport,
/// REST-hook notification handling, event filtering, and reconnection
/// strategies for real-time FHIR data exchange.
///
/// See: http://hl7.org/fhir/R5/subscriptions.html
/// See: http://hl7.org/fhir/R5/subscription.html

import Foundation
import HL7Core

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Subscription Errors

/// Errors that can occur during FHIR subscription operations
public enum FHIRSubscriptionError: Error, Sendable, CustomStringConvertible {
    /// The subscription configuration is invalid or incomplete
    case invalidConfiguration(String)
    /// The WebSocket or REST-hook connection could not be established
    case connectionFailed(String)
    /// The server rejected the subscription request
    case subscriptionRejected(String)
    /// An error occurred on the subscription channel
    case channelError(String)
    /// The WebSocket handshake failed
    case handshakeFailed(String)
    /// An error occurred while processing a notification
    case notificationError(String)
    /// Reconnection attempts have been exhausted
    case reconnectionFailed(String)
    /// The event filter configuration is invalid
    case eventFilterError(String)
    /// The FHIR server returned an error
    case serverError(statusCode: Int, data: Data?)
    /// A network-level error occurred
    case networkError(String)

    public var description: String {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid subscription configuration: \(message)"
        case .connectionFailed(let message):
            return "Subscription connection failed: \(message)"
        case .subscriptionRejected(let message):
            return "Subscription rejected: \(message)"
        case .channelError(let message):
            return "Channel error: \(message)"
        case .handshakeFailed(let message):
            return "Handshake failed: \(message)"
        case .notificationError(let message):
            return "Notification error: \(message)"
        case .reconnectionFailed(let message):
            return "Reconnection failed: \(message)"
        case .eventFilterError(let message):
            return "Event filter error: \(message)"
        case .serverError(let statusCode, _):
            return "Server error: HTTP \(statusCode)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Subscription Status

/// Status of a FHIR Subscription resource
public enum SubscriptionStatus: String, Sendable, Codable, CaseIterable {
    /// The client has requested the subscription and the server has not yet set it up
    case requested
    /// The subscription is active and notifications are being sent
    case active
    /// The subscription has encountered an error
    case error
    /// The subscription has been turned off by the server or client
    case off
}

// MARK: - Subscription Payload Content

/// Level of detail included in subscription notification payloads
public enum SubscriptionPayloadContent: String, Sendable, Codable, CaseIterable {
    /// No resource content is included in the notification
    case empty
    /// Only the resource id is included in the notification
    case idOnly = "id-only"
    /// The full resource is included in the notification
    case fullResource = "full-resource"
}

// MARK: - Subscription Channel Type

/// Channel type for delivering subscription notifications
public enum SubscriptionChannelType: String, Sendable, Codable, CaseIterable {
    /// Notifications delivered via HTTP POST to a registered endpoint
    case restHook = "rest-hook"
    /// Notifications delivered via WebSocket connection
    case websocket
    /// Notifications delivered via email
    case email
    /// Notifications delivered via FHIR messaging
    case message
}

// MARK: - Query Criteria

/// Result behavior for create/delete operations in query criteria
public enum QueryResultBehavior: String, Sendable, Codable {
    /// Trigger when the test passes
    case testPasses = "test-passes"
    /// Trigger when the test fails
    case testFails = "test-fails"
}

/// Criteria for query-based subscription topic triggers
public struct QueryCriteria: Sendable, Codable, Equatable {
    /// FHIRPath expression evaluated against the previous resource state
    public let previous: String?
    /// Behavior when a resource is created
    public let resultForCreate: QueryResultBehavior?
    /// FHIRPath expression evaluated against the current resource state
    public let current: String?
    /// Behavior when a resource is deleted
    public let resultForDelete: QueryResultBehavior?
    /// Whether both previous and current criteria must be met
    public let requireBoth: Bool?

    public init(
        previous: String? = nil,
        resultForCreate: QueryResultBehavior? = nil,
        current: String? = nil,
        resultForDelete: QueryResultBehavior? = nil,
        requireBoth: Bool? = nil
    ) {
        self.previous = previous
        self.resultForCreate = resultForCreate
        self.current = current
        self.resultForDelete = resultForDelete
        self.requireBoth = requireBoth
    }
}

// MARK: - Topic Resource Trigger

/// Interaction types that can trigger a subscription topic
public enum TopicInteraction: String, Sendable, Codable, CaseIterable {
    /// Resource creation
    case create
    /// Resource update
    case update
    /// Resource deletion
    case delete
}

/// Defines which resource events trigger notifications for a subscription topic
public struct TopicResourceTrigger: Sendable, Codable, Equatable {
    /// Human-readable description of the trigger
    public let description: String?
    /// The FHIR resource type this trigger applies to
    public let resource: String
    /// Interactions that activate this trigger
    public let supportedInteraction: [TopicInteraction]
    /// Optional query-based criteria for fine-grained triggering
    public let queryCriteria: QueryCriteria?

    public init(
        description: String? = nil,
        resource: String,
        supportedInteraction: [TopicInteraction],
        queryCriteria: QueryCriteria? = nil
    ) {
        self.description = description
        self.resource = resource
        self.supportedInteraction = supportedInteraction
        self.queryCriteria = queryCriteria
    }
}

// MARK: - FHIR Subscription Topic

/// An R5 topic-based subscription topic definition
///
/// Topics define what events can be subscribed to and what filter criteria
/// are available. They serve as the contract between server and client.
public struct FHIRSubscriptionTopic: Sendable, Codable, Equatable {
    /// Logical id of the topic
    public let id: String
    /// Canonical URL identifying the topic
    public let url: String
    /// Human-readable title
    public let title: String?
    /// Detailed description of the topic
    public let description: String?
    /// Publication status of the topic
    public let status: SubscriptionStatus
    /// Resource triggers that activate this topic
    public let resourceTriggers: [TopicResourceTrigger]

    public init(
        id: String,
        url: String,
        title: String? = nil,
        description: String? = nil,
        status: SubscriptionStatus = .active,
        resourceTriggers: [TopicResourceTrigger] = []
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.description = description
        self.status = status
        self.resourceTriggers = resourceTriggers
    }
}

// MARK: - Filter Criteria

/// Filter criteria for narrowing subscription notifications
public struct FilterCriteria: Sendable, Codable, Equatable {
    /// The FHIR resource type to filter on
    public let resourceType: String?
    /// The search parameter to filter by
    public let filterParameter: String
    /// Comparison operator (e.g., "eq", "gt", "lt")
    public let comparator: String?
    /// Search modifier (e.g., "exact", "contains")
    public let modifier: String?
    /// The value to filter against
    public let value: String

    public init(
        resourceType: String? = nil,
        filterParameter: String,
        comparator: String? = nil,
        modifier: String? = nil,
        value: String
    ) {
        self.resourceType = resourceType
        self.filterParameter = filterParameter
        self.comparator = comparator
        self.modifier = modifier
        self.value = value
    }
}

// MARK: - FHIR Subscription

/// An R5 FHIR Subscription resource for real-time notifications
///
/// Represents a client's request to receive notifications about events
/// matching a specific topic and optional filter criteria.
public struct FHIRSubscription: Sendable, Codable, Equatable {
    /// Logical id of the subscription
    public let id: String?
    /// Current status of the subscription
    public let status: SubscriptionStatus
    /// Canonical URL of the topic this subscription is for
    public let topic: URL
    /// Human-readable reason for the subscription
    public let reason: String?
    /// Filter criteria to narrow notifications
    public let filterBy: [FilterCriteria]
    /// Channel type for notification delivery
    public let channelType: SubscriptionChannelType
    /// Endpoint URL for notification delivery
    public let endpoint: URL?
    /// Interval in seconds for heartbeat notifications
    public let heartbeatPeriod: Int?
    /// Timeout in seconds before the subscription expires
    public let timeout: Int?
    /// MIME type for notification content
    public let contentType: String?
    /// Level of detail in notification payloads
    public let content: SubscriptionPayloadContent

    public init(
        id: String? = nil,
        status: SubscriptionStatus = .requested,
        topic: URL,
        reason: String? = nil,
        filterBy: [FilterCriteria] = [],
        channelType: SubscriptionChannelType = .restHook,
        endpoint: URL? = nil,
        heartbeatPeriod: Int? = nil,
        timeout: Int? = nil,
        contentType: String? = nil,
        content: SubscriptionPayloadContent = .idOnly
    ) {
        self.id = id
        self.status = status
        self.topic = topic
        self.reason = reason
        self.filterBy = filterBy
        self.channelType = channelType
        self.endpoint = endpoint
        self.heartbeatPeriod = heartbeatPeriod
        self.timeout = timeout
        self.contentType = contentType
        self.content = content
    }
}

// MARK: - WebSocket Message

/// Message types received over a WebSocket connection
public enum WebSocketMessage: Sendable, Equatable {
    /// A text message
    case text(String)
    /// A binary data message
    case data(Data)
}

// MARK: - WebSocket Delegate

/// Protocol for receiving WebSocket connection lifecycle events
public protocol WebSocketDelegate: AnyObject, Sendable {
    /// Called when the WebSocket connection is established
    func webSocketDidConnect() async
    /// Called when the WebSocket connection is closed
    func webSocketDidDisconnect(reason: String?) async
    /// Called when a WebSocket error occurs
    func webSocketDidReceiveError(_ error: Error) async
    /// Called when a message is received
    func webSocketDidReceiveMessage(_ message: WebSocketMessage) async
}

// MARK: - Connection State

/// Represents the current state of a subscription connection
public enum ConnectionState: String, Sendable, CaseIterable {
    /// Not connected
    case disconnected
    /// Attempting to establish a connection
    case connecting
    /// Connection is established and active
    case connected
    /// Attempting to re-establish a lost connection
    case reconnecting
    /// Connection has permanently failed
    case failed
}

// MARK: - Reconnection Strategy

/// Configuration for automatic reconnection behavior with exponential backoff
public struct ReconnectionStrategy: Sendable, Equatable {
    /// Maximum number of reconnection attempts before giving up
    public let maxAttempts: Int
    /// Initial delay in seconds before the first reconnection attempt
    public let initialDelay: TimeInterval
    /// Maximum delay in seconds between reconnection attempts
    public let maxDelay: TimeInterval
    /// Multiplier applied to the delay after each failed attempt
    public let backoffMultiplier: Double
    /// Whether to add random jitter to the delay
    public let jitter: Bool

    public init(
        maxAttempts: Int = 5,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        backoffMultiplier: Double = 2.0,
        jitter: Bool = true
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
        self.jitter = jitter
    }

    /// Default reconnection strategy with moderate retry behavior
    public static let `default` = ReconnectionStrategy()

    /// Aggressive strategy for quick reconnection
    public static let aggressive = ReconnectionStrategy(
        maxAttempts: 10,
        initialDelay: 0.5,
        maxDelay: 30.0,
        backoffMultiplier: 1.5,
        jitter: true
    )

    /// Conservative strategy with longer delays between attempts
    public static let conservative = ReconnectionStrategy(
        maxAttempts: 3,
        initialDelay: 5.0,
        maxDelay: 120.0,
        backoffMultiplier: 3.0,
        jitter: true
    )

    /// No retry strategy — fail immediately on disconnection
    public static let noRetry = ReconnectionStrategy(
        maxAttempts: 0,
        initialDelay: 0,
        maxDelay: 0,
        backoffMultiplier: 1.0,
        jitter: false
    )

    /// Calculate the delay before a given reconnection attempt
    ///
    /// - Parameter attempt: The attempt number (0-based)
    /// - Returns: The delay in seconds before the next attempt
    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        guard attempt >= 0, maxAttempts > 0 else { return 0 }
        let exponentialDelay = initialDelay * pow(backoffMultiplier, Double(attempt))
        let clampedDelay = min(exponentialDelay, maxDelay)
        if jitter {
            let jitterRange = clampedDelay * 0.25
            let jitterOffset = Double.random(in: -jitterRange...jitterRange)
            return max(0, clampedDelay + jitterOffset)
        }
        return clampedDelay
    }
}

// MARK: - WebSocket Transport

/// Actor managing a WebSocket connection for FHIR subscription notifications
///
/// Provides connection lifecycle management, message sending/receiving,
/// and automatic reconnection with configurable backoff strategies.
///
/// - Note: Uses `URLSessionWebSocketTask` on Apple platforms.
public actor WebSocketTransport {
    /// The WebSocket server URL
    public let url: URL
    /// Whether the connection is currently active
    public private(set) var isConnected: Bool = false
    /// Number of reconnection attempts made
    public private(set) var reconnectAttempts: Int = 0
    /// Maximum reconnection attempts allowed
    public let maxReconnectAttempts: Int
    /// Current delay between reconnection attempts
    public private(set) var reconnectDelay: TimeInterval
    /// Current connection state
    public private(set) var connectionState: ConnectionState = .disconnected
    /// Reconnection strategy
    private let strategy: ReconnectionStrategy

    #if canImport(Darwin)
    /// The underlying WebSocket task (Apple platforms only)
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession: URLSession
    #endif

    /// Stream continuation for delivering received messages
    private var messageContinuation: AsyncStream<WebSocketMessage>.Continuation?

    public init(
        url: URL,
        maxReconnectAttempts: Int = 5,
        reconnectDelay: TimeInterval = 1.0,
        strategy: ReconnectionStrategy = .default
    ) {
        self.url = url
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectDelay = reconnectDelay
        self.strategy = strategy
        #if canImport(Darwin)
        self.urlSession = URLSession(configuration: .default)
        #endif
    }

    /// Establish a WebSocket connection to the server
    ///
    /// - Throws: `FHIRSubscriptionError.connectionFailed` if the connection cannot be made
    public func connect() async throws {
        connectionState = .connecting
        #if canImport(Darwin)
        let task = urlSession.webSocketTask(with: url)
        task.resume()
        webSocketTask = task
        isConnected = true
        connectionState = .connected
        reconnectAttempts = 0
        #else
        throw FHIRSubscriptionError.connectionFailed(
            "WebSocket transport is not supported on this platform"
        )
        #endif
    }

    /// Close the WebSocket connection
    public func disconnect() async {
        #if canImport(Darwin)
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        #endif
        isConnected = false
        connectionState = .disconnected
        reconnectAttempts = 0
        messageContinuation?.finish()
        messageContinuation = nil
    }

    /// Send a message over the WebSocket connection
    ///
    /// - Parameter message: The message to send
    /// - Throws: `FHIRSubscriptionError.channelError` if the message cannot be sent
    public func send(message: WebSocketMessage) async throws {
        guard isConnected else {
            throw FHIRSubscriptionError.channelError("Not connected")
        }
        #if canImport(Darwin)
        guard let task = webSocketTask else {
            throw FHIRSubscriptionError.channelError("No active WebSocket task")
        }
        let wsMessage: URLSessionWebSocketTask.Message
        switch message {
        case .text(let text):
            wsMessage = .string(text)
        case .data(let data):
            wsMessage = .data(data)
        }
        try await task.send(wsMessage)
        #else
        throw FHIRSubscriptionError.channelError(
            "WebSocket transport is not supported on this platform"
        )
        #endif
    }

    /// Create an async stream of messages received from the WebSocket
    ///
    /// - Returns: An `AsyncStream` that yields `WebSocketMessage` values
    public func receive() -> AsyncStream<WebSocketMessage> {
        let (stream, continuation) = AsyncStream<WebSocketMessage>.makeStream()
        self.messageContinuation = continuation
        #if canImport(Darwin)
        if let task = webSocketTask {
            Task { [weak task] in
                await self.receiveLoop(task: task)
            }
        }
        #endif
        return stream
    }

    #if canImport(Darwin)
    /// Internal receive loop reading messages from the WebSocket task
    private func receiveLoop(task: URLSessionWebSocketTask?) async {
        guard let task = task else { return }
        do {
            let result = try await task.receive()
            let message: WebSocketMessage
            switch result {
            case .string(let text):
                message = .text(text)
            case .data(let data):
                message = .data(data)
            @unknown default:
                return
            }
            messageContinuation?.yield(message)
            await receiveLoop(task: task)
        } catch {
            await handleDisconnection()
        }
    }
    #endif

    /// Handle unexpected disconnection with automatic reconnection
    private func handleDisconnection() async {
        isConnected = false
        connectionState = .reconnecting
        while reconnectAttempts < maxReconnectAttempts {
            let delay = strategy.delayForAttempt(reconnectAttempts)
            reconnectAttempts += 1
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            do {
                try await connect()
                return
            } catch {
                continue
            }
        }
        connectionState = .failed
        messageContinuation?.finish()
    }
}

// MARK: - Subscription Notification

/// Type of subscription notification
public enum SubscriptionNotificationType: String, Sendable, Codable, CaseIterable {
    /// Initial handshake notification
    case handshake
    /// Periodic heartbeat to confirm the subscription is alive
    case heartbeat
    /// Notification containing event data
    case eventNotification = "event-notification"
    /// Status query response
    case queryStatus = "query-status"
    /// Query event notification
    case queryEvent = "query-event"
}

/// An entry within a subscription notification
public struct NotificationEntry: Sendable, Codable, Equatable {
    /// Full URL of the resource that triggered the notification
    public let fullUrl: String?
    /// Raw resource data included in the notification
    public let resourceData: Data?
    /// HTTP method associated with the triggering event
    public let method: String?

    public init(
        fullUrl: String? = nil,
        resourceData: Data? = nil,
        method: String? = nil
    ) {
        self.fullUrl = fullUrl
        self.resourceData = resourceData
        self.method = method
    }
}

/// A parsed subscription notification from the FHIR server
public struct SubscriptionNotification: Sendable, Equatable {
    /// Subscription id this notification belongs to
    public let subscriptionId: String
    /// Topic URL for the subscription
    public let topic: String?
    /// Type of notification
    public let type: SubscriptionNotificationType
    /// Total events since the subscription was started
    public let eventsSinceSubscriptionStart: Int
    /// Number of events in this notification
    public let eventsInNotification: Int
    /// Entries with resource data for event notifications
    public let focus: [NotificationEntry]

    public init(
        subscriptionId: String,
        topic: String? = nil,
        type: SubscriptionNotificationType,
        eventsSinceSubscriptionStart: Int = 0,
        eventsInNotification: Int = 0,
        focus: [NotificationEntry] = []
    ) {
        self.subscriptionId = subscriptionId
        self.topic = topic
        self.type = type
        self.eventsSinceSubscriptionStart = eventsSinceSubscriptionStart
        self.eventsInNotification = eventsInNotification
        self.focus = focus
    }
}

// MARK: - REST-hook Handler

/// Actor managing REST-hook notification processing for FHIR subscriptions
///
/// Registers per-subscription handlers and processes incoming notification
/// bundles, dispatching parsed notifications to the appropriate handler.
public actor RESTHookHandler {
    /// Registered notification handlers keyed by subscription id
    public private(set) var registeredHandlers: [String: @Sendable (SubscriptionNotification) async -> Void] = [:]

    public init() {}

    /// Register a handler for a specific subscription
    ///
    /// - Parameters:
    ///   - subscriptionId: The subscription to handle notifications for
    ///   - handler: Async closure invoked when a notification arrives
    public func registerHandler(
        subscriptionId: String,
        handler: @escaping @Sendable (SubscriptionNotification) async -> Void
    ) async {
        registeredHandlers[subscriptionId] = handler
    }

    /// Remove the handler for a specific subscription
    ///
    /// - Parameter subscriptionId: The subscription to stop handling
    public func unregisterHandler(subscriptionId: String) async {
        registeredHandlers.removeValue(forKey: subscriptionId)
    }

    /// Process a notification for a specific subscription
    ///
    /// - Parameters:
    ///   - subscriptionId: The subscription this notification belongs to
    ///   - payload: Raw notification data
    /// - Throws: `FHIRSubscriptionError.notificationError` if no handler is registered
    public func processNotification(subscriptionId: String, payload: Data) async throws {
        guard let handler = registeredHandlers[subscriptionId] else {
            throw FHIRSubscriptionError.notificationError(
                "No handler registered for subscription: \(subscriptionId)"
            )
        }
        let notification = try await processNotificationBundle(data: payload)
        await handler(notification)
    }

    /// Parse raw notification data into a structured notification
    ///
    /// - Parameter data: Raw JSON notification bundle data
    /// - Returns: A parsed `SubscriptionNotification`
    /// - Throws: `FHIRSubscriptionError.notificationError` on parse failure
    public func processNotificationBundle(data: Data) async throws -> SubscriptionNotification {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FHIRSubscriptionError.notificationError("Invalid notification JSON")
        }

        let subscriptionId = extractSubscriptionId(from: json)
        let topic = extractTopic(from: json)
        let type = extractNotificationType(from: json)
        let entries = extractEntries(from: json)

        let eventsSince = (json["eventsSinceSubscriptionStart"] as? Int)
            ?? extractEventsSinceStart(from: json)
        let eventsInNotification = entries.count

        return SubscriptionNotification(
            subscriptionId: subscriptionId,
            topic: topic,
            type: type,
            eventsSinceSubscriptionStart: eventsSince,
            eventsInNotification: eventsInNotification,
            focus: entries
        )
    }

    // MARK: - Private Helpers

    private func extractSubscriptionId(from json: [String: Any]) -> String {
        // Look in entry array for SubscriptionStatus resource
        if let entries = json["entry"] as? [[String: Any]] {
            for entry in entries {
                if let resource = entry["resource"] as? [String: Any],
                   let resourceType = resource["resourceType"] as? String,
                   resourceType == "SubscriptionStatus",
                   let subscription = resource["subscription"] as? [String: Any],
                   let reference = subscription["reference"] as? String {
                    // Extract id from reference like "Subscription/123"
                    return reference.components(separatedBy: "/").last ?? reference
                }
            }
        }
        return json["subscriptionId"] as? String ?? "unknown"
    }

    private func extractTopic(from json: [String: Any]) -> String? {
        if let entries = json["entry"] as? [[String: Any]] {
            for entry in entries {
                if let resource = entry["resource"] as? [String: Any],
                   let topic = resource["topic"] as? String {
                    return topic
                }
            }
        }
        return json["topic"] as? String
    }

    private func extractNotificationType(from json: [String: Any]) -> SubscriptionNotificationType {
        if let entries = json["entry"] as? [[String: Any]] {
            for entry in entries {
                if let resource = entry["resource"] as? [String: Any],
                   let typeStr = resource["type"] as? String,
                   let type = SubscriptionNotificationType(rawValue: typeStr) {
                    return type
                }
            }
        }
        if let typeStr = json["type"] as? String,
           let type = SubscriptionNotificationType(rawValue: typeStr) {
            return type
        }
        return .eventNotification
    }

    private func extractEntries(from json: [String: Any]) -> [NotificationEntry] {
        guard let entries = json["entry"] as? [[String: Any]] else {
            return []
        }
        // Skip the first entry (SubscriptionStatus) and collect focus entries
        return entries.dropFirst().compactMap { entry in
            let fullUrl = entry["fullUrl"] as? String
            let method = (entry["request"] as? [String: Any])?["method"] as? String
            var resourceData: Data?
            if let resource = entry["resource"] {
                resourceData = try? JSONSerialization.data(withJSONObject: resource)
            }
            return NotificationEntry(
                fullUrl: fullUrl,
                resourceData: resourceData,
                method: method
            )
        }
    }

    private func extractEventsSinceStart(from json: [String: Any]) -> Int {
        if let entries = json["entry"] as? [[String: Any]] {
            for entry in entries {
                if let resource = entry["resource"] as? [String: Any],
                   let count = resource["eventsSinceSubscriptionStart"] as? Int {
                    return count
                }
            }
        }
        return 0
    }
}

// MARK: - Subscription Event Filter

/// Filters subscription notifications by resource type and criteria
///
/// Use `EventFilterBuilder` for a fluent construction API.
public struct SubscriptionEventFilter: Sendable, Equatable {
    /// Set of resource types to accept (empty means accept all)
    public let resourceTypes: Set<String>
    /// Filter criteria that notifications must match
    public let criteria: [FilterCriteria]

    public init(
        resourceTypes: Set<String> = [],
        criteria: [FilterCriteria] = []
    ) {
        self.resourceTypes = resourceTypes
        self.criteria = criteria
    }

    /// Check if a notification matches this filter
    ///
    /// - Parameter notification: The notification to check
    /// - Returns: `true` if the notification passes all filter checks
    public func matches(notification: SubscriptionNotification) -> Bool {
        // Heartbeat and handshake notifications always pass
        if notification.type == .heartbeat || notification.type == .handshake {
            return true
        }
        // If no criteria defined, accept all
        if resourceTypes.isEmpty && criteria.isEmpty {
            return true
        }
        // Check focus entries against resource type filters
        if !resourceTypes.isEmpty {
            let hasMatchingEntry = notification.focus.contains { entry in
                guard let fullUrl = entry.fullUrl else { return false }
                return resourceTypes.contains { type in
                    fullUrl.contains(type)
                }
            }
            if !hasMatchingEntry && !notification.focus.isEmpty {
                return false
            }
        }
        return true
    }

    /// Check if a resource type matches this filter
    ///
    /// - Parameter type: The resource type to check
    /// - Returns: `true` if the type is accepted by this filter
    public func matchesResourceType(_ type: String) -> Bool {
        resourceTypes.isEmpty || resourceTypes.contains(type)
    }

    /// Return a new filter with additional criteria added
    ///
    /// - Parameter newCriteria: The criteria to add
    /// - Returns: A new `SubscriptionEventFilter` with the criteria appended
    public func addCriteria(_ newCriteria: FilterCriteria) -> SubscriptionEventFilter {
        SubscriptionEventFilter(
            resourceTypes: resourceTypes,
            criteria: criteria + [newCriteria]
        )
    }

    /// Return a new filter with the specified resource types
    ///
    /// - Parameter types: The resource types to accept
    /// - Returns: A new `SubscriptionEventFilter` with the resource types set
    public func withResourceTypes(_ types: Set<String>) -> SubscriptionEventFilter {
        SubscriptionEventFilter(
            resourceTypes: types,
            criteria: criteria
        )
    }
}

// MARK: - Event Filter Builder

/// Fluent builder for constructing `SubscriptionEventFilter` instances
public struct EventFilterBuilder: Sendable {
    private var resourceTypes: Set<String> = []
    private var criteria: [FilterCriteria] = []

    public init() {}

    /// Add a resource type to the filter
    ///
    /// - Parameter type: The resource type to include
    /// - Returns: A new builder with the resource type added
    public func forResourceType(_ type: String) -> EventFilterBuilder {
        var copy = self
        copy.resourceTypes.insert(type)
        return copy
    }

    /// Add filter criteria
    ///
    /// - Parameter newCriteria: The criteria to add
    /// - Returns: A new builder with the criteria added
    public func withCriteria(_ newCriteria: FilterCriteria) -> EventFilterBuilder {
        var copy = self
        copy.criteria.append(newCriteria)
        return copy
    }

    /// Build the final filter
    ///
    /// - Returns: A configured `SubscriptionEventFilter`
    public func build() -> SubscriptionEventFilter {
        SubscriptionEventFilter(
            resourceTypes: resourceTypes,
            criteria: criteria
        )
    }
}

// MARK: - FHIR Subscription Manager

/// Main entry point for managing FHIR subscriptions and real-time notifications
///
/// Provides CRUD operations for subscription resources, topic discovery,
/// and real-time notification streaming via WebSocket or REST-hook channels.
///
/// Usage:
/// ```swift
/// let manager = FHIRSubscriptionManager(
///     session: URLSession.shared,
///     baseURL: URL(string: "https://fhir.example.org/r5")!
/// )
/// let topics = try await manager.listTopics()
/// let subscription = try await manager.createSubscription(mySubscription)
/// let stream = try await manager.startListening(subscriptionId: subscription.id!)
/// for await notification in stream {
///     // Handle notification
/// }
/// ```
public actor FHIRSubscriptionManager {
    /// URL session for HTTP requests
    private let session: FHIRURLSession
    /// Base URL of the FHIR server
    public let baseURL: URL
    /// Currently active subscriptions keyed by id
    public private(set) var activeSubscriptions: [String: FHIRSubscription] = [:]
    /// Active WebSocket transports keyed by subscription id
    private var transports: [String: WebSocketTransport] = [:]
    /// REST-hook handler for processing notifications
    private let restHookHandler: RESTHookHandler
    /// Active notification stream continuations keyed by subscription id
    private var streamContinuations: [String: AsyncStream<SubscriptionNotification>.Continuation] = [:]

    /// JSON encoder for request bodies
    private let encoder: JSONEncoder
    /// JSON decoder for response bodies
    private let decoder: JSONDecoder

    public init(session: FHIRURLSession, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
        self.restHookHandler = RESTHookHandler()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Subscription CRUD

    /// Create a new subscription on the FHIR server
    ///
    /// - Parameter subscription: The subscription to create
    /// - Returns: The server-created subscription with assigned id
    /// - Throws: `FHIRSubscriptionError` on failure
    public func createSubscription(_ subscription: FHIRSubscription) async throws -> FHIRSubscription {
        let url = baseURL.appendingPathComponent("Subscription")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(subscription)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let created = try decoder.decode(FHIRSubscription.self, from: data)
        if let id = created.id {
            activeSubscriptions[id] = created
        }
        return created
    }

    /// Retrieve a subscription by id from the FHIR server
    ///
    /// - Parameter id: The subscription id
    /// - Returns: The subscription resource
    /// - Throws: `FHIRSubscriptionError` on failure
    public func getSubscription(id: String) async throws -> FHIRSubscription {
        let url = baseURL.appendingPathComponent("Subscription/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try decoder.decode(FHIRSubscription.self, from: data)
    }

    /// Update an existing subscription on the FHIR server
    ///
    /// - Parameter subscription: The subscription to update (must have an id)
    /// - Returns: The updated subscription
    /// - Throws: `FHIRSubscriptionError` on failure
    public func updateSubscription(_ subscription: FHIRSubscription) async throws -> FHIRSubscription {
        guard let id = subscription.id else {
            throw FHIRSubscriptionError.invalidConfiguration("Subscription must have an id for update")
        }
        let url = baseURL.appendingPathComponent("Subscription/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(subscription)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let updated = try decoder.decode(FHIRSubscription.self, from: data)
        activeSubscriptions[id] = updated
        return updated
    }

    /// Delete a subscription from the FHIR server
    ///
    /// - Parameter id: The subscription id to delete
    /// - Throws: `FHIRSubscriptionError` on failure
    public func deleteSubscription(id: String) async throws {
        let url = baseURL.appendingPathComponent("Subscription/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)

        activeSubscriptions.removeValue(forKey: id)
        await stopListening(subscriptionId: id)
    }

    /// List all subscriptions on the FHIR server
    ///
    /// - Returns: Array of subscriptions
    /// - Throws: `FHIRSubscriptionError` on failure
    public func listSubscriptions() async throws -> [FHIRSubscription] {
        let url = baseURL.appendingPathComponent("Subscription")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        // Parse as a Bundle containing Subscription entries
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["entry"] as? [[String: Any]] else {
            return try decoder.decode([FHIRSubscription].self, from: data)
        }

        return try entries.compactMap { entry in
            guard let resource = entry["resource"] else { return nil }
            let resourceData = try JSONSerialization.data(withJSONObject: resource)
            return try decoder.decode(FHIRSubscription.self, from: resourceData)
        }
    }

    /// Get the current status of a subscription
    ///
    /// - Parameter id: The subscription id
    /// - Returns: The current status
    /// - Throws: `FHIRSubscriptionError` on failure
    public func getSubscriptionStatus(id: String) async throws -> SubscriptionStatus {
        let subscription = try await getSubscription(id: id)
        return subscription.status
    }

    // MARK: - Topic Discovery

    /// List available subscription topics on the FHIR server
    ///
    /// - Returns: Array of subscription topics
    /// - Throws: `FHIRSubscriptionError` on failure
    public func listTopics() async throws -> [FHIRSubscriptionTopic] {
        let url = baseURL.appendingPathComponent("SubscriptionTopic")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["entry"] as? [[String: Any]] else {
            return try decoder.decode([FHIRSubscriptionTopic].self, from: data)
        }

        return try entries.compactMap { entry in
            guard let resource = entry["resource"] else { return nil }
            let resourceData = try JSONSerialization.data(withJSONObject: resource)
            return try decoder.decode(FHIRSubscriptionTopic.self, from: resourceData)
        }
    }

    // MARK: - Real-time Listening

    /// Start listening for notifications on a subscription
    ///
    /// - Parameter subscriptionId: The subscription to listen on
    /// - Returns: An async stream of notifications
    /// - Throws: `FHIRSubscriptionError` if the subscription is not found or cannot be started
    public func startListening(subscriptionId: String) async throws -> AsyncStream<SubscriptionNotification> {
        guard let subscription = activeSubscriptions[subscriptionId] else {
            // Try to fetch from server
            let fetched = try await getSubscription(id: subscriptionId)
            activeSubscriptions[subscriptionId] = fetched
            return try await startListeningForSubscription(fetched, id: subscriptionId)
        }
        return try await startListeningForSubscription(subscription, id: subscriptionId)
    }

    /// Stop listening for notifications on a subscription
    ///
    /// - Parameter subscriptionId: The subscription to stop listening on
    public func stopListening(subscriptionId: String) async {
        streamContinuations[subscriptionId]?.finish()
        streamContinuations.removeValue(forKey: subscriptionId)
        if let transport = transports[subscriptionId] {
            await transport.disconnect()
            transports.removeValue(forKey: subscriptionId)
        }
        await restHookHandler.unregisterHandler(subscriptionId: subscriptionId)
    }

    /// Stop all active subscription listeners
    public func stopAll() async {
        let ids = Array(streamContinuations.keys)
        for id in ids {
            await stopListening(subscriptionId: id)
        }
        activeSubscriptions.removeAll()
    }

    // MARK: - Private Helpers

    private func startListeningForSubscription(
        _ subscription: FHIRSubscription,
        id: String
    ) async throws -> AsyncStream<SubscriptionNotification> {
        let (stream, continuation) = AsyncStream<SubscriptionNotification>.makeStream()
        streamContinuations[id] = continuation

        switch subscription.channelType {
        case .websocket:
            guard let endpoint = subscription.endpoint else {
                throw FHIRSubscriptionError.invalidConfiguration(
                    "WebSocket subscription requires an endpoint URL"
                )
            }
            let transport = WebSocketTransport(url: endpoint)
            transports[id] = transport
            try await transport.connect()
            Task {
                let messages = await transport.receive()
                for await message in messages {
                    if case .text(let text) = message,
                       let data = text.data(using: .utf8) {
                        if let notification = try? await restHookHandler.processNotificationBundle(data: data) {
                            continuation.yield(notification)
                        }
                    } else if case .data(let data) = message {
                        if let notification = try? await restHookHandler.processNotificationBundle(data: data) {
                            continuation.yield(notification)
                        }
                    }
                }
                continuation.finish()
            }

        case .restHook:
            await restHookHandler.registerHandler(subscriptionId: id) { notification in
                continuation.yield(notification)
            }

        case .email, .message:
            throw FHIRSubscriptionError.invalidConfiguration(
                "Channel type '\(subscription.channelType.rawValue)' is not supported for real-time listening"
            )
        }

        return stream
    }

    /// Validate an HTTP response from the FHIR server
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FHIRSubscriptionError.networkError("Invalid HTTP response")
        }
        let statusCode = httpResponse.statusCode
        switch statusCode {
        case 200...299:
            return
        case 400:
            throw FHIRSubscriptionError.invalidConfiguration("Bad request")
        case 401, 403:
            throw FHIRSubscriptionError.subscriptionRejected("Authorization failed")
        case 404:
            throw FHIRSubscriptionError.serverError(statusCode: statusCode, data: nil)
        case 422:
            throw FHIRSubscriptionError.subscriptionRejected("Unprocessable entity")
        default:
            throw FHIRSubscriptionError.serverError(statusCode: statusCode, data: nil)
        }
    }
}
