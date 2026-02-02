//
//  WriteCommandTests.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 31.1.2026.
//

import Testing
import Foundation
@testable import ArgumentParser
@testable import CassetteUtility

@Suite("cassetteutil write")
struct WriteCommandTests {
	struct TestCase: CustomTestStringConvertible {
		var description: String
		var arguments: [String]
		var expected: CassetteUtility.WriteError
		
		var comment: Comment {
			return Comment(stringLiteral: self.description)
		}
		
		var testDescription: String {
			return self.description
		}
	}
	
	@Test("fails when", arguments: [
		TestCase(
			description: "input file does not exist",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("nope.file")
			],
			expected: .inputFileDoesNotExist(.resource("nope.file"))),
		TestCase(
			description: "input file is not readable",
			arguments: [
				"--format", "apple2",
				"--input-file", "/private/etc/master.passwd"
			],
			expected: .inputFileNotReadable("/private/etc/master.passwd")),
		TestCase(
			description: "input file is empty",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("empty.file")
			],
			expected: .inputFileEmpty(.resource("empty.file"))),
		TestCase(
			description: "output file exists",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file"),
				"--output-file", .resource("data.file"),
			],
			expected: .outputFileExists(.resource("data.file"))),
		TestCase(
			description: "output file directory does not exist",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file"),
				"--output-file", .resource("nope/encoded.file")
			],
			expected: .outputFileDirectoryDoesNotExist(.resource("nope/encoded.file"))),
		TestCase(
			description: "output file directory is not writable",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file"),
				"--output-file", "/private/etc/encoded.file"
			],
			expected: .outputFileDirectoryNotWritable("/private/etc")),
		TestCase(
			description: "output device does not exists",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file"),
				"--output", "nope"
			],
			expected: .outputDeviceDoesNotExist("nope")),
	])
	func testCommandArguments(test: TestCase) {
		#expect(throws: test.expected, test.comment) {
			do {
				let _ = try CassetteUtility.Write
					.parse(test.arguments)
			} catch let error as CommandError {
				throw error.parseOriginalError ?? error
			}
		}
	}
}

// MARK: -
extension CassetteUtility.WriteError: Equatable {
	public static func == (lhs: CassetteUtility.WriteError, rhs: CassetteUtility.WriteError) -> Bool {
		switch (lhs, rhs) {
		case (.inputNotFile(let lhs), .inputNotFile(let rhs)),
			(.inputFileDoesNotExist(let lhs), .inputFileDoesNotExist(let rhs)),
			(.inputFileNotReadable(let lhs), .inputFileNotReadable(let rhs)),
			(.inputFileEmpty(let lhs), .inputFileEmpty(let rhs)),
			(.outputDeviceDoesNotExist(let lhs), .outputDeviceDoesNotExist(let rhs)),
			(.outputFileExists(let lhs), .outputFileExists(let rhs)),
			(.outputFileDirectoryDoesNotExist(let lhs), .outputFileDirectoryDoesNotExist(let rhs)),
			(.outputFileDirectoryNotWritable(let lhs), .outputFileDirectoryNotWritable(let rhs)):
			return lhs == rhs
			
		case (.noInput, .noInput),
			(.outputDefaultDeviceDoesNotExist, .outputDefaultDeviceDoesNotExist):
			return true
			
		default:
			return false
		}
	}
}

private extension CommandError {
	var parseOriginalError: Error? {
		guard case ParserError.unableToParseValue(_, _, _, _, let originalError) = self.parserError else {
			return nil
		}
		return originalError
	}
}

private extension String {
	static func resource(_ name: String) -> String! {
		return Bundle.module
			.url(forResource: "data", withExtension: "file")?
			.deletingLastPathComponent()
			.appending(path: name)
			.relativePath
	}
}
