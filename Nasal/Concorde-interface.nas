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
           positions : nil,
           theseats : nil,

           audio : AudioPanel.new(),

           lookup : {},
           names : {},
           nb_seats : 0,

           firstseat : constant.FALSE,
           firstseatview : 0,
           fullcokpit : constant.FALSE,

           floating : {},
           recoverfloating : constant.FALSE,
           last_recover : {},
           initial : {}
         };

   obj.init();

   return obj;
};

Seats.init = func {
   me.controls = props.globals.getNode("/controls/seat");
   me.positions = props.globals.getNode("/systems/seat/position");
   me.theseats = props.globals.getNode("/systems/seat");

   theviews = props.globals.getNode("/sim").getChildren("view");
   last = size(theviews);

   # retrieve the index as created by FG
   for( i = 0; i < last; i=i+1 ) {
        child = theviews[i].getChild("name");

        # nasal doesn't see yet the views of preferences.xml
        if( child != nil ) {
            name = child.getValue();
            if( name == "Engineer View" ) {
                me.save_lookup("engineer", i);
                me.engineerheadinit( theviews[i] );
            }
            elsif( name == "Overhead View" ) {
                me.save_lookup("overhead", i);
            }
            elsif( name == "Copilot View" ) {
                me.save_lookup("copilot", i);
            }
            elsif( name == "Steward View" ) {
                 me.save_lookup("steward", i);
            }
            elsif( name == "Observer View" ) {
                 me.save_lookup("observer", i);
                 me.save_initial( "observer", theviews[i] );
            }
        }
   }

   # default
   me.recoverfloating = me.controls.getChild("recover").getValue();
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

Seats.viewexport = func( name ) {
   me.engineerhead();

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

       me.recover();
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

Seats.recoverexport = func {
   me.recoverfloating = !me.recoverfloating;
   me.controls.getChild("recover").setValue(me.recoverfloating);
}

Seats.engineerheadinit = func( view ) {
   # initial orientation
   headdeg = view.getNode("config").getChild("heading-offset-deg").getValue();
   me.positions.getNode("engineer").getChild("heading-deg").setValue(headdeg);
}

Seats.engineerhead = func {
   # current orientation, before leaving view
   if( me.theseats.getChild("engineer").getValue() ) {
       headdeg = getprop("/sim/current-view/goal-heading-offset-deg");
       me.positions.getNode("engineer").getChild("heading-deg").setValue(headdeg);
   }
}

Seats.scrollexport = func{
   # number of views = 11
   nbviews = size(props.globals.getNode("/sim").getChildren("view"));


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
   nbviews = size(props.globals.getNode("/sim").getChildren("view"));

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

Seats.save_lookup = func( name, index ) {
   me.names[me.nb_seats] = name;

   me.lookup[name] = index;

   if( !me.firstseat ) {
       me.firstseatview = index;
       me.firstseat = constant.TRUE;
   }

   me.floating[name] = constant.FALSE;

   me.nb_seats = me.nb_seats + 1;
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

# backup initial position
Seats.save_initial = func( name, view ) {
   var pos = {};

   config = view.getNode("config");

   pos["x"] = config.getChild("x-offset-m").getValue();
   pos["y"] = config.getChild("y-offset-m").getValue();
   pos["z"] = config.getChild("z-offset-m").getValue();

   me.initial[name] = pos;

   me.floating[name] = constant.TRUE;
   me.last_recover[name] = constant.FALSE;
}

Seats.initial_position = func( name ) {
   position = me.positions.getNode(name);

   posx = me.initial[name]["x"];
   posy = me.initial[name]["y"];
   posz = me.initial[name]["z"];

   setprop("/sim/current-view/x-offset-m",posx);
   setprop("/sim/current-view/y-offset-m",posy);
   setprop("/sim/current-view/z-offset-m",posz);

   position.getChild("x-m").setValue(posx);
   position.getChild("y-m").setValue(posy);
   position.getChild("z-m").setValue(posz);

   position.getChild("move").setValue(constant.FALSE);
}

Seats.last_position = func( name ) {
   # 1st restore
   if( !me.last_recover[ name ] and me.recoverfloating ) {
       position = me.positions.getNode(name);

       posx = position.getChild("x-m").getValue();
       posy = position.getChild("y-m").getValue();
       posz = position.getChild("z-m").getValue();

       if( posx != me.initial[name]["x"] or
           posy != me.initial[name]["y"] or
           posz != me.initial[name]["z"] ) {

           setprop("/sim/current-view/x-offset-m",posx);
           setprop("/sim/current-view/y-offset-m",posy);
           setprop("/sim/current-view/z-offset-m",posz);

           position.getChild("move").setValue(constant.TRUE);
       }

       me.last_recover[ name ] = constant.TRUE;
   }
}

Seats.recover = func {
   for( i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.last_position( name );
            }
            break;
        }
   }
}

Seats.move_position = func( name ) {
   posx = getprop("/sim/current-view/x-offset-m");
   posy = getprop("/sim/current-view/y-offset-m");
   posz = getprop("/sim/current-view/z-offset-m");

   position = me.positions.getNode(name);

   position.getChild("x-m").setValue(posx);
   position.getChild("y-m").setValue(posy);
   position.getChild("z-m").setValue(posz);

   position.getChild("move").setValue(constant.TRUE);
}

Seats.move = func {
   result = constant.FALSE;

   # saves previous position
   for( i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.move_position( name );
                result = constant.TRUE;
            }
            break;
        }
   }

   return result;
}

