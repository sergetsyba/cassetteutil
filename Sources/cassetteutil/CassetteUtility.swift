//
//  main.swift
//  cassetteutil
//
//  Created by Serge Tsyba on 3.1.2026.
//

import ArgumentParser
import libcassetteio

@main
struct CassetteUtility: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "cassettteutil",
		subcommands: [
			Write.self,
			ListFormats.self,
			ListInputDevices.self,
			ListOutputDevices.self
		])
}

func print2(cells: [[String]], separator: String = "\t") {
	guard cells.count > 0,
		  cells[0].count > 0 else {
		return
	}
	
	let widths = cells[0].indices
		.map() { index in
			return cells.map({ $0[index].count })
				.max() ?? 0
		}
	
	for row in cells {
		let formatted = row.enumerated()
			.map({ $0.1.padding(toLength: widths[$0.0], withPad: " ", startingAt: 0) })
			.joined(separator: separator)
		
		print(formatted)
	}
}
