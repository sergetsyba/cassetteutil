//
//  audio.c
//  CassetteUtility
//
//  Created by Serge Tsyba on 22.1.2026.
//

#include "audio.h"

#include <stdatomic.h>
#include <stdbool.h>

#include <CoreAudioTypes/CoreAudioBaseTypes.h>
#include <AudioToolbox/AudioToolbox.h>

#define SAMPLE_TYPE float
#define BUFFER_SIZE 4096 * sizeof(SAMPLE_TYPE)
#define PLAY_BUFFER_COUNT 3


// MARK: -
// MARK: Formats
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


// MARK: -
// MARK: Playback
typedef struct play_context {
	atomic_bool is_disposed;
	size_t (^write_buffer)(float *, size_t);
	void (^completion_handler)(int);
} play_context;

static OSStatus clean_up_play(play_context *data, AudioQueueRef queue, OSStatus status);

static void output_callback(void * _Nonnull data, AudioQueueRef queue, AudioQueueBufferRef buffer) {
	// write audio samples
	play_context *context = (play_context *)data;
	buffer->mAudioDataByteSize = (int)context->write_buffer((float *)buffer->mAudioData, buffer->mAudioDataBytesCapacity);
	
	// keep playing only while there are audio samples
	if (buffer->mAudioDataByteSize > 0) {
		AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
	}
}

static void is_running_listener_callback(void * _Nonnull data, AudioQueueRef queue, AudioQueuePropertyID property_id) {
	UInt32 is_running;
	UInt32 size = sizeof(UInt32);
	AudioQueueGetProperty(queue, property_id, &is_running, &size);
	
	// clean up when playback stops
	if (is_running == 0) {
		AudioQueueRemovePropertyListener(queue, property_id, is_running_listener_callback, data);
		clean_up_play((play_context *)data, queue, noErr);
	}
}

int cassette_play(const int * _Nullable device_id, const int * _Nullable sample_rate, size_t (^ _Nonnull write_buffer)(float * _Nonnull, size_t), void (^ _Nonnull completion_handler)(int)) {
	// TODO:
	AudioStreamBasicDescription audio_format = default_audio_format;
	audio_format.mSampleRate = (Float64)*sample_rate;
	
	// copy block closures onto heap be able to pass it to audio queue
	// callbacks
	play_context *data = (play_context *)malloc(sizeof(play_context));
	data->is_disposed = false;
	data->write_buffer = Block_copy(write_buffer);
	data->completion_handler = Block_copy(completion_handler);
	
	// set up audio queue
	AudioQueueRef queue;
	OSStatus status = AudioQueueNewOutput(&audio_format, output_callback, data, NULL, NULL, 0, &queue);
	if (status != noErr) {
		return clean_up_play(data, queue, status);
	}
	
	// set up audio queue buffers
	for (int index = 0; index < 3; ++index) {
		AudioQueueBufferRef buffer;
		status = AudioQueueAllocateBuffer(queue, 4096 * sizeof(float), &buffer);
		if (status != noErr) {
			return clean_up_play(data, queue, status);
		}
		
		// prime buffer
		output_callback(data, queue, buffer);
	}
	
	// add playback completion listener
	status = AudioQueueAddPropertyListener(queue, kAudioQueueProperty_IsRunning, is_running_listener_callback, data);
	if (status != noErr) {
		return clean_up_play(data, queue, status);
	}
	
	// start playback
	status = AudioQueueStart(queue, NULL);
	if (status != noErr) {
		return clean_up_play(data, queue, status);
	}
	
	return noErr;
}

static OSStatus clean_up_play(play_context * _Nonnull data, AudioQueueRef queue, OSStatus status) {
	// ensure clean up called only once
	bool expected = false;
	if (!atomic_compare_exchange_strong(&data->is_disposed, &expected, true)) {
		return status;
	}
	
	// stop and free audio queue
	AudioQueueStop(queue, true);
	AudioQueueDispose(queue, true);
	
	// notify playback stopped
	data->completion_handler(status);
	
	// free block closure copies and play context
	Block_release(data->write_buffer);
	Block_release(data->completion_handler);
	free(data);
	
	return status;
}


// MARK: -
// MARK: Files
static OSStatus ExtAudioFileCreateWithPath(const char *path, AudioFileTypeID inFileType, const AudioStreamBasicDescription * inStreamDesc, const AudioChannelLayout * __nullable inChannelLayout, UInt32 inFlags, ExtAudioFileRef __nullable * __nonnull outExtAudioFile) {
	const CFStringRef pathString = CFStringCreateWithCString(kCFAllocatorDefault, path, kCFStringEncodingUTF8);
	const CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, pathString, kCFURLPOSIXPathStyle, false);
	
	OSStatus status = ExtAudioFileCreateWithURL(url, inFileType, inStreamDesc, inChannelLayout, inFlags, outExtAudioFile);
	CFRelease(url);
	CFRelease(pathString);
	
	return status;
}

int cassette_write_file(const char * _Nonnull path, int sample_rate, size_t (^ _Nonnull write_buffer)(float * _Nonnull , size_t)) {
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
	float *buffer = (float *)malloc(BUFFER_SIZE);
	
	// allocate buffer list
	AudioBufferList buffer_list;
	buffer_list.mNumberBuffers = 1;
	buffer_list.mBuffers[0].mNumberChannels = 1;
	buffer_list.mBuffers[0].mData = buffer;
	
	UInt32 write_size = 0;
	do {
		// fill buffer
		write_size = (UInt32)write_buffer(buffer, BUFFER_SIZE);
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
