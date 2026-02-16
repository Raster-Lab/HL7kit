// Disambiguate HL7v3Kit types from Foundation types with the same names (available on macOS/Apple platforms).
// On macOS, Foundation vends XMLElement (NSXMLElement) and XMLDocument (NSXMLDocument) which
// collide with HL7v3Kit's own types. These typealiases ensure unqualified names resolve to HL7v3Kit.
import HL7v3Kit

typealias XMLElement = HL7v3Kit.XMLElement
typealias XMLDocument = HL7v3Kit.XMLDocument
