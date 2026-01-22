//
//  audio.c
//  CassetteUtility
//
//  Created by Serge Tsyba on 22.1.2026.
//

#include "audio.h"

#include <CoreAudioTypes/CoreAudioBaseTypes.h>
#include <AudioToolbox/AudioToolbox.h>

static const AudioStreamBasicDescription default_audio_format = {
	.mSampleRate = 44100.0,
	.mFormatID = kAudioFormatLinearPCM,
	.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved,
	.mBytesPerPacket = 4,
	.mFramesPerPacket = 1,
	.mBytesPerFrame = 4,
	.mChannelsPerFrame = 1,
	.mBitsPerChannel = 32,
};

static const AudioStreamBasicDescription default_file_format = {
	.mSampleRate = 44100.0,
	.mFormatID = kAudioFormatLinearPCM,
	.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked,
	.mBytesPerPacket = 1,
	.mFramesPerPacket = 1,
	.mBytesPerFrame = 1,
	.mChannelsPerFrame = 1,
	.mBitsPerChannel = 8
};

static OSStatus ExtAudioFileCreateWithPath(const char *path, AudioFileTypeID inFileType, const AudioStreamBasicDescription * inStreamDesc, const AudioChannelLayout * __nullable inChannelLayout, UInt32 inFlags, ExtAudioFileRef __nullable * __nonnull outExtAudioFile) {
	const CFStringRef pathString = CFStringCreateWithCString(kCFAllocatorDefault, path, kCFStringEncodingUTF8);
	const CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, pathString, kCFURLPOSIXPathStyle, false);
	
	OSStatus status = ExtAudioFileCreateWithURL(url, inFileType, inStreamDesc, inChannelLayout, inFlags, outExtAudioFile);
	CFRelease(url);
	CFRelease(pathString);
	
	return status;
}

int cassette_write_file(const char *path, int sample_rate, size_t (^write_buffer)(float *, size_t)) {
	AudioStreamBasicDescription audio_format = default_audio_format;
	audio_format.mSampleRate = (Float64)sample_rate;
	AudioStreamBasicDescription file_format = default_file_format;
	file_format.mSampleRate = (Float64)sample_rate;
	
	// create file
	ExtAudioFileRef file;
	OSStatus status = ExtAudioFileCreateWithPath(path, kAudioFileAIFFType, &file_format, NULL, kAudioFileFlags_EraseFile, &file);
	if (status != noErr) {
		return status;
	}
	
	// set audio sample format
	status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(audio_format), &audio_format);
	if (status != noErr) {
		ExtAudioFileDispose(file);
		return status;
	}
	
	// allocate sample buffer
	const size_t buffer_size = 4096 * sizeof(float);
	float *buffer = (float *)malloc(buffer_size);
	
	// allocate buffer list
	AudioBufferList buffer_list;
	buffer_list.mNumberBuffers = 1;
	buffer_list.mBuffers[0].mNumberChannels = 1;
	buffer_list.mBuffers[0].mData = buffer;
	
	UInt32 write_size = 0;
	do {
		// fill buffer
		write_size = (UInt32)write_buffer(buffer, buffer_size);
		buffer_list.mBuffers[0].mDataByteSize = write_size;
		
		// write file
		const int frame_count = write_size / sizeof(float);
		status = ExtAudioFileWrite(file, frame_count, &buffer_list);
		if (status != noErr) {
			break;
		}
	} while (buffer_list.mBuffers[0].mDataByteSize > 0);
	
	// clean up
	free(buffer);
	return ExtAudioFileDispose(file);
}
