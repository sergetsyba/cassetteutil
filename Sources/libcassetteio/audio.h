//
//  audio.h
//  CassetteUtility
//
//  Created by Serge Tsyba on 22.1.2026.
//

#ifndef audio_h
#define audio_h

#include <stddef.h>

int cassette_write_file(const char *path, int sample_rate, size_t (write_buffer)(float *, size_t, const void *), const void *user_data);

#endif /* audio_h */