# restore view
Seats.restoreexport = func {
   for( i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.initial_position( name );
            }
            break;
        }
   }
}

Seats.audioexport = func {
   marker = getprop("/sim/current-view/internal");
   panel = constant.TRUE;

   if( me.theseats.getChild("captain").getValue() ) {
       name = "captain";
   }
   elsif( me.theseats.getChild("copilot").getValue() ) {
       name = "copilot";
   }
   elsif( me.theseats.getChild("engineer").getValue() ) {
       name = "engineer";
   }
   else {
       name = "";
       panel = constant.FALSE;
   }

   me.audio.headphones( marker, panel, name );
}


# =====
# DOORS
# =====

Doors = {};

Doors.new = func {
   obj = { parents : [Doors],

           rail : SeatRail.new(),

           engineertable : nil,
           cockpitdoor : nil,

           INSIDEDECKZM : 11.10,

           DOORCLOSED : 0.0,

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
   me.engineertable = props.globals.getNode("/controls/doors/engineer-deck");
   me.cockpitdoor = props.globals.getNode("/controls/doors/flight-deck");

   if( me.cockpitdoor.getChild("opened").getValue() ) {
       me.flightdeck.toggle();
   }
   if( !me.engineertable.getChild("out").getValue() ) {
       me.engineerdeck.toggle();
   }
}

Doors.railexport = func( name ) {
   me.rail.toggle( name );
}

Doors.flightdeckexport = func {
   allowed = constant.TRUE;

   if( me.cockpitdoor.getChild("position-norm").getValue() == me.DOORCLOSED ) {
       # locked in flight
       if( me.cockpitdoor.getChild("normal").getValue() ) {
           # can open only from inside
           if( getprop("/sim/current-view/z-offset-m") > me.INSIDEDECKZM ) {
               allowed = constant.FALSE;
           }
       }
   }

   if( allowed ) {
       me.flightdeck.toggle();
   }
}

Doors.engineerdeckexport = func {
   me.engineerdeck.toggle();

   if( me.engineertable.getChild("out").getValue() ) {
       state = constant.FALSE;
   }
   else {
       state = constant.TRUE;
   }

   me.engineertable.getChild("out").setValue(state);
}


# ====
# MENU
# ====

Menu = {};

Menu.new = func {
   obj = { parents : [Menu],

# menu handles
           crew : nil,
           environment : nil,
           fuel : nil,
           ground : nil,
           instruments : [ nil, nil, nil ],
           navigation : nil,
           radios : nil,
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
    me.environment = gui.Dialog.new("/sim/gui/dialogs/Concorde/environment/dialog",
                                    "Aircraft/Concorde/Dialogs/Concorde-environment.xml");
    me.fuel = gui.Dialog.new("/sim/gui/dialogs/Concorde/fuel/dialog",
                             "Aircraft/Concorde/Dialogs/Concorde-fuel.xml");
    me.ground = gui.Dialog.new("/sim/gui/dialogs/Concorde/ground/dialog",
                               "Aircraft/Concorde/Dialogs/Concorde-ground.xml");

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


# ========
# CREW BOX
# ========

Crewbox = {};

Crewbox.new = func {
   obj = { parents : [Crewbox],

           MINIMIZESEC : 0.0,
           MENUSEC : 3.0,

           timers : 0.0,

           copilot : nil,
           crew : nil,
           crewcontrols : nil,
           engineer : nil,

# left bottom, 1 line, 10 seconds.
           BOXX : 10,
           BOXY : 34,
           BOTTOMY : -768,
           LINEY : 20,

           lineindex : { "speedup" : 0, "checklist" : 1, "engineer" : 2, "copilot" : 3 },
           lasttext : [ "", "", "", "" ],
           textbox : [ nil, nil, nil, nil ],
           nblines : 4
         };

    obj.init();

    return obj;
};

Crewbox.init = func {
    me.copilot = props.globals.getNode("/systems/crew/copilot");
    me.crew = props.globals.getNode("/systems/crew");
    me.crewcontrols = props.globals.getNode("/controls/crew");
    me.engineer = props.globals.getNode("/systems/crew/engineer");
 

    me.MINIMIZESEC = me.crewcontrols.getChild("timeout-s").getValue();
    if( me.MINIMIZESEC < me.MENUSEC ) {
       print( "/controls/crew/timeout-s should be above ", me.MENUSEC, " seconds : ", me.MINIMIZESEC );
    }

    me.resize();

    setlistener("/sim/startup/ysize", crewboxresizecron);
    setlistener("/sim/speed-up", crewboxcron);
    setlistener("/sim/freeze/master", crewboxcron);
}

Crewbox.resize = func {
    ysize = - getprop("/sim/startup/ysize");
    if( ysize == nil ) {
        ysize = me.BOTTOMY;
    }

    # must clear the text, otherwise text remains after close
    me.clear();

    for( i = 0; i < me.nblines; i = i+1 ) {
         # starts at 700 if height is 768
         y = ysize + me.BOXY + me.LINEY * i;

         # not really deleted
         if( me.textbox[i] != nil ) {
             me.textbox[i].close();
         }

         # CAUTION : duration is 0 (infinite), or one must wait that the text vanishes itself;
         # otherwise, overwriting the text makes the view popup tip always visible !!!
         me.textbox[i] = screen.window.new( me.BOXX, y, 1, 0 );
    }

    me.crewtext();
    me.pausetext();
}

Crewbox.pausetext = func {
    if( getprop("/sim/freeze/master") ) {
        text = "pause";
        red = constant.FALSE;
    }
    else {
        speedup = getprop("/sim/speed-up");
        if( speedup > 1 ) {
            text = sprintf( speedup, "3f.0" ) ~ "  t";
        }
        else {
            text = "";
        }
        red = constant.TRUE;
    }

    index = me.lineindex["speedup"];

    me.sendpause( index, red, text );
}

crewboxresizecron = func {
    crewscreen.resize();
}

crewboxcron = func {
    crewscreen.pausetext();
}

Crewbox.minimizeexport = func {
    value = me.crew.getChild("minimized").getValue();
    me.crew.getChild("minimized").setValue(!value);

    me.resettimer();
}

Crewbox.toggleexport = func {
    # 2D feedback
    if( !getprop("/systems/human/serviceable") ) {
        me.crew.getChild("minimized").setValue(constant.FALSE);
        me.resettimer();
    }
}

Crewbox.schedule = func {
    # timeout on text box
    if( me.crewcontrols.getChild("timeout").getValue() ) {
        me.timers = me.timers + me.MENUSEC;
        if( me.timers >= me.MINIMIZESEC ) {
            me.crew.getChild("minimized").setValue(constant.TRUE);
        }
    }

    me.crewtext();
}

Crewbox.resettimer = func {
    me.timers = 0.0;

    me.crewtext();
}

Crewbox.crewtext = func {
    if( !me.crew.getChild("minimized").getValue() or
        !me.crewcontrols.getChild("timeout").getValue() ) {
        me.checklisttext();
        me.copilottext();
        me.engineertext();
    }
    else {
        me.clearcrew();
    }
}

Crewbox.checklisttext = func {
    text = me.crew.getChild("checklist").getValue();

    green = me.crew.getChild("serviceable").getValue();

    index = me.lineindex["checklist"];

    me.sendtext( index, green, text );
}

Crewbox.copilottext = func {
    text = me.copilot.getChild("state").getValue();
    if( text == "" ) {
        if( me.crewcontrols.getChild("copilot").getValue() ) {
            text = "copilot";
        }
    }

    if( me.copilot.getChild("activ").getValue() or
        me.crew.getChild("emergency").getValue() ) {
        green = constant.TRUE;
    }
    else {
        green = constant.FALSE;
    }

    index = me.lineindex["copilot"];

    me.sendtext( index, green, text );
}

Crewbox.engineertext = func {
    text = me.engineer.getChild("state").getValue();
    if( text == "" ) {
        if( me.crewcontrols.getChild("engineer").getValue() ) {
            text = "engineer";
        }
    }

    green = me.engineer.getChild("activ").getValue();

    index = me.lineindex["engineer"];

    me.sendtext( index, green, text );
}

Crewbox.sendtext = func( index, green, text ) {
    me.lasttext[index] = text;
    box = me.textbox[index];

    # dark green
    if( green ) {
        box.write( text, 0, 0.7, 0 );
    }
    # dark yellow
    else {
        box.write( text, 0.7, 0.7, 0 );
    }
}

Crewbox.sendpause = func( index, red, text ) {
    me.lasttext[index] = text;
    box = me.textbox[index];

    # bright red
    if( red ) {
        box.write( text, 1.0, 0, 0 );
    }
    # bright yellow
    else {
        box.write( text, 1.0, 1.0, 0 );
    }
}

Crewbox.clearcrew = func {
    for( i = 1; i < me.nblines; i = i+1 ) {
         if( me.lasttext[i] != "" ) {
             me.lasttext[i] = "";
             me.textbox[i].write( me.lasttext[i], 0, 0, 0 );
         }
    }
}

Crewbox.clear = func {
    for( i = 0; i < me.nblines; i = i+1 ) {
         if( me.lasttext[i] != "" ) {
             me.lasttext[i] = "";
             me.textbox[i].write( me.lasttext[i], 0, 0, 0 );
         }
    }
}


# =========
# VOICE BOX
# =========

Voicebox = {};

Voicebox.new = func {
   obj = { parents : [Voicebox],

           voicecontrol : nil,

           seetext : constant.TRUE,

# centered in the vision field, 1 line, 10 seconds.
           textbox : screen.window.new( nil, -200, 1, 10 )
   };

   obj.init();

   return obj;
}

Voicebox.init = func {
   me.voicecontrol = props.globals.getNode("/controls/crew/voice");
}

Voicebox.schedule = func {
   me.seetext = me.voicecontrol.getChild("text").getValue();
}

Voicebox.textexport = func {
   if( me.seetext ) {
       feedback = "crew text off";
       me.seetext = constant.FALSE;
   }
   else {
       feedback = "crew text on";
       me.seetext = constant.TRUE;
   }

   me.sendtext( feedback, !me.seetext, constant.TRUE );
   me.voicecontrol.getChild("text").setValue(me.seetext);

   return feedback;
}

Voicebox.is_on = func {
   return me.seetext;
}

Voicebox.sendtext = func( text, engineer = 0, force = 0 ) {
   if( me.seetext or force ) {
       # bright blue
       if( engineer ) {
           me.textbox.write( text, 0, 1, 1 );
       }

       # bright green
       else {
           me.textbox.write( text, 0, 1, 0 );
       }
   }
}
