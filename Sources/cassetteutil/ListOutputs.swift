//
//  ListOutputs.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 11.1.2026.
//

import ArgumentParser
import libcassetteio

extension CassetteUtility {
	struct ListOutputs: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "list-outputs",
			abstract: "List available audio output devices.")
	}
	
	func run() throws {
		AudioDevice.all
			.filter({ $0.scope.contains(.output) })
			.map({ ["\($0.id)", $0.name] })
			.print(separator: " ")
	}
}
