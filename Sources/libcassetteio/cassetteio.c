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
#include <stdio.h>

static const int unit = 1e3;

/// Writes samples of a square wave of the specified frequency (in Hz) and duration (in μs) to
/// the specified file. Returns the number of samples written.
static int fwrite_square_wave(int frequency, int sample_rate, int duration, FILE *file) {
	// number of samples in a half cycle measured in units of precision
	const int sample_count = sample_rate * duration / 1e6;
	const int sampled_count_max = (sample_rate * unit) / (frequency * 2);
	// number of samples produced in current half cycle
	int sampled_count = 0;
	
	int8_t amplitude = INT8_MAX;
	for (int index = 0; index < sample_count; ++index) {
		fputc(amplitude, file);
		sampled_count += unit;
		
		// when enough samples produced, flip amplitude
		if (sampled_count > sampled_count_max) {
			sampled_count -= sampled_count_max;
			amplitude = -amplitude;
		}
	}
	
	return sample_count;
}

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
