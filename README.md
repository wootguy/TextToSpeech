# Text to speech

please install on all servers

[![Demo Video](https://img.youtube.com/vi/wkiSr_Rj1IU/0.jpg)](https://www.youtube.com/watch?v=wkiSr_Rj1IU)

# Voices:
- Morgan Freeman
- "Macho Man" Randy Savage
- Turret from Portal
- Moonbase Alpha
- HL Grunt
- w00tguy
- Keen


# Chat/Console Commands:
`.tts` = show help  
`.tts voice` = choose a voice  
`.tts pitch X` = set voice pitch (where X = 1-255)  
`.tts vol X` = set global speech volume (where X = 0-100)


# CVars:
```
as_command tts.disabled 0
as_command tts.spam_length 0
as_command tts.spam_delay 0
```
`tts.disabled` disables speech if set to 1.
`tts.spam_length` sets a time limit (in seconds) for messages. Longer messages will be cut off. 0 = no limit.
`tts.spam_delay` sets the time (in seconds) before a user can speak another message (timer starts after their last message finishes).


# Server Impact:
When the plugin is first loaded, the dictionary file needs to be parsed for word pronunciations. During this time, the **CPU will be working harder than normal and will likely lower the framerate of the server**. After this load finishes (about 20-60 seconds), the plugin will be light on resources. The dictionary is **only loaded once**, not every map change. You can adjust how many words are loaded per frame at line 322 in TextToSpeech.as. Lower number = better framerate during load, but the load lasts longer.

With players quickly spamming long lines of nonsense, net usage will stay relatively low (nothing like if there were a lot of monsters in one area). CPU usage will also be low since playing sounds isn't a complex task. No entities are created by the plugin.

The number of precached sounds = 38 * number of voices (266 by default). This shouldn't be a problem since SC 5.0 has 8192 precache slots and most maps are designed to run with less than 512.

# Installation
1) Extract the folders to svencoop_addon (or wherever you prefer)

2) Add this to svencoop/default_plugins.txt to enable the plugin:
```
  "plugin"
  {
    "name" "TextToSpeech"
    "script" "tts/TextToSpeech"
    "concommandns" "tts"
  }
```

This plugin should be as far toward the end of your plugin list as possible.
If it is too high, you will hear speech for other plugin commands.
If you don't hear any sounds, move it up in the list and try again.
Some plugins can prevent others lower in the list
from using chat commands.


# Adding your own voice:
1) Make a new folder in sound/texttospeech/
2) Read the "Phoneme Set" section on [this site](http://www.speech.cs.cmu.edu/cgi-bin/cmudict#phones) to get an idea of what each file should sound like.
3) Record all 38 phonemes. Alternatively, rip them from some interview (I ripped Morgan's voice [from here](https://www.youtube.com/watch?v=eoKea_49v3I)).
4) Open up TextToSpeech.as and add an entry to the voice list (top of the file). Whatever is first in this list will be the default voice for new players.

