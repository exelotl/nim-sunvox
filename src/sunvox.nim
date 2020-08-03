##
##  SunVox modular synthesizer
##  Copyright (c) 2008 - 2019, Alexander Zolotov <nightradio@gmail.com>, WarmPlace.ru
##

import strutils
import strformat
import math

when defined(Windows):
  const libname* = "sunvox.dll"
elif defined(Linux):
  const libname* = "sunvox.so"
elif defined(MacOSX):
  const libname* = "sunvox.dylib"

# Initialization flags
const
  NO_DEBUG_OUTPUT* = (1 shl 0)
  USER_AUDIO_CALLBACK* = (1 shl 1)  ## Interaction with sound card is on the user side
  OFFLINE* = ( 1 shl 1 ) # Same as SV_INIT_FLAG_USER_AUDIO_CALLBACK
  AUDIO_INT16* = (1 shl 2)
  AUDIO_FLOAT32* = (1 shl 3)
  ONE_THREAD* = (1 shl 4)  ## Audio callback and song modification functions are in single thread

# Time map flags
const
  TIME_MAP_SPEED* = 0
  TIME_MAP_FRAMECNT* = 1
  TIME_MAP_TYPE_MASK* = 3

# Module flags
# (these are not exported, in favour of the templates below)
const
  MODULE_FLAG_EXISTS = ( 1 shl 0 )
  MODULE_FLAG_EFFECT = ( 1 shl 1 )
  MODULE_FLAG_MUTE = ( 1 shl 2 )
  MODULE_FLAG_SOLO = ( 1 shl 3 )
  MODULE_FLAG_BYPASS = ( 1 shl 4 )
  MODULE_INPUTS_OFF = 16
  MODULE_INPUTS_MASK = (255 shl MODULE_INPUTS_OFF)
  MODULE_OUTPUTS_OFF = (16 + 8)
  MODULE_OUTPUTS_MASK = (255 shl MODULE_OUTPUTS_OFF)

type ModuleFlags = distinct cuint
  ## Bitfield containing information about an instrument/effect module.

template mute*(m:ModuleFlags): bool = (m.cuint and MODULE_FLAG_MUTE) != 0
template solo*(m:ModuleFlags): bool = (m.cuint and MODULE_FLAG_SOLO) != 0
template bypass*(m:ModuleFlags): bool = (m.cuint and MODULE_FLAG_BYPASS) != 0
template exists*(m:ModuleFlags): bool = (m.cuint and MODULE_FLAG_EXISTS) != 0
template effect*(m:ModuleFlags): bool = (m.cuint and MODULE_FLAG_EFFECT) != 0
template inputs*(m:ModuleFlags): int = ((m.cuint and MODULE_INPUTS_MASK) shr MODULE_INPUTS_OFF).int
template outputs*(m:ModuleFlags): int = ((m.cuint and MODULE_OUTPUTS_MASK) shr MODULE_OUTPUTS_OFF).int

proc pitchToFreq*(pitch: float): float =
  pow(2.0, (30720.0 - pitch) / 3072.0) * 16.3339

proc freqToPitch*(freq: float): float =
  30720.0 - log2(freq / 16.3339) * 3072.0


# Sample types
const
  STYPE_INT16* = 0
  STYPE_INT32* = 1
  STYPE_FLOAT32* = 2
  STYPE_FLOAT64* = 3

# Special note values
const
  NOTECMD_NOTE_OFF* = 128
  NOTECMD_ALL_NOTES_OFF* = 129
  NOTECMD_CLEAN_SYNTHS* = 130
  NOTECMD_STOP* = 131
  NOTECMD_PLAY* = 132
  NOTECMD_SET_PITCH* = 133 # set pitch ctl_val

