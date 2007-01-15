# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# =====
# SEATS
# =====

Seats = {};

Seats.new = func {
   obj = { parents : [Seats],

           controls : nil,
           theseats : nil,
           thecrews : nil,

           lookup : { "engineer" : 0, "overhead" : 0, "copilot" : 0, "steward" : 0, "observer" : 0 },
           names : [ "engineer", "overhead", "copilot", "steward", "observer" ],
           nb_seats : 5,

           firstseatview : 0,
           fullcokpit : constant.FALSE,

           initial : { "observer" : {"x" : 0, "y" : 0, "z" : 0 } }
         };

   obj.init();

   return obj;
};

Seats.init = func {
   me.controls = props.globals.getNode("/controls/seat");
   me.theseats = props.globals.getNode("/systems/seat");
   me.thecrews = props.globals.getNode("/controls/audio/crew");

   theviews = props.globals.getNode("/sim").getChildren("view");
   last = size(theviews);

   # retrieve the index as created by FG
   for( i = 0; i < last; i=i+1 ) {
        child = theviews[i].getChild("name");

        # nasal doesn't see yet the views of preferences.xml
        if( child != nil ) {
            name = child.getValue();
            if( name == "Engineer View" ) {
                me.lookup["engineer"] = i;
                me.firstseatview = i;
            }
            elsif( name == "Overhead View" ) {
                me.lookup["overhead"] = i;
            }
            elsif( name == "Copilot View" ) {
                me.lookup["copilot"] = i;
           }
           elsif( name == "Steward View" ) {
                me.lookup["steward"] = i;
           }
           elsif( name == "Observer View" ) {
                me.lookup["observer"] = i;
                me.save_position( "observer", theviews[i] );
           }
        }
   }

   # default
   me.fullcockpit = me.controls.getChild("all").getValue();
}

Seats.fullexport = func {
   if( me.fullcockpit ) {
       me.fullcockpit = constant.FALSE;
   }
   else {
       me.fullcockpit = constant.TRUE;
   }

   me.controls.getChild("all").setValue( me.fullcockpit );
}

Seats.restorefull = func {
   found = constant.FALSE;
   index = getprop("/sim/current-view/view-number");
   if( index == 0 or index >= me.firstseatview ) {
       found = constant.TRUE;
   }

   # systematically disable all instruments in external view
   if( found ) {
       me.controls.getChild("all").setValue( me.fullcockpit );
   }
   else {
       me.controls.getChild("all").setValue( constant.FALSE );
   }
}

Seats.viewexport = func( name ) {
   if( name != "captain" ) {

       # swap to view
       if( !me.theseats.getChild(name).getValue() ) {
           index = me.lookup[name];
           setprop("/sim/current-view/view-number", index);
           me.theseats.getChild(name).setValue(constant.TRUE);
           me.theseats.getChild("captain").setValue(constant.FALSE);
       }

       # return to captain view
       else {
           setprop("/sim/current-view/view-number", 0);
           me.theseats.getChild(name).setValue(constant.FALSE);
           me.theseats.getChild("captain").setValue(constant.TRUE);
       }

       # disable all other views
       for( i = 0; i < me.nb_seats; i=i+1 ) {
            if( name != me.names[i] ) {
                me.theseats.getChild(me.names[i]).setValue(constant.FALSE);
            }
       }
   }

   # captain view
   else {
       setprop("/sim/current-view/view-number",0);
       me.theseats.getChild("captain").setValue(constant.TRUE);

        # disable all other views
        for( i = 0; i < me.nb_seats; i=i+1 ) {
             me.theseats.getChild(me.names[i]).setValue(constant.FALSE);
        }
   }

   me.audioexport();

   me.controls.getChild("all").setValue( me.fullcockpit );
}

Seats.scrollexport = func{
   # number of views = 11
   nbviews = getprop("/sim/number-views");

   # by default, returns to captain view
   targetview = nbviews;

   # if specific view, step once more to ignore captain view 
   for( i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            targetview = me.lookup[name];
            break;
        }
   }

   # number of default views (preferences.xml) = 6
   nbdefaultviews = nbviews - me.nb_seats;

   # last default view (preferences.xml) = 5
   lastview = nbdefaultviews - 1;

   # moves to seat
   if( getprop("/sim/current-view/view-number") == lastview ) {
       step = targetview - nbdefaultviews;
       view.stepView(step);
       view.stepView(1);
   }

   # returns to captain
   elsif( getprop("/sim/current-view/view-number") == targetview ) {
       step = nbviews - targetview;
       view.stepView(step);
       view.stepView(1);
   }

   # default
   else {
       view.stepView(1);
   }

   me.audioexport();

   me.restorefull();
}

