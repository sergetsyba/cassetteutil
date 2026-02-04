//
//  Write.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 12.1.2026.
//

import Foundation
import ArgumentParser
import libcassetteio

struct Write: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "write",
		abstract: "Encode and write data to audio output device or file.",)
	
	@Option(help: ArgumentHelp(
		"Audio cassette data format.",
		discussion: "Use --list-formats to view supported formats."))
	var format: Format
	
	@Option(help: ArgumentHelp(
		"File to encode.",
		discussion: "When omitted, encodes data from standard input.",
		valueName: "path"),
			transform: Self.mapInputFile(argument:))
	var inputFile: FileHandle?
	
	@Option(help: ArgumentHelp(
		"Audio device to write output to.",
		discussion: "Uses default audio output device when omitted.\n" +
		"Use --list-outputs to see available audio devices.",
		valueName: "device-id"),
			transform: Self.mapOutputDevice(argument:))
	var output: AudioDevice?
	
	@Option(help: ArgumentHelp(
		"File to write audio output to.",
		valueName: "path"),
			transform: Self.mapOutputFile(argument:))
	var outputFile: FileHandle?
	
	@Option(help: ArgumentHelp(
		"Output audio sample rate.",
		discussion: "When omitted, uses default sample rate of current " +
		"audio device when playing or 44100 when writing a file."))
	var sampleRate: Int?
	
	private static func mapInputFile(argument path: String) throws -> FileHandle {
		let manager: FileManager = .default
		
		// verify input file exists
		var isDirectory: ObjCBool = false
		guard let url = URL(string: path),
			  manager.fileExists(atPath: path, isDirectory: &isDirectory),
			  isDirectory.boolValue == false else {
			throw WriteError.inputFileDoesNotExist(path)
		}
		// verify input file is readable
		guard manager.isReadableFile(atPath: url.path) else {
			throw WriteError.inputFileNotReadable(path)
		}
		// verify input file is not empty
		guard let attributes = try? manager.attributesOfItem(atPath: path),
			  let size = attributes[.size] as? Int64,
			  size > 0 else {
			throw WriteError.inputFileEmpty(path)
		}
		
		return try FileHandle(forReadingFrom: url)
	}
	
	private static func mapOutputFile(argument path: String) throws -> FileHandle {
		// verify output file does not exist
		let manager: FileManager = .default
		guard let url = URL(string: path),
			  manager.fileExists(atPath: url.path) == false else {
			throw WriteError.outputFileExists(path)
		}
		// verify output file directory exists
		let folderURL = url.deletingLastPathComponent()
		guard manager.directoryExists(atPath: folderURL.path) else {
			throw WriteError.outputFileDirectoryDoesNotExist(path)
		}
		// verify output file directory is writable
		guard manager.isWritableFile(atPath: url.path) else {
			throw WriteError.outputFileDirectoryNotWritable(folderURL.path)
		}
		
		return try FileHandle(forWritingTo: url)
	}
	
	private static func mapOutputDevice(argument: String) throws -> AudioDevice {
		// verify output device exists
		guard let id = Int(argument),
			  let device = AudioDevice(id: id),
			  device.scope.contains(.output) else {
			throw WriteError.outputDeviceDoesNotExist(argument)
		}
		
		return device
	}
	
	private var inputData: Data {
		get throws {
			let data: Data?
			if let inputFile = self.inputFile {
				data = try inputFile.readToEnd()
				try? inputFile.close()
			} else {
				let input: FileHandle = .standardInput
				data = try input.readToEnd()
			}
			
			// verify input is not empty
			guard let data,
				  data.count > 0 else {
				throw WriteError.noInput
			}
			return data
		}
	}
	
	private var outputDevice: AudioDevice {
		get throws {
			// play encoded data on an audio device when output device is
			// specified, or on play on default audio device when neither
			// output device nor output file is specified
			if let device = self.output {
				return device
			} else {
				// verify default audio output device exists
				guard let device: AudioDevice = .defaultOutput else {
					throw WriteError.outputDefaultDeviceDoesNotExist
				}
				return device
			}
		}
	}
	
	func run() async throws {
		let data = try self.inputData
		try await withThrowingTaskGroup() {
			$0.addTask() {
				try await self.outputDevice.playEncoded(data: data, sampleRate: self.sampleRate)
			}
			// save encoded data when output file is specified
			if let outputFile {
				$0.addTask() {
					outputFile.writeEncoded(data, sampleRate: self.sampleRate ?? 44100)
				}
			}
			
			// rethrow in case any task fails
			try await $0.waitForAll()
		}
	}
}
// MARK: -
// MARK: Errors
enum WriteError: Error {
	case inputNotFile(String)
	case inputFileDoesNotExist(String)
	case inputFileNotReadable(String)
	case inputFileEmpty(String)
	case noInput
	case outputDeviceDoesNotExist(String)
	case outputDefaultDeviceDoesNotExist
	case outputFileExists(String)
	case outputFileDirectoryDoesNotExist(String)
	case outputFileDirectoryNotWritable(String)
}

extension WriteError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .inputNotFile(let value):
			return "Invalid input file path \(value)."
		case .inputFileDoesNotExist(let path):
			return "No input file at \(path)."
		case .inputFileNotReadable(let path):
			return "Cannot read input file at \(path)."
		case .inputFileEmpty(let path):
			return "Input file is empty \(path)."
		case .noInput:
			return "Input is empty."
		case .outputDeviceDoesNotExist(let deviceId):
			return "No audio output device with id \(deviceId)."
		case .outputDefaultDeviceDoesNotExist:
			return "No default audio output device."
		case .outputFileExists(let path):
			return "Output file already exists at \(path)."
		case .outputFileDirectoryDoesNotExist(let path):
			return "No output file directory at \(path)."
		case .outputFileDirectoryNotWritable(let path):
			return "Cannot write output file at \(path)."
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
	
	func directoryExists(atPath path: String) -> Bool {
		var isDirectory: ObjCBool = false
		let exists = self.fileExists(atPath: path, isDirectory: &isDirectory)
		return exists && isDirectory.boolValue
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