type
  NotePtr* = ptr Note
  Note* {.bycopy.} = object
    note*: uint8      ##  NN: 0 = nothing;  1..127 = note num;  128 = note off;  129, 130... see NOTECMD_xxx constants
    vel*: uint8       ##  VV: Velocity 1..129;  0 = default
    module*: uint8    ##  MM: 0 = nothing;  1..255 = module number + 1
    zero*: uint8      ##  ...future use...
    ctl*: uint16      ##  0xCCEE: CC: 1..127 = controller number + 1;  EE = effect
    ctlVal*: uint16   ##  0xXXYY: value of controller or effect

const noteNames = "CcDdEFfGgAaB"

proc `$`*(n:Note|NotePtr): string =
  ## Get a string representation of a note event.
  ## `n.vel` and `n.module` are displayed as 1 less than their true value,
  ## so that the result matches what you would see in the SunVox pattern editor.
  let (note, vel, module, ctl, ctlVal) = (n.note.int, n.vel.int, n.module.int, n.ctl.int, n.ctlVal.int)
  let nn = if note == 0: ".."  else: noteNames[(note-1) mod 12] & $((note-1) div 12)
  let vv = if vel == 0: ".."  else: (vel-1).toHex(2)
  let mm = if module == 0: ".."  else: (module-1).toHex(2)
  let ccee = if ctl == 0: "...."  else: ctl.toHex(4)
  let xxyy = if ctlVal == 0: "...."  else: ctlVal.toHex(4)
  fmt"[{nn} {vv} {mm} {ccee} {xxyy}]"

type Version = distinct cint
  ## Either a SunVox version number or an error code.

proc error*(v:Version):bool = v.cint < 0              ## check if there was an error. If true, you can use `v.int` to get the error code
proc major*(v:Version):int = (v.cint shr 16) and 255  ## get major version
proc minor*(v:Version):int = (v.cint shr 8) and 255   ## get minor version
proc patch*(v:Version):int = v.cint and 255           ## get patch version
proc `$`*(v:Version):string =
  if v.error: $v.int
  else: $v.major & '.' & $v.minor & '.' & $v.patch

# These functions are wrapped to provide a slightly nicer interface
proc sv_init(config:cstring, freq:cint, channels:cint, flags:cuint): cint {.importc, dynlib:libname.}
proc sv_set_autostop(slot: cint, autostop: cint): cint {.importc, dynlib:libname, discardable.}
proc sv_get_autostop(slot: cint): cint {.importc, dynlib:libname.}
proc sv_end_of_song(slot: cint): cint {.importc, dynlib:libname, discardable.}
proc sv_audio_callback(buf: pointer, frames: cint, latency: cint, outTime: cuint): cint {.importc, dynlib:libname, discardable.}
proc sv_audio_callback2(buf: pointer, frames: cint, latency: cint, outTime: cuint, inType: cint, inChannels: cint, inBuf: pointer): cint {.importc, dynlib:libname, discardable.}
proc sv_get_module_xy(slot: cint, modNum: cint): cuint {.importc, dynlib:libname.}
proc sv_get_module_finetune(slot: cint, modNum: cint): cint {.importc, dynlib:libname.}

proc getSampleRate*(): cint {.importc: "sv_get_sample_rate", dynlib:libname.}
  ## get current sampling rate (it may differ from the frequency specified in sv_init())

proc updateInput*(): cint {.importc: "sv_update_input", dynlib:libname, discardable .}
  ## handle input ON/OFF requests to enable/disable input ports of the sound card
  ## (for example, after the Input module creation).
  ## Call it from the main thread only, where the SunVox sound stream is not locked.

