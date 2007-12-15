Concorde real data
==================
Weight :
    max taxing       : 412000 lb.
    max take off     : 408000 lb.
    max landing      : 245000 lb.
    zero fuel        : 203000 lb.
    operating empty  : 173500 lb.
    max payload      :  29500 lb.

Speeds :
    Max at 51300 ft                              : Mach 2.2 (F).
    Optimum at 51300 ft                          : Mach 2.04 (F).
    V max for jettison (fuel)                    : Mach 0.93.
    V max for windscreen wiper operation         : 325 kt.
    V visor down or operating                    : 325 kt.
    V nose 5 or operating between UP and 5       : 325 kt.
    Vla above 41000 ft (lowest autorized)        : 300 kt.
    V nose DOWN or operating between 5 and DOWN  : 270 kt (at altitudes below 20000 ft).
    V landing lights                             : 270 kt.
    Vlo (landing gear operation)                 : 270 kt.
    Vle (landing gear extended)                  : 270 kt.
    Vla 15000/41000 ft                           : 250 kt.
    Vla below 15000 ft                           : VREF or V2 or V3.
    Vmc (minimum control speed with engine inoperative)
    Vmcl (approach)                              : 150 kt.
    Vmc (takeoff)                                : 132 kt.
    Vmcg (ground)                                : 116 kt.

Procedures :
    Takeoff (408000 lb) : nose 5°, afterburner, V1 165 kt, VR 195 kt, pitch 13.5° at rotation,
                          V2 220 kt.
    Subsonic cruise : Mach 0.95.
    Acceleration : afterburner at Mach 0.93; air intakes starts closing at Mach 1.3;
                   stop afterburner at Mach 1.7.
    Supersonic cruise : Mach 2.0 at FL500.
    Supersonic descent : decelerate at 350 kt, 250 NM before the subsonic level.
    Landing (245000 lb) : nose 12.5°, VREF 162 kt, pitch 10° at touch down.
    Taxi : nose 5°, only 2 engines (B).
    Parking : nose and visor up, as weather seal (A1).

Runway : 11200 ft takeoff, 7300 ft landing (C).
Max climb rate : 5000 ft/min at sea level (F).
Range :
    3550 nm supersonic, 2760 nm subsonic (Mach 0.95 FL300) (C).
    6582 km [3550 nm] with FAR fuel reserves and payload of 19500 lb (F).
    6228 km [3360 nm] with FAR fuel reserves and maximum payload (F).
Duration : Paris / New York 3h45 (D), London Heathrow / New York 3h50 (E).
Maximum operating altitude : 60000 ft (C).
Maximum total temperature (TMO) : 127°C on nose.


Concorde ops
============
Takeoff
-------
- the visor is raised not long after takeoff, to make cockpit quieter (A1).
- the visor protects the windscreen from the 125°C temperature at Mach 2 (A1).

Subsonic cruise
---------------
- Mach 0.93 at FL250, or Mach 0.95 at FL260 (full load) (B).

Supersonic climb
----------------
- start afterburner with VS at 3500 ft/minute; then progressively decrease until 700 ft/minute.
- at Mach 1.1, drag starts to decrease : prepare to increase the climb rate.
- stay inside the corridor of Mach/center of gravity. Below the minimum means a too high altitude
  for the current Mach speed : accelerate by reducing climb speed.
- at Mach 1.3, air intakes open progressively, providing additional thrust : prepare to increase
  the climb rate.
- climb from Mach 0.95 (28000 ft) to Mach 1.7 (47000 ft) lasts 10 minutes (A2).

Supersonic cruise
-----------------
- from London-Heathrow, Mach 2 is reached 40 minutes - 650 NM (Bristol Channel) - after takeoff (A3).
- cruise at Mach 2 consumes 20.5 tons/hour (E).
- transatlantic flight at Mach 2 lasts 2 hours; 2h35 above Mach 1 (A4).
- at FL500 Mach 2, slow climb rate of 50-60 ft/minute, to reduce fuel consumption (A3).

Supersonic descent
------------------
- decelerate speed until 325-380 kt before starting the descent (B).
- deceleration is started at 250 NM : 165 NM from Mach 2.0 FL580 to Mach 1.0 at FL350 (A3).
- maintain the 50 ft climb rate to accelerate the deceleration.
- maintain the 325-380 kt speed during the descent.

Landing
-------
- approach speed : 190 kt (A1).
- at 750 ft AGL, disable autopilot and autothrottle, keep the trim of the glide slope mode;
  maintain pitch at 10 degrees, control descent rate with speed (throttle).
