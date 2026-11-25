#import "LocalTranscription.h"
#import <whisper/whisper.h>

NSString *AiCatTranscribeRussian(NSString *modelPath, NSData *pcm) {
    NSUInteger count = pcm.length / sizeof(float);
    if (count < 3200 || count > 16000 * 31) return nil;
    struct whisper_context_params contextParams = whisper_context_default_params();
    contextParams.use_gpu = false;
    struct whisper_context *context = whisper_init_from_file_with_params(modelPath.fileSystemRepresentation, contextParams);
    if (!context) return nil;
    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.language = "ru";
    params.n_threads = 3;
    params.no_context = true;
    params.no_timestamps = true;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    NSMutableString *result = nil;
    if (whisper_full(context, params, pcm.bytes, (int)count) == 0) {
        result = [NSMutableString string];
        for (int i = 0; i < whisper_full_n_segments(context); i++) {
            const char *text = whisper_full_get_segment_text(context, i);
            if (text) [result appendString:[NSString stringWithUTF8String:text] ?: @""];
        }
    }
    whisper_free(context);
    return result;
}
