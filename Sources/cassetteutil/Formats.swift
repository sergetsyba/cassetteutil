//
//  Formats.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 11.1.2026.
//

import ArgumentParser

enum Format: String, ExpressibleByArgument {
	case frequencyShiftKeying
}


// MARK: -
struct ListFormats: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "List supported data formats.")
	
	func run() throws {
		print("Supported formats and aliases:")
		
		for format in Format.cases {
			let joined = format.aliases
				.joined(separator: ", ")
			
			print("\t\(joined)")
		}
	}
}

extension Format {
	var aliases: [String] {
		switch self {
		case .frequencyShiftKeying:
			return ["frequency-shift-keying", "fsk", "apple2"]
		}
	}
	
	init?(argument: String) {
		guard let format = Self.cases
			.first(where: { $0.aliases.contains(argument) }) else {
			return nil
		}
		self = format
	}
}

// NOTE: exposing all values explicitly insstead of adopting CaseIterable
// prevents ArgumentParser from including default values in help info
extension Format {
	static var cases: [Self] {
		return [.frequencyShiftKeying]
	}
}
