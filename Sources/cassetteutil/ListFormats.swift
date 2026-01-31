//
//  ListFormats.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 11.1.2026.
//

import ArgumentParser

extension CassetteUtility {
	struct ListFormats: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "list-formats",
			abstract: "List supported data formats.")
		
		func run() throws {
			for format in Format.cases {
				print(format)
			}
		}
	}
}


// MARK: -
// MARK: Formats
enum Format: String, ExpressibleByArgument {
	case apple2
}

extension Format {
	var aliases: [String] {
		switch self {
		case .apple2:
			return ["apple2", "apple2-monitor"]
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
		return [.apple2]
	}
}
