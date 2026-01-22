//
//  apple2.c
//  libcassetteio
//
//  Created by Serge Tsyba on 3.1.2026.
//

#include "apple2.h"

#include <stdlib.h>
#include <string.h>

struct cassette_apple2_encoder {
	size_t data_size;
	uint8_t *data;
	uint8_t checksum;
	
	/// Total number of FSK cycles in the output audio.
	long cycle_count;
	long cycle_index;
	
	/// Number of samples to be carried over to the next half-cycle due to fractional mismatch
	/// between sampling rate and wave frequency.
	int remainder;
	int sample_rate;
};

#define MICROSECONDS ((uint64_t)1e6)
#define HEADER_CYCLE_COUNT (8192)

cassette_apple2_encoder *cassette_apple2_alloc_encoder(const uint8_t *data, size_t data_size, int sample_rate) {
	cassette_apple2_encoder *encoder = (cassette_apple2_encoder *)malloc(sizeof(cassette_apple2_encoder));
	encoder->data = (uint8_t *)data;
	encoder->data_size = data_size;
	encoder->checksum = 0x00;
	
	// 8192 cycles of lead tone
	// 1 cycle of sync bit
	// 1 cycle for each bit of data
	encoder->cycle_count = HEADER_CYCLE_COUNT + 1 + (data_size * 8);
	encoder->cycle_index = 0;
	encoder->sample_rate = sample_rate;
	
	return encoder;
}

static uint64_t sample_count(int sample_rate, int duration, int *remainder) {
	// number of samples in a signal interval, measured in μs;
	// uint64_t guards against integer overflow
	const uint64_t sample_count_units = (sample_rate * duration) + *remainder;
	// number of fractional samples to carry over to the next interval
	*remainder = (int)(sample_count_units % MICROSECONDS);
	// number of samples in a signal interval, measured in s
	return sample_count_units / MICROSECONDS;
}

#define AMPLITUDE_MAX 1.0f
#define AMPLITUDE_MIN -1.0f

static size_t write_cycle(const int durations[2], float **buffer, size_t *buffer_size, cassette_apple2_encoder *state) {
	int remainder = state->remainder;
	size_t sample_counts[2] = {
		sample_count(state->sample_rate, durations[0], &remainder),
		sample_count(state->sample_rate, durations[1], &remainder)
	};
	
	// ensure all samples fit into audio buffer
	const size_t sample_count = sample_counts[0] + sample_counts[1];
	const size_t samples_size = sample_count * sizeof(float);
	if (samples_size > *buffer_size) {
		return 0;
	}
	
	// write ssamples of 2 half-cycles
	for (int index = 0; index < sample_counts[0]; ++index, ++(*buffer)) {
		**buffer = AMPLITUDE_MAX;
	}
	for (int index = 0; index < sample_counts[1]; ++index, ++(*buffer)) {
		**buffer = AMPLITUDE_MIN;
	}
	
	// update encoder state
	state->remainder = remainder;
	state->cycle_index += 1;
	
	*buffer_size -= samples_size;
	return sample_count;
}

#define HEADER_CYCLE_DURATIONS (int[]){650, 650}
#define SYNC_CYCLE_DURATIONS (int[]){200, 250}
#define BIT_0_CYCLE_DURATIONS (int[]){250, 250}
#define BIT_1_CYCLE_DURATIONS (int[]){500, 500}

static size_t encode_data_uint8(uint8_t data, int bit, float **buffer, size_t *buffer_size, cassette_apple2_encoder *state) {
	size_t sampl_count = 0;
	uint8_t mask = (1<<bit);
	
	for (; mask > 0x00; mask >>= 1) {
		const int *durations = (data & mask)
		? BIT_1_CYCLE_DURATIONS
		: BIT_0_CYCLE_DURATIONS;
		
		const size_t count = write_cycle(durations, buffer, buffer_size, state);
		if (count == 0) {
			break;
		}
		
		sampl_count += count;
	};
	return sampl_count;
}

static inline int data_bit_index(cassette_apple2_encoder *state) {
	// number of cycles without header and sync bit
	const long data_cycle_index = state->cycle_index - (HEADER_CYCLE_COUNT+1);
	return data_cycle_index < 0 ? -1 : 7 - (data_cycle_index % 8);
}

size_t cassette_apple2_write_monitor_record(float *buffer, size_t buffer_size, cassette_apple2_encoder *state) {
	size_t old_buffer_size = buffer_size;
	// header tone
	while (state->cycle_index < HEADER_CYCLE_COUNT) {
		const size_t sample_count = write_cycle(HEADER_CYCLE_DURATIONS, &buffer, &buffer_size, state);
		if (sample_count == 0) {
			goto end;
		}
	}
	
	// sync bit
	if (state->cycle_index == HEADER_CYCLE_COUNT) {
		const size_t sample_count = write_cycle(SYNC_CYCLE_DURATIONS, &buffer, &buffer_size, state);
		if (sample_count == 0) {
			goto end;
		}
	}
	
	// data
	while (state->data_size > 0) {
		int bit = data_bit_index(state);
		const size_t sample_count = encode_data_uint8(*(state->data), bit, &buffer, &buffer_size, state);
		if (sample_count == 0) {
			goto end;
		}
		
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
		const size_t sample_count = encode_data_uint8(state->checksum, bit, &buffer, &buffer_size, state);
		if (sample_count == 0) {
			goto end;
		}
	}
	
	// final pulse
	// ensures hardware detects the last bit of checksum
	if (state->cycle_index == state->cycle_count) {
		const size_t sample_count = write_cycle((int[]){250, 250}, &buffer, &buffer_size, state);
		if (sample_count == 0) {
			goto end;
		}
	}
	
	// encoding complete
	end: return old_buffer_size - buffer_size;
}
