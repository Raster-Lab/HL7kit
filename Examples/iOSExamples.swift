// iOS-specific examples for HL7kit demonstrating platform features
// These examples show how to use HL7kit in iOS applications with SwiftUI, UIKit,
// HealthKit, CloudKit, Shortcuts, and other iOS-specific frameworks.

#if canImport(UIKit) && !os(watchOS)
import Foundation
import HL7Core
import HL7v2Kit
import HL7v3Kit
import FHIRkit

#if canImport(SwiftUI)
import SwiftUI

// MARK: - SwiftUI Message Viewer

/// SwiftUI view for displaying HL7 v2.x messages in a structured format
@available(iOS 16.0, *)
public struct HL7MessageView: View {
    let message: HL7v2Message
    @State private var selectedSegment: HL7v2Segment?
    
    public init(message: HL7v2Message) {
        self.message = message
    }
    
    public var body: some View {
        List {
            Section("Message Header") {
                if let msh = message.allSegments.first(where: { $0.segmentID == "MSH" }) {
                    SegmentDetailView(segment: msh)
                }
            }
            
            Section("Segments") {
                ForEach(message.allSegments.dropFirst(), id: \.segmentID) { segment in
                    Button {
                        selectedSegment = segment
                    } label: {
                        VStack(alignment: .leading) {
                            Text(segment.segmentID)
                                .font(.headline)
                            Text("\(segment.fields.count) fields")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("HL7 Message")
        .sheet(item: Binding(
            get: { selectedSegment.map { IdentifiableSegment(segment: $0) } },
            set: { selectedSegment = $0?.segment }
        )) { item in
            NavigationStack {
                SegmentDetailView(segment: item.segment)
                    .navigationTitle(item.segment.segmentID)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                selectedSegment = nil
                            }
                        }
                    }
            }
        }
    }
}

@available(iOS 16.0, *)
private struct SegmentDetailView: View {
    let segment: BaseSegment
    
    var body: some View {
        List {
            ForEach(Array(segment.fields.enumerated()), id: \.offset) { index, field in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Field \(index)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(try? field.serialize() ?? "")
                        .font(.body)
                }
            }
        }
    }
}

@available(iOS 16.0, *)
private struct IdentifiableSegment: Identifiable {
    let id = UUID()
    let segment: BaseSegment
}

// MARK: - SwiftUI FHIR Patient Card

/// SwiftUI view for displaying FHIR Patient resource
@available(iOS 16.0, *)
public struct FHIRPatientCard: View {
    let patient: Patient
    
