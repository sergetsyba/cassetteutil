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
			ListOutputs.self
		])
}