- the tail wheel protects the reversers from hitting the ground (A1).
- avoid autoland by gusty wind.


Installation
============
A mouse with 3rd (middle) button, or its emulation (left + right button), is required.

Fuel load
---------
- default is maximum landing weight, 245000 lb (19000 kg fuel).
- for alternate load, press "ctrl-I f" (saved on exit in aircraft-data).

Sounds
------
- see Sounds/Concorde-real-sound.xml to install real Concorde sounds.
- voice callouts requires Festival (festival --server in a separate shell),
  set /sim/sound/voices/enabled to true; to see the text of callouts, press "shift-ctrl-R"
  (saved on exit in aircraft-data). 

Frame rate
----------
The number of instruments is :
- optimized for a view at 55 degrees.
- minimum straight forwards the Captain heading (landing) : press "shift up arrow"
  to align the view.

Not essential panels can be put in comments in Models/Concorde_ba.xml :
electric, hydraulic, pressurization, air bleed, temperature.

Known compatibility
-------------------
- 0.9.11 : minimal version.


Keyboard
========
- "ctrl-D" : "D"isconnects the autopilot (button A/P DISC on the yoke).
- "ctrl-F" : a"F"terburner.
- "f"      : "f"ull cockpit (all instruments).
- "q"      : "q"uit speed up.

Views
-----
- "ctrl-E" : "E"ngineer view.
- "ctrl-J" : Copilot view.
- "ctrl-K" : Observer view (floating).
- "ctrl-O" : "O"verhead view.
- "ctrl-W" : Ste"W"ard view.
- "shift-ctrl-X" : restore floating view.

Virtual crew
------------
- "shift-ctrl-R" : show c"R"ew text.
- "ctrl-Z" : virtual crew.

Unchanged behaviour
-------------------
- "left / right : changes autopilot heading.
- "x / X"  : zooms in the small fonts; reset with "ctrl-X".

Same behaviour
--------------
- "b / B"  : parking brake.
- "g / G"  : gear.
- "s"      : swaps between Captain and Center 2D panels.
- "ctrl-A" : "A"ltitude acquire.
- "ctrl-G" : "G"lide slope.
- "ctrl-N" : "N"av 1 hold.
- "ctrl-P" : "P"itch hold.
- "ctrl-R" : "R"adio frequencies.
- "ctrl-S" : autothrottle.

Improved behaviour
------------------
- "a / A" : speeds up BOTH speed and time. Until X 5 subsonic, X 7 supersonic;
            automatically resets to 1, when above 3500 ft/min.
- "ctrl-H" : "H"eading hold.
- "page up / page down" : increases / decreases speed hold, Mach hold.
- "up / down"  : increases / decreases (fast) altitude hold, vertical speed hold, pitch hold,
                 speed hold with pitch, Mach hold with pitch.
- "home / end" : increases / decreases (slow) altitude hold, vertical speed hold, pitch hold,
                 speed hold with pitch, Mach hold with pitch.

Alternate behaviour
-------------------
- "ctrl-B" : reverse thrust used as speedbrake (FDM not implemented).
- "ctrl-I" : menu.
- "ctrl-T" : altitude hold.
- "[ / ]"  : nose used as flaps.
- "left / right" : move floating view in width.
- "up / down"  : move floating view in length.
- "home / end" : move floating view in length (fast).
- "page up / page down" : move floating view in height.


Mouse
=====
The 3rd button of mouse :
- pushes a button, when 1st button turns it. Example : track / heading.
- toggles a less used 3rd state. Example : gear neutral, emergency switch.

Autopilot
---------
- before pressing "TH" (track/heading), select "HDG" magnetic heading, or "TRK" true heading,
  with mouse 3rd button.
- "HH" (heading hold) is always magnetic.
- "CL" (max climb) sets the autothrottle to VMO (MMO above 50200 ft), and holds pitch.
- "AA" (altitude acquire) works by capture : the target altitude is reached by another
   altitude mode, "CL", "PH" or "VS".
- see Panels/Concorde-autopilot.xml (list of all buttons).

Electrical
----------
- autopilots and a few instruments depend of a particular ACC ESS BUS.

Engine
------
- to start an engine, activate the starter, before opening the HP VALVE (overhead).
  The starter requires air bleed, either from the ground service (open 1 cross bleed valve),
  or by its adjacent running engine (open 2 cross bleed valve).
  The starter is not required in flight (relight), if enough speed.
