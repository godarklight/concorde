# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains 3D feedbacks.
# Code is heavily optimized, to not use ressource when disabled (heavy mesh).



# ==========
# HUMAN CREW
# ==========

# for inheritance, the component must be the last of parents.
Crewhuman = {};

# not called by child classes !!!
Crewhuman.new = func {
   obj = { parents : [Crewhuman],

           crew : nil,
           crewcontrol : nil,
           human : nil,
           humancontrol : nil,
           voices : nil,

           nightlighting : Nightlighting.new("engineer"),

           HEADSEC : 45.0,
           EYEMAXSEC : 7.0,                              # human eye blinks every 3 - 7 s
           EYEMINSEC : 3.0,
           WAITSEC : 3.0,
           CHARACTERSEC : 0.15,
           BLINKSEC : 0.15,
           STOPSEC : -999.0,

           heads : 0.0,

           TURNDEG : 60.0,
           RAISEDEG : 15.0,
           FORWARDSDEG : 0.0,

           MUSCLEDEGPSEC : 8.0,

           crewmember : "",
           crewpath : "",
           crewvoice : "",

           mooth : nil,

           sleephead : constant.TRUE,
           sleepeye : constant.TRUE,

           movehead : constant.FALSE,
           openeye : constant.TRUE
         };

   return obj;
}

Crewhuman.init_ancestor = func( path, member, panel, voice ) {
   obj = Crewhuman.new();

   me.nightlighting = obj.nightlighting;
   me.nightlighting.set_member( panel );

   me.HEADSEC  = obj.HEADSEC;
   me.EYEMAXSEC = obj.EYEMAXSEC;
   me.EYEMINSEC = obj.EYEMINSEC;
   me.WAITSEC = obj.WAITSEC;
   me.CHARACTERSEC = obj.CHARACTERSEC;
   me.BLINKSEC = obj.BLINKSEC;
   me.STOPSEC = obj.STOPSEC;
   me.heads = obj.heads;
   me.TURNDEG = obj.TURNDEG;
   me.RAISEDEG = obj.RAISEDEG;
   me.FORWARDSDEG = obj.FORWARDSDEG;
   me.MUSCLEDEGPSEC = obj.MUSCLEDEGPSEC;
   me.crewmember = member;
   me.crewpath = path;
   me.crewvoice = voice;
   me.mooth = obj.mooth;
   me.sleephead = obj.sleephead;
   me.sleepeye = obj.sleepeye;
   me.movehead = obj.movehead;
   me.openeye = obj.openeye;

   me.crew = props.globals.getNode( me.crewpath );
   me.crewcontrol = props.globals.getNode("/controls/crew");
   me.humancontrol = props.globals.getNode("/controls/human");
   me.human = props.globals.getNode("/systems/human");
   me.voices = props.globals.getNode("/sim/sound/voices");

   me.listenmooth();

   # must wait for initialization
   settimer(func { me.eyescron(); }, 0);
   settimer(func { me.headcron(); }, 0);
}

Crewhuman.set_relation = func( lighting ) {
    me.nightlighting.set_relation( lighting );
}

Crewhuman.wakeup = func {
   if( me.sleepeye ) {
       me.eyescron();
   }
   if( me.sleephead ) {
       me.headcron();
   }

   me.listenmooth();
}

Crewhuman.wakeupexport = func {
   me.wakeup();
}

Crewhuman.schedule = func {
   if( me.crewcontrol.getChild(me.crewmember).getValue() ) {
       me.nightlighting.schedule();
   }
}

Crewhuman.talkrates = func {
   # opens the mooth according to phrase length
   phrase = me.voices.getChild(me.crewvoice).getValue();
   steps = size( phrase ) * me.CHARACTERSEC;

   return steps;
}

Crewhuman.endtalk = func {
   me.crew.getChild("teeth").setValue(constant.FALSE);
}

