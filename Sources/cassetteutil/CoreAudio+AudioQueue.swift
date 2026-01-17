//
//  CoreAudio+AudioQueue.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 15.1.2026.
//

import AudioToolbox

class AudioQueue {
	private var ref: AudioQueueRef!
	private var outputCallback: ((AudioQueue, AudioQueueBufferRef) -> Void)?
	private var propertyCallbacks: [AudioQueuePropertyID: [(Any) -> Void]] = [:]
	
	func setOutput(format: AudioStreamBasicDescription, _ callback: (AudioQueue, AudioQueueBufferRef) throws -> Void) throws {
		// TODO: clean-up queue ref if present
		
		var queue: AudioQueueRef?
		var format = format
		let data = Unmanaged.passUnretained(self)
			.toOpaque()
		
		let callback: AudioQueueOutputCallback = { (data, _, buffer) in
			let queue = Unmanaged<AudioQueue>.fromOpaque(data!)
				.takeUnretainedValue()
			queue.outputCallback?(queue, buffer)
		}
		
		let error = AudioQueueNewOutput(&format, callback, data, nil, nil, 0, &queue)
		guard error == noErr else {
			throw error
		}
	}
	
	func start() throws {
		let error = AudioQueueStart(self.ref, nil)
		guard error == noErr else {
			throw error
		}
	}
	
	func stop(immediate: Bool = false) throws {
		let error = AudioQueueStop(self.ref, immediate)
		guard error == noErr else {
			throw error
		}
	}
}


// MARK: -
// MARK: Buffers
extension AudioQueue {
	func allocateBuffer(size: Int) throws -> AudioQueueBufferRef {
		var buffer: AudioQueueBufferRef?
		let error = AudioQueueAllocateBuffer(self.ref, UInt32(size), &buffer)
		guard error == noErr,
			  let buffer else {
			throw error
		}
		
		return buffer
	}
	
	func enqueueBuffer(_ buffer: AudioQueueBufferRef) throws {
		let error = AudioQueueEnqueueBuffer(self.ref, buffer, 0, nil)
		guard error == noErr else {
			throw error
		}
	}
}


// MARK: -
// MARK: Properties
extension AudioQueue {
	func value<T>(for property: AudioQueuePropertyID) throws -> T {
		return try withUnsafeTemporaryAllocation(of: T.self, capacity: 1) {
			var pointer = $0.baseAddress!
			var size = UInt32(MemoryLayout<T>.size)
			
			let status = AudioQueueGetProperty(self.ref, property, pointer, &size)
			guard status == noErr else {
				throw status
			}
			
			return pointer.pointee
		}
	}
	
	func addPropertyListener<T>(for property: AudioQueuePropertyID, callback: (T) throws -> Void) throws {
		var data = Unmanaged<AudioQueue>.passUnretained(self)
			.toOpaque()
		
		let callback: AudioQueuePropertyListenerProc = { data, _, _ in
			let queue = Unmanaged<AudioQueue>.fromOpaque(data!)
				.takeUnretainedValue()
			
			if let value: T = try? queue.value(for: property),
			   let callbacks = queue.propertyCallbacks[property] {
				for callback in callbacks {
					callback(value)
				}
			}
		}
		
		let status = AudioQueueAddPropertyListener(self.ref, property, callback, &data)
		guard status == noErr else {
			throw status
		}
	}
}

extension AudioQueue {
	var isPlaying: Bool {
		get throws {
			try self.value(for: .isPlaying) != 0
		}
	}
}

extension AudioQueuePropertyID {
	static let isPlaying: Self = kAudioQueueProperty_IsRunning
}


// MARK: -
// MARK: Formats
extension AudioStreamBasicDescription {
	static func mono(sampleRate: Int) -> Self {
		AudioStreamBasicDescription(
			mSampleRate: Float64(sampleRate),
			mFormatID: kAudioFormatLinearPCM,
			mFormatFlags: kAudioFormatFlagIsSignedInteger,
			mBytesPerPacket: 1,
			mFramesPerPacket: 1,
			mBytesPerFrame: 1,
			mChannelsPerFrame: 1,
			mBitsPerChannel: 8,
			mReserved: 0)
	}
}