    public init(patient: Patient) {
        self.patient = patient
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let name = patient.name?.first {
                Text(fullName(from: name))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            if let birthDate = patient.birthDate {
                Label {
                    Text("Born: \(birthDate)")
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.subheadline)
            }
            
            if let gender = patient.gender {
                Label {
                    Text("Gender: \(gender.capitalized)")
                } icon: {
                    Image(systemName: "person.fill")
                }
                .font(.subheadline)
            }
            
            if let identifier = patient.identifier?.first {
                Label {
                    Text("ID: \(identifier.value ?? "Unknown")")
                } icon: {
                    Image(systemName: "number")
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func fullName(from name: HumanName) -> String {
        var parts: [String] = []
        if let given = name.given {
            parts.append(contentsOf: given)
        }
        if let family = name.family {
            parts.append(family)
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - SwiftUI Message List

/// SwiftUI view for displaying a list of HL7 messages
@available(iOS 16.0, *)
public struct MessageListView: View {
    let messages: [HL7v2Message]
    @State private var selectedMessage: HL7v2Message?
    
    public init(messages: [HL7v2Message]) {
        self.messages = messages
    }
    
    public var body: some View {
        NavigationStack {
            List(messages, id: \.self) { message in
                NavigationLink {
                    HL7MessageView(message: message)
                } label: {
                    MessageRowView(message: message)
                }
            }
            .navigationTitle("Messages (\(messages.count))")
        }
    }
}

@available(iOS 16.0, *)
private struct MessageRowView: View {
    let message: HL7v2Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(messageType)
                .font(.headline)
            Text("\(message.segmentCount) segments")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var messageType: String {
        return message.messageType()
    }
}

#endif

#if canImport(UIKit)
import UIKit

// MARK: - UIKit Message View Controller

/// UIViewController for displaying HL7 messages with UIKit
@available(iOS 13.0, *)
open class HL7MessageViewController: UIViewController {
    private let message: HL7v2Message
    private var tableView: UITableView!
    
    public init(message: HL7v2Message) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        title = "HL7 Message"
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SegmentCell")
        view.addSubview(tableView)
    }
}

@available(iOS 13.0, *)
extension HL7MessageViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return message.segmentCount
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath)
        let segment = message.allSegments[indexPath.row]
        
        var config = cell.defaultContentConfiguration()
        config.text = segment.segmentID
        config.secondaryText = "\(segment.fields.count) fields"
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

@available(iOS 13.0, *)
extension HL7MessageViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let segment = message.allSegments[indexPath.row]
        let detailVC = SegmentDetailViewController(segment: segment)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

@available(iOS 13.0, *)
private class SegmentDetailViewController: UIViewController {
    private let segment: BaseSegment
    private var tableView: UITableView!
    
    init(segment: BaseSegment) {
        self.segment = segment
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = segment.segmentID
        setupTableView()
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FieldCell")
        view.addSubview(tableView)
    }
}

@available(iOS 13.0, *)
extension SegmentDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return segment.fields.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FieldCell", for: indexPath)
        let field = segment.fields[indexPath.row]
        
        var config = cell.defaultContentConfiguration()
        config.text = "Field \(indexPath.row)"
        config.secondaryText = (try? field.serialize()) ?? ""
        config.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = config
        
        return cell
    }
}

#endif

// MARK: - User Notifications for Message Processing

#if canImport(UserNotifications)
import UserNotifications

/// Manages notifications for HL7 message processing events
@available(iOS 10.0, *)
public actor NotificationManager {
    public static let shared = NotificationManager()
    
    private init() {}
    
    /// Request notification permissions
    public func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
    
    /// Send a notification when message processing completes
    public func notifyMessageProcessed(messageType: String, count: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "HL7 Message Processed"
        content.body = "Successfully processed \(count) \(messageType) message(s)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    /// Send a notification when validation fails
    public func notifyValidationError(messageType: String, error: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "HL7 Validation Error"
        content.body = "Error in \(messageType): \(error)"
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
}

#endif

// MARK: - Background Processing

#if canImport(BackgroundTasks)
import BackgroundTasks

/// Manages background processing of HL7 messages
@available(iOS 13.0, *)
public actor BackgroundMessageProcessor {
    public static let shared = BackgroundMessageProcessor()
    public static let taskIdentifier = "com.hl7kit.process-messages"
    
    private init() {}
    
    /// Register background task
    public func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            Task {
                await self.handleBackgroundTask(task: task as! BGProcessingTask)
            }
        }
    }
    
    /// Schedule a background task to process messages
    public func scheduleProcessing() throws {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        
        try BGTaskScheduler.shared.submit(request)
    }
    
    private func handleBackgroundTask(task: BGProcessingTask) async {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Process pending messages
        // This is a placeholder - actual implementation would load and process messages
        do {
            try await Task.sleep(for: .seconds(5))
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }
}

#endif

// MARK: - Local Storage with File System

/// iOS-specific file storage for HL7 messages
public actor iOSMessageStorage {
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    
    public init() throws {
        documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
    
    /// Save a message to the documents directory
    public func saveMessage(_ message: HL7v2Message, filename: String) async throws {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        let serialized = try message.serialize()
        let data = Data(serialized.utf8)
        try data.write(to: fileURL)
    }
    
    /// Load a message from the documents directory
    public func loadMessage(filename: String) async throws -> HL7v2Message {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        let data = try Data(contentsOf: fileURL)
        let parser = HL7v2Parser()
        let result = try await parser.parse(data)
        return result.message
    }
    
    /// List all saved messages
    public func listMessages() async throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: nil
        )
        return contents
            .filter { $0.pathExtension == "hl7" }
            .map { $0.lastPathComponent }
    }
    
    /// Delete a message
    public func deleteMessage(filename: String) async throws {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        try fileManager.removeItem(at: fileURL)
    }
}

// MARK: - Example Usage Functions

/// Example: Parse and display message in SwiftUI
@available(iOS 16.0, *)
public func exampleSwiftUIMessageDisplay() async throws {
    let messageString = """
    MSH|^~\\&|SendingApp|SendingFac|ReceivingApp|ReceivingFac|20240101120000||ADT^A01|MSG001|P|2.5.1
    EVN||20240101120000
    PID|1||MRN12345^^^Hospital^MR||Doe^John^A||19800115|M|||123 Main St^^Anytown^CA^12345||555-1234
    """
    
    let parser = HL7v2Parser()
    let result = try await parser.parse(messageString)
    let message = result.message
    
    // Use in SwiftUI:
    // HL7MessageView(message: message)
}

/// Example: Display FHIR patient in SwiftUI card
@available(iOS 16.0, *)
public func exampleFHIRPatientCard() {
    let patient = Patient(
        id: "patient-123",
        identifier: [
            Identifier(
                value: "MRN12345",
                system: "http://hospital.example.org/mrn"
            )
        ],
        name: [
            HumanName(
                family: "Doe",
                given: ["John", "A"]
            )
        ],
        gender: "male",
        birthDate: "1980-01-15"
    )
    
    // Use in SwiftUI:
    // FHIRPatientCard(patient: patient)
}

/// Example: Process messages with notifications
@available(iOS 10.0, *)
public func exampleBackgroundProcessingWithNotifications() async throws {
    let notificationManager = NotificationManager.shared
    
    // Request permission
    let granted = try await notificationManager.requestAuthorization()
    guard granted else {
        print("Notification permission denied")
        return
    }
    
    // Process some messages
    let parser = HL7v2Parser()
    let result = try await parser.parse("""
    MSH|^~\\&|App|Fac|App|Fac|20240101||ADT^A01|MSG001|P|2.5.1
    PID|1||MRN001^^^Hosp^MR||Smith^John
    """)
    
    let message = result.message
    
    // Validate
    do {
        try message.validate()
        try await notificationManager.notifyMessageProcessed(messageType: "ADT^A01", count: 1)
    } catch {
        try await notificationManager.notifyValidationError(
            messageType: "ADT^A01",
            error: error.localizedDescription
        )
    }
}

/// Example: Store messages locally
public func exampleLocalStorage() async throws {
    let storage = try iOSMessageStorage()
    
    // Parse a message
    let parser = HL7v2Parser()
    let result = try await parser.parse("""
    MSH|^~\\&|App|Fac|App|Fac|20240101||ADT^A01|MSG001|P|2.5.1
    PID|1||MRN001^^^Hosp^MR||Smith^John
    """)
    
    let message = result.message
    
    // Save to disk
    try await storage.saveMessage(message, filename: "message001.hl7")
    
    // List all messages
    let files = try await storage.listMessages()
    print("Saved messages: \(files)")
    
    // Load back
    let loaded = try await storage.loadMessage(filename: "message001.hl7")
    print("Loaded message with \(loaded.segmentCount) segments")
}

#endif