Crewhuman.eyesrates = func {
   if( me.crewcontrol.getChild(me.crewmember).getValue() and
       me.human.getChild("serviceable").getValue() ) {
       me.sleepeye = constant.FALSE;

       if( me.openeye ) {
           steps = me.BLINKSEC * rand();
           me.openeye = constant.FALSE;
       }

       else {
           factor = rand();
           steps = me.EYEMAXSEC * factor + me.EYEMINSEC * ( 1.0 - factor );
           me.openeye = constant.TRUE;
       }

       me.crew.getChild("eyes").setValue(me.openeye);
   }

   else {
       me.sleepeye = constant.TRUE;
       me.removemooth();
       steps = me.STOPSEC;
   }
 
   return steps;
}

Crewhuman.headrates = func {
   if( me.crewcontrol.getChild(me.crewmember).getValue() and
       me.human.getChild("serviceable").getValue() ) {
       me.sleephead = constant.FALSE;

       if( !me.movehead ) {
           me.movehead = constant.TRUE;
           headingdeg = me.TURNDEG * ( rand() - 0.5 );
           pitchdeg = me.RAISEDEG * ( rand() - 0.5 );
           me.heads = constant.abs( headingdeg / me.MUSCLEDEGPSEC );

           # waits for end of rotation
           steps = me.heads + me.WAITSEC * rand();
       }

       # restores head
       else {
           me.movehead = constant.FALSE;
           headingdeg = me.FORWARDSDEG;
           pitchdeg = me.FORWARDSDEG;
           steps = me.HEADSEC * ( 1 + rand() );
       }

       interpolate( me.crewpath ~ "/heading-deg", headingdeg, me.heads );
       interpolate( me.crewpath ~ "/pitch-deg", pitchdeg, me.heads );
   }

   else {
       me.sleephead = constant.TRUE;
       me.removemooth();
       steps = me.STOPSEC;
   }
 
   return steps;
}

Crewhuman.moothcron = func {
   steps = me.talkrates();
   settimer(func { me.endtalk(); }, steps);
}

Crewhuman.eyescron = func {
   steps = me.eyesrates();
   if( steps > 0 ) {
       settimer(func { me.eyescron(); }, steps);
   }
}

Crewhuman.headcron = func {
   steps = me.headrates();
   if( steps > 0 ) {
       settimer(func { me.headcron(); }, steps);
   }
}

Crewhuman.listenmooth = func {
   if( me.mooth == nil ) {
       me.mooth = setlistener(me.crewpath ~ "/teeth", func { me.moothcron(); });
   }
}

Crewhuman.removemooth = func {
   if( me.mooth != nil ) {
       removelistener(me.mooth);
       me.mooth = nil;
   }
}


# =============
# HUMAN COPILOT
# =============
Copilothuman = {};

Copilothuman.new = func {
   obj = { parents : [Copilothuman,Crewhuman]
         };

   obj.init();

   return obj;
}

Copilothuman.init = func {
   me.init_ancestor( "/systems/human/copilot", "copilot", "copilot", "copilot" );
}


# ==============
# HUMAN ENGINEER
# ==============
Engineerhuman = {};

Engineerhuman.new = func {
   obj = { parents : [Engineerhuman,Crewhuman],

           seat : Engineerseat.new()
         };

   obj.init();

   return obj;
}

Engineerhuman.init = func {
   me.init_ancestor( "/systems/human/engineer", "engineer", "engineer", "pilot" );
}

Engineerhuman.wakeupexport = func {
   me.wakeup();
   me.seat.reset();
}

Engineerhuman.slowschedule = func {
   if( me.crewcontrol.getChild("engineer").getValue() ) {
       if( me.human.getChild("serviceable").getValue() ) {
           me.seat.schedule();
       }
   }

}


# ==============
# NIGHT LIGHTING
# ==============

Nightlighting = {};

