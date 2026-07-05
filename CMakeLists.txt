#[=========================================================================[
  Copyright (c) 2022-2026 Pedro López-Cabanillas

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]=========================================================================]

cmake_minimum_required(VERSION 3.21)

project( sonivox
    LANGUAGES C CXX
    VERSION 4.0.1.0
)

# GoogleTest requires at least C++14
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED TRUE)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN TRUE)

option(USE_44KHZ "Output 44100 Hz audio sample rate (instead of 22050 Hz)" TRUE)
option(USE_16BITS_SAMPLES "Use 16 bits samples (instead of 8 bit)" TRUE)
option(BUILD_SHARED_LIBS "Build the shared library (instead of a static lib)" TRUE)
option(NEW_HOST_WRAPPER "Use the new host wrapper" TRUE)
option(SF2_SUPPORT "Enable SF2 support and float DCF" TRUE)
option(ZLIB_SUPPORT "Enable XMF ZLIB Unpacker support" TRUE)
option(EAS_WT_SYNTH "Enable WaveTable Synth" TRUE)
option(EAS_FM_SYNTH "Enable FM Synth" TRUE)
option(INSTALL_DEPENDENCIES "Deploy dependency libraries" FALSE)

if (NOT (EAS_WT_SYNTH OR EAS_FM_SYNTH OR EAS_HYBRID_SYNTH))
    message(FATAL_ERROR "At least one synthesizer type must be enabled: EAS_WT_SYNTH, EAS_FM_SYNTH, EAS_HYBRID_SYNTH.")
endif()

include(CMakeDependentOption)
cmake_dependent_option(EAS_HYBRID_SYNTH "Enable Hybrid Synth" FALSE "NOT USE_44KHZ;NOT USE_16BITS_SAMPLES" FALSE)
cmake_dependent_option(MP3_SUPPORT "Enable MP3 Decoder support" TRUE "USE_16BITS_SAMPLES" FALSE)
cmake_dependent_option(BUILD_TESTING "Build the unit tests" TRUE "NOT ANDROID" FALSE)
cmake_dependent_option(SOUNDFONT_TEST "Test DLS processing" FALSE "BUILD_TESTING" FALSE)
cmake_dependent_option(BUILD_APPLICATION "Build and install the CLI program" TRUE "NOT ANDROID" FALSE)
cmake_dependent_option(BUILD_MANPAGE "Build the manpage of the CLI program" FALSE "BUILD_APPLICATION" FALSE)

set(MAX_SYNTH_VOICES 64 CACHE STRING "Maximum number of voices")
mark_as_advanced(MAX_SYNTH_VOICES)

# Not yet configurable options. Please don't modify:
# in the future, they may be either options or cached variables
set(UNIFIED_DEBUG_MESSAGES ON)
set(NUM_OUTPUT_CHANNELS 2)
set(_FILTER_ENABLED ON)
set(DLS_SYNTHESIZER ON)
set(_REVERB_ENABLED ON)
set(_CHORUS_ENABLED ON)
set(_STATIC_MEMORY OFF)
set(_IMELODY_PARSER OFF)
set(_RTTTL_PARSER OFF)
set(_OTA_PARSER OFF)
set(_XMF_PARSER ON)
set(JET_INTERFACE OFF)
set(_RMID_PARSER ON)

set(_METRICS_ENABLED OFF)
set(MMAPI_SUPPORT OFF)
set(EXTERNAL_AUDIO OFF)

#derived options:
if (USE_16BITS_SAMPLES)
    set(_16_BIT_SAMPLES ON)
else()
    set(_8_BIT_SAMPLES ON)
endif()

if (USE_44KHZ)
    set(_SAMPLE_RATE_44100 ON)
else()
    set(_SAMPLE_RATE_22050 ON)
endif()

if (SF2_SUPPORT)
    set(_SF2_SUPPORT ON)
    set(_FLOAT_DCF ON)
endif()

