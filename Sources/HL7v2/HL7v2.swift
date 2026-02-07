/// HL7v2 — parsing, encoding, validation, and MLLP transport for HL7 v2.x messages.
///
/// This module provides a complete toolkit for working with HL7 v2.x pipe-delimited
/// (ER7) and XML-encoded messages, including a HAPI-inspired terser for path-based
/// field access.
///
/// ## Quick Start
///
/// ```swift
/// import HL7v2
///
/// let message = try Message(parsing: rawHL7String)
/// let patientName = message.terser["PID-5-1"]
/// ```
