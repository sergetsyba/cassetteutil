//
//  File.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 12.1.2026.
//

import Foundation
import AudioToolbox
import ArgumentParser
import libcassetteio
import AVFoundation

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
		var output: AudioDevice?
		
		@Option(help: ArgumentHelp(
			"File to encode.",
			discussion: "When omitted, encodes data from standard input.",
			valueName: "path"))
		var inputFile: URL?
		
		@Option(help: ArgumentHelp(
			"File to write audio output to.",
			valueName: "path"))
		var outputFile: URL?
		
		@Option(help: ArgumentHelp(
			"Output audio sample rate.",
			discussion: "When omitted, uses default sample rate of current " +
			"audio device when playing or 44100 when writing a file."))
		var sampleRate: Int?
		
		func validate() throws {
			// verify input file exists, when specified
			let manager: FileManager = .default
			if let path = self.inputFile?.path() {
				guard manager.fileExists(atPath: path) else {
					throw WriteCommandError.inputFileDoesNotExist(path)
				}
				// verify file is readable
				guard manager.isReadableFile(atPath: path) else {
					throw WriteCommandError.inputFileNotReadable(path)
				}
				// verify input file is not empty
				guard let attributes = try? manager.attributesOfItem(atPath: path),
					  let size = attributes[.size] as? Int64,
					  size > 0 else {
					throw WriteCommandError.inputFileEmpty(path)
				}
			}
			// verify output file does not exists, when specified
			if let path = self.outputFile?.path() {
				guard manager.fileExists(atPath: path) == false else {
					throw WriteCommandError.outputFileExists(path)
				}
			}
			// verify either input file specified or there's data in
			// standard input
			guard manager.standardInputAvailable ||
					manager.fileExists(atPath: self.inputFile?.path() ?? "") else {
				throw WriteCommandError.noInput
			}
			
			// TODO: verify output audio device exists, when specified
		}
		
		func run() async throws {
			try await withThrowingTaskGroup() {
				let data = try self.readInput()
				
				// play encoded data on an audio device when output device is
				// specified, or on play on default audio device when neither
				// output device nor output file is specified
				if self.output != nil || self.outputFile == nil {
					$0.addTask() {
						let device = self.output ?? .output
						await device.playEncoded(data: data)
					}
				}
				// save encoded data when output file is specified
				if let url = self.outputFile {
					$0.addTask() {
						let sampleRate = self.sampleRate ?? 44100
						data.writeEncoded(to: url, sampleRate: sampleRate)
					}
				}
			}
		}
		
		private func readInput() throws -> Data {
			if let url = self.inputFile {
				return try Data(contentsOf: url)
			} else {
				return try FileHandle.standardInput
					.readToEnd()!
			}
		}
	}
}

enum WriteCommandError: LocalizedError {
	case noInput
	case inputFileDoesNotExist(String)
	case inputFileNotReadable(String)
	case inputFileEmpty(String)
	case outputDeviceDoesNotExist(AudioDeviceID)
	case outputFileExists(String)
	
	var errorDescription: String? {
		switch self {
		case .noInput:
			return "No input specified."
		case .inputFileDoesNotExist(let path):
			return "No input file at \(path)."
		case .inputFileNotReadable(let path):
			return "Cannot read file at \(path)."
		case .inputFileEmpty:
			return "Input file is empty."
		case .outputDeviceDoesNotExist(let deviceId):
			return "No output audio device with id \(deviceId)."
		case .outputFileExists(let path):
			return "File already exists at \(path)."
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension FileManager {
	var standardInputAvailable: Bool {
		var pollfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
		return poll(&pollfd, 1, 0) > 0 && (pollfd.events & Int16(POLLIN) != 0)
	}
}

extension AudioDevice: ExpressibleByArgument {
	init?(argument: String) {
		guard let id = Int(argument) else {
			return nil
		}
		self.init(id: id, name: "", scope: [])
	}
}

extension URL: @retroactive ExpressibleByArgument {
	public init?(argument: String) {
		self.init(fileURLWithPath: argument)
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
