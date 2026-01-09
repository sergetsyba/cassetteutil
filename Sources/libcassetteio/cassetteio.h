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

#endif /* cassetteio_h */
