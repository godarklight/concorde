The real aircraft
=================
The nose strakes improves the air flow over the delta wing (A).
The plane bulge at the top of the aft fuselage is the ADF antenna (A).

The black strip under the wing edge is de-icing (A).
The black holes below the front doors are the pressure discharge valves (A).

The anti-collision lights are red (G).

Cockpit
-------
- blue (instrument panels), white beige (walls) and black (window pillars and sills).
- pilot seat, near the 2nd pillar. As instruments (artificial horizon, ASI) are close,
  the reading at landing is easy.
- overhead panel stops before the engineer panel.
- autopilot height = less than 1/2 of panel height.
- panel height = 1/2 of height to floor (below the panel).


Model
=====
The floor is supposed to be at the same level than the external nose strakes (blade),
which puts it slightly above the bottom of the (textured) doors.

The seats stop at window bottom, and pilot shoulder (F).
The engineer seat must match the engineer view (rotation).

These meshes are not smoothed (solid) :
- overhead.
- engineer panel.
- blue avionics rack, near the observer seat.


Pitch
------
The original 3D model had a pitch and a longer front gear :
- the fuselage is always horizontal (B).
- the pitch seems to exist (C)(D) at empty load.
- the front gear is longer in flight (piston extended) (E).


Transparency
------------
The external lights must be the last of the file :
- all other objects belong to a hull, cockpit group, front or light group;
  the front window must be after the cockpit; the visor must be after the front window :

      Hull
      Cockpit
      Front + nose
      Visor + lights

- the hull group, not visible, is disabled inside cockpit.
- a few invisible parents, at origin, help the ordering by 2.42a export script.
- for selection during design, hull, cockpit, front and lights are in separate layers
  (one cannot use a group to isolate the cockpit).

The external lights must :
- be centered at the model origin, where the billboard rotation happen (also required by scaling).
- have the surface vertical, oriented to the left of aircraft (otherwise billboard makes
  the object disappear !).


VRP
---
The model is aligned vertically along the nose axis, but is still centered
horizontally on the center of gravity :
- that is more handy with the Blender grid. 
- the alignment of VRP to the nose tip is finished by XML (horizontal offset).


Texturing
---------
The cockpit texture without alpha makes the 2D instruments visible on a panel;
the other texture with alpha is for clipping of 2D instruments.


TO DO
=====
- visor well.
- compression of gear spring.
- afterburner smoke.
- probes on nose, RAT.
- yokes, levers.


Known problems
==============
- removing polygons (mainly the wings) could increase the frame rate :
  it will be waited for hardware upgrade.
- polygons with no area must be removed with Utils/Modeller/ac3d-despeckle, after Blender export.

Known problems outside
----------------------
- avionics racks are not enough long, because the textured doors and portholes are too forwards :
  left aft door should be more below the vertical fin, and front doors more aft (B).
- the tail wheel door seems too long : one part of tail gear hole is closed by the small left and
  right doors.
- the water deflector of main gear crosses the fuselage at retraction.

Known problems cockpit
----------------------
- overhead slightly too large ?
- joint of engineer panel with cockpit ceiling too large ?


References
==========
(A) http://www.concordesst.com :

(B) http://www.airliners.net/open.file/0603013/L/ :
    G-BOAD, by Stefan Welsch, without pitch.

(C) http://www.airliners.net/open.file/0229834/L/ :
    G-BOAF, by Carlos Borda, with pitch.

(D) http://www.concordesst.com/video/98airtoair.mov :
    British Airways clip.

(E) http://www.airliners.net/open.file/0441886/L/ :
    G-BOAE, by Harm Rutten.

(F) http://www.airliners.net/open.file/0024969/L/ :
    by Richard Paul.

(G) http://fr.wikipedia.org/wiki/Concorde :


Credits
=======
Concorde model (without 3D cockpit) is from "Bogey" (unknown name and mail).

It has been made available to Flightgear upon a request of M. Franz.
See the forum of http://www.blender.org/, message from "Bogey", subject "Update Concord. Screen shots
and download links" (24 october 2003 6:23 pm).


Updates (-) and additions (+) to the original model                                   Version
---------------------------------------------------------------------------------------------
+ tail door closed.                                                                     1.1
+ cockpit.                                                                              1.2
- visibility of visor and nose from cockpit.                                            2.0
- split of nozzles (reverser).                                                          2.1
- transparent windows (texture alpha).                                                  2.1
- alignment of main gear internal doors with their well.
- split of main gear wheels (spin).                                                     2.2
+ external lights.                                                                      2.2
- alignment to the nose tip, instead of the tail tip (VRP).                             2.3
- split of main gear pistons (bogie compression and torsion).                           2.3
- higher side stays and stearing unit (front gear compression).                         2.3
- horizontal fuselage, without pitch (flat cockpit).                                    2.3
- centered axis of front window (to match overhead).                                    2.4
- split of primary nozzles (reheat off texture).                                        2.4


Made with Blender 2.43.


6 April 2007.
