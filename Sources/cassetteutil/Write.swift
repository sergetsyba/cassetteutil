//
//  File.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 12.1.2026.
//

import Foundation
import ArgumentParser
import libcassetteio

extension CassetteUtility {
	struct Write: AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "write",
			abstract: "Encode and write data to audio output device or file.",)
		
		@Option(help: ArgumentHelp(
			"Audio cassette data format.",
			discussion: "Use --list-formats to view supported formats."))
		var format: Format
		
		@Option(help: ArgumentHelp(
			"Audio device to write output to.",
			discussion: "Uses default audio output device when omitted.\n" +
			"Use --list-outputs to see available audio devices.",
			valueName: "device-id"))
		var output: Int?
		
		@Option(help: ArgumentHelp(
			"File to encode.",
			discussion: "When omitted, encodes data from standard input.",
			valueName: "path"))
		var inputFile: String?
		
		@Option(help: ArgumentHelp(
			"File to write audio output to.",
			valueName: "path"))
		var outputFile: String?
		
		@Option
		var sampleRate: Int = 11025
		
		func validate() throws {
			// verify input file exists, when specified
			let manager: FileManager = .default
			if let path = self.inputFile {
				guard manager.fileExists(atPath: path) else {
					throw WriteError.inputFileDoesNotExist(path)
				}
				// verify file is readable
				guard manager.isReadableFile(atPath: path) else {
					throw WriteError.inputFileNotReadable(path)
				}
				// verify input file is not empty
				guard let attributes = try? manager.attributesOfItem(atPath: path),
					  let size = attributes[.size] as? Int64,
					  size > 0 else {
					throw WriteError.inputFileEmpty(path)
				}
			}
			// verify output file does not exist, when specified
			if let path = self.outputFile {
				guard manager.fileExists(atPath: path) == false else {
					throw WriteError.outputFileExists(path)
				}
			}
			// verify either input file specified or there's data in
			// standard input
			guard manager.standardInputAvailable ||
					manager.fileExists(atPath: self.inputFile ?? "") else {
				throw WriteError.noInput
			}
		}
		
		private func readInput() throws -> Data {
			if let path = self.inputFile {
				let url = URL(filePath: path)
				return try Data(contentsOf: url)
			} else {
				let input: FileHandle = .standardInput
				return try input.readToEnd()!
			}
		}
		
		private func playEncoded(data: Data) async throws {
			var encoder: UnsafeMutablePointer<cassette_apple2_encoder>!
			data.withUnsafeBytes() {
				encoder = cassette_apple2_malloc_encoder($0.baseAddress!, data.count, Int32(UInt32(self.sampleRate)))
			}
			
			try await AudioQueue.play(format: .mono(sampleRate: self.sampleRate)) {
				cassette_apple2_write_monitor_record($0, $1, encoder)
			}
		}
		
		private func saveEncoded(data: Data, at path: String) async throws {
			var encoder: UnsafeMutablePointer<cassette_apple2_encoder>!
			data.withUnsafeBytes() {
				encoder = cassette_apple2_malloc_encoder($0.baseAddress!, data.count, Int32(self.sampleRate))
			}
			
			let url = URL(fileURLWithPath: path)
			try await AudioFile.writeFile(at: url, format: .mono(sampleRate: self.sampleRate)) {
				cassette_apple2_write_monitor_record($0, $1, encoder)
			}
		}
		
		func run() async throws {
			try await withThrowingTaskGroup() {
				let data = try self.readInput()
				
				// save file when output is specified
				if self.output != nil || self.outputFile == nil {
					$0.addTask() {
						try await self.playEncoded(data: data)
					}
				}
				// save encoded data when output file is specified
				if let path = self.outputFile {
					$0.addTask() {
						try await self.saveEncoded(data: data, at: path)
					}
				}
			}
		}
	}
}

enum WriteError: LocalizedError {
	case noInput
	case inputFileDoesNotExist(String)
	case inputFileNotReadable(String)
	case inputFileEmpty(String)
	case outputFileExists(String)
	
	var errorDescription: String? {
		switch self {
		case .noInput:
			return "No input specified."
		case .inputFileDoesNotExist(let path):
			return "No input file exists at \(path)."
		case .inputFileNotReadable(let path):
			return "Cannot read file at \(path)."
		case .inputFileEmpty:
			return "Input file is empty."
		case .outputFileExists(let path):
			return "Output file already exists at \(path)."
		}
	}
}

private extension FileManager {
	var standardInputAvailable: Bool {
		var pollfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
		return poll(&pollfd, 1, 0) > 0 && (pollfd.events & Int16(POLLIN) != 0)
	}
}

// MARK: -
// MARK: Examples

/// write data from standard input to default audio output device using Apple || cassette format
// cassetteutil write --format apple2

/// write data from ~/data.txt to audio device #23 using Apple || cassette format
// cassetteutil write --format apple2 --input-file ~/data.txt --output=23

/// write data from ~/data.txt to AIFF file ~/cassette.aiff using Apple || cassette format
// cassetteutil write --format apple2 --input-file ~/data.txt --output-file ~/cassette.aiff
