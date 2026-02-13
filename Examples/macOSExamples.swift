// macOS-specific examples for HL7kit demonstrating platform features
// These examples show how to use HL7kit in macOS applications with AppKit,
// menu bar integration, AppleScript, and batch file processing.

#if os(macOS)
import Foundation
import HL7Core
import HL7v2Kit
import HL7v3Kit
import FHIRkit

#if canImport(AppKit)
import AppKit

// MARK: - AppKit Message Window Controller

/// NSWindowController for displaying HL7 messages with AppKit
@available(macOS 11.0, *)
open class HL7MessageWindowController: NSWindowController {
    private let message: HL7v2Message
    
    public init(message: HL7v2Message) {
        self.message = message
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HL7 Message Viewer"
        window.center()
        
        super.init(window: window)
        
        setupContentView()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupContentView() {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        
        // Left: Segment list
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("segment"))
        column.title = "Segment"
        column.width = 200
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        
        // Right: Field details
        let textView = NSTextView()
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let textScrollView = NSScrollView()
        textScrollView.documentView = textView
        textScrollView.hasVerticalScroller = true
        
        splitView.addArrangedSubview(scrollView)
        splitView.addArrangedSubview(textScrollView)
        
        window?.contentView = splitView
    }
}

@available(macOS 11.0, *)
extension HL7MessageWindowController: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return message.segments.count
    }
    
    public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let segment = message.segments[row]
        return "\(segment.id) (\(segment.fields.count) fields)"
    }
}

@available(macOS 11.0, *)
extension HL7MessageWindowController: NSTableViewDelegate {
    public func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        
        let segment = message.segments[row]
        let details = segment.fields.enumerated()
            .map { "Field \($0): \($1)" }
            .joined(separator: "\n")
        
        if let splitView = window?.contentView as? NSSplitView,
           let textScrollView = splitView.arrangedSubviews.last as? NSScrollView,
           let textView = textScrollView.documentView as? NSTextView {
            textView.string = details
        }
    }
}

// MARK: - Menu Bar Integration

/// Menu bar item for quick access to HL7 tools
@available(macOS 11.0, *)
public class HL7MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    public func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "heart.text.square", accessibilityDescription: "HL7")
        }
        
        menu = NSMenu()
        
        menu?.addItem(NSMenuItem(title: "Parse Message...", action: #selector(parseMessage), keyEquivalent: "p"))
        menu?.addItem(NSMenuItem(title: "Validate Message...", action: #selector(validateMessage), keyEquivalent: "v"))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: "Batch Process...", action: #selector(batchProcess), keyEquivalent: "b"))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func parseMessage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.text, .data]
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.handleParseMessage(url: url)
        }
    }
    
    @objc private func validateMessage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.handleValidateMessage(url: url)
        }
    }
    
    @objc private func batchProcess() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                await self.handleBatchProcess(directory: url)
            }
        }
    }
    
    private func handleParseMessage(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let parser = HL7v2Parser()
            let message = try parser.parse(data)
            
            let windowController = HL7MessageWindowController(message: message)
            windowController.showWindow(nil)
        } catch {
            showError("Failed to parse message: \(error.localizedDescription)")
        }
    }
    
    private func handleValidateMessage(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let parser = HL7v2Parser()
            let message = try parser.parse(data)
            try message.validate()
            
            showSuccess("Message is valid!")
        } catch {
            showError("Validation failed: \(error.localizedDescription)")
        }
    }
    
    private func handleBatchProcess(directory: URL) async {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            showError("Cannot read directory")
            return
        }
        
        var processed = 0
        var errors = 0
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "hl7" else { continue }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let parser = HL7v2Parser()
                _ = try parser.parse(data)
                processed += 1
            } catch {
                errors += 1
            }
        }
        
        showSuccess("Processed \(processed) messages with \(errors) errors")
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
    
    private func showSuccess(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

#endif

// MARK: - AppleScript Support

/// Provides AppleScript integration for HL7 message processing
@available(macOS 11.0, *)
public actor AppleScriptSupport {
    /// Execute an AppleScript to process HL7 messages
    public func executeScript(_ script: String) async throws -> String {
        guard let appleScript = NSAppleScript(source: script) else {
            throw NSError(domain: "HL7kit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid script"])
        }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            throw NSError(domain: "HL7kit", code: -2, userInfo: [NSLocalizedDescriptionKey: error.description])
        }
        
        return result.stringValue ?? ""
    }
    
    /// Generate an AppleScript for batch processing
    public func generateBatchProcessScript(directory: String) -> String {
        return """
        tell application "Finder"
            set folderPath to POSIX file "\(directory)" as alias
            set fileList to every file of folderPath whose name extension is "hl7"
            
            repeat with aFile in fileList
                set filePath to POSIX path of (aFile as alias)
                -- Process file with hl7 command-line tool
                do shell script "swift run hl7 validate " & quoted form of filePath
            end repeat
        end tell
        """
    }
}

