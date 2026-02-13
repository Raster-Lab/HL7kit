// HelpText.swift
// HL7CLI
//
// Help text and usage information for the HL7kit CLI tools.

import Foundation

/// Provides help text for all CLI commands
public enum HelpText {
    /// Main help text shown when no command is specified
    public static let main = """
        HL7kit CLI - Command-line tools for HL7 message processing

        USAGE:
            hl7 <command> [options]

        COMMANDS:
            validate      Validate HL7 v2.x messages
            convert       Convert between HL7 message formats
            inspect       Inspect and debug HL7 messages
            batch         Batch process multiple HL7 message files
            conformance   Check message conformance against profiles

        OPTIONS:
            --help, -h    Show help information
            --version, -v Show version information

        EXAMPLES:
            hl7 validate message.hl7
            hl7 inspect message.hl7 --stats
            hl7 convert message.hl7 --from hl7v2 --to hl7v3
            hl7 batch *.hl7 --operation validate
            hl7 conformance message.hl7 --profile ADT_A01

        Run 'hl7 <command> --help' for more information on a specific command.
        """

    /// Help text for the validate command
    public static let validate = """
        USAGE:
            hl7 validate [options] <file> [<file> ...]

        DESCRIPTION:
            Validates one or more HL7 v2.x messages for structural correctness,
            required fields, and data type conformance.

        ARGUMENTS:
            <file>          One or more HL7 message files to validate

        OPTIONS:
            --strict        Enable strict validation mode
            --stdin         Read message from standard input
            --format <fmt>  Output format: 'text' (default) or 'json'
            --help, -h      Show help information

        EXAMPLES:
            hl7 validate message.hl7
            hl7 validate --strict message.hl7
            hl7 validate --format json message.hl7
            cat message.hl7 | hl7 validate --stdin
        """

    /// Help text for the convert command
    public static let convert = """
        USAGE:
            hl7 convert [options] <file>

        DESCRIPTION:
            Converts an HL7 message between different formats. Supports conversion
            between HL7 v2.x, HL7 v3.x (CDA), and FHIR (JSON/XML) formats.

        ARGUMENTS:
            <file>              Input message file

        OPTIONS:
            --from <format>     Source format: 'hl7v2', 'hl7v3', 'fhir-json', 'fhir-xml'
            --to <format>       Target format: 'hl7v2', 'hl7v3', 'fhir-json', 'fhir-xml'
            --output, -o <file> Output file (prints to stdout if omitted)
            --pretty            Pretty-print the output
            --help, -h          Show help information

        EXAMPLES:
            hl7 convert message.hl7 --from hl7v2 --to hl7v3
            hl7 convert message.hl7 --from hl7v2 --to fhir-json --pretty
            hl7 convert message.hl7 --from hl7v2 --to hl7v3 -o output.xml
        """

    /// Help text for the inspect command
    public static let inspect = """
        USAGE:
            hl7 inspect [options] <file>

        DESCRIPTION:
            Inspects an HL7 v2.x message, showing its structure, segments,
            fields, and components in a human-readable format.

        ARGUMENTS:
            <file>              Input message file

        OPTIONS:
            --no-tree           Hide the tree view
            --stats             Show message statistics
            --search, -s <term> Search for a value in the message
            --format <fmt>      Output format: 'text' (default) or 'json'
            --help, -h          Show help information

        EXAMPLES:
            hl7 inspect message.hl7
            hl7 inspect message.hl7 --stats
            hl7 inspect message.hl7 --search "Doe"
            hl7 inspect message.hl7 --no-tree --stats
        """

    /// Help text for the batch command
    public static let batch = """
        USAGE:
            hl7 batch [options] <file> [<file> ...]

        DESCRIPTION:
            Batch processes multiple HL7 message files. Supports validation,
            inspection, and conversion operations across many files.

        ARGUMENTS:
            <file>                  One or more HL7 message files

        OPTIONS:
            --operation, --op <op>  Operation: 'validate' (default), 'inspect', 'convert'
            --output-dir, -d <dir>  Output directory for results
            --stop-on-error         Stop processing on first error
            --format <fmt>          Output format: 'text' (default) or 'json'
            --help, -h              Show help information

        EXAMPLES:
            hl7 batch *.hl7
            hl7 batch --operation inspect messages/*.hl7
            hl7 batch --operation validate --format json *.hl7
            hl7 batch --stop-on-error messages/*.hl7
        """

    /// Help text for the conformance command
    public static let conformance = """
        USAGE:
            hl7 conformance [options] <file>

        DESCRIPTION:
            Checks an HL7 v2.x message against a conformance profile.
            Validates segment structure, required fields, data types,
            and cardinality constraints.

        ARGUMENTS:
            <file>                  Input message file

        OPTIONS:
            --profile, -p <name>    Profile name (auto-detected if omitted)
                                    Available profiles: ADT_A01, ORU_R01, ORM_O01, ACK
            --format <fmt>          Output format: 'text' (default) or 'json'
            --help, -h              Show help information

        EXAMPLES:
            hl7 conformance message.hl7
            hl7 conformance message.hl7 --profile ADT_A01
            hl7 conformance message.hl7 --format json
        """

    /// Version string
    public static let version = "HL7kit CLI v1.0.0"
}
