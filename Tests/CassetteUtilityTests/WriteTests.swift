//
//  WriteTests.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 31.1.2026.
//

import Foundation
import Testing

@testable import ArgumentParser
@testable import CassetteUtility

@Suite("cassetteutil write")
struct WriteTests {
	@Test("runs when", arguments: [
		TestCase(
			description: "input file exists and is not empty",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file")
			]),
		TestCase(
			description: "output device exists",
			arguments: [
				"--format", "apple2",
				"--output", .anyAudioOutputDeviceId
			]),
		TestCase(
			description: "input file and output device omited",
			arguments: [
				"--format", "apple2"
			])
	])
	func validCommandArguments(test: TestCase) throws {
		let _ = try Write
			.parse(test.arguments)
	}
	
	@Test("fails when", arguments: [
		TestCase(
			description: "input file does not exist",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("nope.file")
			],
			error: .inputFileDoesNotExist(.resource("nope.file"))),
		TestCase(
			description: "input file is not readable",
			arguments: [
				"--format", "apple2",
				"--input-file", "/private/etc/master.passwd"
			],
			error: .inputFileNotReadable("/private/etc/master.passwd")),
		TestCase(
			description: "input file is empty",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("empty.file")
			],
			error: .inputFileEmpty(.resource("empty.file"))),
		TestCase(
			description: "output file exists",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file"),
				"--output-file", .resource("data.file"),
			],
			error: .outputFileExists(.resource("data.file"))),
		TestCase(
			description: "output file directory does not exist",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file"),
				"--output-file", .resource("nope/encoded.file")
			],
			error: .outputFileDirectoryDoesNotExist(.resource("nope/encoded.file"))),
		TestCase(
			description: "output file directory is not writable",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file"),
				"--output-file", "/private/etc/encoded.file"
			],
			error: .outputFileDirectoryNotWritable("/private/etc")),
		TestCase(
			description: "output device does not exists",
			arguments: [
				"--format", "apple2",
				"--input-file", .resource("data.file"),
				"--output", "nope"
			],
			error: .outputDeviceDoesNotExist("nope")),
	])
	func invalidCommandArguments(test: TestCase) {
		#expect(throws: test.error!, test.comment) {
			do {
				let _ = try Write
					.parse(test.arguments)
			} catch let commandError as CommandError {
				// unwrap original write command error
				if case .unableToParseValue(_, _, _, _, let originalError) = commandError.parserError,
				   let error = originalError as? WriteError {
					throw error
				}
				throw commandError
			}
		}
	}
}

extension WriteTests {
	struct TestCase: CustomTestStringConvertible {
		var description: String
		var arguments: [String]
		var error: WriteError?
		
		init(description: String, arguments: [String], error: WriteError? = nil) {
			self.description = description
			self.arguments = arguments
			self.error = error
		}
		
		var comment: Comment {
			return Comment(stringLiteral: self.description)
		}
		
		var testDescription: String {
			return self.description
		}
	}
}


// MARK: -
extension WriteError: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		switch (lhs, rhs) {
		case let (.inputNotFile(lhs), .inputNotFile(rhs)),
			let (.inputFileDoesNotExist(lhs), .inputFileDoesNotExist(rhs)),
			let (.inputFileNotReadable(lhs), .inputFileNotReadable(rhs)),
			let (.inputFileEmpty(lhs), .inputFileEmpty(rhs)),
			let (.outputDeviceDoesNotExist(lhs), .outputDeviceDoesNotExist(rhs)),
			let (.outputFileExists(lhs), .outputFileExists(rhs)),
			let (.outputFileDirectoryDoesNotExist(lhs), .outputFileDirectoryDoesNotExist(rhs)),
			let (.outputFileDirectoryNotWritable(lhs), .outputFileDirectoryNotWritable(rhs)):
			return lhs == rhs
			
		case (.noInput, .noInput),
			(.outputDefaultDeviceDoesNotExist, .outputDefaultDeviceDoesNotExist):
			return true
			
		default:
			return false
		}
	}
}

private extension String {
	static var anyAudioOutputDeviceId: Self {
		return String(AudioDevice.defaultOutput!.id)
	}
	
	static func resource(_ name: String) -> String! {
		return Bundle.module
			.url(forResource: "data", withExtension: "file")?
			.deletingLastPathComponent()
			.appending(path: name)
			.relativePath
	}
}
