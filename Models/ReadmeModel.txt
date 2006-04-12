The real aircraft
=================
The nose strakes improves the air flow over the delta wing.

The black strip under the wing edge is de-icing.
The black holes below the front doors are the pressure discharge valves.

The cockpit :
- blue (instrument panels), white beige (walls) and black (window pillars and sills).
- pilot seat, near the 2nd pillar. As instruments (artificial horizon, ASI) are close, the reading at landing is easy.
- overhead panel stops before the engineer panel.
- autopilot height = less than 1/2 of panel height.
- panel height = 1/2 of height to floor (below the panel).


Cockpit Model
=============
The floor is supposed to be at the same level than the external nose strakes (blade),
which puts it slightly above the bottom of the (textured) doors.

The cockpit texture without alpha makes the 2D instruments visible on a panel;
the other texture with alpha is for clipping of 2D instruments.

The external lights :
- must be the last of the file, for the transparency;
 they are inside a single group, whose parent is the last object of the AC3D file.
- must be centered at the model origin, where the billboard rotation happen (also required by scaling).
- must have the surface vertical, oriented to the left of aircraft (otherwise billboard makes the object disappear !).


TO DO
=====
- visor well.
- compression of wing gear.
- afterburner (smoke).
- probes on nose, RAT.
- seats, yokes.


Known problems
==============
- removing polygons (mainly the wings) could increase the frame rate : it will be waited for hardware upgrade.
- polygons with no area must be removed with Utils/Modeller/ac3d-despeckle, after Blender export.
- avionics racks are not enough long, because the textured doors and portholes are too forwards
  (left aft door more below the vertical fin).

Known problems cockpit
----------------------
- overhead slightly too large ?
- in the engineer view, the autopilot panel is align with the yoke pillars, like in Blender;
  in the captain view, the autopilot panel appears with a right shift : this is a visual effect.


References
==========
- http://www.concordesst.com :


Credits
=======
Concorde model (without 3D cockpit) is from "Bogey" (unknown name and mail).

It has been made available to Flightgear upon a request of M. Franz.
See the forum of http://www.blender.org/, message from "Bogey", subject "Update Concord. Screen shots and download
links" (24 october 2003 6:23 pm).


List of updates to the original model :
- addition of tail door closed, cockpit, external lights.
- visibility of visor and nose from cockpit.
- split of nozzles, main gear wheels (animation).
- transparent windows (texture alpha).
- alignment of main gear internal doors with their well.


Contact devel-list for the .blend file (Blender 2.36) :
- distinct object group for the cockpit (lost at AC3D export/import).
- which is otherwise very difficult to isolate in the mesh jungle : one needs to eliminate the fuselage to vizualize the
cockpit interior (alternate solution : cockpit in different layer).


19 March 2006.