if (DEFINED ENV{GITHUB_OUTPUT})
    file(APPEND
        "$ENV{GITHUB_OUTPUT}"
        "config_version=${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}\n"
    )
endif()

include(GNUInstallDirs)

set(PROJECT_RELEASE_DATE "February 14, 2026")

if (BUILD_TESTING)
    find_package(GTest CONFIG)
    if (GTest_FOUND)
        message( STATUS "Found GTest v${GTest_VERSION}")
    else()
        message( STATUS "GTest not found. Fetching the git repository..." )
        set( INSTALL_GTEST OFF CACHE BOOL "Enable installation of gooogletest" FORCE )
        set( BUILD_GMOCK OFF CACHE BOOL "Builds the googlemock subproject" FORCE )
        include( FetchContent )
        FetchContent_Declare( googletest
          GIT_REPOSITORY "https://github.com/google/googletest.git"
          GIT_TAG "v1.15.2"
        )
        # For Windows: Prevent overriding the parent project's compiler/linker settings
        set( gtest_force_shared_crt ON CACHE BOOL "" FORCE )
        FetchContent_MakeAvailable( googletest )
        if ( WIN32 )
            set_target_properties( gtest PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} )
            set_target_properties( gtest_main PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} )
        endif()
    endif()
endif()

if (UNIX AND NOT APPLE AND NOT EMSCRIPTEN)
    find_library(MATH_LIBRARY m)
    if(MATH_LIBRARY)
        message(STATUS "Found Math library: ${MATH_LIBRARY}")
        list(APPEND DEPLIBS ${MATH_LIBRARY})
        list(APPEND PRIVATE_LIST "-lm")
    endif()
endif()

set(_ZLIB_UNPACKER OFF)
if (ZLIB_SUPPORT)
    find_package(ZLIB)
    if (ZLIB_FOUND)
        message(STATUS "Enabling XMF ZLIB Unpacker support.")
        list(APPEND DEPLIBS ZLIB::ZLIB)
        list(APPEND PRIVATE_LIST "-lz")
        set(_ZLIB_UNPACKER ON)
    else()
        message(STATUS "ZLIB not found. Disabling XMF ZLIB Unpacker support.")
    endif()
endif()

list(APPEND SOURCES
  arm-wt-22k/host_src/eas_config.c
#arm-wt-22k/host_src/eas_hostmm.c
#arm-wt-22k/host_src/eas_main.c
  arm-wt-22k/host_src/eas_report.c
#arm-wt-22k/host_src/eas_wave.c
  arm-wt-22k/lib_src/eas_chorus.c
  arm-wt-22k/lib_src/eas_dlssynth.c
  arm-wt-22k/lib_src/eas_flog.c
#arm-wt-22k/lib_src/eas_ima_tables.c
#arm-wt-22k/lib_src/eas_imaadpcm.c
#arm-wt-22k/lib_src/eas_imelody.c
  arm-wt-22k/lib_src/eas_math.c
  arm-wt-22k/lib_src/eas_mdls.c
  arm-wt-22k/lib_src/eas_midi.c
  arm-wt-22k/lib_src/eas_mixbuf.c
  arm-wt-22k/lib_src/eas_mixer.c
#arm-wt-22k/lib_src/eas_ota.c
  arm-wt-22k/lib_src/eas_pan.c
  arm-wt-22k/lib_src/eas_pcm.c
  arm-wt-22k/lib_src/eas_public.c
  arm-wt-22k/lib_src/eas_reverb.c
#arm-wt-22k/lib_src/eas_rtttl.c
  arm-wt-22k/lib_src/eas_smf.c
  arm-wt-22k/lib_src/eas_tonecontrol.c
  arm-wt-22k/lib_src/eas_voicemgt.c
#arm-wt-22k/lib_src/eas_wavefile.c
  arm-wt-22k/lib_src/eas_xmf.c
#arm-wt-22k/lib_src/jet.c
  arm-wt-22k/src/rmidi.c
  arm-wt-22k/lib_src/eas_sndlibmgt.c
)

