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

Procedures :
    Takeoff (408000 lb) : nose 5°, afterburner, V1 165 kt, VR 195 kt, pitch 13.5° at rotation, V2 220 kt.
    Subsonic cruise : Mach 0.95.
    Acceleration : afterburner at Mach 0.93; air intakes starts closing at Mach 1.3; stop afterburner at Mach 1.7.
    Supersonic cruise : Mach 2.0 at FL500.
    Landing (245000 lb) : nose 12.5°, VREF 162 kt, pitch 10° at touch down.
    Taxi : nose 5°, only 2 engines (B).

Runway : 11200 ft takeoff, 7300 ft landing (C).
Max climb rate : 5000 ft/s (C).
Range : 3550 nm supersonic, 2760 nm subsonic (Mach 0.95 FL300) (C).
Duration : Paris / New York 3h45 (D), London Heathrow / New York 3h50 (E).
Maximum operating altitude : 60000 ft (C).
Maximum total temperature (TMO) : 127°C on nose.


Concorde ops
============
Takeoff
-------
- the visor is raised not long after takeoff, to make cockpit quieter (A).
- the visor protects the windscreen from the 125°C temperature at Mach 2 (A).

Subsonic cruise
---------------
- Mach 0.93 at FL250, or Mach 0.95 at FL260 (full load) (B).

Supersonic climb
----------------
- start afterburner with VS at 3500 ft/minute; then decrease at 2500-1500-1000-700 ft/minute.
- at Mach 1.1, drag starts to decrease.
- stay inside the corridor of Mach/center of gravity. Below the minimum means a too high altitude for the current Mach
speed : accelerate by reducing climb speed.
- if required (pressure/temperature) after Mach 1.2, reduce at 100 ft/minute to break the Mach 1.3 final barrier.
- at Mach 1.3, air intakes open progressively, providing additional thrust. This is the hardest speed to reach,
burning much fuel, which would be otherwise in excess at landing.
- climb from Mach 0.95 (28000 ft) to Mach 1.7 (47000 ft) lasts 10 minutes (A).

Supersonic cruise
-----------------
- from London-Heathrow, Mach 2 is reached 40 minutes - 650 NM (Bristol Channel) - after takeoff (A).
- cruise at Mach 2 consumes 20.5 tons/hour (E).
- transatlantic flight at Mach 2 lasts 2 hours; 2h35 above Mach 1 (A).
- at FL500 Mach 2, slow climb rate of 50-60 ft/minute, to reduce fuel consumption (A).

Supersonic descent
------------------
- decelerate speed until 325-380 kt before starting the descent (B).
- deceleration is started at 250 NM : 165 NM from Mach 2.0 FL580 to Mach 1.0 at FL350 (A).
- maintain the 50 ft climb rate to accelerate the deceleration.
- slowly increase the descent rate, keeping the 325-380 kt speed : slow at FL580, higher at lower altitudes.

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
- "ctrl-D" : "D"isconnects the autopilot (button A/P DISC on the yoke).
- "ctrl-E" : toggles "E"ngineer/Captain view.
- "ctrl-F" : a"F"terburner.

Overriden
---------
- "s" swaps between Captain and Center 2D panels.
- nose used as flaps.
- "ctrl-A" : altitude hold.
- "ctrl-G" : glide slope.
- "ctrl-H" : heading hold.
- "ctrl-N" : nav 1 hold.
- "ctrl-P" : pitch hold.
- "ctrl-S" : autothrottle.
- "page up" : increases autothrottle (+/-22 kt, +/-0.06 Mach).
- "page down" : decreases autothrottle.
- "up" : increases pitch hold (+/- 11 deg).
- "down" : decreases pitch hold.

