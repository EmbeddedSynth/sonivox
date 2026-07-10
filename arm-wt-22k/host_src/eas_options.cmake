#ifndef EAS_OPTIONS_CMAKE
#define EAS_OPTIONS_CMAKE

#cmakedefine UNIFIED_DEBUG_MESSAGES
#cmakedefine EAS_WT_SYNTH
#cmakedefine EAS_FM_SYNTH
#cmakedefine EAS_HYBRID_SYNTH
#cmakedefine NUM_OUTPUT_CHANNELS @NUM_OUTPUT_CHANNELS@
#cmakedefine MAX_SYNTH_VOICES @MAX_SYNTH_VOICES@
#cmakedefine _FILTER_ENABLED
#cmakedefine DLS_SYNTHESIZER
#cmakedefine _REVERB_ENABLED
#cmakedefine _CHORUS_ENABLED
#cmakedefine _STATIC_MEMORY
#cmakedefine _IMELODY_PARSER
#cmakedefine _RTTTL_PARSER
#cmakedefine _OTA_PARSER
#cmakedefine _XMF_PARSER
#cmakedefine JET_INTERFACE
#cmakedefine _RMID_PARSER

#cmakedefine _METRICS_ENABLED
#cmakedefine MMAPI_SUPPORT
#cmakedefine EXTERNAL_AUDIO

#cmakedefine EAS_BIG_ENDIAN
#cmakedefine _16_BIT_SAMPLES
#cmakedefine _8_BIT_SAMPLES
#cmakedefine _SAMPLE_RATE_44100
#cmakedefine _SAMPLE_RATE_22050

#cmakedefine _ZLIB_UNPACKER
#cmakedefine _SF2_SUPPORT
#cmakedefine _FLOAT_DCF
#cmakedefine MP3_SUPPORT

#endif // EAS_OPTIONS_CMAKE