if(EAS_WT_SYNTH OR EAS_HYBRID_SYNTH)
    list(APPEND SOURCES
        arm-wt-22k/lib_src/eas_wtengine.c
        arm-wt-22k/lib_src/eas_wtsynth.c
    )
endif()

if(EAS_FM_SYNTH OR EAS_HYBRID_SYNTH)
    list(APPEND SOURCES
        arm-wt-22k/lib_src/eas_fmengine.c
        arm-wt-22k/lib_src/eas_fmsynth.c
        arm-wt-22k/lib_src/eas_fmtables.c
    )
endif()

if(EAS_WT_SYNTH)
    list(APPEND SOURCES
        arm-wt-22k/lib_src/wt_200k_G.c
    )
endif()

if(EAS_FM_SYNTH)
    list(APPEND SOURCES
        arm-wt-22k/lib_src/eas_fmsndlib.c
    )
endif()

if(EAS_HYBRID_SYNTH)
    list(APPEND SOURCES
        arm-wt-22k/lib_src/hybrid_22khz_mcu.c
    )
endif()

if (NEW_HOST_WRAPPER)
    list(APPEND SOURCES arm-wt-22k/src/hostmm_ng.c)
else()
    list(APPEND SOURCES arm-wt-22k/host_src/eas_hostmm.c)
endif()

if (SF2_SUPPORT)
    list(APPEND SOURCES arm-wt-22k/lib_src/eas_sf2.c arm-wt-22k/lib_src/eas_filter_float.c)
else()
    message(STATUS "SF2 support disabled.")
    list(APPEND SOURCES arm-wt-22k/lib_src/eas_filter.c)
endif()

if (_STATIC_MEMORY)
    list(APPEND SOURCES
        arm-wt-22k/lib_src/eas_chorusdata.c
        arm-wt-22k/lib_src/eas_data.c
        #arm-wt-22k/lib_src/eas_imelodydata.c
        arm-wt-22k/lib_src/eas_mididata.c
        #arm-wt-22k/lib_src/eas_otadata.c
        arm-wt-22k/lib_src/eas_pcmdata.c
        arm-wt-22k/lib_src/eas_reverbdata.c
        #arm-wt-22k/lib_src/eas_rtttldata.c
        arm-wt-22k/lib_src/eas_smfdata.c
        arm-wt-22k/lib_src/eas_tcdata.c
        #arm-wt-22k/lib_src/eas_wavefiledata.c
        arm-wt-22k/lib_src/eas_xmfdata.c
    )
endif()

include(TestBigEndian)
test_big_endian(EAS_BIG_ENDIAN)

include ( CheckIncludeFile )
check_include_file ( getopt.h HAVE_GETOPT_H )

configure_file(arm-wt-22k/host_src/eas_version.cmake libsonivox/eas_version.h @ONLY)
configure_file(arm-wt-22k/host_src/eas_options.cmake libsonivox/eas_options.h @ONLY)

list(APPEND PUBLIC_HEADERS
    arm-wt-22k/host_src/eas.h
    arm-wt-22k/host_src/eas_chorus.h
    arm-wt-22k/host_src/eas_reverb.h
    arm-wt-22k/host_src/eas_types.h
    arm-wt-22k/host_src/eas_report.h
    ${CMAKE_CURRENT_BINARY_DIR}/libsonivox/eas_version.h
    ${CMAKE_CURRENT_BINARY_DIR}/libsonivox/eas_options.h
    ${CMAKE_CURRENT_BINARY_DIR}/libsonivox/eas_visibility.h
    #arm-wt-22k/host_src/jet.h
)