Engineer
--------
- "Aft" transfers forwards trim tanks (9 & 10) to aft trim tanks (11, 5A & 7A). "Forward" does the reverse transfer.
- "Engine" transfers trim tanks to the engine supply tanks (1, 2, 3 & 4) : choose the direction "Aft" or "Forw".
- "Jettison" (2 buttons for confirmation) dumps the rear tanks (11, 5A, 7A, 2 & 3).
- Activate "Cross", to balance the dissymetrical tanks.
- "kg/h" checks that fuel pumping matches the fuel flow indicated by the engines.
- "T/O CG" (Max performance takeoff at 54% CG) increases maximum center of gravity, from takeoff to Mach 0.45.
- "105t"/"165t" reduces VMO and increases maximum center of gravity (105 t = 13900 kg fuel).
- engine start : activate the starter, before removing the cutoff.

Inertial Navigation System
--------------------------
- INS indicates the consumption at the waypoints.
- "2" (up) and "8" (down) scrolls the waypoints.
- "CLear" turns on/off the INS. 

Alarms
------
- "Terrain" : too low gear (horn).
- "M/CG" : center of gravity out of corridor.
- "Speed" : overspeed (clink).

Autopilot
---------
- "HDG" is magnetic heading, and "TRK" true heading.
- "Max Climb" mode sets the autothrottle to VMO (MMO above 50200 ft) (B).
- See the panel file for capabilies of autopilot and autothrottle.
- At subsonic speed, no speed up above X 3.
- At supersonic speed, no speed up above X 2.


Real 3D cockpit
===============
- blue (instrument panels), white beige (walls) and black (window pillars and sills).
- pilot seat, near the 2nd pillar. As instruments (artificial horizon, ASI) are close, the reading at landing is easy.
- engineer panel seems to cover the 2nd window of copilot.
- overhead panel stops before the engineer panel.


JBSim
=====
- maximum thrust (without air intakes) at FL500 is 10093 lb, matching the real value of 10000 lb !
- center of gravity inside corridor.
- the geometry is real data.
- tanks default at maximum takeoff weight (408000 lb).
- consumption London - New York : correct landing weight at KJFK.
- fuel around 20500 kg/h at Mach 2.02 (E).

Consumption
-----------
It decreases with altitude, from FL500 to FL580.
Fuel must be just below 19000 kg with the direct route (short SID/STAR). So that it remains enough fuel, in case the
SID/STAR becomes long.

EGLL 09R COMPTON 3 - KJFK 04L CAMRN 3 (SIE), 3322 NM (calibration route) :
- short SID (WOD, CPT). Acceleration 30 NM before MERLY.
- reaches FL500 with 70000 kg, 2h25 from LYNUS, at 2700 NM and 18500 kg.
- 27 kt westerly (jetstreams are rather around FL330), Mach 2.02, climbing slowly until 58000 ft.
- deceleration 250 NM before LYNUS : INS indicates 24300 kg at LYNUS, and 21000 kg at KJFK.
- short STAR : 17500 kg at landing. 

EGLL 27L COMPTON 3 - KJFK 22L DE LANCEY (DNY.PWL2), 3383 NM :
- deceleration 250 NM before LINND.
- long STAR.

KJFK 22L - EGLL 27R OCKHAM 1 FOXTROT, 3140 NM:
- acceleration at LINND.
- westerly wind < 5 kt : remove at least 1000 kg of fuel.
- short STAR (NIGIT, OCK).

LFPG 26L - KJFK 22L DE LANCEY (DNY.PWL2), 3541 NM.
- short SID. Acceleration after the sea shore.
- long STAR.

LFPG 08L BVS (8G 8K) - KJFK 04L CAMRN 3 (SIE), 3492 NM :
- short SID (RSY, LFPP, CRL, BVS). Acceleration after the sea shore.
- reaches FL500 with 71500 kg, 2h35 from LYNUS, at 2880 NM and 17300 kg.
- 27 kt westerly, Mach 2.02, climbing slowly until 58000 ft.
- deceleration 250 NM before LYNUS : INS indicates 24400 kg at LYNUS, and 21200 kg at KJFK.
- short STAR : 18800 kg at landing. 


