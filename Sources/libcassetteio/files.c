//
//  files.c
//  CassetteUtility
//
//  Created by Serge Tsyba on 5.1.2026.
//

#include "files.h"

/// Writes the specified 16 bit value to the specified file in big-endian byte order.
static inline void fwrite_uint16(uint16_t value, FILE *file) {
	const uint16_t swapped = __builtin_bswap16(value);
	fwrite(&swapped, sizeof(uint16_t), 1, file);
}

/// Writes the specified 32 bit value to the specified file in big-endian byte order.
static inline void fwrite_uint32(uint32_t value, FILE *file) {
	const uint32_t swapped = __builtin_bswap32(value);
	fwrite(&swapped, sizeof(uint32_t), 1, file);
}

/// Writes the specified 32 bit value to the specified file as a Standard Apple Numerics Environment,
/// extended 80 bit value in big-endian byte order.
static void fwrite_sane_extended(uint32_t value, FILE *file) {
	uint16_t exponent = 0;
	if (value > 0) {
		// find most significant position of 1 bit
		const int bit = 31 - __builtin_clz(value);
		exponent = bit + 16383;
		
		// shift value such that leading 1 is in the most significant bit
		value <<= (31 - bit);
	}
	// when value == 0, bias must not be added to exponent
	// and exponent is 0 as well
	
	// write sign bit 0 and 15 bits of exponent
	fwrite_uint16(exponent, file);
	// write significand and remaining 4 bytes
	fwrite_uint32(value, file);
	fwrite_uint32(0, file);
}

void fwrite_8_bit_aiff(int sample_rate, int (^write_samples)(FILE *file), FILE *file) {
	// form container chunk
	// chunk id = FORM
	// size
	// form type = AIFF
	fwrite("FORM", sizeof(char), 4, file);
	
	const long form_size_position = ftell(file);
	fwrite_uint32(0, file);
	fwrite("AIFF", sizeof(char), 4, file);
	
	// common chunk
	// chunk id = COMM
	// size = 18
	// channel count = 1
	// sample count
	// sample size = 8
	// sample rate
	fwrite("COMM", sizeof(char), 4, file);
	fwrite_uint32(2+4+2+10, file);
	fwrite_uint16(1, file);
	
	const long sample_count_position = ftell(file);
	fwrite_uint32(0, file);
	fwrite_uint16(8, file);
	fwrite_sane_extended(sample_rate, file);
	
	// sound data chunk
	// chunk id = SSND
	// size
	// offset = 0
	// block size = 0
	fwrite("SSND", sizeof(char), 4, file);
	
	const long sound_size_position = ftell(file);
	fwrite_uint32(0, file);
	fwrite_uint32(0, file);
	fwrite_uint32(0, file);
	
	// write samples
	int sample_count = write_samples(file);
	// AIFF requires samples be padded to an even number of bytes
	const int padding = sample_count % 2;
	if (padding > 0) {
		fputc(0x00, file);
	}
	
	// update common chunk sample count
	fseek(file, sample_count_position, SEEK_SET);
	fwrite_uint32(sample_count, file);
	
	// update sound chunk size
	const uint32_t sound_chunk_size = 8 + sample_count;
	fseek(file, sound_size_position, SEEK_SET);
	fwrite_uint32(sound_chunk_size, file);
	
	// update form chunk size
	const uint32_t form_chunk_size = 4+26 + (8 + sound_chunk_size) + padding;
	fseek(file, form_size_position, SEEK_SET);
	fwrite_uint32(form_chunk_size, file);
	fseek(file, 0, SEEK_END);
}
