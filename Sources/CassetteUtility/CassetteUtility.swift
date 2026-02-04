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


// MARK: -
// MARK: Output formatting
extension Collection where Element: Collection< StringProtocol>, Index == Element.Index {
	func print(separator: String = "\t") {
		guard let firstRow = self.first,
			  firstRow.count > 0 else {
			return
		}
		
		let widths = firstRow.indices
			.map() { index in
				return self.map({ $0[index].count })
					.max() ?? 0
			}
		
		for row in self {
			let formatted = row.enumerated()
				.map() { (index, string) in
					String(string)
						.padded(toLength: widths[index], atEnd: index > 0)
				} .joined(separator: separator)
			
			Swift.print(formatted)
		}
	}
}

extension StringProtocol {
	func padded(toLength length: Int, using pad: Self = " ", atEnd: Bool = true) -> String {
		let padLength = length - self.count
		guard padLength > 0 else {
			return String(self)
		}
		
		let pad = (0..<padLength)
			.map({ _ in pad })
			.joined()
		
		return atEnd
		? self.appending(pad)
		: pad.appending(self)
	}
}