proc audioCallback*(buf: pointer, frames: cint, latency: cint, outTime: cuint): bool {.discardable.} = sv_audio_callback(buf, frames, latency, outTime).bool
  ## Get the next piece of SunVox audio.
  ## This lets you ignore the built-in SunVox sound output mechanism and use some other sound system.
  ## Set USER_AUDIO_CALLBACK flag in init() if you want to use this function.
  ## Parameters:
  ## `buf`    destination buffer of type `cshort` (if AUDIO_INT16 used in init()) or `cfloat` (if AUDIO_FLOAT32 used in init())
  ##          stereo data will be interleaved in this buffer: LRLR... where LR is a single frame (Left+Right channels)
  ## `frames`    number of frames in destination buffer
  ## `latency`   audio latency (in frames)
  ## `outTime`   buffer output time (in system ticks)
  ##
  ## Returns `false` for silence (buffer filled with zeroes), `true` if any signal was produced
  ##
  ## Example:
  ## ```
  ##   let userOutTime: cuint = ...                    # output time in user time space (NOT SunVox time space!)
  ##   let userCurTime: cuint = ...                    # current time (user time space)
  ##   let userTicksPerSecond: cuint = ...             # ticks per second (user time space)
  ##   let userLatency = (userOutTime - userCurTime)   # latency in user time space
  ##   let sunvoxLatency = (userLatency * getTicksPerSecond()) div userTicksPerSecond   # latency in SunVox time space
  ##   let latencyFrames = (userLatency * sampleRateHz) div userTicksPerSecond          # latency in frames
  ##   audioCallback(buf, frames, latencyFrames.cint, getTicks() + sunvoxLatency)
  ## ```

proc audioCallback*(buf: pointer, frames: cint, latency: cint, outTime: cuint, inType: cint, inChannels: cint, inBuf: pointer): bool {.discardable.} = sv_audio_callback2(buf, frames, latency, outTime, inType, inChannels, inBuf).bool
  ## Extended version of `audioCallback`, allowing you to specify an input buffer to be processed.
  ## Sends some data to the Input module and receive the filtered data from the Output module.
  ## Parameters:
  ## `buf`    destination buffer of type `cshort` (if AUDIO_INT16 used in init()) or `cfloat` (if AUDIO_FLOAT32 used in init())
  ##          stereo data will be interleaved in this buffer: LRLR... where LR is a single frame (Left+Right channels)
  ## `frames`     number of frames in destination buffer
  ## `latency`    audio latency (in frames)
  ## `outTime`    buffer output time (in system ticks)
  ## `inType`     input buffer type: 0 = signed short (16bit integer); 1 = float (32bit floating point)
  ## `inChannels` number of input channels
  ## `inBuf`      input buffer; stereo data will be interleaved in this buffer: LRLR... where LR is a single frame (Left+Right channels)
  ##
  ## `false` for silence (buffer filled with zeroes), `true` if any signal was produced

proc init*(freq:cint = 44100, channels:cint = 2, flags:cuint = 0): Version = sv_init(nil, freq, channels, flags).Version
  ## Initialize the SunVox engine
  ## Be sure to check the returned `Version` in case any error occurred.
  ## Parameters:
  ## `freq`      sample rate (Hz), minimum 44100
  ## `channels`  only 2 supported now
  ## `flags`     mix of initialization flags

proc init*(config:cstring, freq:cint = 44100, channels:cint = 2, flags:cuint = 0): Version = sv_init(config, freq, channels, flags).Version
  ## Initialize the SunVox engine (with config string)
  ## Be sure to check the returned `Version` in case any error occurred.
  ## Parameters:
  ## `config`  string with additional configuration in the following format: "option_name=value|option_name=value";
  ##           example: "buffer=1024|audiodriver=alsa|audiodevice=hw:0,0";
  ##           use null if you agree to the automatic configuration;
  ## `freq`      sample rate (Hz), minimum 44100
  ## `channels`  only 2 supported now
  ## `flags`     mix of initialization flags

proc deinit*(): cint {.importc: "sv_deinit", dynlib:libname, discardable.}

proc openSlot*(slot: cint): cint {.importc: "sv_open_slot", dynlib:libname, discardable.}
  ## A slot is an integer representing a usable instance of the SunVox engine.
  ## For simple usage, you can just do all your work on slot 0.
  ## In which case, openSlot(0) is the first thing you should do after init().

