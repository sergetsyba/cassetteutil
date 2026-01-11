//
//  CoreAudio+AudioObject.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 11.1.2026.
//

import CoreAudio

struct AudioObject {
	var id: AudioObjectID
}


// MARK: -
// MARK: CoreAudio abstraction
extension AudioObject {
	func object<T: AnyObject>(for selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = .global, element: AudioObjectPropertyElement = .main) throws -> T {
		var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
		var size = UInt32(MemoryLayout<Unmanaged<T>?>.size)
		var value: Unmanaged<T>?
		
		let status = AudioObjectGetPropertyData(self.id, &address, 0, nil, &size, &value)
		guard let value = value,
			  status == noErr else {
			throw status
		}
		
		return value.takeRetainedValue()
	}
	
	func values<T>(for selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = .global, element: AudioObjectPropertyElement = .main) throws -> [T] {
		var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
		var size: UInt32 = 0
		
		var status = AudioObjectGetPropertyDataSize(self.id, &address, 0, nil, &size)
		guard status == noErr else {
			throw status
		}
		
		let valueCount = Int(size) / MemoryLayout<T>.size
		let values = try withUnsafeTemporaryAllocation(of: T.self, capacity: valueCount) {
			let ptr = UnsafeMutableRawPointer($0.baseAddress!)
			status = AudioObjectGetPropertyData(self.id, &address, 0, nil, &size, ptr)
			guard status == noErr else {
				throw status
			}
			
			return Array($0)
		}
		
		return values
	}
}

extension OSStatus: @retroactive Error {
}


// MARK: -
extension AudioObjectID {
	static let system = AudioObjectID(kAudioObjectSystemObject)
}
extension AudioObjectPropertySelector {
	static let devices = kAudioHardwarePropertyDevices
	static let name = kAudioDevicePropertyDeviceNameCFString
	static let streams = kAudioDevicePropertyStreams
}
extension AudioObjectPropertyScope {
	static let global = kAudioObjectPropertyScopeGlobal
	static let input = kAudioObjectPropertyScopeInput
	static let output = kAudioObjectPropertyScopeOutput
}
extension AudioObjectPropertyElement {
	static let main = kAudioObjectPropertyElementMain
}
