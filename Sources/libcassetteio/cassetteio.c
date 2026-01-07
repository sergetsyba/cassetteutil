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

/// Writes samples of a square wave of the specified frequency in Hz and duration in milliseconds
/// to the specified file.
static int fwrite_square_wave(int frequency, int sample_rate, int duration, FILE *file) {
	// number of samples in a half cycle measured in units of precision
	const int sample_count = sample_rate * duration / 1e3;
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

void cassette_init() {
	const int frequency = 770;
	const int sample_rate = 44100;
	const int duration = 5000;
	
	FILE *file = fopen("/Users/Serge/Desktop/output.aiff", "wb+");
	fwrite_8_bit_aiff(sample_rate, ^int(FILE *file) {
		return fwrite_square_wave(frequency, sample_rate, duration, file);
	}, file);
	
	fclose(file);
}
