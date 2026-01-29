//
//  device.h
//  CassetteUtility
//
//  Created by Serge Tsyba on 26.1.2026.
//

#ifndef device_h
#define device_h

#include <stdint.h>

typedef enum {
	CASSETTE_AUDIO_INPUT_DEVICE = 1<<0,
	CASSETTE_AUDIO_OUTPUT_DEVICE = 1<<1
} cassette_audio_device_scope;

typedef struct {
	int id;
	char *name;
	uint8_t scope;
} cassette_audio_device;

/**
 * Returns all available audio devices.
 *
 * @param devices Pointer to an array of available audio devices.
 * @param count Pointer to number of items in the array of available audio devices.
 * @return 0 when getting audio devices succeeds, error code when fails.
 *
 * @note This function allocates memory for the devices array and names of each device in the array.
 * 		Caller is responsible for deallocating memory once done.
 */
int cassette_get_audio_devices(cassette_audio_device **devices, int *count);

/**
 * Returns default audio device with the specified scope.
 *
 * @param scope Scope of audio device to return.
 * @param device Pointer an audio device object to write result into.
 * @return 0 when getting audio device succeeds, error code when fails.
 *
 * @note This function allocates memory for the device and its name. Caller is responsible for
 * 		deallocating memory once done.
 */
int cassette_get_default_audio_device(cassette_audio_device_scope scope, cassette_audio_device *device);

#endif /* device_h */