// MARK: - Service Menu Integration

#if canImport(AppKit)

/// Provides macOS Service menu integration
@available(macOS 11.0, *)
public class HL7ServiceProvider: NSObject {
    @objc public func validateHL7Message(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let messageString = pasteboard.string(forType: .string) else {
            error.pointee = "No text in pasteboard" as NSString
            return
        }
        
        do {
            let parser = HL7v2Parser()
            let message = try parser.parse(messageString)
            try message.validate()
            
            pasteboard.clearContents()
            pasteboard.setString("✓ Valid HL7 message", forType: .string)
        } catch {
            error.pointee = "Validation failed: \(error.localizedDescription)" as NSString
        }
    }
    
    @objc public func formatHL7Message(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let messageString = pasteboard.string(forType: .string) else {
            error.pointee = "No text in pasteboard" as NSString
            return
        }
        
        do {
            let parser = HL7v2Parser()
            let message = try parser.parse(messageString)
            
            // Format with line breaks
            let formatted = message.segments
                .map { segment in
                    "\(segment.id)|\(segment.fields.joined(separator: "|"))"
                }
                .joined(separator: "\n")
            
            pasteboard.clearContents()
            pasteboard.setString(formatted, forType: .string)
        } catch {
            error.pointee = "Formatting failed: \(error.localizedDescription)" as NSString
        }
    }
}

#endif

// MARK: - Batch File Processing