list(APPEND PRIVATE_HEADERS
    arm-wt-22k/host_src/eas_build.h
    arm-wt-22k/host_src/eas_config.h
    arm-wt-22k/host_src/eas_debugmsgs.h
    arm-wt-22k/host_src/eas_host.h
    arm-wt-22k/host_src/eas_wave.h
    arm-wt-22k/lib_src/dls.h
    arm-wt-22k/lib_src/dls2.h
    arm-wt-22k/lib_src/eas_ctype.h
    arm-wt-22k/lib_src/eas_imelodydata.h
    arm-wt-22k/lib_src/eas_midi.h
    arm-wt-22k/lib_src/eas_otadata.h
    arm-wt-22k/lib_src/eas_pan.h
    arm-wt-22k/lib_src/eas_pcm.h
    arm-wt-22k/lib_src/eas_pcmdata.h
    arm-wt-22k/lib_src/eas_rtttldata.h
    arm-wt-22k/lib_src/eas_smfdata.h
    arm-wt-22k/lib_src/eas_synth_protos.h
    arm-wt-22k/lib_src/eas_wavefile.h
    arm-wt-22k/lib_src/eas_xmf.h
    arm-wt-22k/lib_src/jet_data.h
    arm-wt-22k/lib_src/eas_tcdata.h
    arm-wt-22k/lib_src/eas_reverbdata.h
    arm-wt-22k/lib_src/minimp3.h
    arm-wt-22k/lib_src/pcm_aulaw.h
    arm-wt-22k/lib_src/eas_effects.h
    arm-wt-22k/lib_src/eas_xmfdata.h
    arm-wt-22k/lib_src/eas_data.h
    arm-wt-22k/lib_src/eas_dlssynth.h
    arm-wt-22k/lib_src/eas_math.h
    arm-wt-22k/lib_src/eas_mdls.h
    arm-wt-22k/lib_src/eas_midictrl.h
    arm-wt-22k/lib_src/eas_miditypes.h
    arm-wt-22k/lib_src/eas_mixer.h
    arm-wt-22k/lib_src/eas_parser.h
    arm-wt-22k/lib_src/eas_sf2.h
    arm-wt-22k/lib_src/eas_smf.h
    arm-wt-22k/lib_src/eas_vm_protos.h
    arm-wt-22k/lib_src/eas_wt_IPC_frame.h
    arm-wt-22k/lib_src/eas_wtengine.h
    arm-wt-22k/lib_src/eas_wtsynth.h
    arm-wt-22k/lib_src/eas_synthcfg.h
    arm-wt-22k/lib_src/eas_sndlib.h
    arm-wt-22k/lib_src/eas_synth.h
    arm-wt-22k/lib_src/eas_audioconst.h
    arm-wt-22k/lib_src/eas_chorusdata.h
    arm-wt-22k/lib_src/eas_filter.h
    arm-wt-22k/lib_src/eas_fmengine.h
    arm-wt-22k/lib_src/eas_fmsynth.h
    arm-wt-22k/lib_src/eas_dlslib.h
)

add_library( sonivox
    ${SOURCES}
    ${PUBLIC_HEADERS}
    ${PRIVATE_HEADERS}
    arm-wt-22k/host_src/eas_options.cmake
    arm-wt-22k/host_src/eas_version.cmake
)