proc closeSlot*(slot: cint): cint {.importc: "sv_close_slot", dynlib:libname, discardable.}
  ## Call this when a slot is no longer needed.

proc lockSlot*(slot: cint): cint {.importc: "sv_lock_slot", dynlib:libname, discardable.}
  ## Lock a slot. Must be called before using any of the following procedures:
  ## `newModule`, `removeModule`, `connectModule`, `disconnectModule`, `patternMute`
  ## Remember to call `unlockSlot()` when you're done.

proc unlockSlot*(slot: cint): cint {.importc: "sv_unlock_slot", dynlib:libname, discardable.}
  ## Call this when you're done making changes (see lockSlot)

proc getSampleType*(): cint {.importc: "sv_get_sample_type", dynlib:libname, discardable.}
  ## Get internal sample type of the SunVox engine. Return value: one of the STYPE_xxx constants.
  ## Use it to get the scope buffer type from getModuleScope()
  ## May not work / not found in sunvox.h

proc load*(slot: cint, name: cstring): cint {.importc: "sv_load", dynlib:libname, discardable.}
  ## Load a song from file path.
  ## Returns 0 on success, negative value on error.

proc loadFromMemory*(slot: cint, data: pointer, dataSize: cuint): cint {.importc: "sv_load_from_memory", dynlib:libname, discardable.}
  ## Load a song from raw data

proc play*(slot: cint): cint {.importc: "sv_play", dynlib:libname, discardable.}
  ## Start or resume song playback

proc playFromBeginning*(slot: cint): cint {.importc: "sv_play_from_beginning", dynlib:libname, discardable.}
  ## Start song playback from the beginning

proc stop*(slot: cint): cint {.importc: "sv_stop", dynlib:libname, discardable.}
  ## Pause song playback.

proc setAutostop*(slot: cint, autostop: bool): cint {.discardable.} = sv_set_autostop(slot, autostop.cint)
  ## When false, song is playing infinitely in a loop.

proc getAutostop*(slot: cint): bool = sv_get_autostop(slot).bool
  ## Check whether autostop is enabled (see `setAutostop`)

proc endOfSong*(slot: cint): bool = sv_end_of_song(slot).bool
  ## Returns false if the song is playing, true if the song has stopped

proc rewind*(slot: cint, lineNum: cint): cint {.importc: "sv_rewind", dynlib:libname, discardable.}
  ## Seek to line number

proc seek*(slot: cint, lineNum: cint): cint {.discardable.} = rewind(slot, line_num)
  ## Seek to line number (alias for `rewind`)

proc volume*(slot: cint, vol: cint): cint {.importc: "sv_volume", dynlib:libname, discardable.}
  ## Set master volume from 0 (min) to 256 (max 100%) inclusive

proc setEventT*(slot: cint, timeSet: cint, t: cint): cint {.importc: "sv_set_event_t", dynlib:libname, discardable.}
  ## Set the time of events to be sent by ``sendEvent()``
  ## Parameters:
  ##  `slot`
  ##  `set`  1 = set; 0 = reset (use automatic time setting - the default mode)
  ##  `t`    the time when the events occurred (in system ticks, SunVox time space).
  ## Examples:
  ## ```
  ##   setEventT( slot, 1, 0 ) //not specified - further events will be processed as quickly as possible
  ##   setEventT( slot, 1, sv_get_ticks() ) //time when the events will be processed = NOW + sound latency * 2
  ## ```

proc sendEvent*(slot: cint, trackNum: cint, note: cint, vel: cint, module: cint, ctl: cint, ctlVal: cint): cint {.importc: "sv_send_event", dynlib:libname, discardable.}
  ## Send some event (note ON, note OFF, controller change, etc.)
  ## Parameters:
  ##  `slot`
  ##  `trackNum`  track number within the pattern
  ##  `note`      0 = nothing;  1..127 = note num;  128 = note off;  129, 130... see NOTECMD_xxx constants
  ##  `vel`       velocity 1..129; 0 - default
  ##  `module`    0 = nothing; 1..255 = module number + 1
  ##  `ctl`       0xCCEE. CC - number of a controller (1..255). EE - effect
  ##  `ctlVal`    value of controller or effect

