//
//  File.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 27.1.2026.
//

import Foundation
import libcassetteio

extension FileHandle {
	func writeEncoded(_ data: Data, sampleRate: Int = 4410) {
		data.withUnsafeBytes() { bytes in
			// init encoder
			let encoder = cassette_apple2_alloc_encoder(bytes.baseAddress!, data.count, Int32(sampleRate))
			defer { cassette_apple2_free_encoder(encoder) }
			
			cassette_write_file(self.path, Int32(sampleRate), { buffer, size in
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
	
	private var path: String? {
		var path = Array<CChar>(repeating: 0, count: Int(MAXPATHLEN))
		guard fcntl(self.fileDescriptor, F_GETPATH, &path) == 0 else {
			return nil
		}
		
		return path.withUnsafeBufferPointer() {
			return String(cString: $0.baseAddress!)
		}
	}
}
