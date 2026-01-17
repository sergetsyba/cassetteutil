//
//  CoreAudio+Player.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 12.1.2026.
//

import AudioToolbox

extension AudioQueue {
	static func play(format: AudioStreamBasicDescription, _ write: @escaping (AudioQueueBufferRef) -> Bool) async throws {
		try await withCheckedThrowingContinuation() { (continuation: CheckedContinuation<Void, any Error>) in
			let queue = AudioQueue()
			do {
				// set up audio queue output
				try queue.setOutput(format: format) {
					do {
						if write($0) {
							try queue.enqueueBuffer($0)
						} else {
							// stop queue when enocoder finished producing
							// audio samples
							try queue.stop()
						}
					} catch {
						continuation.resume(throwing: error)
					}
				}
				// allocate and prime audio queue buffers
				for _ in 0..<3 {
					let buffer = try queue.allocateBuffer(size: 4096)
					if write(buffer) {
						try queue.enqueueBuffer(buffer)
					}
				}
				// return once all buffers finished playing and no more
				// samples have been produced
				try queue.addPropertyListener(for: .isRunning) { (isRunning: UInt32) in
					if isRunning == 0 {
						continuation.resume(with: .success(()))
					}
				}
				// start playing
				try queue.start()
			} catch {
				continuation.resume(throwing: error)
			}
			
			// TODO: dispose audio queue
		}
	}
}
