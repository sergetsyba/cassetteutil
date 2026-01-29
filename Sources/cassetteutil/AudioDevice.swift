//
//  File.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 27.1.2026.
//

import Foundation
import libcassetteio

struct AudioDevice {
	var id: Int
	var name: String
	var scope: Scope
}

extension AudioDevice {
	struct Scope: OptionSet {
		static let input = Scope(rawValue: Int(CASSETTE_AUDIO_INPUT_DEVICE.rawValue))
		static let output = Scope(rawValue: Int(CASSETTE_AUDIO_OUTPUT_DEVICE.rawValue))
		var rawValue: Int
	}
}

// MARK: -
// MARK: Device enumeration
extension AudioDevice {
	/// All available audio devices.
	static var all: [Self] {
		var pointer: UnsafeMutablePointer<cassette_audio_device>!
		var count: Int32 = 0
		let _ = cassette_get_audio_devices(&pointer, &count)
		// TODO: handle error
		
		let buffer = UnsafeBufferPointer(start: pointer, count: Int(count))
		defer {
			buffer.forEach({ $0.name.deallocate() })
			pointer.deallocate()
		}
		
		return buffer.map({ AudioDevice($0) })
	}
	
	/// Default audio output device.
	static var output: Self {
		var device = cassette_audio_device()
		let _ = cassette_get_default_audio_device(CASSETTE_AUDIO_OUTPUT_DEVICE, &device)
		// TODO: handle error
		defer {
			device.name.deallocate()
		}
		
		return AudioDevice(device)
	}
	
	private init(_ device: cassette_audio_device) {
		self.id = Int(device.id)
		self.name = String(cString: device.name)
		self.scope = Scope(rawValue: Int(device.scope))
	}
}


// MARK: -
// MARK: Playback
extension AudioDevice {
	func playEncoded(data: Data, sameplRate: Int = 44100) async {
		// TODO: use device sample rate when nil
		var id = Int32(self.id)
		var sampleRate = Int32(sameplRate)
		
		await withCheckedContinuation() { (continuation: CheckedContinuation<Void, Never>) in
			data.withUnsafeBytes() {
				// init encoder
				let encoder = cassette_apple2_alloc_encoder($0.baseAddress!, data.count, sampleRate)
				cassette_play(&id, &sampleRate, {
					// return 0 to stop playback when current task is cancelled
					guard Task.isCancelled == false else {
						return 0
					}
					// write buffer
					return cassette_apple2_write_monitor_record($0, $1, encoder)
				}, { _ in
					// clean up and resume continuation when playback stops
					cassette_apple2_free_encoder(encoder)
					continuation.resume()
				})
			}
		}
	}
}