proc getCurrentLine*(slot: cint): cint {.importc: "sv_get_current_line", dynlib:libname.}
  ## Get current line number

proc getCurrentLine2*(slot: cint): cint {.importc: "sv_get_current_line2", dynlib:libname.}
  ## Get current line number in fixed point format 27.5

proc getCurrentSignalLevel*(slot: cint, channel: cint): cint {.importc: "sv_get_current_signal_level", dynlib:libname.}
  ## From 0 to 255

proc getSongName*(slot: cint): cstring {.importc: "sv_get_song_name", dynlib:libname.}

proc getSongBpm*(slot: cint): cint {.importc: "sv_get_song_bpm", dynlib:libname.}

proc getSongTpl*(slot: cint): cint {.importc: "sv_get_song_tpl", dynlib:libname.}

proc getSongLengthLines*(slot: cint): cuint {.importc: "sv_get_song_length_lines", dynlib:libname.}
  ## Get the project length in lines.

proc getSongLengthFrames*(slot: cint): cuint {.importc: "sv_get_song_length_frames", dynlib:libname.}
  ## Get the project length in frames.
  ## A frame is one discrete of the sound. Sample rate 44100 Hz means you hear 44100 frames per second.

proc getTimeMap*(slot: cint, startLine: cint, len: cint, dest: ptr uint32, flags: cint): cint {.importc: "sv_get_time_map", dynlib:libname, discardable.}
  ## Parameters:
  ##  `slot`
  ##  `startLine` first line to read (usually 0)
  ##  `len`       number of lines to read
  ##  `dest`      pointer to the buffer (size = len*sizeof(uint32_t)) for storing the map values
  ##  `flags`    TIME_MAP_SPEED: dest[X] = BPM | ( TPL << 16 ) (speed at the beginning of line X)
  ##             TIME_MAP_FRAMECNT: dest[X] = frame counter at the beginning of line X
  ## Returns:
  ##   0 if successful, or negative value in case of some error.

proc newModule*(slot: cint, kind: cstring, name: cstring, x, y, z: cint): cint {.importc: "sv_new_module", dynlib:libname, discardable.}
  ## Create a new module in the song
  ## Use with `lockSlot()` and `unlockSlot()`!

proc removeModule*(slot: cint, modNum: cint): cint {.importc: "sv_remove_module", dynlib:libname, discardable.}
  ## Remove selected module
  ## Use with `lockSlot()` and `unlockSlot()`!

proc connectModule*(slot: cint, source: cint, destination: cint): cint {.importc: "sv_connect_module", dynlib:libname, discardable.}
  ## Connect the source to the destination
  ## Use with `lockSlot()` and `unlockSlot()`!

proc disconnectModule*(slot: cint, source: cint, destination: cint): cint {.importc: "sv_disconnect_module", dynlib:libname, discardable.}
  ## Disconnect the source from the destination
  ## Use with `lockSlot()` and `unlockSlot()`!

proc loadModule*(slot: cint, fileName: cstring, x, y, z: cint): cint {.importc: "sv_load_module", dynlib:libname, discardable.}
  ## Load a module or sample.
  ## Supported file formats: sunsynth, xi, wav, aiff
  ## Returns: New module number, or negative value in case of some error.

proc loadModuleFromMemory*(slot: cint, data: pointer, dataSize: cuint, x, y, z: cint): cint {.importc: "sv_load_module_from_memory", dynlib:libname, discardable.}
  ## Load a module or sample from memory.

proc samplerLoad*(slot: cint, samplerModule: cint, fileName: cstring, sampleSlot: cint): cint {.importc: "sv_sampler_load", dynlib:libname, discardable.}
  ## Load a sample into an already created sampler.
  ## If you want to replace the whole sampler, set `sample_slot` to -1