TO DO
=====
- turbulence mode doesn't filter turbulence (disable yaw damper ?).
- control (?) max cruise mode with TMO temperature (B).
- reduce nasal code with Flightgear subsystems : Mach autopilot, fuel pumping, cross-feeding, cabine altitude, true
airspeed and ground speed.
- replace digital instruments by real analog textures.
- 3D instruments, keeping the 3D cockpit complete (temporary cohabitation 2D/3D instruments).
- missing in Flightgear : engine rating, 2 ADF, 2 DME.
- make transparent the external windows of cockpit.
- check the subsonic range.
- system failures.
- abacus to fill the tanks, as function of aloft winds.

TO DO JBSim
-----------
- extrapolate the engine tables at 60000 ft and Mach 2.2.
- tabulation on a right column the aeromatic values.


Known problems
==============
- press "Aft" the first time to make the trim pumps working (Nasal bug ?).

Known problems JBSim
--------------------
- no inverser at landing.
- fuel consumption too low at idle (ground).
- aero reference point has its position of Mach 2.0 (static).
- very light waddling at mach 2 (autopilot rudder trim, to solve roll of autopilot heading at Mach speeds).
- AoA at 180°, when one breaks strongly (empty tanks).
- at Mach 1.7, military thrust must be lower than augmented thrust.
- only 1 tank seems to feed each engine :
http://www.dft.gov.uk/stellent/groups/dft_avsafety/documents/page/dft_avsafety_029047.hcsp
- no support of engine rating.
- cannot disable yaw damper.
- near Mach 2, setting vertical speed at +60 ft/min, can go down. While /velocities/vertical-speed-fps, controlled by
autopilot, is correct.
- cannot start engines, when they have runned out of fuel.

Known problems autopilot
------------------------
- vertical speed autopilot is excellent; but at high altitude it doesn't match the indicated vertical speed, since its
input is the physical vertical speed (/velocities/vertical-speed-fps).
- confirm autoland landing speed, whatever the wind and fuel weight.
- autothrottles Mach/speed with pitch might need some tuning.

Known problems 2D instruments
-----------------------------
- uniform lightning of artificial horizon's attitude warning, when negativ pitch.
- TCAS (radar) only works with 2D panel.

Known problems 3D cockpit
-------------------------
- panel can be too much white, depending of sun location : material and/or Flightgear lightning.
- instruments have been disabled in external views, because there are transparent through aircraft.
More gravely, copilot instruments hang outside the cockpit, because of a view shift to the right.

Known problems 3D aircraft
--------------------------
- since the introduction of 3D cockpit, there is a transparency of the front window edge, visible when the nose is down.
- removing polygons (mainly the wings) will decrease the frame rate. But would it be better to wait for 256 MB cards ?
Will wait them, before moving to 3D instruments : http://www.flight-manuals-on-cd.com/Concorde.html.

Known problems sound
--------------------
- fading with distance (tower views) doesn't work with engine real sounds.
- with low hardware, exception through OpenAL errors, when too many sounds : remove for example engine start/shutdown.
This is why engine shutdown/start sound is the same for all views.


References
==========
(A) http://www.airliners.net/discussions/tech_ops/ :
    search by key words.

(B) http://sebby2.free.fr/pm2/PM2C_V2_MANUAL.exe/ (www.fsfrance.com/Projets/Mach2/Download.htm) :
    scan of an Air France ops manual (in French).

(C) http://www.titanic.com/story/159/Concorde/.

(D) http://www.concorde-jet.com/.

(E) http://www.alpa.org/alpa/DesktopModules/ViewDocument.aspx?DocumentID=814


Credits
=======
Concorde model (without 3D cockpit) is from "Bogey" (unknown name and mail).
It has been made available to Flightgear upon a request of Melchior Franz.

See the forum of http://www.blender.org/, message from "Bogey", subject "Update Concord. Screen shots and download
links" (24 october 2003 6:23 pm).


Contact devel-list for the .blend file : distinct object group for the cockpit (lost at AC3D export/import).


11 september 2004.