/// FHIRJSONSerialization.swift
/// JSON serialization and deserialization for FHIR resources
///
/// This file provides JSON parsing and serialization for FHIR R4 resources
/// using Foundation's JSONEncoder/JSONDecoder with FHIR-specific customizations.

import Foundation
import HL7Core

// MARK: - FHIR JSON Serializer

/// FHIR JSON serialization actor for thread-safe JSON operations
public actor FHIRJSONSerializer {
    /// Serialization configuration
    public let configuration: FHIRSerializationConfiguration
    
    /// Internal encoder
    private let encoder: JSONEncoder
    
    /// Internal decoder
    private let decoder: JSONDecoder
    
    public init(configuration: FHIRSerializationConfiguration = .default) {
        self.configuration = configuration
        
        // Configure encoder
        self.encoder = JSONEncoder()
        switch configuration.outputFormatting {
        case .compact:
            self.encoder.outputFormatting = []
        case .prettyPrinted:
            self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        }
        
        switch configuration.dateStrategy {
        case .iso8601:
            self.encoder.dateEncodingStrategy = .iso8601
        case .formatted(let formatter):
            self.encoder.dateEncodingStrategy = .formatted(formatter)
        }
        
        // Configure decoder
        self.decoder = JSONDecoder()
        switch configuration.dateStrategy {
        case .iso8601:
            self.decoder.dateDecodingStrategy = .iso8601
        case .formatted(let formatter):
            self.decoder.dateDecodingStrategy = .formatted(formatter)
        }
    }
    
    // MARK: - Encoding
    
    /// Encode a FHIR resource to JSON data
    public func encode<T: Encodable & Sendable>(_ resource: T) throws -> Data {
        try encoder.encode(resource)
    }
    
    /// Encode a FHIR resource to JSON string
    public func encodeToString<T: Encodable & Sendable>(_ resource: T) throws -> String {
        let data = try encode(resource)
        guard let string = String(data: data, encoding: .utf8) else {
            throw FHIRSerializationError.invalidJSON("Failed to convert data to UTF-8 string")
        }
        return string
    }
    
    // MARK: - Decoding
    
    /// Decode FHIR resource from JSON data
    public func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch let error as DecodingError {
            throw FHIRSerializationError.invalidJSON(error.localizedDescription)
        }
    }
    
    /// Decode FHIR resource from JSON string
    public func decode<T: Decodable & Sendable>(_ type: T.Type, from string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw FHIRSerializationError.invalidJSON("Invalid UTF-8 string")
        }
        return try decode(type, from: data)
    }
    
    /// Decode FHIR resource container from JSON data (polymorphic)
    public func decodeResource(from data: Data) throws -> ResourceContainer {
        try decode(ResourceContainer.self, from: data)
    }
    
    /// Decode FHIR resource container from JSON string (polymorphic)
    public func decodeResource(from string: String) throws -> ResourceContainer {
        try decode(ResourceContainer.self, from: string)
    }
}

// MARK: - Convenience Functions

/// Global convenience functions for FHIR JSON serialization
public enum FHIRJSON {
    /// Encode a FHIR resource to JSON data
    public static func encode<T: Encodable & Sendable>(_ resource: T, configuration: FHIRSerializationConfiguration = .default) async throws -> Data {
        let serializer = FHIRJSONSerializer(configuration: configuration)
        return try await serializer.encode(resource)
    }
    
    /// Encode a FHIR resource to JSON string
    public static func encodeToString<T: Encodable & Sendable>(_ resource: T, configuration: FHIRSerializationConfiguration = .default) async throws -> String {
        let serializer = FHIRJSONSerializer(configuration: configuration)
        return try await serializer.encodeToString(resource)
    }
    
    /// Decode FHIR resource from JSON data
    public static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data, configuration: FHIRSerializationConfiguration = .default) async throws -> T {
        let serializer = FHIRJSONSerializer(configuration: configuration)
        return try await serializer.decode(type, from: data)
    }
    
    /// Decode FHIR resource from JSON string
    public static func decode<T: Decodable & Sendable>(_ type: T.Type, from string: String, configuration: FHIRSerializationConfiguration = .default) async throws -> T {
        let serializer = FHIRJSONSerializer(configuration: configuration)
        return try await serializer.decode(type, from: string)
    }
    
    /// Decode FHIR resource container (polymorphic)
    public static func decodeResource(from data: Data, configuration: FHIRSerializationConfiguration = .default) async throws -> ResourceContainer {
        let serializer = FHIRJSONSerializer(configuration: configuration)
        return try await serializer.decodeResource(from: data)
    }
    
    /// Decode FHIR resource container from string (polymorphic)
    public static func decodeResource(from string: String, configuration: FHIRSerializationConfiguration = .default) async throws -> ResourceContainer {
        let serializer = FHIRJSONSerializer(configuration: configuration)
        return try await serializer.decodeResource(from: string)
    }
}

// MARK: - Bundle Streaming Parser

/// Streaming parser for large FHIR Bundles
public actor FHIRBundleStreamParser {
    /// Configuration
    public let configuration: FHIRSerializationConfiguration
    
    /// Chunk size for streaming
    private let chunkSize: Int
    
    public init(configuration: FHIRSerializationConfiguration = .default, chunkSize: Int = 1024 * 1024) {
        self.configuration = configuration
        self.chunkSize = chunkSize
    }
    
    /// Parse a large Bundle from data stream
    public func parseBundleEntries(from data: Data) async throws -> AsyncStream<ResourceContainer> {
        AsyncStream { continuation in
            Task {
                do {
                    // Decode the entire bundle first
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let bundle = try decoder.decode(Bundle.self, from: data)
                    
                    // Stream entries one at a time
                    if let entries = bundle.entry {
                        for entry in entries {
                            if let resource = entry.resource {
                                continuation.yield(resource)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                    throw FHIRSerializationError.invalidJSON(error.localizedDescription)
                }
            }
        }
    }
    
    /// Parse Bundle entries from file
    public func parseBundleEntries(fromFile path: String) async throws -> AsyncStream<ResourceContainer> {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        return try await parseBundleEntries(from: data)
    }
}
