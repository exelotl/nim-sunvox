sunvox
======

This repo contains Nim bindings for the SunVox shared library / DLL - v1.9.5d

[SunVox](https://www.warmplace.ru/soft/sunvox/) is a powerful freeware cross-platform modular synthesizer and sequencer.

I made these bindings because I think the SunVox engine could be a really great way to add dynamic music and sfx to games, and would generally make a great foundation for a lot of audio-related projects.


### Installation

Get the bindings via Nimble:
```
nimble install sunvox
```

Download the 'SunVox library for developers' from the [SunVox homepage](https://www.warmplace.ru/soft/sunvox/).

Extract the shared library for your platform and make sure your programs can access it. On Windows, that means copying `sunvox.dll` into the same folder as your final executable.

You can try running the example in this repo with `nim c -r example.nim`

Enjoy!
