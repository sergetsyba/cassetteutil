//
//  cassetteio.c
//  libcassetteio
//
//  Created by Serge Tsyba on 3.1.2026.
//

#include "cassetteio.h"
#include "files.h"

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static const int unit = 1e3;

/**
 * Writes audio samples for a single half-cycle (pulse) of a square wave.
 *
 * Maintains phase continuity by flipping the amplitude after writing and carrying over fractional sample
 * timing (via the remainder) to prevent cumulative frequency drift.
 *
 * @param sample_rate Output audio sample rate in Hz.
 * @param duration Duration of the half-cycle in μs.
 * @param amplitude Sample amplitude. Flipped once function returns to be specified when writing
 * 	samples of the next half-cycle.
 * @param remainder Number of fractional samples omitted for a given sample rate and square wave
 *		frequency. The returned value must be specified when writing samples of the next half-cycle to
 *		prevent frequency drift.
 * @param file File handle to write data to.
 * @return Number of samples written.
 */
static int fwrite_half_cycle(int sample_rate, int duration, int8_t *amplitude, int *remainder, FILE *file) {
	// number of samples measured in precision units in a half cycle
	// of the specified duration
	long sample_count_units = ((long)unit * sample_rate * duration / 1e6) + *remainder;
	// number of whole samples in a half cycle
	long sample_count = sample_count_units / unit;
	// remainder of fractional samples to carry over to the next half cycle
	*remainder = sample_count_units % unit;
	
	// write samples
	for (int sample = 0; sample < sample_count; ++sample) {
		fputc(*amplitude, file);
	}
	// flip amplitude
	*amplitude = -(*amplitude);
	return (int)sample_count;
}

/**
 * Writes the specified 1 byte of data as audio using Apple II Frequency Shift Keying protocol to
 * the specified file.
 *
 * @param data Data to be output as audio.
 * @param sample_rate Output audio sample rate in Hz.
 * @param file File handle to write data to.
 * @return Number of samples written.
 */
static int fwrite_fsk_uint8(uint8_t data, int sample_rate, int8_t *amplitude, int *remainder, FILE *file) {
	int sample_count = 0;
	for (int bit = 0; bit < 8; ++bit) {
		// write most significant bit first
		if (data & 0x80) {
			// write 1 (2 half-cycles of 500 μs)
			sample_count += fwrite_half_cycle(sample_rate, 500, amplitude, remainder, file);
			sample_count += fwrite_half_cycle(sample_rate, 500, amplitude, remainder, file);
		} else {
			// write 0 (2 half-cycles of 250 μs)
			sample_count += fwrite_half_cycle(sample_rate, 250, amplitude, remainder, file);
			sample_count += fwrite_half_cycle(sample_rate, 250, amplitude, remainder, file);
		}
		data <<= 1;
	}
	
	return sample_count;
}

int fwrite_fsk(uint8_t *data, size_t size, int sample_rate, FILE *file) {
	int8_t amplitude = INT8_MAX;
	int remainder = 0;
	
	// write leader tone (8192*2 half-cycles of 650 μs)
	int sample_count = 0;
	for (int index = 0; index < 8192*2; ++index) {
		sample_count += fwrite_half_cycle(sample_rate, 650, &amplitude, &remainder, file);
	}
	
	// write sync bit (2 half-cycles of 200 μs and 250 μs)
	sample_count += fwrite_half_cycle(sample_rate, 200, &amplitude, &remainder, file);
	sample_count += fwrite_half_cycle(sample_rate, 250, &amplitude, &remainder, file);
	
	// write data
	uint8_t checksum = 0xff;
	for (int index = 0; index < size; ++index) {
		sample_count += fwrite_fsk_uint8(data[index], sample_rate, &amplitude, &remainder, file);
		checksum ^= data[index];
	}
	
	// write checksum
	sample_count += fwrite_fsk_uint8(checksum, sample_rate, &amplitude, &remainder, file);
	return sample_count;
}

cassette_apple2_encoder *cassette_apple2_malloc_encoder(const uint8_t *data, size_t data_size, int sample_rate) {
	cassette_apple2_encoder *encoder = (cassette_apple2_encoder *)malloc(sizeof(cassette_apple2_encoder));
	encoder->data = (uint8_t *)data;
	encoder->data_size = data_size;
	
	encoder->sample_rate = sample_rate;
	encoder->checksum = 0x00;
	encoder->cycle_index = 0;
	
	return encoder;
}

#define MICROSECONDS ((uint64_t)1e6)