Seats.scrollreverseexport = func{
   # number of views = 11
   nbviews = getprop("/sim/number-views");

   # by default, returns to captain view
   targetview = 0;

   # if specific view, step once more to ignore captain view 
   for( i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            targetview = me.lookup[name];
            break;
        }
   }

   # number of default views (preferences.xml) = 6
   nbdefaultviews = nbviews - me.nb_seats;

   # last view = 10
   lastview = nbviews - 1;

   # moves to seat
   if( getprop("/sim/current-view/view-number") == 1 ) {
       # to 0
       view.stepView(-1);
       # to last
       view.stepView(-1);
       step = targetview - lastview;
       view.stepView(step);
   }

   # returns to captain
   elsif( getprop("/sim/current-view/view-number") == targetview ) {
       step = nbdefaultviews - targetview;
       view.stepView(step);
       view.stepView(-1);
   }

   # default
   else {
       view.stepView(-1);
   }

   me.audioexport();

   me.restorefull();
}

# forwards is positiv
Seats.movelengthexport = func( step ) {
   if( me.move() ) {
       headdeg = getprop("/sim/current-view/goal-heading-offset-deg");

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = -1;
       }
       else {
           prop = "/sim/current-view/x-offset-m";
           sign = 1;
       }

       pos = getprop(prop);
       pos = pos + sign * step;
       setprop(prop,pos);

       result = constant.TRUE;
   }

   else {
       result = constant.FALSE;
   }

   return result;
}

# left is negativ
Seats.movewidthexport = func( step ) {
   if( me.move() ) {
       headdeg = getprop("/sim/current-view/goal-heading-offset-deg");

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = 1;
       }
       else {
           prop = "/sim/current-view/z-offset-m";
           sign = -1;
       }

       pos = getprop(prop);
       pos = pos + sign * step;
       setprop(prop,pos);

       result = constant.TRUE;
   }

   else {
       result = constant.FALSE;
   }

   return result;
}

# up is positiv
Seats.moveheightexport = func( step ) {
   if( me.move() ) {
       pos = getprop("/sim/current-view/y-offset-m");
       pos = pos + step;
       setprop("/sim/current-view/y-offset-m",pos);

       result = constant.TRUE;
   }

   else {
       result = constant.FALSE;
   }

   return result;
}

# backup initial position
Seats.save_position = func( name, view ) {
   config = view.getNode("config");
   me.initial[name]["x"] = config.getChild("x-offset-m").getValue();
   me.initial[name]["y"] = config.getChild("y-offset-m").getValue();
   me.initial[name]["z"] = config.getChild("z-offset-m").getValue();
}

Seats.restore_position = func( name ) {
   setprop("/sim/current-view/x-offset-m",me.initial[name]["x"]);
   setprop("/sim/current-view/y-offset-m",me.initial[name]["y"]);
   setprop("/sim/current-view/z-offset-m",me.initial[name]["z"]);
}

