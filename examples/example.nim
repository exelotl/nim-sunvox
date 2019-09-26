import sunvox

let ver = init()

if ver.error:
  echo "SunVox init error: ", ver
  quit(1)
  
echo "SunVox lib version: ", ver

# A slot represents an instance of the SunVox engine
const slot = 0
openSlot(slot)

# Yeah I made this, under my old handle :)
load(slot, "geckojsc - Frosty Falls.sunvox")

# If we don't rewind, the song will play from the cursor position when it was last saved
rewind(slot, 0)
play(slot)

# Let's print some info about a note in a pattern (but this API is rather unsafe so we need to do some checks first)
const pattern = 0
const col = 3
const row = 0

let numPatterns = getNumberOfPatterns(slot)
doAssert(pattern < numPatterns, "No such pattern " & $pattern)

let numTracks = getPatternTracks(slot, pattern)
let numLines = getPatternLines(slot, pattern)
doAssert(col < numTracks, "Track out of bounds")
doAssert(row < numLines, "Line out of bounds")

let notes = getPatternData(slot, pattern)
echo notes[row * numTracks + col]

echo "Press any key to quit..."
discard stdin.readChar()

# Stop the song and clean up:
stop(slot)
closeSlot(slot)
deinit()