if (CMAKE_C_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
    target_compile_options( sonivox PRIVATE
        -Wno-unused-parameter
        -Wno-unused-value
        -Wno-unused-variable
        -Wno-unused-function
        -Wno-misleading-indentation
        -Wno-attributes
        -Wformat
    )
endif()

if (BUILD_SHARED_LIBS)
    target_compile_definitions( sonivox PRIVATE sonivox_EXPORTS )
else()
    target_compile_definitions ( sonivox PUBLIC SONIVOX_STATIC_DEFINE )
endif()

include(GenerateExportHeader)
generate_export_header( sonivox
  EXPORT_FILE_NAME     ${CMAKE_CURRENT_BINARY_DIR}/libsonivox/eas_visibility.h
  EXPORT_MACRO_NAME    EAS_PUBLIC
  NO_EXPORT_MACRO_NAME EAS_PRIVATE
  INCLUDE_GUARD_NAME   EAS_VISIBILITY_H
)

target_include_directories( sonivox PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/libsonivox>"
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/arm-wt-22k/host_src>"
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/arm-wt-22k/lib_src>"
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/fakes>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/sonivox>" )
set_target_properties( sonivox PROPERTIES VERSION ${PROJECT_VERSION} )
set_target_properties( sonivox PROPERTIES SOVERSION ${PROJECT_VERSION_MAJOR} )
set_target_properties( sonivox PROPERTIES PUBLIC_HEADER "${PUBLIC_HEADERS}" )
target_link_libraries( sonivox PRIVATE ${DEPLIBS} )
if (NOT APPLE)
    target_link_options( sonivox PUBLIC "LINKER:--build-id=none" )
endif()
#target_link_options( sonivox PRIVATE "LINKER:-z,defs" )
add_library( sonivox::sonivox ALIAS sonivox )
list( APPEND SONIVOX_TARGETS sonivox )

if(IS_ABSOLUTE ${CMAKE_INSTALL_LIBDIR})
    set(sonivox_libdir "${CMAKE_INSTALL_LIBDIR}")
else()
    set(sonivox_libdir "\${exec_prefix}/${CMAKE_INSTALL_LIBDIR}")
endif()
if(IS_ABSOLUTE ${CMAKE_INSTALL_INCLUDEDIR})
    set(sonivox_includedir "${CMAKE_INSTALL_INCLUDEDIR}")
else()
    set(sonivox_includedir "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
endif()

list(JOIN PRIVATE_LIST " " PRIVATE_LIBS)
configure_file(sonivox.pc.in ${CMAKE_CURRENT_BINARY_DIR}/sonivox.pc @ONLY)
install( FILES ${CMAKE_CURRENT_BINARY_DIR}/sonivox.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
    COMPONENT sonivox_development
)

install( TARGETS ${SONIVOX_TARGETS}
    EXPORT sonivox-targets
    RUNTIME_DEPENDENCY_SET sonivox-dependencies
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
            COMPONENT sonivox_runtime
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            COMPONENT sonivox_development
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            COMPONENT sonivox_runtime
            NAMELINK_COMPONENT sonivox_development
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/sonivox
            COMPONENT sonivox_development
)

if (BUILD_SHARED_LIBS)
    set(type shared)
else ()
    set(type static)
endif ()

install( EXPORT sonivox-targets
    FILE ${PROJECT_NAME}-${type}-targets.cmake
    NAMESPACE ${PROJECT_NAME}::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
    COMPONENT sonivox_development
)

export( EXPORT sonivox-targets
    FILE "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-${type}-targets.cmake"
    NAMESPACE ${PROJECT_NAME}::
)

include( CMakePackageConfigHelpers )

write_basic_package_version_file(
    ${PROJECT_NAME}-config-version.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
)

configure_package_config_file(
    ${PROJECT_NAME}-config.cmake.in
    ${PROJECT_NAME}-config.cmake
    INSTALL_DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
)

install( FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-config-version.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
        COMPONENT sonivox_development
)

# Unit testing
if (BUILD_TESTING)
    enable_testing()

    add_executable( SonivoxTest
        test/SonivoxTest.cpp
        test/SonivoxTestEnvironment.h
    )

    target_include_directories( SonivoxTest PRIVATE
        ${CMAKE_CURRENT_BINARY_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/arm-wt-22k/include
        ${CMAKE_CURRENT_SOURCE_DIR}/fakes
    )

    if (NOT HAVE_GETOPT_H)
        target_sources( SonivoxTest PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/getopt_port/getopt.c
            ${CMAKE_CURRENT_SOURCE_DIR}/getopt_port/getopt.h )
        target_include_directories( SonivoxTest PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/getopt_port )
    endif()

    target_link_libraries( SonivoxTest PRIVATE
        GTest::gtest_main
        sonivox
    )

    if(DEFINED ENV{TEMP})
        set(TEMPDIR "$ENV{TEMP}")
    elseif(DEFINED ENV{XDG_RUNTIME_DIR})
        set(TEMPDIR "$ENV{XDG_RUNTIME_DIR}")
    else()
        message(FATAL_ERROR "Cannot find a temporary directory. Define the TEMP environment variable.")
    endif()

    if (SOUNDFONT_TEST)
        set(SOUNDFONT "${TEMPDIR}/soundfont.dls")
        if (NOT EXISTS ${SOUNDFONT})
            message(STATUS "Downloading DLS file for testing to ${SOUNDFONT}")
            file(DOWNLOAD "http://www.ronimusic.com/sf2/Airfont_340.dls" ${SOUNDFONT})

            file(SIZE ${SOUNDFONT} SOUNDFONTSIZE)
            file(MD5 ${SOUNDFONT} SOUNDFONTHASH)
            message(STATUS "DLS file ${SOUNDFONT} size: ${SOUNDFONTSIZE}")
            message(STATUS "DLS file ${SOUNDFONT} MD5 hash: ${SOUNDFONTHASH}")
            if (NOT (SOUNDFONTSIZE EQUAL 81362584 AND SOUNDFONTHASH STREQUAL "40c0cd4ad29ae411a8fc3d6681002a2b"))
                message(FATAL_ERROR "The downloaded DLS file is corrupted.")
            endif()
        endif()
    endif()

    include( GoogleTest )
    gtest_discover_tests( SonivoxTest EXTRA_ARGS "-P${CMAKE_CURRENT_SOURCE_DIR}/test/res/" DISCOVERY_TIMEOUT 300 )
endif()

# CLI program
if (BUILD_APPLICATION)
    set(sonivox_DIR ${CMAKE_CURRENT_BINARY_DIR})
    add_subdirectory(example)
endif()

if (INSTALL_DEPENDENCIES)
    message(STATUS "DEPENDENCY_DIRS: ${DEPENDENCY_DIRS}")
    install(RUNTIME_DEPENDENCY_SET sonivox-dependencies
        COMPONENT sonivox_runtime
        PRE_INCLUDE_REGEXES $<$<BOOL:${_ZLIB_UNPACKER}>:.*zlib.*>
        PRE_EXCLUDE_REGEXES .*
        DIRECTORIES ${CMAKE_CURRENT_BINARY_DIR} ${DEPENDENCY_DIRS}
    )
endif()

# CPack support
set ( CPACK_PACKAGE_DESCRIPTION_SUMMARY "Sonivox EAS synthesizer" )
set ( CPACK_PACKAGE_VENDOR "https://github.com/pedrolcl/sonivox" )
set ( CPACK_PACKAGE_DESCRIPTION_FILE "${sonivox_SOURCE_DIR}/README.md" )
set ( CPACK_RESOURCE_FILE_LICENSE "${sonivox_SOURCE_DIR}/LICENSE" )
set ( CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR} )
set ( CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR} )
set ( CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH} )
set ( CPACK_PACKAGE_EXECUTABLES "sonivoxrender" "Sonivox CLI" )

# source packages
set ( CPACK_SOURCE_IGNORE_FILES "/.git/;/build/;~$;${CPACK_SOURCE_IGNORE_FILES}" )
set ( CPACK_SOURCE_PACKAGE_FILE_NAME "sonivox-${PROJECT_VERSION}" )
set ( CPACK_SOURCE_STRIP_FILES OFF )

# binary packages
include ( InstallRequiredSystemLibraries )
set ( CPACK_PACKAGE_NAME sonivox )
set ( CPACK_STRIP_FILES ON )

include ( CPack )

cpack_add_component(sonivox_runtime
  DISPLAY_NAME "Runtime Library"
  DESCRIPTION "Shared library (DLL) needed to run Sonivox programs")
cpack_add_component(sonivox_application
  DISPLAY_NAME "Sonivox CLI Program"
  DESCRIPTION "Sonivox Command Line Interface Program"
  DEPENDS sonivox_runtime)
cpack_add_component(sonivox_development
  DISPLAY_NAME "C Headers and import library"
  DESCRIPTION "C headers and import library for using Sonivox library"
  DEPENDS sonivox_runtime)

