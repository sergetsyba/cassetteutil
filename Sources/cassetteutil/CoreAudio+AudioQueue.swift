//
//  CoreAudio+AudioQueue.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 15.1.2026.
//

import AudioToolbox

class AudioQueue {
	private var ref: AudioQueueRef!
	private var bufferCallback: ((AudioQueueBufferRef) -> Void)?
	private var propertyCallbacks: [AudioQueuePropertyID: [() -> Void]] = [:]
	
	func setOutput(format: AudioStreamBasicDescription, _ bufferCallback: @escaping (AudioQueueBufferRef) -> Void) throws {
		// TODO: clean-up queue ref if present
		var format = format
		let data = Unmanaged.passUnretained(self)
			.toOpaque()
		
		let callback: AudioQueueOutputCallback = { (data, _, buffer) in
			Unmanaged<AudioQueue>.fromOpaque(data!)
				.takeUnretainedValue()
				.bufferCallback?(buffer)
		}
		
		let error = AudioQueueNewOutput(&format, callback, data, nil, nil, 0, &self.ref)
		guard error == noErr else {
			throw error
		}
		
		self.bufferCallback = bufferCallback
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
		let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
		var size = UInt32(MemoryLayout<T>.size)
		defer {
			pointer.deallocate()
		}
		
		let status = AudioQueueGetProperty(self.ref, property, pointer, &size)
		guard status == noErr else {
			throw status
		}
		
		return pointer.pointee
	}
	
	func addPropertyListener<T>(for property: AudioQueuePropertyID, changeCallback: @escaping (T) -> Void) throws {
		let data = Unmanaged<AudioQueue>.passUnretained(self)
			.toOpaque()
		
		let callback: AudioQueuePropertyListenerProc = { data, _, property in
			Unmanaged<AudioQueue>.fromOpaque(data!)
				.takeUnretainedValue()
				.propertyCallbacks[property]?
				.forEach({ $0() })
		}
		
		var callbacks = self.propertyCallbacks[property] ?? []
		callbacks.append({
			do {
				let value: T = try self.value(for: property)
				changeCallback(value)
			} catch {
				// does nothing
			}
		})
		self.propertyCallbacks[property] = callbacks
		
		let status = AudioQueueAddPropertyListener(self.ref, property, callback, data)
		guard status == noErr else {
			throw status
		}
	}
}

extension AudioQueue {
	var isRunning: Bool {
		get throws {
			let isRunning: UInt32 = try self.value(for: .isRunning)
			return isRunning != 0
		}
	}
}

extension AudioQueuePropertyID {
	static let isRunning: Self = kAudioQueueProperty_IsRunning
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
