# World of Warcraft 1.12.1 Addons
A collection of addons for the World of Warcraft 1.12.1 client and game.  These addons were mostly written by request or for personal use, and are therefore lacking polish and features.  

With the release of WoW Classic, the 1.12.1 client has fallen out of popularity and there is little motivation to continue adding functionality.  However, if there is a need for a fix or improvement contact me and I may look into it.

## EZDI
World of Warcraft 1.12.1 Addon for requesting spells through whispers.  Primary use case is forcing a player to cast a critical reactive spell on command, such as Blessing of Protection or Divine Intervention.

### Usage
Add ```/script EZDI:CastNext();``` at the start of a macro on the target character. Upon activation, it will attempt to perform the next queued action.

Whisper a spell name to queue it for casting. 
```/t paladin Blessing of Protection```
```/t paladin bop```

To cast on a target by name, whisper Spell>Target. (no spaces around >)
```/t paladin di>name```

Offensive spells cast on allies will cast on ally's target.

Queries:
* !queue / !q - Get number of spells in queue
* !cooldown / !cd Spell - Get cooldown of spell
* !pp / !buff - Get currently assigned paladin buff
* !use itemName / !item itemName - Use an inventory item by name
* !clear - Clear all queued spells
* !help / !usage - Help message

## IgniteMonitor
Tracks current Ignite damage, stacks, duration, and total damage for all targets in range. Displays stacks of related debuffs such as Scorch, Curse of Elements, and Nightfall.  Also attempts to predict which players and spells built the ignite for determining individual mage contributions.  

For accurate tracking, make sure combat log range is large enough that it captures all spells by other mages.  Due to limitations in the 1.12.1 client, it is not possible to differentiate between targets with the same name.

Click to toggle stack prediction window.

Commands
* ```/im hide``` - hide window
* ```/im show``` - show window

## FFat20
Tracks and displays the player's Faerie Fire duration on each target.  Not guranteed to be completely accurate due to limitations of the 1.12.1 client.

### Usage:

Replace your existing Faerie Fire or Feral Fire button with a macro containing:
```
/script FF:CastFF()
```
or
```
/script FF:FF()
```
Casts Faerie Fire on the current target, shifting to caster form if needed.  If Faerie Fire(Feral) is available in the current form & talents that will be cast instead.  

If an ally is targetted, it will chain through target of target and cast on the first enemy found, up to a default maximum of 3 hops.

* /ff hide - hide bars
* /ff show - show bars
* /ff lock - lock bars in place
* /ff unlock - unlock bars for movement
* /ff chain number - set the maximum number of target of target chaining when casting FF

## ConsumeBar
Adds an additional bar for consumables.  Similar to TrinketMenu/ItemRack but for inventory items.  

### Usage:
Mouse over a button to select from all available consumes.

Keybinds can be set from the standard keybind menu.  

Move by holding ctrl.  

#### Commands
* Add a new empty button to bar
```/cb add```

* Add a new button to bar
```/cb add itemname```

* Remove last button
```/cb remove```

* Remove button for target item
```/cb remove itemname```

* Hide bar
```/cb hide```

* Show bar
```/cb show```

* Lock bar
```/cb lock```

* Unlock bar
```/cb unlock```


## ItemScripts
Macro functions for using items.

Search inventory for itemName and use if found.
```UseItem(itemName)```

Search inventory for each item in itemPrioList in order.  If an item is not found, search for the next until an item is used.
```UseFirst(itemPrioList)```

## TargetPercent
Adds a percent indicator to the default target frame.

## Util
Misc functions.  Adds short print() function.
