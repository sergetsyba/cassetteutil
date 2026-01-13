//
//  File.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 12.1.2026.
//

import ArgumentParser
import AudioToolbox

extension CassetteUtility {
	struct Write: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "write",
			abstract: "Write data to audio output device or file.",)
		
		@Option(help: ArgumentHelp(
			"Audio cassette data format.",
			discussion: "Use --list-formats to view supported formats."))
		var format: Format
		
		@Option(help: ArgumentHelp(
			"Audio device to write output to.",
			discussion: "Uses default audio output device when omitted.\nUse --list-outputs to view available devices.",
			valueName: "device-id"))
		var output: Int?
		
		@Option(help: ArgumentHelp(
			"File to write audio output to.",
			valueName: "path"))
		var outputFile: String?
		
		func run() throws {
			
		}
		
		
		
	}
}

// MARK: -
// MARK: Examples

/// write data from standard input to default audio output device using Apple || cassette format
// cassetteutil write --format=apple2

/// write data from ~/data.txt to audio device #23 using Apple || cassette format
// cassetteutil write --format=apple2 --file ~/data.txt --output=23

/// write data from ~/data.txt to AIFF file ~/cassette.aiff using Apple || cassette format
// cassetteutil write --format=apple2 --file ~/data.txt --output-file ~/cassette.aiff
