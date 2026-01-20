//
//  CoreAudio+WriteFile.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 19.1.2026.
//

import AudioToolbox

class AudioFile {
	private var ref: ExtAudioFileRef!
}

extension AudioFile {
	static func writeFile(at url: URL, format: AudioStreamBasicDescription, _ write: @escaping (UnsafeMutablePointer<Int8>, Int) -> Int) async throws {
		var format = format
		let file = AudioFile()
		
		// create audio file
		var status = ExtAudioFileCreateWithURL(url as CFURL, .aiff, &format, nil, 0, &file.ref)
		guard status == noErr else {
			throw status
		}
		defer {
			// TODO: check returned status
			ExtAudioFileDispose(file.ref)
		}
		
		// set client data format to match audio file format
		let size = MemoryLayout<AudioStreamBasicDescription>.size
		status = ExtAudioFileSetProperty(file.ref, .clientDataFormat, UInt32(size), &format)
		guard status == noErr else {
			throw status
		}
		
		// allocate output buffer
		let bufferSize = 4096
		let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
		defer {
			buffer.deallocate()
		}
		
		// set up buffer list
		// NOTE: for number of channels > 1, this needs heap allocation
		var buffers = AudioBufferList()
		buffers.mNumberBuffers = 1
		buffers.mBuffers.mNumberChannels = format.mChannelsPerFrame
		buffers.mBuffers.mData = UnsafeMutableRawPointer(buffer)
		buffers.mBuffers.mDataByteSize = UInt32(bufferSize)
		
		var writeSize: Int = .max
		while writeSize > 0 {
			// yield execution
			try Task.checkCancellation()
			await Task.yield()
			
			// generate next set of audio samples
			writeSize = write(buffer, bufferSize)
			buffers.mBuffers.mDataByteSize = UInt32(writeSize)
			
			// even though write is asynchronous, CoreAudio copies buffer
			// data out before function returns
			let frameCount = UInt32(writeSize) / format.mBytesPerFrame
			status = ExtAudioFileWrite(file.ref, frameCount, &buffers)
			guard status == noErr else {
				throw status
			}
		}
	}
}

extension AudioFormatFlags {
	static let isSignedInteger: Self =  kLinearPCMFormatFlagIsSignedInteger
	static let isPacked: Self =  kLinearPCMFormatFlagIsPacked
	static let isBigEndian: Self =  kLinearPCMFormatFlagIsBigEndian
}

extension AudioFileTypeID {
	static let aiff: Self = kAudioFileAIFFType
}

extension ExtAudioFilePropertyID {
	static let clientDataFormat: Self = kExtAudioFileProperty_ClientDataFormat
}