- the 1st engine start requires AC voltage, either from the ground service (steward view),
  or in flight (4 engines flame out) by the emergency generator :
  * activate the virtual copilot.
  * deploy the RAM Air Turbine : standby instruments work.
  * most other instruments also work, if the emergency generator has automatically started.
  * with the emergency relight busbar (below the starters), select the 1st engine to start.
  * relight this engine, before opening its HP VALVE (overhead).
  * once this engine started, restore the relight selector to off.
  * start the 3 other engines normally.

Fuel
----
Use virtual engineer (or to 2D panel) to start :
- the collector tanks 1 2 3 4 feed respectively engines 1 2 3 4.
- the main tanks 5 7 feed the collector tanks.

Hydraulics
----------
- nose, gear, brakes depend of green (up only) and yellow circuits.
- ground pumps require ground electrical power.

Radio
-----
- only "ctrl-R" or "ctrl-I r" : NAV 0 (default radio menu) is reserved for interface with autopilot.


2D panel
========
The 2D Panel has simplified buttons for :
- fuel transfers (inlet valves are automatically opened).
- engine start (voltage and air bleed are not required).

Fuel
----
- "Aft" transfers forwards trim tanks (9, 10) to aft trim tanks (11).
  "Forward" does the reverse transfer (only to 9).
- "Engine" transfers trim tanks to the main tanks (5, 7) : choose the direction "Aft" or "Forw".
- the transfert valve feeds a main tank (5, 7) by its auxilliary tank (5A, 7A);
- "Jettison" (2 buttons for confirmation) dumps the trim (9, 10, 11) and collector tanks
  (1, 2, 3, 4) : isolate a trim tank by stopping its fuel pumps. 
- activate "Cross", to balance the dissymetrical tanks.


Virtual crew
============
- to enable only 1 crew member, press "ctrl-I c".
- the virtual crew is independent of the voice callouts.
- a green crew member is performing his checklist.
- a yellow crew member is not performing his checklist.

3D
--
- to activate 3D, press "ctrl-I c".
- a crew member without headset is not performing his checklist.

Captain
-------
- brake release triggers the count down before takeoff.

Copilot
-------
- is never the pilot in command; except 4 engines flameout : holds the aircraft during
  engine start.
- gear, nose and lightning (subsonic only).

Engineer
--------
- center of gravity, tanks and engine rating (not supported by FDM).
- taxi with 2 engines, after landing.


Alarms
======
Not listed warning lights are not yet implemented.

Sound
-----
- horn    : too low speed.
- pull-up : excessive descent speed; too low gear at approach, nose not down at touch down.
- rattle  : overspeed.
- whistle : JSBSim stall (rare), aft center of gravity warning, underspeed.

Red
---
- "AP"    : instrument failure, abnormal pitch, abnormal AoA.
- "AT"    : instrument failure, autothrottle expected.
- "AUTO LAND" : autothrottle expected, ILS missing, outside path at touch down.
- "M/CG"  : center of gravity outside of corridor.
- "TERRAIN"   : excessive descent speed; too low gear at approach, nose not down at touch down.
- "TYRE"  : tyre pressure.

Overhead
........
- "DOORS" : ground supply.
- "ELEC"  : electrical failure.
- "ENG"   : engine stopped.
- "FEEL"  : no green and blue hydraulics.
- "ICE"   : engine and wing anti-icing expected.
- "INT"   : intake without hydraulics.
- "PFC"   : flight control channel on green or mechanical.
- "PRESS" : pressurization failure, no air conditioning.

Brakes
......
- "FWD"   : brake overheat.
- "REAR"  : brake overheat.
- "WHEEL" : brake overheat.

Doors
.....
- "MISC HATCHES" : ground supply.

Electrical
..........
- "DC ESS BUS"   : no voltage from AC essential bus and battery.
- "DC MAIN BUS"  : no voltage from AC main bus.

Engines
.......
- "INTAKE" : no hydraulics.

Hydraulics
..........
- "BRAKES FAIL" : no normal brakes (no green hydraulics).

INS
...
- "WARN"   : INS failure.

Pressurization
..............
- "EXCESS ALT" : cabine under pressure.
- "OVER PRESS" : cabine over pressure.

Amber
-----
- "ATT"  : excessive attitude.
- "CTY"  : reheat at takeoff.
- "DH"   : decision altitude.

Overhead
........
- "ELEC" : electrical failure.
- "FUEL" : fuel failure.
- "HYD"  : hydraulical failure.
- "INHIBIT" : all MWS lights inhibited, except red PFC and ENG.
- "INT"  : intake lost its main hydraulics.

