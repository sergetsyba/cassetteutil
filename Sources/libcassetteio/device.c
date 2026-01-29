//
//  device.c
//  CassetteUtility
//
//  Created by Serge Tsyba on 26.1.2026.
//

#include "device.h"

#include <AudioToolbox/AudioToolbox.h>

static OSStatus get_device_ids(AudioDeviceID **ids, int *count) {
	AudioObjectPropertyAddress property = {
		kAudioHardwarePropertyDevices,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMain
	};
	
	UInt32 data_size = 0;
	OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &property, 0, NULL, &data_size);
	if (status != noErr) {
		return status;
	}
	
	*ids = malloc(data_size);
	*count = data_size / sizeof(AudioDeviceID);
	
	status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &property, 0, NULL, &data_size, *ids);
	if (status != noErr) {
		free(*ids);
		return status;
	}
	
	return noErr;
}

static OSStatus get_device_name(AudioDeviceID device_id, char **name) {
	AudioObjectPropertyAddress property = {
		kAudioObjectPropertyName,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMain
	};
	
	CFStringRef string;
	UInt32 data_size = sizeof(string);
	
	OSStatus status = AudioObjectGetPropertyData(device_id, &property, 0, NULL, &data_size, &string);
	if (status != noErr) {
		return status;
	}
	
	// get string length
	CFIndex length = CFStringGetLength(string);
	CFIndex string_size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
	
	// allocate character buffer
	size_t name_size = string_size * sizeof(char) + 1;
	*name = malloc(name_size);
	if (*name == NULL) {
		return -1;
	}
	
	// copy string into chharacter buffer and release it
	Boolean is_ok = CFStringGetCString(string, *name, name_size, kCFStringEncodingUTF8);
	CFRelease(string);
	if (!is_ok) {
		status = -1;
		goto clean_up;
	}
	
	return noErr;
	
clean_up:
	free(*name);
	return status;
}

static OSStatus has_stream_channels(AudioDeviceID device_id, AudioObjectPropertyScope scope, bool *has_channels) {
	AudioObjectPropertyAddress property = {
		kAudioDevicePropertyStreamConfiguration,
		scope,
		kAudioObjectPropertyElementMain
	};
	
	UInt32 data_size = 0;
	OSStatus status = AudioObjectGetPropertyDataSize(device_id, &property, 0, NULL, &data_size);
	if (status != noErr) {
		return status;
	}
	
	AudioBufferList *buffer_list = malloc(data_size);
	if (buffer_list == NULL) {
		return -1;
	}
	
	// get device stream configuration
	status = AudioObjectGetPropertyData(device_id, &property, 0, NULL, &data_size, buffer_list);
	if (status != noErr) {
		goto clean_up;
	}
	
	// check if there are audio channels in configuration
	*has_channels = false;
	for (int index = 0; index < buffer_list->mNumberBuffers; ++index) {
		if (buffer_list->mBuffers[index].mNumberChannels > 0) {
			*has_channels = true;
			status = noErr;
			goto clean_up;
		}
	}
	
clean_up:
	free(buffer_list);
	return status;
}

static OSStatus get_audio_device(AudioDeviceID device_id, cassette_audio_device *device) {
	device->id = device_id;
	device->scope = 0;
	
	// get device_name
	OSStatus status = get_device_name(device_id, &device->name);
	if (status != noErr) {
		goto clean_up;
	}
	
	// check whether audio input device
	bool has_channels = false;
	status = has_stream_channels(device_id, kAudioObjectPropertyScopeInput, &has_channels);
	if (status != noErr) {
		goto clean_up;
	}
	if (has_channels) {
		device->scope |= CASSETTE_AUDIO_INPUT_DEVICE;
	}
	
	// check whether audio input device
	status = has_stream_channels(device_id, kAudioObjectPropertyScopeOutput, &has_channels);
	if (status != noErr) {
		goto clean_up;
	}
	if (has_channels) {
		device->scope |= CASSETTE_AUDIO_OUTPUT_DEVICE;
	}
	
	return noErr;
	
clean_up:
	if (device->name != NULL) {
		free(device->name);
	}
	return status;
}

int cassette_get_audio_devices(cassette_audio_device **devices, int *count) {
	// get device ids
	AudioDeviceID *device_ids;
	OSStatus status = get_device_ids(&device_ids, count);
	if (status != noErr) {
		return status;
	}
	
	*devices = calloc(*count, sizeof(cassette_audio_device));
	for (int index = 0; index < *count; ++index) {
		status = get_audio_device(device_ids[index], &((*devices)[index]));
		if (status != noErr) {
			goto clean_up;
		}
	}
	
	free(device_ids);
	return noErr;
	
clean_up:
	for (int index = 0; index < *count; ++index) {
		cassette_audio_device device = (*devices)[index];
		if (device.name != NULL) {
			free(device.name);
		}
	}
	
	free(*devices);
	free(device_ids);
	return status;
}

int cassette_get_default_audio_device(cassette_audio_device_scope scope, cassette_audio_device *device) {
	// TODO:
}
