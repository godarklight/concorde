Concorde real data
==================
Weight (lbs) : max take off 408000, zero fuel 203000, operating empty 173500, max payload 29500, max taxing 412000,
               max landing 245000.

Speeds :
    Vlo (landing gear operation)                 : 270 kt.
    Vle (landing gear extended)                  : 270 kt.
    V visor down or operating                    : 325 kt.
    V nose 5° or operating between UP and 5°     : 325 kt.
    V nose DOWN or operating between 5° and DOWN : 270 kt (at altitudes below 20000 ft).
    V landing lights                             : 270 kt.
    Vmc (minimum control speed with engine inoperative)
    Vmcg (ground)                                : 116 kt.
    Vmc (takeoff)                                : 132 kt.
    Vmcl (approach)                              : 150 kt.
    V max for windscreen wiper operation         : 325 kt.
    V max for jettison (fuel)                    : Mach 0.93.
    Vla above 41000 ft (lowest autorized)        : 300 kt.
    Vla 15000/41000 ft                           : 250 kt.
    Vla below 15000 ft                           : VREF or V2 or V3.

Maximum operating altitude : 60000 ft.
Maximum total temperature (TMO) : 127°C on nose.

Procedures :
    Takeoff (408000 lb) : nose 5°, afterburner, V1 165 kt, VR 195 kt, pitch 13.5° at rotation, V2 220 kt.
    Subsonic cruise : Mach 0.93.
    Acceleration : afterburner at Mach 0.93; air intakes starts closing at Mach 1.3; stop afterburner at Mach 1.7.
    Supersonic cruise : Mach 2.0 at FL500.
    Landing (245000 lb) : nose 12.5°, VREF 162 kt, pitch 10° at touch down.
    Taxi : nose 12.5°, only 2 reactors.


Concorde ops
============
Takeoff
-------
- the visor is raised not long after takeoff, to make cockpit quieter (A).
- the visor protects the windscreen from the 125°C temperature at Mach 2 (A).

Supersonic climb
----------------
- start afterburner with VS at 3500 ft/minute; then decrease at 1500 ft/minute, and finally 500 ft/minute.
- at Mach 1.1, drag starts to decrease.
- stay inside the corridor of Mach/center of gravity. Below the minimum means a too high altitude for the current Mach
speed : accelerate by reducing climb speed.
- at Mach 1.3, air intakes open progressively, providing additional thrust. This is the hardest speed to reach,
burning much fuel, which would be otherwise in excess at landing.
- climb from Mach 0.95 (28000 ft) to Mach 1.7 (47000 ft) lasts 10 minutes (A).

Supersonic cruise
-----------------
- from London-Heathrow, Mach 2 is reached 40 minutes - 650 NM (Bristol Channel) - after takeoff (A).
- cruise at Mach 2 consumes 20.5 tons/hour.
- transatlantic flight at Mach 2 lasts 2 hours; 2h35 above Mach 1 (A).
- at FL500 Mach 2, slow climb rate of 50-60 ft/minute, to reduce fuel consumption (A).

Supersonic descent
------------------
- deceleration is started at 250 NM : 165 NM from Mach 2.0 FL580 to Mach 1.0 at FL350 (A).
- maintain the 50 ft climb rate to accelerate the deceleration.

Landing
-------
- approach speed : 190 kt (A).
- at 750 ft AGL, disable the autopilot, keep the trim of the glide slope mode; control with speed and pitch, touch down
below 750 ft/minute : more speed enables to land with less pitch and vertical speed; more pitch reduces the descent rate.
- the tail wheel protects the reversers from hitting the ground (A).


Customizing
===========
Set file has 2 configurations (max payload) :
- maximum landing weight, 245000 lb (19000 kg fuel).
- maximum takeoff weight, 408000 lb (93000 kg fuel, London - New York) : put in comment the US gallons
(inheritance from JBSim).

Sounds
------
concorde-real-sound.xml tells, how to install real Concorde sounds.


Keyboard
========
- "s" swaps between Captain and Pedestal panels.
- nose used as flaps.
- "ctrl-R" : afterburner.
- "ctrl-L" : disables autopilot (button A/P DISC on yoke).

Engineer panel
--------------
- "Aft" transfers forwards trim tanks (9 & 10) to aft trim tanks (11, 5A & 7A). "Forw" does the reverse transfer.
- "Engine" transfers trim tanks to the engine supply tanks (1, 2, 3 & 4) : choose the direction "Aft" or "Forw".
- "Dump" (2 buttons for confirmation) dumps the rear tanks (11, 5A, 7A, 2 & 3).
- Activate "Cross", to balance the dissymetrical tanks.
- "kg/h" checks that fuel pumping matches the fuel flow indicated by the engines.

Overhead panel
--------------
- "105t"/"165t" reduces VMO and increases maximum center of gravity (105 t = 13900 kg fuel).
- "Max TO" (Max performance takeoff) increases maximum center of gravity, from takeoff to Mach 0.45.


JBSim
=====
- maximum thrust (without air intakes) at FL500 is 10093 lb, matching the real value of 10000 lb !
- center of gravity inside corridor.
- the geometry is real data.
- tanks default at maximum takeoff weight (408000 lb).
- consumption London - New York : correct landing weight at KJFK.


TO DO
=====
- nose temperature (TMO).
- inverser at landing.
- turbulence mode doesn't filter turbulence.
- real instruments.
- spread instruments on real 3D panels : autopilot, captain, center, overhead, pedestal, engineer.

Known problems
--------------
- press "Aft" the first time to make the pumps working (Nasal bug ?).
- autoland glides when tail wind (or wrong position of ILS at KSEA 16R ?).
- vertical speed autopilot is excellent; but it never matches the indicated vertical speed, since its input is the
physical vertical speed.
- autopilots Mach/speed with pitch might need some tuning.

Known problems JBSim
--------------------
- fuel consumption too low at idle.
- aero reference point has its position of Mach 2.0 (static).
- very light waddling at mach 2 (autopilot rudder trim, to solve roll of autopilot heading at Mach speeds).
- AoA at 180°, when one breaks strongly with 14000 kg of fuel (taxi at KJFK).
- at Mach 1.7, military thrust must be lower than augmented thrust.


(A) http://www.airliners.net/discussions/tech_ops/