Electrical
..........
- "AC ESS BUS"   : no voltage from main bus.
- "AC MAIN BUS"  : no voltage from generator.
- "BATT ISOLATE" : battery disconnected.
- "CSD"  : constant speed drive disconnected.
- "GEN"  : generator disconnected from main bus.

Engines
.......
- "HYD"  : intake lost its main hydraulics.

Fuel
....
- "LOW LEVEL" : collector tank low.
- "LOW PRESSURE"  : no fuel pump, empty tank, LP valve not open.
- "TANK PRESSURE" : air bleed failure.

Hydraulics
..........
- "BRAKES EMER" : parking or emergency brakes (no green hydraulics).
- "L/PRESS"     : pump disconnected, engine stopped.

INS
...
- "ALERT"  : 1 minute until next waypoint.
- "BAT"    : no voltage.
- "REMOTE" : waypoint insert to all INS.

Yellow
------
- "ILS"  : missing ILS.

Air conditioning
................
- "COMPARATOR" : no air conditioning on group 3 or 4.

Electrical
..........
- "FAIL" : no hydraulical pressure (green circuit), emergency generator isolated.

Engines
.......
- "START PUMP" : starter / relight activated.

Fuel
....
- "ACC"  : no fuel pump.
- "LOW PRESSURE" : engine fuel pump stopped, empty tank.

Blue
----
- "REV"  : reverse thrust.

Overhead
........
- "EXTENDED" : landing light not retracted.
- "ICE " : ice condition detected.

Hydraulics
..........
- "SELECTED" : emegercy generator selected.
- "TEST"     : RAM Air Turbine test.

Green
-----
- clear to go (above N2) : armed by takeoff monitor (bug on fuel flow).
- "LAND 1" : autoland with 1 autopilot.
- "LAND 2" : autoland with 2 autopilots.

Overhead
........
- "IGV PRESS" : engine anti-icing activated.

Engines
.......
- "LH IGN" : engine ignition.
- "RH IGN" : engine ignition.

Hydraulics
..........
- "R.A.T." : RAM Air Turbine deployed.

White
-----
- CLB : climb engine rating.
- CRS : cruise engine rating.
- TO  : takeoff engine rating.

Electrical
..........
- "GROUND PWR AVAILABLE" : electrical power from ground service.


Consumption
===========
Consumption decreases with altitude, from FL500 to FL580 (60 ft/min. during 2h10).
Fuel must be just below 19000 kg with the direct route (short SID/STAR).
So that it remains enough fuel, in case the SID/STAR becomes long :
STAR at KJFK seems to have been always short (range edge).

Route
-----
East bound :
- acceleration 30 NM before MERLY.
- deceleration 250 NM before LINND or LYNUS.

West bound :
- acceleration at LINND.
- deceleration 40 NM after BANDU (BARIX missing).

KJFK 22L - EGLL 27R, 3150 NM.
EGLL 09R - KJFK 04L, 3300 NM.
LFPG 08L - KJFK 04L, 3500 NM.
LFPG 26L - KJFK 22L, 3550 NM.
TBPB 09  - EGLL 27R, 3700 NM (Barbados).

Example
-------
EGLL 27L - KJFK 22L, 3400 NM :
- load --flight-plan from Doc.
- acceleration 30 NM before MERLY.
- stable at FL500 with 71500 kg, 2h20 from LINND, at 2700 NM and 11500 kg (see "ctrl-I n").
- warm, 275 deg 5 kt westerly, Mach 2.02, climbing slowly until 57600 ft (60 ft/min 2h07).
- deceleration 250 NM (13 minutes) before LINND : INS indicates 20900 kg at LINND,
  and 15700 kg at KJFK (590 NM).
- 8500 kg at landing.

Cruise
------
85000 kg (full) at Mach 0.95 (550 kt true) FL260, stable : 23600 kg/h.
71000 kg at Mach 1.99 50000 ft, stable : 26300 kg/h.
69000 kg at Mach 2.02 50300 ft, climb 60 ft/min : 26200 kg/h.
Average (depends of altitude) at Mach 2.02 : 20500 kg/h.
26000 kg at Mach 2.02 57800 ft, stable : 17700 kg/h.
25000 kg at Mach 2.02 57800 ft, climb 60 ft/min : 18100 kg/h.
19000 kg at Mach 0.95 (510 kt true) FL380, stable : 13900 kg/h. 

Decreasing the TSFC increases the range.