Nightlighting.new = func {
   obj = { parents : [Nightlighting],

           lightingsystem : nil,

           crew : nil,
           human : nil,
           lighting : nil,

           NIGHTNORM : 0.0,
           DAYNORM : 0.0,

           crewmember : "",

           NIGHTRAD : 1.57,                        # sun below horizon

           night : constant.FALSE
         };

  obj.init();

  return obj;
}

Nightlighting.init = func {
    me.crew = props.globals.getNode("/controls/lighting/crew");
    me.human = props.globals.getNode("/controls/human/lighting");
}

Nightlighting.set_member = func( path ) {
    me.crewmember = path;

    me.lighting = props.globals.getNode("/controls/lighting/crew").getChild(me.crewmember);

    me.NIGHTNORM = me.human.getChild(path).getValue();
}

Nightlighting.set_relation = func( lighting ) {
    me.lightingsystem = lighting;
}

Nightlighting.schedule = func {
   # optional
   if( me.human.getChild("night").getValue() ) {

       # only once, can be customized by user
       if( me.is_change() ) {
           if( me.night ) {
               lightlevel = me.NIGHTNORM;
               lightlow = constant.TRUE;
           }
           else {
               lightlevel = me.DAYNORM;
               lightlow = constant.FALSE;
           }

           # flood lights
           me.lighting.getChild("flood-norm").setValue( lightlevel );
           me.lightingsystem.floodexport();

           # level of warning lights
           if( me.crewmember == "engineer" ) {
               me.lighting.getNode("forward").getChild("low").setValue( lightlow );
               me.lighting.getNode("center").getChild("low").setValue( lightlow );
               me.lighting.getNode("aft").getChild("low").setValue( lightlow );
           }
           elsif( me.crewmember == "copilot" ) {
               me.lighting.getChild("low").setValue( lightlow );
               me.crew.getNode("center").getChild("low").setValue( lightlow );
               me.crew.getNode("afcs").getChild("low").setValue( lightlow );
           }
       }
   }
}

Nightlighting.is_change = func {
   change = constant.FALSE;
   if( getprop("/sim/time/sun-angle-rad") > me.NIGHTRAD ) {
       if( !me.night ) {
           me.night = constant.TRUE;
           change = constant.TRUE;
       }
   }
   else {
       if( me.night ) {
           me.night = constant.FALSE;
           change = constant.TRUE;
       }
   }

   return change;
}


# =============
# ENGINEER SEAT
# =============

Engineerseat = {};

Engineerseat.new = func {
   obj = { parents : [Engineerseat,System],

           SEATDEGPSEC : 25.0,
           BOGGIESEC : 5.0,

           crew : nil,
           movement : nil,

           TAKEOFFDEG : 360,                                        # towards pedestal
           FLIGHTDEG : 270,

           headdeg : 0,

           STATICDEG : 0,

           TAKEOFFM : 0.45,                                         # near pedestal
           FLIGHTM : 0.0,

           headm : 0.0,

           STATICM : 0.0
         };

   obj.init();

   return obj;
}

Engineerseat.init = func {
   me.init_ancestor("/systems/human");

   me.crew = props.globals.getNode("/systems/crew");
   me.movement = props.globals.getNode("/systems/human/engineer");

   me.headdeg = me.slave["engineer"].getChild("heading-deg").getValue();
}

Engineerseat.schedule = func {
   # restores seat position after a swap to the engineer view,
   # where the seat rotates with view
   if( !me.slave["seat"].getChild("engineer").getValue() ) {
       checklist = me.crew.getChild("checklist").getValue();
       if( checklist == "holding" or checklist == "takeoff" or checklist == "landing" ) {
           takeoff = constant.TRUE;
       }
       else {
           takeoff = constant.FALSE;
       }

       # rotation, then translation, in 2 distinct steps
       if( takeoff ) {
           if( me.movement.getChild("stowe-norm").getValue() == 0.0 ) {
               targetdeg = me.TAKEOFFDEG; 
               targetm = me.TAKEOFFM; 

               if( me.headdeg != targetdeg ) {
                   me.rotate( targetdeg );
               }

               elsif( me.headm != targetm ) {
                   me.translate( targetm );
               }
           }
       }

       # reversed order
       else {
           targetdeg = me.FLIGHTDEG; 
           targetm = me.FLIGHTM; 

           if( me.headm != targetm ) {
               me.translate( targetm );
           }

           elsif( me.headdeg != targetdeg ) {
               me.rotate( targetdeg );
           }
       }
   }

   # clears engineer movement
   else {
       me.reset();
   }
}