/// Returns the number of samples in a signal of the specified sample rate (in Hz) and duration (in μs).
static uint64_t sample_count(int sample_rate, int duration, int *remainder) {
	// number of samples in a signal interval, measured in μs;
	// uint64_t guards against integer overflow
	const uint64_t sample_count_units = (sample_rate * duration) + *remainder;
	// number of fractional samples to carry over to the next interval
	*remainder = (int)(sample_count_units % MICROSECONDS);
	// number of samples in a signal interval, measured in s
	return sample_count_units / MICROSECONDS;
}

/// Returns the number bytes written.
static size_t write_cycle(const int durations[2], int8_t *buffer, size_t buffer_size, cassette_apple2_encoder *state) {
	int remainder = state->remainder;
	size_t samples_sizes[2] = {
		sample_count(state->sample_rate, durations[0], &remainder),
		sample_count(state->sample_rate, durations[1], &remainder)
	};
	
	// ensure all samples fit into audio buffer
	const size_t samples_size = samples_sizes[0] + samples_sizes[1];
	if (samples_size > buffer_size) {
		return 0;
	}
	
	// write 2 half-cyclessamples and advance audio buffer pointer
	memset(buffer, INT8_MAX, samples_sizes[0]);
	memset(buffer + samples_sizes[0], INT8_MIN, samples_sizes[1]);
	
	// update encoder sstate
	state->remainder = remainder;
	state->cycle_index += 1;
	return samples_size;
}

static size_t encode_data_uint8(uint8_t data, int bit, int8_t *buffer, size_t buffer_size, cassette_apple2_encoder *state) {
	size_t encoded_size = 0;
	uint8_t mask = (1<<bit);
	
	for (; mask > 0x00; mask >>= 1) {
		const int duration = (data & mask) ? 500 : 250;
		const size_t size = write_cycle((int[]){duration, duration}, buffer, buffer_size, state);
		if (size == 0) {
			break;
		}
		
		encoded_size += size;
		buffer += size;
		buffer_size -= size;
	};
	return encoded_size;
}

#define HEADER_CYCLE_COUNT (8192)
#define HEADER_CYCLE_DURATIONS (int[]){650, 650}
#define SYNC_CYCLE_DURATIONS (int[]){200, 250}

static inline int data_bit_index(cassette_apple2_encoder *state) {
	// number of cycles without header and sync bit
	const int data_cycle_index = state->cycle_index - (HEADER_CYCLE_COUNT+1);
	return data_cycle_index < 0 ? -1 : 7 - (data_cycle_index % 8);
}

size_t cassette_apple2_write_monitor_record(int8_t *buffer, size_t buffer_size, cassette_apple2_encoder *state) {
	size_t encoded_size = 0;
	// header tone
	while (state->cycle_index < HEADER_CYCLE_COUNT) {
		const size_t size = write_cycle(HEADER_CYCLE_DURATIONS, buffer, buffer_size, state);
		if (size == 0) {
			return encoded_size;
		}
		
		encoded_size += size;
		buffer += size;
		buffer_size -= size;
	}
	
	// sync bit
	if (state->cycle_index == HEADER_CYCLE_COUNT) {
		const size_t size = write_cycle(SYNC_CYCLE_DURATIONS, buffer, buffer_size, state);
		if (size == 0) {
			return encoded_size;
		}
		
		encoded_size += size;
		buffer += size;
		buffer_size -= size;
	}
	
	// data
	while (state->data_size > 0) {
		int bit = data_bit_index(state);
		const size_t size = encode_data_uint8(*(state->data), bit, buffer, buffer_size, state);
		if (size == 0) {
			return encoded_size;
		}
		
		encoded_size += size;
		buffer += size;
		buffer_size -= size;
		
		// advance data pointers when all bits of the current byte in data
		// were encoded; in case no bits were encoded and cycle index was at
		// bit 7 initially, encoded size would be 0 and function would return
		// earlier
		bit = data_bit_index(state);
		if (bit == 7) {
			state->checksum ^= *(state->data);
			state->data += 1;
			state->data_size -= 1;
		}
	}
	
	// checksum
	if (state->cycle_index < state->cycle_count) {
		// works even for checksum byte since data bytes are encoded by
		// 8 cycles each
		const int bit = data_bit_index(state);
		const size_t size = encode_data_uint8(state->checksum, bit, buffer, buffer_size, state);
		if (size == 0) {
			return encoded_size;
		}
		
		encoded_size += size;
		buffer += size;
		buffer_size -= size;
	}
	
	// final pulse
	// ensures hardware detects the last bit of checksum
	if (state->cycle_index == state->cycle_count) {
		const size_t size = write_cycle((int[]){250, 250}, buffer, buffer_size, state);
		if (size == 0) {
			return encoded_size;
		}
		
		encoded_size += size;
		buffer += size;
		buffer_size -= size;
	}
	
	// encoding complete
	return encoded_size;
}
