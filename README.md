Attempting to improve the concorde for flightgear.

UPDATE JANUARY 2015: THE DEVELOPMENT OF THIS AIRCRAFT HAS CONTINUED OVER TO ISLANDMONKEY
========================================================================================

INSTALLING
==========

Move the aircraft into any aircraft folder (It no longer has to be $FG_ROOT/Aircraft), and rename it "Concorde". It has to be the only aircraft named "Concorde".

KNOWN BUGS
==========

My instruments don't honour the serviceable flag yet (no fail flags).

Autopilot was ~~recently~~ scrapped and rewritten, godarklight probably had a few bugs that he didn't catch yet.

The standby airspeed indicator mach part is not animated.

If you find any bugs don't be afraid to email me. I don't bite :)

The more everyone tests and finds bugs, the more I can fix them and the better this will be when (if?) it gets into ~~FGDATA~~ FGAddon.

FUTURE PLANS
============

Replace every 2D panel with a 3D one.

Retexture the instrument frames with an actual texture. It will make it look better than the solid blue.

~~Port to rembrandt but remain compatible with the default renderer. Fly the 777 at night, you will see why I want to.~~ UPDATE JAN 2015: This is not going to occur. The dev for rembrandt is inactive and the renderer is one slow, unoptimised thing.

Further tuning of the autopilot until it kicks every other planes AP out of the sky.

Rewrite electrical system - On my computer it causes 20ms of lag every 3 seconds (it jitters).

When I am finished and believe it is complete ~~(maybe August 2013?)~~ (whenever it is ready), I will look at getting this into ~~FGDATA~~ FGAddon for everyone.


CONTACT
=======
I love hearing about bugs / issues. If there is anything you notice please email/skype me.

Email: islandmonkeee@gmail.com or godarklight@gmail.com (inactive from flightgear)
Skype: godarklight (inactive)
Forum thread: http://www.flightgear.org/forums/viewtopic.php?f=14&t=19824

This is the first aircraft that godarklight worked on. He had to learn blender, flightgear's XML, and nasal all because a (pretty) aircraft that hasn't flown for years. If you are an aircraft developer and you can see that I'm "doing it wrong", please give me pointers, Otherwise I will continue slowly and surely along from where godarklight finished.

I'm improving the concorde because I want to. ~~This might explain it: http://mpserver15.flightgear.org/modules/fgtracker/?FUNCT=FLIGHTS&CALLSIGN=DARK-L (Looks like the tracker had it's time reset, but effective flight time is accurate)~~


I have been unable to contact the aircraft developer who is anonymous or unknown. If the author does read this, I'm interested in becoming a maintainer after I have finished it. I haven't added myself to the authors because I believe it is still "Unknown's" plane. Maybe I'll add it in after I finish replacing the panels :)

GIT INFO
========

Updating:
Using any git client, just do a "git pull". You will receive any updates I have pushed.

Master branch:
This is the branch I recommend for most people, If I do an update that does not break anything, it gets merged into master straight away.

Devel branch:
If I don't break anything, this branch is kept in sync with master. If I do break things (on purpose, like a rewrite of the AP/Elec/Fuel system) this branch is updated and master is kept back. You are free to use this branch, but expect things to go wrong sometimes.
