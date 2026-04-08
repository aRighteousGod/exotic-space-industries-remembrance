# Tesla's Legacy (Electric Turrets) [SA]

This is the 'Space Age' (SA for short) dependent version of my [original mod](https://mods.factorio.com/mod/tesla_legacy) . If you are not using SA, please use the [original mod](https://mods.factorio.com/mod/tesla_legacy).

## Features
This mod provides 2 new electric turrets and a new tank variant with many new technologies.

* ***Tesla coil***
> A Tesla coil is an electrical resonant transformer modified to deliver high-current electrical discharges to close by enemies. It has a relatively low damage output but it can effect multiple targets at once.

Tesla coils have the capability to **slow down enemies** and can **attack multiple enemies** at once in a circular radius. All attacks made by the Tesla coil have a **chance to propagate** to nearby enemies. This capability becomes stronger the more biters are clogged together and remains useful even in mid and late game. Its energy consumption is lower than a laser and it is available sooner, but its range and damage is limited.

* ***Advanced Tesla coil***
> A significantly improved version of the Tesla coil. Its reach is larger and its damage output is extremely high. It has an extensive steel plating for increased survivability.

The advanced Tesla coil consumes more electricity than a laser turret and has a considerably slower rate of fire. Its damage per shot is much higher however. Each killing blow made by an Advanced Tesla coil has a **chance to** induce and **explosion or burn** the ground. Some **nearby enemies may also be struck** by additional lightning arcs as well.

* ***Tesla tank***
> A deadly new tank variant equipped with 2 medium sized Advanced Tesla coil. Single use Portable Tesla coils provide the necessary energy surge to trigger the firing mechanism. This tank takes advantage of the natural volatile nature of electric currents as beam weapons, by employing a special amplification process. The installed coils fire at the same time, but instead of interfering they are synergizing with each other. As a result the created lightning arcs easily bypass most matter damaging anything and everything in its path.

The Tesla tank has slightly more health than a standard tank. It fires deadly arcs of electricity that **bypass** all enemies in a line. It has the same special properties that a Tesla coil has and more. It can modulate its own damage potential and even **insta kill** some enemies regardless of remaining health. It also has a moderately sized equipment grid.

### Electric Volatility
All electric damage done by tesla coil technology is **highly volatile** in nature. This means that each attack has a small chance to become a **critical hit**. When a normal hit becomes a critical hit, its damage gets multiplied by a critical multiplier. In such cases a **flying text** is also displayed.

### Configuration
The following attributes of the above entities are configurable:

* **Maximum Health**
The health of the entity when it is fully healed.
* **Damage**
The damage the entity does.
* **Fire Rate**
The number of time the entity shoot per second (per 60 frames)
* **Maximum range**
The distance measured in game tiles which allows the entity to attack enemies.

Furthermore the general **critical hit damage** and **chance** is also configurable as well as some **aesthetic choice** for **flying texts** and for the **Advanced Tesla coil** specifically.

## Compatibility
This mod is adding new recipes, items, technologies and entities. It does not change an already existing game objects. It should be compatible with everything. At this moment there are no known incompatibilities.

## Alternate Mods
The original mods that were the basis of this mod are available and can be used together with this mod:

* [Tesla Tank](https://mods.factorio.com/mod/TeslaTank)
The tank featured in [Tesla tank](https://mods.factorio.com/mod/TeslaTank) is also added by this mod however it has a different strategic role. The original design was very cool and extremely fun to play with however it was a bit OP (IMHO).
* [Soviet Tesla Coils](https://mods.factorio.com/mod/Soviet-Tesla-Coils)
The Tesla coils featured in  [Soviet Tesla Coils](https://mods.factorio.com/mod/Soviet-Tesla-Coils) are integrated into this mod. The basic stats of the turret was modified and a bunch of new abilities have been added. This mod also provides some minor cosmetic enhancement over its predecessor, like glowing electricity in the dark and branch new beam graphics.
* [Past's Defense stuff](https://mods.factorio.com/mod/pasts-defense-stuff)
The Tesla coils featured in [Past's Defense stuff](https://mods.factorio.com/mod/pasts-defense-stuff) are integrated to this mod. Their behavior has been extended with new abilities. Other content from [Past's Defense stuff](https://mods.factorio.com/mod/pasts-defense-stuff) like the shotgun turret are not included in this mod.

Additionally the mod [Electric Weapons](https://mods.factorio.com/mod/Electric-Weapons) (EW for short) covers similar ground as this mod. It also has new turrets that use electricity both as ammo and damage type. It also covers personal weaponry which this mod currently does not. This is however the end of the similarities.
This mod has a particular theme built up around Tesla coils, while EW has more generic electric turrets. The used graphics are entirely different and the gameplay can also hugely vary between the two mods. EW plays somewhat similar to other weaponry mods, whene you can unlock specialized ammunition and weapons to unlock a new damage type. This mod attempts to differentiate itself by utilizing an RPG like skill/tech tree where powerful new abilities and effects can be unlocked for your apparatus. Key point of this mod's design was NOT to provide a more powerful 'no-brainer' alternative for anything, but to provide a fun new tool/toy to play with.

## Background
I always loved the C&C and Red Alert series. Who didn't? The [Soviet Tesla Coils](https://mods.factorio.com/mod/Soviet-Tesla-Coils) in particular was always my favourite defensive building. When I first realized that they are available as a mod for Factorio, I immediately downloaded them. I shortly after noticed that the legendary [Tesla Tank](https://mods.factorio.com/mod/TeslaTank) is also available as a mod. I have played with both of these mods for quite a while and I thoroughly enjoyed both of them.

One thing which always bothered me somewhat is the fact that the Tesla coil's beam was too straight. The beam of the Tesla tank was much better, however that beast of a tank was nigh indestructible. Nothing could come to its proximity without being shocked to death. 

I was looking for other Tesla coil mods when I came across [Past's Defense stuff](https://mods.factorio.com/mod/pasts-defense-stuff). I really liked the idea of a relatively early Tesla coil and grow quite fond of the simple but very immersive implementation. 

However, as always the case, I was not satisfied with the integration of these 3 mods, or the lack thereof. I also yearned for deep gameplay elements that make tesla coils distinctive. I did not want to have a 'blue-laser' but a completely distinct military application with its own pros and cons.

I have sink my teeth into the source code of these great mods, and started working. Hours became days, days became weeks. Before I knew it, the mod has almost outgrown me. new features upon new features. Ideas in, ideas out. What started out as a coding adventure quickly became a full on design/effect endeavour, trying to piece together pre existing graphics and sound. And don't even get me started on animation. It was a real battle to settle with something which at the end is quite close to what fulfils my initial expectations. 

### Performance
To avoid scripting this mod creates quite a few prototypes  (hundreds? thousands? who counts!). This can increase the load time of the game by a few seconds. I could not fully avoid however the scripting to achieve the desired effects, so a little bit of runtime performance is also impacted. Generally speaking the more enemies are attacking the higher the performance cost. However when all affected enemy is killed the mod has nearly zero footprint.
You may encounter problems IF you are literally *constantly* fighting thousands of biters nonstop.

### Credit
- Thanks to [PastTheFuture](https://mods.factorio.com/user/PastTheFuture) for [Past's Defense stuff](https://mods.factorio.com/mod/pasts-defense-stuff)
- Thanks to [Gouitsu](https://mods.factorio.com/user/Gouitsu) for [Soviet Tesla Coils](https://mods.factorio.com/mod/Soviet-Tesla-Coils)
- Thanks to [Sacredanarchy](https://mods.factorio.com/user/Sacredanarchy) for [Tesla Tank](https://mods.factorio.com/mod/TeslaTank)

Full list of credits can be found in the CREDITS.txt inside the package. 
