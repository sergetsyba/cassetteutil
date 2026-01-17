//
//  AudioPlayer.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 12.1.2026.
//

import Foundation
import AudioToolbox
import libcassetteio

protocol AudioSource {
	func fill(_ buffer: AudioQueueBufferRef) -> Bool
}

class AudioPlayer {
	private var queue: AudioQueue!
	private var buffers: [AudioQueueBufferRef]!
	private var continuation: CheckedContinuation<Void, any Error>?
	
	var audioSource: AudioSource?
	
	init(sampleRate: Int? = nil) throws {
		let format: AudioStreamBasicDescription = .mono(sampleRate: sampleRate ?? 44100)
		let queue = AudioQueue()
		
		// set up output
		try queue.setOutput(format: format) { [unowned self] queue, buffer in
			do {
				if self.audioSource?.fill(buffer) ?? false {
					try queue.enqueueBuffer(buffer)
				} else {
					// stop queue when enocoder finished producing
					// audio samples
					try queue.stop()
				}
			} catch {
				self.continuation?
					.resume(throwing: error)
			}
		}
		// allocate buffers
		let buffers = try (0..<3).map() { _ in
			try queue.allocateBuffer(size: 4096)
		}
		// return when queue stops playing
		try queue.addPropertyListener(for: .isPlaying) { [unowned self] in
			do {
				if try !queue.isPlaying {
					// TODO: dispose queue
					self.continuation?
						.resume(with: .success(()))
				}
			} catch {
				self.continuation?
					.resume(throwing: error)
			}
		}
		
		self.queue = queue
		self.buffers = buffers
	}
	
	func play() async throws {
		// prime buffers
		for buffer in self.buffers {
			if self.audioSource?.fill(buffer) ?? false {
				try self.queue.enqueueBuffer(buffer)
			}
		}
		// start playing
		try await withCheckedThrowingContinuation() { [unowned self] continuation in
			self.continuation = continuation
			do {
				try self.queue.start()
			} catch {
				self.continuation?
					.resume(throwing: error)
			}
		}
	}
	
	func stop() {
		do {
			try self.queue.stop(immediate: true)
			self.continuation?
				.resume(with: .success(()))
		} catch {
			self.continuation?
				.resume(throwing: error)
		}
	}
}