proc samplerLoadFromMemory*(slot: cint, samplerModule: cint, data: pointer, dataSize: cuint, sampleSlot: cint): cint {.importc: "sv_sampler_load_from_memory", dynlib:libname, discardable.}
  ## Load a sample from memory into an already created sampler.
  ## If you want to replace the whole sampler, set `sample_slot` to -1

proc getNumberOfModules*(slot: cint): cint {.importc: "sv_get_number_of_modules", dynlib:libname.}
  ## Get the number of modules in the song.

proc findModule*(slot: cint, name: cstring): cint {.importc: "sv_find_module", dynlib:libname.}
  ## sv_find_module() - find a module by name;
  ## return value: module number or -1 (if not found);

proc getModuleFlags*(slot: cint, modNum: cint): ModuleFlags {.importc: "sv_get_module_flags", dynlib:libname.}
  ## Retrieve flags (is active, is effect, number of inputs/outputs) for a module.

proc getModuleInputs*(slot: cint, modNum: cint): ptr UncheckedArray[cint] {.importc: "sv_get_module_inputs", dynlib:libname.}
  ## Get pointer to the int array of input links.
  ## Use `getModuleFlags().inputs` to get the length of the array.

proc getModuleOutputs*(slot: cint, modNum: cint): ptr UncheckedArray[cint] {.importc: "sv_get_module_outputs", dynlib:libname.}
  ## Get pointer to the int array of output links.
  ## Use `getModuleFlags().outputs` to get the length of the array.

proc getModuleName*(slot: cint, modNum: cint): cstring {.importc: "sv_get_module_name", dynlib:libname.}

proc getModuleXY*(slot: cint, modNum: cint): tuple[x, y: int] =
  ## Get module XY coordinates.
  ## Normal working area: 0x0..1024x1024
  ## Center: 512x512
  var xy = sv_get_module_xy(slot, modNum)
  result.x = (xy and 0xffff).int
  if (result.x and 0x8000) != 0: result.x -= 0x10000
  result.y = ((xy shr 16) and 0xffff).int
  if (result.y and 0x8000) != 0: result.y -= 0x10000

proc getModuleColor*(slot: cint, modNum: cint): cint {.importc: "sv_get_module_color", dynlib:libname.}
  ## Get module color in the following format: 0xBBGGRR

proc getModuleFinetune*(slot: cint, modNum: cint): tuple[finetune, relativeNote: int] =
  ## Get the relative note and finetune of the module
  var in_finetune = sv_get_module_finetune(slot, modNum)
  result.finetune = (in_finetune and 0xFFFF).int
  if (result.finetune and 0x8000) != 0: result.finetune -= 0x10000
  result.relativeNote = ((in_finetune shr 16) and 0xffff).int
  if (result.relativeNote and 0x8000) != 0: result.relativeNote -= 0x10000

proc getModuleScope*(slot: cint, modNum: cint, channel: cint, bufferOffset: ptr cint, bufferSize: ptr cint): pointer {.importc: "sv_get_module_scope", dynlib:libname.}

proc getModuleScope2*(slot: cint, modNum: cint, channel: cint, destBuf: ptr cshort, samplesToRead: cuint): cuint {.importc: "sv_get_module_scope2", dynlib:libname.}
  ## Return value = received number of samples (may be less than or equal to `samplesToRead`)

