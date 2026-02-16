// Disambiguate HL7v3Kit.XMLElement from Foundation.XMLElement (available on macOS/Apple platforms).
// This typealias ensures that unqualified `XMLElement` in HL7v3KitTests always refers to HL7v3Kit.XMLElement.
import HL7v3Kit

typealias XMLElement = HL7v3Kit.XMLElement
