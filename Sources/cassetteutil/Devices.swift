//
//  Devices.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 11.1.2026.
//

import ArgumentParser
import CoreAudio

struct ListInputDevices: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-inputs",
		abstract: "List available audio input devices.")
	
	func run() throws {
		try AudioObject.devices
			.filter({ try $0.inputStreams.count > 0 })
			.forEach() {
				print("\($0.id): \(try $0.name)")
			}
	}
}

struct ListOutputDevices: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-outputs",
		abstract: "List available audio output devices.")
	
	func run() throws {
		try AudioObject.devices
			.filter({ try $0.outputStreams.count > 0 })
			.forEach() {
				print("\($0.id): \(try $0.name)")
			}
	}
}


// MARK: -
// MARK: Convenience functionality
extension AudioObject {
	static var devices: [AudioObject] {
		get throws {
			try AudioObject(id: .system)
				.values(for: .devices)
				.map({ AudioObject(id: $0) })
		}
	}
	
	var name: String {
		get throws {
			let name: CFString = try self.object(for: .name)
			return name as String
		}
	}
	
	var inputStreams: [AudioObject] {
		get throws {
			try self.values(for: .streams, scope: .input)
				.map({ AudioObject(id: $0) })
		}
	}
	
	var outputStreams: [AudioObject] {
		get throws {
			try self.values(for: .streams, scope: .output)
				.map({ AudioObject(id: $0) })
		}
	}
}
