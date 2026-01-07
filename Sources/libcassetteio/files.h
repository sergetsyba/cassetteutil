//
//  files.h
//  CassetteUtility
//
//  Created by Serge Tsyba on 5.1.2026.
//

#ifndef files_h
#define files_h

#include <stdint.h>
#include <stdio.h>

/// Writes an AIFF file with 8-bit audio samples produced by the specified block and the specified
/// sampling rate in Hz.
// TODO: change signature to use file path
void fwrite_8_bit_aiff(int sample_rate, int (^write_samples)(FILE *file), FILE *file);

#endif /* files_h */
