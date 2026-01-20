//
//  cassetteio.h
//  libcassetteio
//
//  Created by Serge Tsyba on 1.1.2026.
//

#ifndef cassetteio_h
#define cassetteio_h

#include <stdint.h>
#include <stdio.h>

/**
 * Writes the specified data as a standard Apple II cassette audio record using Frequency Shift Keying
 * protocol to the specified file.
 *
 * @param data Data to be output as audio record.
 * @param size Number of bytes in the data.
 * @param sample_rate Output audio sample rate in Hz.
 * @param file File handle to write data to. File must be fseek-able (wb+).
 * @return Number of samples written.
 */
int fwrite_fsk(uint8_t *data, size_t size, int sample_rate, FILE *file);

/**
 * Writes the specified data as a standard Apple II cassette audio record using Frequency Shift Keying
 * protocol to the specified buffer.
 *
 * @param src Data to be encoded as audio record.
 * @param src_size Number of bytes in the data.
 * @param dst Pointer to an allocated array of audio samples encoded from data.
 * @param sample_rate Output audio sample rate in Hz.
 * @return Number of samples written.
 */
int write_fsk(uint8_t *data, size_t data_size, int8_t *buffer, size_t buffer_size, int sample_rate);

typedef struct {
	long data_size;
	uint8_t *data;
	uint8_t checksum;
	
	/// Output sample rate.
	int sample_rate;
	/// Number of samples to be carried over to the next half-cycle due to fractional mismatch
	/// between sampling rate and wave frequency.
	int remainder;
	
	int cycle_index;
	int cycle_count;
} cassette_apple2_encoder;

cassette_apple2_encoder *cassette_apple2_malloc_encoder(const uint8_t *data, size_t data_size, int sample_rate);

/**
 * Writes the specified data as a standard Apple II monitor cassette audio record to the specified
 * audio sample buffer.
 */
size_t cassette_apple2_write_monitor_record(int8_t *buffer, size_t buffer_size, cassette_apple2_encoder *encoder);
size_t cassette_apple2_fwrite_monitor_record(FILE *file, cassette_apple2_encoder *encoder);

#endif /* cassetteio_h */