JSBSim
======
- maximum thrust (without air intakes) at FL500 is 10093 lb, matching the real value of 10000 lb !
- center of gravity inside corridor.
- shift of center or pressure.
- the geometry is real data.
- tanks default at maximum takeoff weight (408000 lb).
- consumption London - New York : correct landing weight at KJFK.
- climb Mach 0.95 - 1.7 in 10 minutes.
- fuel around 20500 kg/h at Mach 2.02 (E).
- intake failure (4 at once).


TO DO
=====
- battery discharge.
- control max cruise mode with TMO temperature (B).
- move a few procedures to tutorials.

TO DO instruments
-----------------
- control of 2D instrument luminosity (only possible with 3D instruments).
- see Panels/Instruments/ReadmeInstruments.txt

TO FDM
-------
- weaker supersonic lift (no negativ AOA).
- inertia of surfaces.
- move autopilot PID inside the FDM ?
- additional drag when RAT.
- alteration of FDM by icing.
- check the subsonic range.
- turbulence filter.

FDM update often implies a tuning of autopilot (mainly heading hold),
and always a complete test (autoland, subsonic, supersonic).

TO DO JSBSim
------------
- reverse thrust is not implemented : ctrl-B only animates the lights and nozzles.
- failure on only 1 intake at once.


Known problems
==============
- the file in application-data (saved configuration) causes the bounce at loading
 (it seems to trim over the runway).
- if brakes, gear and nose don't work, see Nasal/Concorde-override.nas.

Known problems autopilot
------------------------
- heading hold is a little slow to converge.
- if deviation is enough large (supersonic speed), close waypoint may not pop for the next one,
  to avoid a strong bank.

Known problems autoland
-----------------------
- nav must be accurate until 0 ft AGL : KSFO 28R, RJAA 34L are correct;
  but EGLL 27R, KJFK 22L are wrong : to land at these airports,
  set /controls/autoflight/real-nav to false, by "ctrl-I g".

Known problems sound
--------------------
- ATIS volume (VHF) changed only at the frequency swap.
- exception through OpenAL errors (low hardware ?) means too many sounds :
  remove for example engine start/shutdown or external sounds.
  This is why engine shutdown/start sound is the same for all views.

Known problems keyboard
-----------------------
- because of ctrl-I overriding, TAB altimeter menu is not available with GLUT.

Known problems OSG
------------------
The following artefacts are supposed to be solved by OSG (works with 0.9.11 / Plib) :
- missing hotspots.
- panels swaping too early.
- instrument transparent through layer with alpha (steward view).
- blurr on texture crop (example : left edge of artificial horizon). 
- transparency order of blinking anti-collision light over wing.
- dark external lights.
- engineer 3D seat/crew doesn't rotate forwards at takeoff (reset by ctrl-E).


Secondary problems
==================

Secondary problems FDM
-----------------------
- very light waddling at mach 2 (autopilot rudder trim, to solve roll of autopilot heading
  at Mach speeds).
- disable yaw damper, when turbulence ?
- fuel consumption too low at idle (ground).
- oil pressure too high.

Secondary problems JSBSim
-------------------------
- AoA at 180°, when one breaks strongly (empty tanks).

Secondary problems autopilot
----------------------------
- confirm autoland landing speed, whatever the wind.

Secondary problems instruments
----------------------------
- see Panels/Instruments/ReadmeInstruments.txt

Secondary problems sound
------------------------
- VHF volume not implemented for Festival (possible ?).
- engineer uses pilot voice.


References
==========
(A1) http://www.airliners.net/discussions/tech_ops/read.main/28473/4/ :

(A2) http://www.airliners.net/discussions/tech_ops/read.main/24517/4/ :

(A3) http://www.airliners.net/discussions/tech_ops/read.main/46757/4/ :

(A4) http://www.airliners.net/discussions/tech_ops/read.main/60137/ :

(B) http://sebby2.free.fr/pm2/PM2C_V2_MANUAL.exe/ :
    http://www.fsfrance.com/Projets/Mach2/Download.htm/ :
    scan of an Air France ops manual (in French).

(C) http://www.titanic.com/story/159/Concorde/ :

(D) http://www.concorde-jet.com/ :

(E) http://www.alpa.org/alpa/DesktopModules/ViewDocument.aspx?DocumentID=814 :

(F) http://www.aeroflight.co.uk/types/international/aerospat-bac/concorde/concorde.htm :

    http://www.flight-manuals-on-cd.com/Concorde.html/ :
    British Airways flight manual 1979, 1600 pages. 


9 December 2007.