Seats.move = func {
   if( me.theseats.getChild("observer").getValue() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# restore view
Seats.restoreexport = func {
   if( me.theseats.getChild("observer").getValue() ) {
       me.restore_position( "observer" );
   }
}

Seats.sendaudio = func( adf1, adf2, comm1, comm2, nav1, nav2, marker ) {
   setprop("/instrumentation/adf[0]/volume-norm",adf1);
   setprop("/instrumentation/adf[1]/volume-norm",adf2);
   setprop("/instrumentation/comm[0]/volume",comm1);
   setprop("/instrumentation/comm[1]/volume",comm2);
   setprop("/instrumentation/nav[1]/volume",nav1);
   setprop("/instrumentation/nav[2]/volume",nav2);
   setprop("/instrumentation/marker-beacon/audio-btn",marker);
}

Seats.audioexport = func {
   # hears nothing outside
   if( !getprop("/sim/current-view/internal") ) {
       me.sendaudio( 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, constant.FALSE );
   }

   # each crew has an audio panel
   else {
       audio = nil;
       if( me.theseats.getChild("captain").getValue() ) {
           audio = me.thecrews.getNode("captain");
       }
       elsif( me.theseats.getChild("copilot").getValue() ) {
           audio = me.thecrews.getNode("copilot");
       }
       elsif( me.theseats.getChild("engineer").getValue() ) {
           audio = me.thecrews.getNode("engineer");
       }

       if( audio != nil ) {
           adf1  = audio.getNode("adf[0]/volume").getValue();
           adf2  = audio.getNode("adf[1]/volume").getValue();
           comm1 = audio.getNode("comm[0]/volume").getValue();
           comm2 = audio.getNode("comm[1]/volume").getValue();
           nav1  = audio.getNode("nav[0]/volume").getValue();
           nav2  = audio.getNode("nav[1]/volume").getValue();
           me.sendaudio( adf1, adf2, comm1, comm2, nav1, nav2, constant.TRUE );
       }
       else {
           me.sendaudio( 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, constant.TRUE );
       }
   }
}


# =====
# DOORS
# =====

Doors = {};

Doors.new = func {
   obj = { parents : [Doors],
# 10 s, door closed
           flightdeck : aircraft.door.new("controls/doors/flight-deck", 10.0),
# 4 s, deck out
           engineerdeck : aircraft.door.new("controls/doors/engineer-deck", 4.0)
         };

# user customization
   obj.init();

   return obj;
};

Doors.init = func {
   if( getprop("/controls/doors/flight-deck/opened") ) {
       me.flightdeck.toggle();
   }
   if( !getprop("/controls/doors/engineer-deck/out") ) {
       me.engineerdeck.toggle();
   }
}

Doors.flightdeckexport = func {
   me.flightdeck.toggle();
}

Doors.engineerdeckexport = func {
   me.engineerdeck.toggle();
}


# ====
# MENU
# ====

Menu = {};

Menu.new = func {
   obj = { parents : [Menu],

           crew : nil,
           fuel : nil,
           radios : nil,
           instruments : [ nil, nil, nil ],
           navigation : nil,
           systems : nil,
           menu : nil
         };

   obj.init();

   return obj;
};

Menu.init = func {
   me.menu = gui.Dialog.new("/sim/gui/dialogs/Concorde/menu/dialog",
                            "Aircraft/Concorde/Dialogs/Concorde-menu.xml");
   me.crew = gui.Dialog.new("/sim/gui/dialogs/Concorde/crew/dialog",
                            "Aircraft/Concorde/Dialogs/Concorde-crew.xml");
   me.fuel = gui.Dialog.new("/sim/gui/dialogs/Concorde/fuel/dialog",
                            "Aircraft/Concorde/Dialogs/Concorde-fuel.xml");

   me.instruments[0] = gui.Dialog.new("/sim/gui/dialogs/Concorde/instruments[0]/dialog",
                                      "Aircraft/Concorde/Dialogs/Concorde-instruments.xml");
   for( i = 1; i <= 2; i=i+1 ) {
      j = i + 1;
      me.instruments[i] = gui.Dialog.new("/sim/gui/dialogs/Concorde/instruments[" ~ i ~ "]/dialog",
                                         "Aircraft/Concorde/Dialogs/Concorde-instruments" ~ j ~ ".xml");
   }

   me.navigation = gui.Dialog.new("/sim/gui/dialogs/Concorde/navigation/dialog",
                                  "Aircraft/Concorde/Dialogs/Concorde-navigation.xml");

   me.radios = gui.Dialog.new("/sim/gui/dialogs/Concorde/radios/dialog",
                            "Aircraft/Concorde/Dialogs/Concorde-radios.xml");
   me.systems = gui.Dialog.new("/sim/gui/dialogs/Concorde/systems/dialog",
                               "Aircraft/Concorde/Dialogs/Concorde-systems.xml");
}


# ================
# VIRTUAL ENGINEER
# ================

VirtualEngineer = {};

VirtualEngineer.new = func {
   obj = { parents : [VirtualEngineer], 

           autopilotsystem : nil,
           fuelsystem : nil,

           GROUNDSEC : 30.0,
           CRUISESEC : 15.0,
           rates : 0.0,

           SAFEFT : 1500.0,

           aglft : 0.0,

           CRUISEMACH : 1.95,

           SUBSONICKT : 480,                                 # estimated ground speed
           FLIGHTKT : 150,                                   # minimum ground speed

           grounkt : 0,

           MAXPERCENT : 53.6,                                # maximum on ground
           CGPERCENT : 0.3,

           crew : nil,
           crewcontrol : nil,
           engineer : nil,
           engines : nil,
           waypoints : nil,
           route : nil,

           activ : constant.FALSE,
           state : "",

           SUBSONICKGPH : 20000,                                # subsonic consumption

           kgph : 0,

           NOFUELKG : -999,

           totalkg : 0,
           estimatedfuelkg : [ 0.0, 0.0, 0.0 ],

           slave : { "cg" : nil, "fuel" : nil, "ins" : nil },
           noinstrument : { "agl" : "", "altitude" : "", "mach" : "" }
         };

    obj.init();

    return obj;
}

VirtualEngineer.init = func {
    propname = getprop("/systems/crew/engineer/slave/cg");
    me.slave["cg"] = props.globals.getNode(propname);
    propname = getprop("/systems/crew/engineer/slave/fuel");
    me.slave["fuel"] = props.globals.getNode(propname);
    propname = getprop("/systems/crew/engineer/slave/ins");
    me.slave["ins"] = props.globals.getNode(propname);

    me.noinstrument["agl"] = getprop("/systems/crew/engineer/noinstrument/agl");
    me.noinstrument["altitude"] = getprop("/systems/crew/engineer/noinstrument/altitude");
    me.noinstrument["mach"] = getprop("/systems/crew/engineer/noinstrument/mach");

    me.crew = props.globals.getNode("/systems/crew");
    me.crewcontrol = props.globals.getNode("/controls/crew");
    me.engineer = props.globals.getNode("/systems/crew/engineer");
    me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
    me.waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
    me.route = props.globals.getNode("/systems/crew/engineer/route").getChildren("wp");

    settimer( engineercron, me.CRUISESEC );
}

VirtualEngineer.set_relation = func( autopilot, fuel ) {
    me.autopilotsystem = autopilot;
    me.fuelsystem = fuel;
}

VirtualEngineer.toggleexport = func {
   if( me.crew.getChild("serviceable").getValue() ) {
       if( !me.crewcontrol.getChild("engineer").getValue() ) {
           me.crewcontrol.getChild("engineer").setValue(constant.TRUE);
       
           me.supervisor();
       }
       else {
           me.crewcontrol.getChild("engineer").setValue(constant.FALSE);
       }

       me.crew.getChild("minimized").setValue(constant.FALSE);
   }
}

engineercron = func {
   engineercrew.schedule();
}

VirtualEngineer.schedule = func {
    if( me.crew.getChild("serviceable").getValue() ) {
        me.supervisor();
    }
    else {
        me.rates = me.GROUNDSEC;
    }

    me.navigation();

    settimer( engineercron, me.rates );
}

# for FDM debug
VirtualEngineer.navigation = func {
   groundfps = me.slave["ins"].getChild("ground-speed-fps").getValue();
   if( groundfps == nil ) {
       groundfps = 0.0;
   }
   me.groundkt = groundfps * constant.FPSTOKT;

   # waypoint
   id = me.waypoints[0].getChild("id").getValue();
   distnm = me.waypoints[0].getChild("dist").getValue();
   me.estimatefuel( 0, id, distnm );

   # next
   id = me.waypoints[1].getChild("id").getValue();
   distnm = me.waypoints[1].getChild("dist").getValue();
   me.estimatefuel( 1, id, distnm );

   # last
   id = getprop("/autopilot/route-manager/wp-last/id"); 
   distnm = getprop("/autopilot/route-manager/wp-last/dist"); 
   me.estimatefuel( 2, id, distnm );


   # display
   for( i = 0; i < 3; i=i+1 ) {
        me.route[i].getChild("fuel-kg").setValue(me.estimatedfuelkg[i]);
   }
}

VirtualEngineer.estimatefuel = func( index, id, distnm ) {
   if( id != "" and distnm != nil ) {
       # refresh
       if( index == 0 ) {
           me.totalkg = me.slave["fuel"].getChild("total-kg").getValue();

           # on ground
           if( me.groundkt < me.FLIGHTKT ) {
               me.groundkt = me.SUBSONICKT;
               me.kgph = me.SUBSONICKGPH;
           }
           else {
               # gauge is NOT REAL
               me.kgph = me.slave["fuel"].getChild("fuel-flow-kg_ph").getValue();
           }
       }

       ratio = distnm / me.groundkt;
       fuelkg = me.kgph * ratio;
       fuelkg = me.totalkg - fuelkg;
       if( fuelkg < 0 ) {
           fuelkg = 0;
       }
   }
   else {
       fuelkg = me.NOFUELKG;
   }

   me.estimatedfuelkg[index] = fuelkg;
}

VirtualEngineer.supervisor = func {
    me.activ = constant.FALSE;
    me.rates = me.GROUNDSEC;

    if( me.crewcontrol.getChild("engineer").getValue() ) {
        me.state = "";

        me.aglft = getprop(me.noinstrument["agl"]);
        if( me.aglft > constantaero.APPROACHFT ) {
            me.rates = me.CRUISESEC;
        }

        checklist = me.crew.getChild("checklist").getValue();

        if( checklist == "taxi" ) {
            me.activ = constant.TRUE;
            me.afterlanding();
        }

        elsif( checklist != "gate" and checklist != "parking" ) {
            me.activ = constant.TRUE;
            me.flight();
        }

        me.engineer.getChild("state").setValue(me.state);
        me.engineer.getChild("time").setValue(getprop("/sim/time/gmt-string"));
    }

    me.engineer.getChild("activ").setValue(me.activ);
}

VirtualEngineer.flight = func {
    me.fuel();
    me.rating();
}

VirtualEngineer.afterlanding = func {
    me.fuel();
    me.rating();

    # taxi with outboard engines
    if( !me.engines[1].getChild("cutoff").getValue() or
        !me.engines[2].getChild("cutoff").getValue() ) {
        for( i=1; i<3; i=i+1 ) {
             me.engines[i].getChild("cutoff").setValue(constant.TRUE);
        }

        me.log("2engines");
    }
}

VirtualEngineer.rating = func {
    rating = "takeoff";
    flight = "climb";

    if( me.aglft > me.SAFEFT ) {
        rating = "flight";
    }

    if( me.autopilotsystem.has_altitude_hold() ) {
        flight = "cruise";
    }

    else {
        speedmach = getprop(me.noinstrument["mach"]);
        # see check-list
        if( speedmach > me.CRUISEMACH ) {
            flight = "cruise";
        }
    }

    me.applyrating( flight, rating );
}

VirtualEngineer.applyrating = func( flight, rating ) {
    for( i=0; i<4; i=i+1 ) {
         flightnow = me.engines[i].getChild("rating-flight").getValue();
         if( flightnow != flight ) {
             me.engines[i].getChild("rating-flight").setValue(flight);
         }

         # flight once safe
         ratingnow = me.engines[i].getChild("rating").getValue();
         if( ratingnow != rating and rating == "flight" ) {
             if( !getprop("/controls/gear/gear-down") ) {
                 me.engines[i].getChild("rating").setValue(rating);
             }
         }
    }
}

VirtualEngineer.fuel = func {
    if( me.slave["cg"].getChild("serviceable").getValue() ) {
        max = me.slave["cg"].getChild("max-percent").getValue();
        min = me.slave["cg"].getChild("min-percent").getValue();
        cg = me.slave["cg"].getChild("percent").getValue();

        forward = constant.FALSE;
        aft = constant.FALSE;
        engine = constant.FALSE;
        afttrim = constant.FALSE;

        # emergency
        if( cg < min ) {
            me.log("below-min");
            aft = constant.TRUE;
            engine = constant.TRUE;
            afttrim = constant.TRUE;
        }
        elsif( cg > max ) {
            me.log("above-max");
            forward = constant.TRUE;
            engine = constant.TRUE;
        }

        # above 250 kt beyond 10000 ft
        elsif( getprop(me.noinstrument["altitude"]) > constantaero.APPROACHFT ) {
            mean = min + ( max - min ) / 2;

            if( cg < mean - me.CGPERCENT ) {
                me.log("aft");
                aft = constant.TRUE;
                engine = constant.TRUE;
             }

             # don't move on ground, if within limits
             elsif( cg > mean + me.CGPERCENT and cg > me.MAXPERCENT ) {
                me.log("forward");
                forward = constant.TRUE;
                engine = constant.TRUE;
             }
        }

        me.applyfuel( forward, aft, engine, afttrim );
    }
}

VirtualEngineer.applyfuel = func( forward, aft, engine, afttrim) {
    # pumps
    empty5 = me.fuelsystem.empty("5");
    empty5A = me.fuelsystem.empty("5A");
    empty6 = me.fuelsystem.empty("6");
    empty7 = me.fuelsystem.empty("7");
    empty7A = me.fuelsystem.empty("7A");
    empty8 = me.fuelsystem.empty("8");
    empty9 = me.fuelsystem.empty("9");
    empty10 = me.fuelsystem.empty("10");
    empty11 = me.fuelsystem.empty("11");

    me.fuelsystem.togglepump( "5", constant.TRUE );
    me.fuelsystem.togglepump( "5A", !empty5A );
    me.fuelsystem.togglepump( "6", !empty6 );
    me.fuelsystem.togglepump( "7", constant.TRUE );
    me.fuelsystem.togglepump( "7A", !empty7A );
    me.fuelsystem.togglepump( "8", !empty8 );
    me.fuelsystem.togglepump( "9", constant.TRUE );
    me.fuelsystem.togglepump( "10", !empty10 );
    me.fuelsystem.togglepump( "11", constant.TRUE );


    # aft trim
    me.fuelsystem.toggleafttrim( afttrim );


    # transfers auxilliary tanks
    auxilliary = constant.FALSE;
    if( empty5 and empty6 ) {
        if( !empty5A ) {
            auxilliary = constant.TRUE;
            me.fuelsystem.toggletransvalve( "5A", constant.TRUE );
        }
    }
    if( empty7 and empty8 ) {
        if( !empty7A ) {
            auxilliary = constant.TRUE;
            me.fuelsystem.toggletransvalve( "7A", constant.TRUE );
        }
    }
    if( auxilliary ) {
        me.log("auxilliary");
    }

    # low level (emergency)
    if( me.fuelsystem.lowlevel() ) {
        # avoid aft CG  
        if( ( forward or !aft ) and !empty11 ) {
            me.log("low-level");
            me.fuelsystem.toggleengine( constant.TRUE );
            me.fuelsystem.toggleforward( constant.TRUE );
        }
        elsif( !empty9 or !empty10 ) {
            me.log("low-level");
            me.fuelsystem.toggleengine( constant.TRUE );
            me.fuelsystem.toggleaft( constant.TRUE );
        }
        # last fuel
        elsif( !empty11 ) {
            me.log("low-level");
            me.fuelsystem.toggleengine( constant.TRUE );
            me.fuelsystem.toggleforward( constant.TRUE );
        }
        else {
            me.fuelsystem.toggleengine( constant.FALSE );
        }
    }

    # aft transfert
    elsif( aft ) {
        if( !empty9 or !empty10 ) {
            if( !me.fuelsystem.full( "11" ) ) {
                me.fuelsystem.toggleengine( constant.FALSE );
            }
            elsif( engine ) {
                me.fuelsystem.toggleengine( constant.TRUE );
            }
            me.fuelsystem.toggleaft( constant.TRUE );
        }
        else {
            me.fuelsystem.toggleengine( constant.FALSE );
        }
    }

    # forward transfert
    elsif( forward ) {
        if( !empty11 ) {
            if( !me.fuelsystem.full( "9" ) ) {
                me.fuelsystem.toggleengine( constant.FALSE );
            }
            elsif( engine ) {
                me.fuelsystem.toggleengine( constant.TRUE );
            }
            me.fuelsystem.toggleforward( constant.TRUE );
        }
        else {
            me.fuelsystem.toggleengine( constant.FALSE );
        }
    }

    # no transfert
    else {
        me.fuelsystem.toggleengine( constant.FALSE );
    }
}

VirtualEngineer.log = func( message ) {
    me.state = me.state ~ " " ~ message;
}


# ===============
# VIRTUAL COPILOT
# ===============

VirtualCopilot = {};

VirtualCopilot.new = func {
   obj = { parents : [VirtualCopilot],

           autopilotsystem : nil,
 
           copilot : nil,
           crew : nil,
           crewcontrol : nil,
           flaps : nil,
           lighting : nil,

           CRUISESEC : 30.0,
           TAKEOFFSEC : 5.0,
           rates : 0.0,

           SOUNDMACH : 1.0,
           GEARKT : 220.0,

           speedkt : 0.0,

           MACHFT : 25000.0,                              # altitude for Mach speed
           NOSEFT : 600.0,                                # nose retraction
           GEARFT : 250.0,                                # gear retraction
           MARGINFT : 100.0,

           aglft : 0.0,
           altitudeft : 0.0,

           activ : constant.FALSE,
           emergency : constant.FALSE,
           state : "",
           checklist : "",

           slave : { "asi" : nil },
           noinstrument : { "agl" : "", "altitude" : "", "mach" : "" }
         };

   obj.init();

   return obj;
};

VirtualCopilot.init = func {
   me.copilot = props.globals.getNode("/systems/crew/copilot");
   me.crew = props.globals.getNode("/systems/crew");
   me.crewcontrol = props.globals.getNode("/controls/crew");
   me.flaps = props.globals.getNode("/sim/flaps");
   me.lighting = props.globals.getNode("/controls/lighting");

   propname = getprop("/systems/crew/copilot/slave/asi");
   me.slave["asi"] = props.globals.getNode(propname);

   me.noinstrument["agl"] = getprop("/systems/crew/copilot/noinstrument/agl");
   me.noinstrument["altitude"] = getprop("/systems/crew/copilot/noinstrument/altitude");
   me.noinstrument["mach"] = getprop("/systems/crew/copilot/noinstrument/mach");

   settimer( copilotcron, me.TAKEOFFSEC );
}

VirtualCopilot.set_relation = func( autopilot ) {
   me.autopilotsystem = autopilot;
}

VirtualCopilot.toggleexport = func {
   if( me.crew.getChild("serviceable").getValue() ) {
       if( !me.crewcontrol.getChild("copilot").getValue() ) {
           me.crewcontrol.getChild("copilot").setValue(constant.TRUE);
       
           me.supervisor();
       }
       else {
           me.crewcontrol.getChild("copilot").setValue(constant.FALSE);
       }

       me.crew.getChild("minimized").setValue(constant.FALSE);
   }
}

copilotcron = func {
   copilotcrew.schedule();
}

VirtualCopilot.schedule = func {
   if( me.crew.getChild("serviceable").getValue() ) {
       me.supervisor();
   }
   else {
       me.rates = me.CRUISESEC;
   }

   settimer( copilotcron, me.rates );
}

VirtualCopilot.supervisor = func {
   me.activ = constant.FALSE;
   me.emergency = constant.FALSE;
   me.rates = me.CRUISESEC;

   if( me.crewcontrol.getChild("copilot").getValue() ) {
       me.state = "";
       me.checklist = me.crew.getChild("checklist").getValue();

       me.altitudeft = getprop(me.noinstrument["altitude"]);

       # 4 engines flame out
       if( me.engine4flameout() ) {
       }

       # normal procedures
       elsif ( me.normal() ) {
       }

       else {
           me.autopilotsystem.real();
       }

       me.copilot.getChild("state").setValue(me.state);
       me.copilot.getChild("time").setValue(getprop("/sim/time/gmt-string"));
   }

   else {
       me.autopilotsystem.real();
   }

   me.crew.getChild("emergency").setValue(me.emergency);
   me.copilot.getChild("activ").setValue(me.activ);
}

VirtualCopilot.engine4flameout = func {
   # hold heading and speed, during engine start
   if( me.altitudeft > constantaero.APPROACHFT and me.checklist == "flight" ) {
       if( me.autopilotsystem.no_voltage() ) {
           me.activ = constant.TRUE;
           me.emergency = constant.TRUE;
           me.log("no-autopilot");

           me.autopilotsystem.virtual();
           me.autopilotsystem.apenable();

           me.keepheading();

           me.keepspeed();
       }
   }

   return me.activ;
}

# instrument failures ignored
VirtualCopilot.normal = func {
   if( me.checklist != "gate" and me.checklist != "parking" ) {
       if( getprop(me.noinstrument["mach"]) < me.SOUNDMACH ) {
           me.activ = constant.TRUE;

           me.speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();

           me.aglft = getprop(me.noinstrument["agl"]);

           if( me.checklist == "landing" ) {
               me.beforelanding();
               me.rates = me.TAKEOFFSEC;
           }
           elsif( me.checklist == "taxi" ) {
               me.afterlanding();
           }
           else {
               if( me.aglft <= constantaero.APPROACHFT ) {
                   me.rates = me.TAKEOFFSEC;
               }

               if( me.aglft <= me.GEARFT  ) {
                   me.beforetakeoff();
               }
               else {
                   me.aftertakeoff();
               }
           }
       }
   }

   return me.activ;
}

VirtualCopilot.beforetakeoff = func {
   me.nosevisor( constant.FALSE, constant.FALSE );
   me.landinglights( constant.FALSE );

   setprop("/instrumentation/takeoff-monitor/armed",constant.TRUE);
}

VirtualCopilot.aftertakeoff = func {
   me.landinggear( constant.FALSE );
   me.nosevisor( constant.FALSE, constant.FALSE );
   me.landinglights( constant.FALSE );

   setprop("/instrumentation/takeoff-monitor/armed",constant.FALSE);
}

VirtualCopilot.beforelanding = func {
   me.landinggear( constant.TRUE );
   me.nosevisor( constant.TRUE, constant.FALSE );
   me.landinglights( constant.TRUE );

   # disable
   if( getprop("/controls/gear/brake-parking-lever") ) {
       controls.applyParkingBrake(1);
   }

   # relocation in flight
   setprop("/instrumentation/takeoff-monitor/armed",constant.FALSE);
}

VirtualCopilot.afterlanding = func {
   me.nosevisor( constant.TRUE, constant.TRUE );
}

VirtualCopilot.keepspeed = func {
   if( me.altitudeft > me.MACHFT and !me.autopilotsystem.is_mach_pitch() ) {
       me.log("mach-pitch");
       me.autopilotsystem.apmachpitchexport();
   }
   elsif( me.altitudeft <= me.MACHFT and !me.autopilotsystem.is_speed_pitch() ) {
       me.log("speed-pitch");
       me.autopilotsystem.apspeedpitchexport();
   }
}

VirtualCopilot.keepheading = func {
   if( !me.autopilotsystem.is_lock_magnetic() ) {
       me.log("magnetic");
       me.autopilotsystem.apheadingholdexport();
   }
}

VirtualCopilot.landinggear = func( landing ) {
   if( !landing and me.aglft > me.GEARFT ) {
       if( me.speedkt > me.GEARKT ) {
           controls.gearDown(-1);
       }
   }
   elsif( landing and me.aglft < constantaero.LANDINGFT ) {
       if( me.speedkt < me.GEARKT ) {
           controls.gearDown(1);
       }
   }
}

VirtualCopilot.nosevisor = func( landing, taxi ) {
    change = constant.TRUE;

    # nose 5 degrees
    if( taxi ) {
        targetpos = 2;
    }

    elsif( !landing ) {
        if( me.aglft > me.NOSEFT ) {
            # visor up
            if( me.altitudeft > ( constantaero.APPROACHFT + me.MARGINFT ) ) {
                targetpos = 0;
            }
            # visor down
            elsif( me.altitudeft < ( constantaero.APPROACHFT - me.MARGINFT ) ) {
                targetpos = 1;
            }
            else {
                change = constant.FALSE;
            }
        }

        # nose 5 degrees
        else {
            targetpos = 2;
        }
    }

    elsif( landing ) {
       # nose 12 degress
       if( me.aglft < constantaero.LANDINGFT ) {
           targetpos = 3;
       }
       # visor down
       elsif( me.altitudeft < constantaero.APPROACHFT ) {
           targetpos = 1;
       }
    }

    # not to us to create the property
    if( change ) {
        child = me.flaps.getChild("current-setting");
        if( child == nil ) {
            currentpos = 0;
        }
        else {
            currentpos = child.getValue();
        }

        if( targetpos <= 1 or ( targetpos > 1 and me.speedkt < me.GEARKT ) ) {
            pos = targetpos - currentpos;
            if( pos != 0 ) {
                controls.flapsDown( pos );
                me.log("nose");
            }
        }
    }
}

VirtualCopilot.landinglights = func( landing ) {
    if( !landing and me.aglft > me.NOSEFT ) {
        me.landingtaxi( constant.FALSE );
        me.mainlanding( constant.FALSE );
    }

    # terminal area
    if( me.altitudeft <= constantaero.APPROACHFT ) {
        me.taxiturn( constant.TRUE );
    }
    else {
        me.taxiturn( constant.FALSE );
    }
}

VirtualCopilot.mainlanding = func( set ) {
    for( i=0; i < 2; i=i+1 ) {
         me.lighting.getNode("external/main-landing[" ~ i ~ "]/extend").setValue( set );
         me.lighting.getNode("external/main-landing[" ~ i ~ "]/on").setValue( set );
    }
}

VirtualCopilot.landingtaxi = func( set ) {
    for( i=0; i < 2; i=i+1 ) {
         me.lighting.getNode("external/landing-taxi[" ~ i ~ "]/extend").setValue( set );
         me.lighting.getNode("external/landing-taxi[" ~ i ~ "]/on").setValue( set );
    }
}

VirtualCopilot.taxiturn = func( set ) {
    for( i=0; i < 2; i=i+1 ) {
         me.lighting.getNode("external/taxi-turn[" ~ i ~ "]/on").setValue( set );
    }
}

VirtualCopilot.log = func( message ) {
    me.state = me.state ~ " " ~ message;
}
