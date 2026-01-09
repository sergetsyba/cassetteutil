//
//  main.swift
//  cassetteutil
//
//  Created by Serge Tsyba on 3.1.2026.
//

import ArgumentParser
import libcassetteio

struct CassetteUtility: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "cassettteutil",
		subcommands: [
			Write.self,
			ListFormats.self
		])
}

// MARK: -
// MARK: write
extension CassetteUtility {
	struct Write: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "write",
			abstract: "Write data to audio output or file.")
		
		@Option(help: "File to write audio output to.")
		var outputFile: String
		
		@Option(help: "Output audio sample rate (in Hz).")
		var sampleRate: Int = 44100
		
		func run() throws {
			let data = "Hello Apple II"
			
			
		}
	}
}


// MARK: -
// MARK: list-formats
extension CassetteUtility {
	struct ListFormats: ParsableCommand {
		static let configuration = CommandConfiguration(
			abstract: "List supported data formats.")
		
		func run() throws {
			print("Supported formats and aliases:")
			
			for format in Format.allCases {
				let joined = format.aliases
					.joined(separator: ", ")
				
				print("\t\(joined)")
			}
		}
	}
	
	enum Format: String, ExpressibleByArgument, CaseIterable {
		case frequencyShiftKeying
		
		var aliases: [String] {
			switch self {
			case .frequencyShiftKeying:
				return ["frequency-shift-keying", "fsk", "apple2"]
			}
		}
		
		init?(argument: String) {
			guard let format = Self.allCases
				.first(where: { $0.aliases.contains(argument) }) else {
				return nil
			}
			self = format
		}
	}
}

CassetteUtility
	.main()