Engineerseat.reset = func {
    me.translateclear();
    me.rotateclear();
}

Engineerseat.rotate = func( targetdeg ) {
    me.headdeg = targetdeg;

    seatdeg = me.movement.getChild("seat-deg").getValue();
    if( seatdeg == me.STATICDEG ) {
        viewdeg = me.slave["engineer"].getChild("heading-deg").getValue();

        # correction by engineer view rotation
        movementdeg = targetdeg - viewdeg;
        movementdeg = constant.crossnorth( movementdeg );
        movementsec = constant.abs( movementdeg / me.SEATDEGPSEC );
    }

    # clears engineer rotation
    else {
        movementdeg = me.STATICDEG;
        movementsec = constant.abs( seatdeg / me.SEATDEGPSEC );
    }


    interpolate("/systems/human/engineer/seat-deg", movementdeg, movementsec );
}

Engineerseat.translate = func( targetm ) {
    me.headm = targetm;

    interpolate("/systems/human/engineer/seat-x-m", me.headm, me.BOGGIESEC );
}

Engineerseat.rotateclear = func {
    # except during rotation (should not happen)
    me.headdeg = me.FLIGHTDEG;
    me.movement.getChild("seat-deg").setValue(me.STATICDEG);
}

Engineerseat.translateclear = func {
   seatm = me.movement.getChild("seat-x-m").getValue();

   # except during translation
   if( seatm == me.FLIGHTM or seatm == me.TAKEOFFM ) {
       me.headm = me.FLIGHTM;
       me.movement.getChild("seat-x-m").setValue(me.STATICM);
   }
}


# =========
# SEAT RAIL
# =========

SeatRail = {};

SeatRail.new = func {
   obj = { parents : [SeatRail,System],

           RAILSEC : 5.0,

           engineer : nil,
           human : nil,

           ENGINEERDEG : 270,

           FLIGHT : 0.0,
           PARK : 1.0
         };

   obj.init();

   return obj;
}

SeatRail.init = func {
   me.init_ancestor("/systems/human");

   me.engineer = props.globals.getNode("/systems/human/engineer");
   me.human = props.globals.getNode("/systems/human");
}

SeatRail.toggle = func( seat ) {
   canstowe = constant.TRUE;

   if( seat == "engineer" ) {
       if( me.engineer.getChild("stowe-norm").getValue() == 0 ) {
           # except if seat has moved
           if( me.engineer.getChild("seat-deg").getValue() > 0 or
               me.engineer.getChild("seat-x-m").getValue() > 0 or
               me.slave["engineer"].getChild("heading-deg").getValue() != me.ENGINEERDEG ) {
               canstowe = constant.FALSE;
           }
       }
   }

   if( canstowe ) {
       me.roll("/systems/human/" ~ seat ~ "/stowe-norm");
   }
}

SeatRail.is_stowed = func( seat ) {
   if( me.human.getNode(seat).getChild("stowe-norm").getValue() == 1.0 ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# roll on rail
SeatRail.roll = func( path ) {
   pos = getprop(path);
   if( pos == me.FLIGHT ) {
       interpolate( path, me.PARK, me.RAILSEC );
   }
   elsif( pos == me.PARK ) {
       interpolate( path, me.FLIGHT, me.RAILSEC );
   }
}
