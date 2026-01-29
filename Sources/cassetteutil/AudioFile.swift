//
//  File.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 27.1.2026.
//

import Foundation
import libcassetteio

extension Data {
	func writeEncoded(to url: URL, sampleRate: Int = 44100) {
		self.withUnsafeBytes() { bytes in
			// init encoder
			let encoder = cassette_apple2_alloc_encoder(bytes.baseAddress!, self.count, Int32(sampleRate))
			defer { cassette_apple2_free_encoder(encoder) }
			
			cassette_write_file(url.path(), Int32(sampleRate), { buffer, size in
				// return 0 to stop writing the file when current task
				// is cancelled
				guard !Task.isCancelled else {
					return 0
				}
				// write buffer
				return cassette_apple2_write_monitor_record(buffer, size, encoder)
			})
		}
	}
}