/// Advanced batch file processor for macOS with progress reporting
@available(macOS 11.0, *)
public actor BatchFileProcessor {
    public struct ProcessingResult {
        public let totalFiles: Int
        public let successCount: Int
        public let errorCount: Int
        public let errors: [String: Error]
        public let processingTime: TimeInterval
        
        public init(totalFiles: Int, successCount: Int, errorCount: Int, errors: [String: Error], processingTime: TimeInterval) {
            self.totalFiles = totalFiles
            self.successCount = successCount
            self.errorCount = errorCount
            self.errors = errors
            self.processingTime = processingTime
        }
    }
    
    public enum Operation {
        case validate
        case parse
        case convert(format: String)
    }
    
    /// Process all HL7 files in a directory
    public func processDirectory(
        _ directory: URL,
        operation: Operation,
        recursive: Bool = false
    ) async throws -> ProcessingResult {
        let startTime = Date()
        let fileManager = FileManager.default
        
        var files: [URL] = []
        
        if recursive {
            let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension == "hl7" {
                    files.append(fileURL)
                }
            }
        } else {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
            files = contents.filter { $0.pathExtension == "hl7" }
        }
        
        var successCount = 0
        var errors: [String: Error] = [:]
        
        for fileURL in files {
            do {
                try await processFile(fileURL, operation: operation)
                successCount += 1
            } catch {
                errors[fileURL.lastPathComponent] = error
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return ProcessingResult(
            totalFiles: files.count,
            successCount: successCount,
            errorCount: errors.count,
            errors: errors,
            processingTime: processingTime
        )
    }
    
    private func processFile(_ url: URL, operation: Operation) async throws {
        let data = try Data(contentsOf: url)
        let parser = HL7v2Parser()
        let message = try parser.parse(data)
        
        switch operation {
        case .validate:
            try message.validate()
            
        case .parse:
            // Already parsed
            break
            
        case .convert(let format):
            switch format {
            case "json":
                // Convert to JSON representation
                _ = try JSONEncoder().encode(message)
            case "xml":
                // Convert to XML (v3 CDA if applicable)
                break
            default:
                throw NSError(domain: "HL7kit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown format: \(format)"])
            }
        }
    }
    
    /// Export processing results to a report file
    public func exportReport(_ result: ProcessingResult, to url: URL) async throws {
        let report = """
        HL7kit Batch Processing Report
        ===============================
        
        Total Files: \(result.totalFiles)
        Successful: \(result.successCount)
        Errors: \(result.errorCount)
        Processing Time: \(String(format: "%.2f", result.processingTime))s
        
        Errors:
        \(result.errors.map { "- \($0.key): \($0.value.localizedDescription)" }.joined(separator: "\n"))
        """
        
        try report.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Document-Based Application Support

#if canImport(AppKit)

/// Document class for HL7 message documents
@available(macOS 11.0, *)
open class HL7Document: NSDocument {
    private var message: HL7v2Message?
    
    open override class var autosavesInPlace: Bool {
        return true
    }
    
    open override func makeWindowControllers() {
        guard let message = message else { return }
        
        let windowController = HL7MessageWindowController(message: message)
        addWindowController(windowController)
    }
    
    open override func data(ofType typeName: String) throws -> Data {
        guard let message = message else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        
        let serializer = HL7v2Serializer()
        return try serializer.serialize(message)
    }
    
    open override func read(from data: Data, ofType typeName: String) throws {
        let parser = HL7v2Parser()
        message = try parser.parse(data)
    }
}

#endif

// MARK: - Spotlight Integration

/// Metadata importer for HL7 messages (conceptual - actual implementation would be in a Spotlight plugin)
@available(macOS 11.0, *)
public struct SpotlightMetadata {
    public let messageType: String
    public let sendingApplication: String
    public let messageControlID: String
    public let patientID: String?
    
    public init(from message: HL7v2Message) {
        // Extract MSH fields
        if let msh = message.segments.first(where: { $0.id == "MSH" }), msh.fields.count > 10 {
            self.sendingApplication = msh.fields[2]
            self.messageType = msh.fields[8]
            self.messageControlID = msh.fields[9]
        } else {
            self.sendingApplication = ""
            self.messageType = ""
            self.messageControlID = ""
        }
        
        // Extract patient ID from PID segment
        if let pid = message.segments.first(where: { $0.id == "PID" }), pid.fields.count > 3 {
            self.patientID = pid.fields[3]
        } else {
            self.patientID = nil
        }
    }
}

// MARK: - Command Line Tool Integration

/// Helper for integrating with the hl7 CLI tool
@available(macOS 11.0, *)
public actor CLIIntegration {
    /// Run the hl7 CLI tool with arguments
    public func runCLI(arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "run", "hl7"] + arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Validate a file using the CLI
    public func validateFile(_ url: URL) async throws -> Bool {
        let output = try await runCLI(arguments: ["validate", url.path])
        return !output.contains("Error")
    }
    
    /// Inspect a file using the CLI
    public func inspectFile(_ url: URL) async throws -> String {
        return try await runCLI(arguments: ["inspect", url.path])
    }
}

// MARK: - Example Usage Functions

/// Example: Create a menu bar app
@available(macOS 11.0, *)
public func exampleMenuBarApp() {
    let menuBarManager = HL7MenuBarManager()
    menuBarManager.setupMenuBar()
}

/// Example: Batch process directory
@available(macOS 11.0, *)
public func exampleBatchProcessing() async throws {
    let processor = BatchFileProcessor()
    let directoryURL = URL(fileURLWithPath: "/path/to/messages")
    
    let result = try await processor.processDirectory(
        directoryURL,
        operation: .validate,
        recursive: true
    )
    
    print("Processed \(result.totalFiles) files")
    print("Success: \(result.successCount)")
    print("Errors: \(result.errorCount)")
    print("Time: \(result.processingTime)s")
    
    // Export report
    let reportURL = URL(fileURLWithPath: "/tmp/processing-report.txt")
    try await processor.exportReport(result, to: reportURL)
}

/// Example: AppleScript automation
@available(macOS 11.0, *)
public func exampleAppleScriptAutomation() async throws {
    let appleScript = AppleScriptSupport()
    
    let script = appleScript.generateBatchProcessScript(directory: "/path/to/messages")
    let result = try await appleScript.executeScript(script)
    print("AppleScript result: \(result)")
}

/// Example: CLI integration
@available(macOS 11.0, *)
public func exampleCLIIntegration() async throws {
    let cli = CLIIntegration()
    
    let fileURL = URL(fileURLWithPath: "/path/to/message.hl7")
    
    // Validate
    let isValid = try await cli.validateFile(fileURL)
    print("Valid: \(isValid)")
    
    // Inspect
    let inspection = try await cli.inspectFile(fileURL)
    print("Inspection:\n\(inspection)")
}

/// Example: Service menu integration
@available(macOS 11.0, *)
public func exampleServiceMenuSetup() {
    // In your app's Info.plist, add:
    // <key>NSServices</key>
    // <array>
    //   <dict>
    //     <key>NSMessage</key>
    //     <string>validateHL7Message</string>
    //     <key>NSPortName</key>
    //     <string>YourAppName</string>
    //     <key>NSSendTypes</key>
    //     <array>
    //       <string>NSStringPboardType</string>
    //     </array>
    //     <key>NSReturnTypes</key>
    //     <array>
    //       <string>NSStringPboardType</string>
    //     </array>
    //     <key>NSMenuItem</key>
    //     <dict>
    //       <key>default</key>
    //       <string>Validate HL7 Message</string>
    //     </dict>
    //   </dict>
    // </array>
    
    let provider = HL7ServiceProvider()
    NSApplication.shared.servicesProvider = provider
}

#endif
