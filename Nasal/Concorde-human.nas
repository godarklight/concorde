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
   var obj = { parents : [Crewhuman],

           crew : nil,
           crewcontrol : nil,
           human : nil,
           humancontrol : nil,
           voices : nil,

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

Crewhuman.init_ancestor = func( path, member, voice ) {
   var obj = Crewhuman.new();

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
}

Crewhuman.talkrates = func {
   # opens the mooth according to phrase length
   var phrase = me.voices.getChild(me.crewvoice).getValue();
   var steps = size( phrase ) * me.CHARACTERSEC;

   return steps;
}

Crewhuman.endtalk = func {
   me.crew.getChild("teeth").setValue(constant.FALSE);
}

Crewhuman.eyesrates = func {
   var steps = 0.0;
   var factor = 0.0;

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
   var headingdeg = 0.0;
   var pitchdeg = 0.0;
   var steps = 0.0;

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
   var steps = me.talkrates();

   settimer(func { me.endtalk(); }, steps);
}

Crewhuman.eyescron = func {
   var steps = me.eyesrates();

   if( steps > 0 ) {
       settimer(func { me.eyescron(); }, steps);
   }
}

Crewhuman.headcron = func {
   var steps = me.headrates();

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
   var obj = { parents : [Copilothuman,Crewhuman]
         };

   obj.init();

   return obj;
}

Copilothuman.init = func {
   me.init_ancestor( "/systems/human/copilot", "copilot", "copilot" );
}


# ==============
# HUMAN ENGINEER
# ==============
Engineerhuman = {};

Engineerhuman.new = func {
   var obj = { parents : [Engineerhuman,Crewhuman],

           seat : Engineerseat.new()
         };

   obj.init();

   return obj;
}

Engineerhuman.init = func {
   me.init_ancestor( "/systems/human/engineer", "engineer", "pilot" );
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
   var obj = { parents : [Nightlighting,System],

           lightingsystem : nil,

           human : nil,

           DAYNORM : 0.0,

           lightlevel : 0.0,
           lightlow : constant.FALSE,

           NIGHTRAD : 1.57,                        # sun below horizon

           completed : constant.TRUE,
           night : constant.FALSE
         };

  obj.init();

  return obj;
}

Nightlighting.init = func {
    me.init_ancestor("/systems/human");

    me.human = props.globals.getNode("/controls/human/lighting");
}

Nightlighting.set_relation = func( lighting ) {
    me.lightingsystem = lighting;
}

Nightlighting.copilot = func( task ) {
   # optional
   if( me.human.getChild("night").getValue() ) {

       # only once, can be customized by user
       if( me.has_task() ) {
           me.light( "copilot" );

           me.completed = constant.FALSE;

           # flood lights
           if( task.can() ) {
               if( me.slave["lighting-copilot"].getChild("flood-norm").getValue() != me.lightlevel ) {
                   me.slave["lighting-copilot"].getChild("flood-norm").setValue( me.lightlevel );
                   me.lightingsystem.floodexport();
                   task.toggleclick("flood-light");
               }
           }

           # level of warning lights
           if( task.can() ) {
               if( me.slave["lighting-copilot"].getChild("low").getValue() != me.lightlow ) {
                   me.slave["lighting-copilot"].getChild("low").setValue( me.lightlow );
                   task.toggleclick("panel-light");
               }
           }
           if( task.can() ) {
               if( me.slave["lighting"].getNode("center").getChild("low").getValue() != me.lightlow ) {
                   me.slave["lighting"].getNode("center").getChild("low").setValue( me.lightlow );
                   task.toggleclick("center-light");
               }
           }
           if( task.can() ) {
               if( me.slave["lighting"].getNode("afcs").getChild("low").getValue() != me.lightlow ) {
                   me.slave["lighting"].getNode("afcs").getChild("low").setValue( me.lightlow );
                   task.toggleclick("afcs-light");
                   me.completed = constant.TRUE;
               }
           }
       }
   }
}

Nightlighting.engineer = func( task ) {
   # optional
   if( me.human.getChild("night").getValue() ) {

       # only once, can be customized by user
       if( me.has_task() ) {
           me.light( "engineer" );

           me.completed = constant.FALSE;

           # flood lights
           if( task.can() ) {
               if( me.slave["lighting-engineer"].getChild("flood-norm").getValue() != me.lightlevel ) {
                   me.slave["lighting-engineer"].getChild("flood-norm").setValue( me.lightlevel );
                   me.lightingsystem.floodexport();
                   task.toggleclick("flood-light");
               }
           }

           # level of warning lights
           if( task.can() ) {
               if( me.slave["lighting-engineer"].getNode("forward").getChild("low").getValue() != me.lightlow ) {
                   me.slave["lighting-engineer"].getNode("forward").getChild("low").setValue( me.lightlow );
                   task.toggleclick("forward-light");
               }
           }
           if( task.can() ) {
               if( me.slave["lighting-engineer"].getNode("center").getChild("low").getValue() != me.lightlow ) {
                   me.slave["lighting-engineer"].getNode("center").getChild("low").setValue( me.lightlow );
                   task.toggleclick("center-light");
               }
           }
           if( task.can() ) {
               if( me.slave["lighting-engineer"].getNode("aft").getChild("low").getValue() != me.lightlow ) {
                   me.slave["lighting-engineer"].getNode("aft").getChild("low").setValue( me.lightlow );
                   task.toggleclick("aft-light");
                   me.completed = constant.TRUE;
               }
           }
       }
   }
}

Nightlighting.light = func( path ) {
   var NIGHTNORM = me.human.getChild(path).getValue();

   me.lightlevel = me.DAYNORM;
   me.lightlow = constant.FALSE;

   if( me.night ) {
       me.lightlevel = NIGHTNORM;
       me.lightlow = constant.TRUE;
   }
   else {
       me.lightlevel = me.DAYNORM;
       me.lightlow = constant.FALSE;
   }
}

Nightlighting.is_change = func {
   var change = constant.FALSE;

   if( me.noinstrument["sun"].getValue() > me.NIGHTRAD ) {
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

Nightlighting.has_task = func {
   var result = constant.FALSE;

   if( me.is_change() or !me.completed ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}


# =============
# ENGINEER SEAT
# =============

Engineerseat = {};

Engineerseat.new = func {
   var obj = { parents : [Engineerseat,System],

           SEATDEGPSEC : 25.0,
           BOGGIESEC : 5.0,

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

   me.movement = props.globals.getNode("/systems/human/engineer");

   me.headdeg = me.slave["engineer"].getChild("heading-deg").getValue();
}

Engineerseat.schedule = func {
   var takeoff = constant.FALSE;
   var targetdeg = 0.0;
   var targetm = 0.0;
   var checklist = "";

   # restores seat position after a swap to the engineer view,
   # where the seat rotates with view
   if( !me.slave["seat"].getChild("engineer").getValue() ) {
       checklist = me.slave["voice"].getChild("checklist").getValue();
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
    var viewdeg = 0.0;
    var movementdeg = 0.0;
    var movementsec = 0.0;
    var seatdeg = me.movement.getChild("seat-deg").getValue();

    me.headdeg = targetdeg;

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
   var seatm = me.movement.getChild("seat-x-m").getValue();

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
   var obj = { parents : [SeatRail,System],

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
   var canstowe = constant.TRUE;

   if( seat == "engineer" ) {
       if( me.engineer.getChild("stowe-norm").getValue() == me.FLIGHT ) {
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
   var result = constant.FALSE;

   if( me.human.getNode(seat).getChild("stowe-norm").getValue() == me.PARK ) {
       result = constant.TRUE;
   }

   return result;
}

# roll on rail
SeatRail.roll = func( path ) {
   var pos = getprop(path);

   if( pos == me.FLIGHT ) {
       interpolate( path, me.PARK, me.RAILSEC );
   }
   elsif( pos == me.PARK ) {
       interpolate( path, me.FLIGHT, me.RAILSEC );
   }
}
