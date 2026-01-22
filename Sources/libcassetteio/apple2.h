//
//  apple2.h
//  libcassetteio
//
//  Created by Serge Tsyba on 1.1.2026.
//

#ifndef apple2_h
#define apple2_h

#include <stdint.h>

typedef struct cassette_apple2_encoder cassette_apple2_encoder;

/**
 * Allocates a new instance of Apple II cassette audio record encoder.
 *
 * @param data Data to encode as audio cassette record. Encoder only keeps a reference to the data,
 *		so it must not be freed or modified until encoding is complete.
 * @param data_size Size of data to encode as audio cassette record, in bytes.
 * @param sample_rate Encoded audio cassette record sample rate, in Hz.
 * @return A new instance of encoder, or NULL when allocation fails.
 */
cassette_apple2_encoder *cassette_apple2_alloc_encoder(const uint8_t *data, size_t data_size, int sample_rate);

/**
 * Writes encoded audio samples of a standard Apple II cassette audio record into the specified audio
 * sample buffer.
 *
 * This function writes as many audio samples as fit into the buffer of the specified size and returns the
 * number of samples written. Call this function repeatedly with the same encoder instance until it returns 0,
 * at which point encoding is complete.
 *
 * This function writes output audio samples in chunks, encoded from whole FSK cycles. It returns once
 * encoded audio samples of a single cycle no longer fit into the buffer. As a consequence, the output
 * buffer must be large enough to fit audio samples of at least one FSK cycle. This size equals to output
 * audio sample rate × 0.0013. For instance, for a sample rate of 44100 Hz, the output audio buffer size
 * must be at least 58 bytes.
 *
 * @param buffer Pointer to a pre-allocated buffer where output audio samples are written.
 * @param buffer_size Size of the output audio sample buffer, in bytes.
 * @param encoder An instance of Apple II cassette encoder, which preserves encoding state
 * 		between calls.
 * @return Size of all encoded audio samples written, in bytes.
 */
size_t cassette_apple2_write_monitor_record(float *buffer, size_t buffer_size, cassette_apple2_encoder *encoder);

#endif /* apple2_h */
