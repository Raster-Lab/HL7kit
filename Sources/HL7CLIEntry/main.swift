// main.swift
// HL7CLI
//
// Entry point for the HL7kit command-line tools.

import Foundation
import HL7CLICore

/// Main entry point
let result = CLIParser.parse(CommandLine.arguments)

switch result {
case .success(let command):
    let exitCode: ExitCode
    switch command {
    case .validate(let options):
        exitCode = runValidate(options)
    case .convert(let options):
        exitCode = runConvert(options)
    case .inspect(let options):
        exitCode = runInspect(options)
    case .batch(let options):
        exitCode = runBatch(options)
    case .conformance(let options):
        exitCode = runConformance(options)
    case .help:
        print(HelpText.main)
        exitCode = .success
    case .version:
        print(HelpText.version)
        exitCode = .success
    }
    exit(exitCode.rawValue)

case .failure(let error):
    printError("\(error)")
    print("")
    print(HelpText.main)
    exit(ExitCode.usageError.rawValue)
}