proc moduleCurve*(slot: cint, modNum: cint, curveNum: cint, data: ptr cfloat, len: cint, w: cint): cint {.importc: "sv_module_curve", dynlib:libname, discardable .}
  ## Access to the curve values of the specified module
  ##   Parameters:
  ##     slot;
  ##     mod_num - module number;
  ##     curve_num - curve number;
  ##     data - destination or source buffer;
  ##     len - number of items to read/write;
  ##     w - read (0) or write (1).
  ##   return value: number of items processed successfully.
  ##
  ##   Available curves (Y=CURVE[X]):
  ##     MultiSynth:
  ##       0 - X = note (0..127); Y = velocity (0..1); 128 items;
  ##       1 - X = velocity (0..256); Y = velocity (0..1); 257 items;
  ##     WaveShaper:
  ##       0 - X = input (0..255); Y = output (0..1); 256 items;
  ##     MultiCtl:
  ##       0 - X = input (0..256); Y = output (0..1); 257 items;
  ##     Analog Generator, Generator:
  ##       0 - X = drawn waveform sample number (0..31); Y = volume (-1..1); 32 items;


proc getNumberOfModuleCtls*(slot: cint, modNum: cint): cint {.importc: "sv_get_number_of_module_ctls", dynlib:libname.}

proc getModuleCtlName*(slot: cint, modNum: cint, ctlNum: cint): cstring {.importc: "sv_get_module_ctl_name", dynlib:libname.}

proc getModuleCtlValue*(slot: cint, modNum: cint, ctlNum: cint, scaled: cint): cint {.importc: "sv_get_module_ctl_value", dynlib:libname.}

proc getNumberOfPatterns*(slot: cint): cint {.importc: "sv_get_number_of_patterns", dynlib:libname.}

proc findPattern*(slot: cint, name: cstring ): cint {.importc: "sv_find_pattern", dynlib:libname.}
  ## find a pattern by name
  ## return value: pattern number or -1 (if not found);

proc getPatternX*(slot: cint, patNum: cint): cint {.importc: "sv_get_pattern_x", dynlib:libname.}

proc getPatternY*(slot: cint, patNum: cint): cint {.importc: "sv_get_pattern_y", dynlib:libname.}

proc getPatternTracks*(slot: cint, patNum: cint): cint {.importc: "sv_get_pattern_tracks", dynlib:libname.}

proc getPatternLines*(slot: cint, patNum: cint): cint {.importc: "sv_get_pattern_lines", dynlib:libname.}

proc getPatternName*(slot: cint, patNum: cint): cstring {.importc: "sv_get_pattern_name", dynlib:libname.}

proc getPatternData*(slot: cint, patNum: cint): ptr UncheckedArray[Note] {.importc: "sv_get_pattern_data", dynlib:libname.}
  ## Get the pattern buffer for reading and writing
  ## containing notes (events) in the following order:
  ## line 0: note for track 0, note for track 1, ... note for track X;
  ## line 1: note for track 0, note for track 1, ... note for track X;
  ## ...
  ## line X: ...
  ##
  ## Be sure to use the values returned by `getPatternTracks()` and `getPatternLines()`
  ##  to make sure you don't read outside the bounds of the pattern.
  ##
  ## Example of use:
  ## ```
  ##    let numTracks = getPatternTracks(slot, pattern)
  ##    let data = getPatternData(slot, pattern)
  ##    let note = data[line * numTracks + track]
  ##    # ... and then do something with note
  ## ```

proc patternMute*(slot: cint, patNum: cint, mute: cint): cint {.importc: "sv_pattern_mute", dynlib:libname, discardable.}
  ## Use with `lockSlot()` and `unlockSlot()`!

proc getTicks*(): cuint {.importc: "sv_get_ticks", dynlib:libname.}
  ## SunVox engine uses its own time space, measured in system ticks (don't confuse it with the project ticks).
  ## This is required when calculating the outTime parameter in calls to audioCallback()
  ## Returns the current tick counter (from 0 to 0xFFFFFFFF).

proc getTicksPerSecond*(): cuint {.importc: "sv_get_ticks_per_second", dynlib:libname.}
  ## Get the number of SunVox ticks per second.

proc getLog*(size: cint): cstring {.importc: "sv_get_log", dynlib:libname.}
  ## Get the latest messages from the log
  ## `size`  max number of bytes to read
  ## Returns a pointer to the null-terminated string with the latest log messages.
