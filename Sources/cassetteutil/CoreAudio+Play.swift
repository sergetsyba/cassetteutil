//
//  CoreAudio+Play.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 12.1.2026.
//

import AudioToolbox

extension AudioQueue {
	static func play(format: AudioStreamBasicDescription, _ write: @escaping (UnsafeMutablePointer<Int8>, Int) -> Int) async throws {
		try await withCheckedThrowingContinuation() { (continuation: CheckedContinuation<Void, any Error>) in
			let queue = AudioQueue()
			do {
				// set up audio queue output
				try queue.setOutput(format: format) {
					do {
						let writeSize = write(
							$0.pointee.mAudioData.assumingMemoryBound(to: Int8.self),
							Int($0.pointee.mAudioDataBytesCapacity))
						
						if writeSize > 0 {
							$0.pointee.mAudioDataByteSize = UInt32(writeSize)
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
					let writeSize = write(
						buffer.pointee.mAudioData.assumingMemoryBound(to: Int8.self),
						Int(buffer.pointee.mAudioDataBytesCapacity))
					
					if writeSize > 0 {
						buffer.pointee.mAudioDataByteSize = UInt32(writeSize)
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
