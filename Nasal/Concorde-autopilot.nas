# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by sched are called from cron

# Like the real Concorde : see http://www.concordesst.com.



# =========
# AUTOPILOT
# =========

Autopilot = {};

Autopilot.new = func {
   obj = { parents : [Autopilot],

           autothrottlesystem : nil,
 
           ap : nil,
           channels : nil,
           flightdirectors : nil,
           locks : nil,
           mouse : nil,
           settings : nil,
           sonic : nil,
           waypoints : nil,

           AUTOPILOTSEC : 3.0,                            # refresh rate
           ALTACQUIRESEC : 2.0,
           MAXCLIMBSEC : 1.0,
           SAFESEC : 1.0,                                 # autoland
           GOAROUNDSEC : 1.0,
           TOUCHSEC : 0.2,
           FLARESEC : 0.1,

           SONICMACH : 1.0,                               # Mach where the PID changes
           CRUISEKT : 450.0,
           TRANSITIONKT : 250.0,
           VREFLANDINGKT : 162.0,                         # autoland
           VREFEMPTYKT : 152.0,

           CLIMBFPM : 2000.0,
           ACQUIREFPM : 800.0,
           TOUCHFPM : -750.0,                             # autoland
           DESCENTFPM : -1000.0,

           MACHFT : 25000.0,                              # altitude for Mach speed
           AUTOLANDFT : 1500.0,
           ALTIMETERFT : 1200.0,
           LANDINGFT : 500.0,                             # adjusts to the landing pitch
           PITCHFT : 100.0,                               # reaches the landing pitch
           FLAREFT : 100.0,                               # leaves glide slope
           LIGHTFT : 50.0,

           ROLLDEG : 2.0,                                 # roll to swap to next waypoint
           WPTNM : 4.0,                                   # distance to swap to next waypoint
           VORNM : 3.0,                                   # distance to inhibate VOR

           LANDINGKG : 19000.0,                           # max fuel for landing

           GOAROUNDDEG : 15.0,

# If no pitch control, sudden swap to 10 deg causes a rebound, worsened by the ground effect.
# Ignoring the glide slope at 200-300 ft, with a pitch of 10 degrees, would be simpler;
# but the glide slope following is implicit until 100 ft (red autoland light).
           FLAREDEG : 10.0,

# If 10 degrees, vertical speed, too high to catch the glide slope,
# cannot be recovered during the last 100 ft.
           LANDINGDEG : 8.5,                              # landing pitch

           landheadingdeg : 0.0,

           engaged_channel : -1,

           noinstrument : { "altitude" : "", "magnetic" : "", "pitch" : "", "roll" : "" },
           slave : { "altimeter" : nil, "asi" : nil, "dme" : nil, "electric" : nil, "ins" : nil,
                     "ivsi" : nil, "mach" : nil, "nav" : nil, "radioaltimeter" : nil, "weight" : nil }
         };

# autopilot initialization
   obj.init();

   return obj;
};

Autopilot.init = func {
   me.ap = props.globals.getNode("/controls/autoflight");
   me.channels = props.globals.getNode("/controls/autoflight").getChildren("autopilot");
   me.flightdirectors = props.globals.getNode("/controls/autoflight").getChildren("flight-director");
   me.locks = props.globals.getNode("/autopilot/locks");
   me.mouse = props.globals.getNode("/devices/status/mice/mouse").getChildren("button");
   me.settings = props.globals.getNode("/autopilot/settings");
   me.sonic = props.globals.getNode("/autopilot/locks/sonic");
   me.waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");

   me.noinstrument["altitude"] = getprop("/systems/autopilot/noinstrument/altitude");
   me.noinstrument["magnetic"] = getprop("/systems/autopilot/noinstrument/magnetic");
   me.noinstrument["pitch"] = getprop("/systems/autopilot/noinstrument/pitch");
   me.noinstrument["roll"] = getprop("/systems/autopilot/noinstrument/roll");

   propname = getprop("/systems/autopilot/slave/altimeter");
   me.slave["altimeter"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/asi");
   me.slave["asi"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/dme");
   me.slave["dme"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/electric");
   me.slave["electric"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/ins");
   me.slave["ins"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/ivsi");
   me.slave["ivsi"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/mach");
   me.slave["mach"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/nav");
   me.slave["nav"] = props.globals.getNode(propname).getChildren("nav");
   propname = getprop("/systems/autopilot/slave/radio-altimeter");
   me.slave["radioaltimeter"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/weight");
   me.slave["weight"] = props.globals.getNode(propname);

   # - NAV 0 is reserved for autopilot.
   # - copy NAV 0-1 from preferences.xml to 1-2.
   me.sendnav( 1, 2 );
   me.sendnav( 0, 1 );

   me.apdiscexport();
}

Autopilot.set_relation = func( autothrottle ) {
   me.autothrottlesystem = autothrottle;
}

Autopilot.schedule = func {
   me.supervisor();
}

Autopilot.slowschedule = func {
   me.releasedatum();
}

Autopilot.supervisor = func {
   me.inslight();

   # waypoint transition
   if( me.is_engaged() ) {
       if( me.is_ins() ) {
           me.lockwaypointroll();
       }

       # VOR transition
       elsif( me.is_vor() ) {
           me.lockvorroll();
       }
   }

   # more sensitive at supersonic speed
   if( me.is_lock_magnetic() ) {
       me.sonicmagneticheading();
   }

   elsif( me.is_lock_true() ) {
       me.sonictrueheading();
   }
   else {
       me.sonic.getChild("heading").setValue("");
   }

   if( me.is_lock_vertical() ) {
       me.sonicverticalspeed();
   }
   else {
       me.sonic.getChild("altitude").setValue("");
   }

   # disconnect autopilot if no voltage (TO DO by FG)
   me.voltage();
}

Autopilot.no_voltage = func {
   if( !me.slave["electric"].getChild("autopilot1").getValue() and
       !me.slave["electric"].getChild("autopilot2").getValue() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# disconnect if no voltage (cannot disable the autopilot !)
Autopilot.voltage = func {
   voltage1 = me.slave["electric"].getChild("autopilot1").getValue();
   voltage2 = me.slave["electric"].getChild("autopilot2").getValue();

   if( !voltage1 or !voltage2 ) {
       # not yet in hand of copilot
       if( !getprop("/systems/autopilot/state/virtual") ) {

           # disconnect autopilot 1
           if( !voltage1 ) {
               channel = me.channels[0].getChild("engage").getValue();
               if( channel ) {
                   me.engagechannel(0, constant.FALSE);
                   channel = me.channels[1].getChild("engage").getValue();
                   if( !channel ) {
                       me.apdiscexport();
                   }
               }
           }

           # disconnect autopilot 2
           if( !voltage2 ) {
               channel = me.channels[1].getChild("engage").getValue();
               if( channel ) {
                   me.engagechannel(1, constant.FALSE);
                   channel = me.channels[0].getChild("engage").getValue();
                   if( !channel ) {
                       me.apdiscexport();
                   }
               }
           }

           me.autothrottlesystem.voltage();
       }
   }
}

# emulates a human pilot
Autopilot.virtual = func {
    # cut autopilot before, if no voltage
    me.voltage();

    setprop("/systems/autopilot/state/virtual",constant.TRUE);
}

Autopilot.real = func {
    setprop("/systems/autopilot/state/virtual",constant.FALSE);
}

# avoid strong roll near a waypoint
Autopilot.lockwaypointroll = func {
    distancenm = me.waypoints[0].getChild("dist").getValue();

    # next waypoint
    if( distancenm != nil ) {
        # restores after waypoint pop
        if( me.is_lock_magnetic() ) {
            wpt = me.waypoints[0].getChild("id").getValue();
            lastwpt = getprop("/systems/autopilot/state/waypoint");
            if( wpt != lastwpt ) {
                me.locktrue();
            }
        }

        # avoids strong roll
        else {
            if( distancenm < me.WPTNM ) {
                # 2 time steps
                speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();
                speednmps =  speedkt / constant.HOURTOSECOND;
                stepnm = speednmps * me.AUTOPILOTSEC;
                stepnm = stepnm * 2.0;

                # switches to heading hold
                rolldeg =  getprop(me.noinstrument["roll"]);
                if( distancenm < stepnm or rolldeg < - me.ROLLDEG or rolldeg > me.ROLLDEG ) {
                    if( me.is_lock_true() ) {
                        me.magneticheading();
                        me.lockmagnetic();
                        wpt = me.waypoints[0].getChild("id").getValue();
                        setprop("/systems/autopilot/state/waypoint",wpt);
                    }
                }
            }
        }
    }
}

Autopilot.get_nav = func {
    # NAV 0, if not engaged
    index = me.engaged_channel + 1;

    # once frenquecy is sended, NAV 0 reflects NAV 1/2 only at the next loop !!
    return me.slave["nav"][index];
}

# avoid strong roll near a VOR
Autopilot.lockvorroll = func {
    # near VOR
    if( me.slave["dme"].getChild("in-range").getValue() ) {
        # restores after VOR
        distancenm = me.slave["dme"].getChild("indicated-distance-nm").getValue();
        if( distancenm > me.VORNM ) {
            if( me.is_lock_magnetic() ) {
                me.locknav1();
            }
        }

        # avoids strong roll
        else {
            # switches to heading hold
            if( me.is_lock_nav() ) {
                # except if mode has just been engaged, leaving a VOR :
                # EGLL 27R, then leaving LONDON VOR 113.60 on its 260 deg radial (SID COMPTON 3).
                if( !me.get_nav().getChild("from-flag").getValue() ) { 
                    me.magneticheading();
                    me.lockmagnetic();
                }
            }
        }
    }
}


# ---------------
# AUTOPILOT MODES
# ---------------

# To avoid bugs, swaping from an horizontal / vertical mode (composed of 2 or more submodes)
# may keep submodes, if that is coherent.
# Example : swaping from turbulence mode (= pitch + heading hold) to pitch hold, keeps heading hold.

# disconnect autopilot
Autopilot.apdiscexport = func {
   me.apdischeading();
   me.apdiscvertical();
   me.apdischorizontal();
   me.apdiscaltitude();

   me.engagechannel(0, constant.FALSE);
   me.engagechannel(1, constant.FALSE);

   me.locks.getChild("altitude").setValue("");
   me.locks.getChild("heading").setValue("");
}

Autopilot.is_disc = func {
   altitude = me.ap.getChild("altitude").getValue();
   heading = me.ap.getChild("heading").getValue();
   vertical = me.ap.getChild("vertical").getValue();
   horizontal = me.ap.getChild("horizontal").getValue();

   if( altitude == "" and heading == "" and vertical == "" and horizontal == "" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# activate a mode, and engage a channel
Autopilot.apactivatemode2 = func( property, value, value2 ) {
   if( property == "altitude" ) {
       if( value2 != "" ) {
           me.apactivatemode("vertical",value2);
       }
       else {
           me.apdiscvertical();
       }
   }
   elsif( property == "heading" ) {
       if( value2 != "" ) {
           me.apactivatemode("horizontal",value2);
       }
       else {
           me.apdischorizontal();
       }
   }

   me.apactivatemode( property, value );
}

# activate a mode, and engage a channel
Autopilot.apactivatemode = func( property, value ) {
   if( property == "altitude" ) {
       me.apdiscaltitude();
   }
   elsif( property == "vertical" ) {
       me.apdiscvertical();
   }
   elsif( property == "heading" ) {
       me.apdischeading();
   }
   elsif( property == "horizontal" ) {
       me.apdischorizontal();
   }

   me.ap.getChild(property).setValue(value);

   channel1 = me.channels[0].getChild("engage").getValue();
   channel2 = me.channels[1].getChild("engage").getValue();

   # remove 2nd channel of autoland after a goaround
   if( channel1 and channel2 ) {
       if( !me.is_autoland() ) {
           channel2 = constant.FALSE;
           me.engagechannel(1, channel2);
       }
   }

   me.autothrottlesystem.atdiscincompatible( channel1, channel2 );
}

Autopilot.apenable = func {
   if( !me.is_engaged() ) {
       me.engagechannel(0, constant.TRUE);
   }
}

Autopilot.is_engaged = func {
   if( me.channels[0].getChild("engage").getValue() or
       me.channels[1].getChild("engage").getValue() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.apengage = func {
   if( me.is_engaged() ) {
       altitudemode = me.ap.getChild("altitude").getValue();
       headingmode = me.ap.getChild("heading").getValue();
   }
   else {
       altitudemode = "";
       headingmode = "";
   }

   me.locks.getChild("altitude").setValue(altitudemode);
   me.locks.getChild("heading").setValue(headingmode);

   me.supervisor();
}

Autopilot.apengagealtitude = func {
   if( me.is_engaged() ) {
       altitudemode = me.ap.getChild("altitude").getValue();
   }
   else {
       altitudemode = "";
   }

   me.locks.getChild("altitude").setValue(altitudemode);

   me.supervisor();
}

# activate autopilot
Autopilot.apexport = func {
   channel1 = me.channels[0].getChild("engage").getValue();
   channel2 = me.channels[1].getChild("engage").getValue();

   # channel engaged by XML
   me.whichchannel();

   me.apsendheadingexport();
   me.apsendnavexport();

   # 2 channels only in land mode
   if( channel1 and channel2 ) {
       if( !me.is_autoland() ) {
           me.engagechannel(1, constant.FALSE);
       }
   }

   # pitch hold and heading hold is default on activation
   elsif( channel1 or channel2 ) {
       if( me.is_disc() ) {
           me.appitchexport();
           me.apheadingholdexport();
       }
       else {
           me.apengage();
       }

       # disconnect autothrottle, if not compatible
       me.autothrottlesystem.atdiscincompatible( channel1, channel2 );
   }

   # disconnect if no channel
   else {
       me.apengage();
   }
}

Autopilot.engagechannel = func( index, value ) {
    me.channels[index].getChild("engage").setValue(value);

    me.whichchannel();
}

Autopilot.whichchannel = func {
    # records the 1st channel of autoland; otherwise must disengage to swap.
    if( me.channels[0].getChild("engage").getValue() ) {
        if( !me.channels[1].getChild("engage").getValue() ) {
            me.engaged_channel = 0;
        }
    }
    elsif( me.channels[1].getChild("engage").getValue() ) {
        if( !me.channels[0].getChild("engage").getValue() ) {
            me.engaged_channel = 1;
        }
    }

    # crash if channel access !
    else {
        me.engaged_channel = -1;
    }
}

# spring returns to center, once released by hand
Autopilot.releasedatum = func {
   if( me.ap.getNode("datum/altitude").getValue() != 0.0 ) {
       # no mouse left click
       if( !me.mouse[0].getValue() ) {
           me.ap.getNode("datum/altitude").setValue(0.0);
       }
   }
}

# datum adjust of autopilot, arguments
# - step plus/minus 1 (fast) or 0.1 (slow)
Autopilot.datumapexport = func( sign ) {
   altitudemode = me.locks.getChild("altitude").getValue();

   if( altitudemode != "" and altitudemode != nil ) {
       result = constant.TRUE;

       maxcruise = me.autothrottlesystem.is_maxcruise();
# TO DO : slaving to TMO not implemented
       maxcruise = constant.FALSE;

       # plus/minus 6000 ft/min (real)
       # plus/minus 17 kt (real) : maxclimb
       if( me.is_lock_vertical() and !maxcruise ) {
           # 80 or 800 ft/min per second (real) : 10 or 100 ft/min per key
           # 0.7 or 2 kt per second (real) : 10 or 100 ft/min per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
               step = 0.16667 * sign;
           }
           else {
               value = 100.0 * sign;
               step = 0.16667 * sign;
           }
       }
       # plus/minus 11 deg
       elsif( altitudemode == "pitch-hold" ) {
           # 0.1 or 0.5 deg per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 1.0 * sign;
               step = 0.90909 * sign;
           }
           else {
               value = 0.5 * sign;
               step = 0.454545 * sign;
           }
       }
       # plus/minus 600 ft (real)
       elsif( altitudemode == "altitude-hold" ) {
           # 20 or 60 ft per second (real) : 10 or 50 ft per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
               step = 1.66667 * sign;
           }
           else {
               value = 50.0 * sign;
               step = 0.83333 * sign;
           }
       }
       # plus/minus 20 kt (real)
       elsif( altitudemode == "speed-with-pitch" ) {
           # 0.7 or 2 kt per second (real) : 0.5 or 1 kt per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 5.0 * sign;
               step = 0.25 * sign;
           }
           else {
               value = 1.0 * sign;
               step = 0.5 * sign;
           }
       }
       # plus/minus 0.06 Mach (real)
       elsif( altitudemode == "mach-with-pitch" ) {
           # 0.002 or 0.007 Mach per second (real)
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 0.02 * sign;
               step = 3.33333 * sign;
           }
           else {
               value = 0.007 * sign;
               step = 1.166667 * sign;
           }
       }
       # default (touches cursor)
       else {
           value = 0.0;
           step = 1.0 * sign;
       }

       # limited to plus/minus 10 steps
       datum = me.ap.getNode("datum/altitude").getValue();
       if( datum == nil ) {
           datum = step;
       }
       else {
           datumold = datum;
           datum = datum + step;

           # maximum value of cursor
           if( datum > 10.0 and datumold < 10.0 ) {
               maxstep = 10.0 - datumold;
               ratio = maxstep / step;
               value = ratio * value;
               datum = 10.0;
           }
           # minimum value of cursor
           elsif( datum < -10.0 and datumold > -10.0 ) {
               maxstep = -10.0 - datumold;
               ratio = maxstep / step;
               value = ratio * value;
               datum = -10.0;
           }
       }

       if( datum >= -10.0 and datum <= 10.0 ) {
           if( me.is_lock_vertical() and !maxcruise ) {
               targetfpm = me.settings.getChild("vertical-speed-fpm").getValue();
               if( targetfpm == nil ) {
                   targetfpm = 0.0;
               }
               targetfpm = targetfpm + value;
               me.verticalspeed(targetfpm);
           }
           elsif( altitudemode == "pitch-hold" ) {
               targetdeg = me.settings.getChild("target-pitch-deg").getValue();
               targetdeg = targetdeg + value;
               me.pitch( targetdeg );
           }
           elsif( altitudemode == "altitude-hold" ) {
               targetft = me.settings.getChild("target-altitude-ft").getValue();
               targetft = targetft + value;
               me.apaltitude(targetft);
           }
           elsif( altitudemode == "speed-with-pitch" ) {
               targetkt = me.settings.getChild("target-speed-kt").getValue();
               targetkt = targetkt + value;
               me.autothrottlesystem.speed(targetkt);
           }
           elsif( altitudemode == "mach-with-pitch" ) {
               targetmach = me.settings.getChild("target-mach").getValue();
               targetmach = targetmach + value;
               me.autothrottlesystem.mach(targetmach);
           }

           me.ap.getNode("datum/altitude").setValue(datum);
       }
   }

   else {
       result = constant.FALSE;
   }

   return result;
}


# ---------------
# FLIGHT DIRECTOR
# ---------------

# activate autopilot
Autopilot.fdexport = func {
   fd1 = me.flightdirectors[0].getChild("engage").getValue();
   fd2 = me.flightdirectors[1].getChild("engage").getValue();

   if( fd1 or fd2 ) {
       altitude = me.ap.getChild("altitude").getValue();
       heading = me.ap.getChild("heading").getValue();
       vertical = me.ap.getChild("vertical").getValue();
       horizontal = me.ap.getChild("horizontal").getValue();

       # pitch hold is default on activation
       if( ( altitude == "" or altitude == nil ) and ( vertical == "" or vertical == nil ) and
           ( heading == "" or heading == nil ) and ( horizontal == "" or horizontal == nil ) ) {
           me.appitchexport();
       }
   }
}


# -------------
# VERTICAL MODE
# -------------

Autopilot.apdiscverticalmode2 = func {
   me.apdiscvertical();
   me.apdiscaltitude();
}

# disconnect vertical mode
Autopilot.apdiscvertical = func {
   me.ap.getChild("vertical").setValue("");
}

# go around mode
Autopilot.goaround = func {
   # cron runs without autopilot engagement
   if( me.is_engaged() ) {

       # 2 throttles full foward during an autoland or glide slope
       if( me.is_glide() or me.is_landing() ) {
           if( me.autothrottlesystem.goaround() ) {
               me.apactivatemode("heading","wing-leveler","");

               # pitch at 15 deg and hold the wing level, until the next command of crew
               me.modepitch( me.GOAROUNDDEG );

               # crew control
               me.autothrottlesystem.atdiscexport();

               # throttle is being changed by autothrottle
               me.autothrottlesystem.full();

               # light on
               me.apactivatemode("vertical","goaround");

               me.apengage();
           }
       }

       # light off
       elsif( me.is_going_around() ) {
           if( !me.is_pitch() or
               me.ap.getChild("heading").getValue() != "wing-leveler" ) {
               me.apdiscvertical();
           }
       }
   }
}

Autopilot.is_going_around = func {
   if( me.ap.getChild("vertical").getValue() == "goaround" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# CAUTION, avoids concurrent crons (stack overflow Nasal error) :
# one may activate glide slope, then arm autoland = 2 calls.
Autopilot.is_goaround = func {
   if( me.ap.getChild("vertical2").getValue() == "goaround-armed" or me.is_going_around() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.clampkg = func ( vallanding, valempty ) {
    tankskg = me.slave["weight"].getChild("total-kg").getValue();
    if( tankskg > me.LANDINGKG ) {
        result = vallanding;
    }
    else {
        result = vallanding + ( valempty - vallanding ) * ( me.LANDINGKG - tankskg ) / me.LANDINGKG;
    }

    return result;
}

# adjust target speed with wind
# - target speed (kt)
Autopilot.targetwind = func {
   # VREF 152-162 kt
   targetkt = me.clampkg( me.VREFLANDINGKT, me.VREFEMPTYKT );

   # wind increases lift
   windkt = me.slave["ins"].getChild("wind-speed-kt").getValue();
   if( windkt > 0 ) {
       winddeg = me.slave["ins"].getChild("wind-from-heading-deg").getValue();
       vordeg = me.get_nav().getNode("radials").getChild("target-radial-deg").getValue();
       offsetdeg = vordeg - winddeg;
       offsetdeg = constant.crossnorth( offsetdeg );

       # add head wind component;
       # except tail wind (too much glide)
       if( offsetdeg > -constant.DEG90 and offsetdeg < constant.DEG90 ) {
           offsetrad = offsetdeg * constant.DEGTORAD;
           offsetkt = windkt * math.cos( offsetrad );
           targetkt = targetkt + offsetkt;
       }
   }

   # avoid infinite gliding (too much ground effect ?)
   me.autothrottlesystem.speed(targetkt);
}

# smooth the rebound of pitch hold during the flare
Autopilot.targetpitch = func( targetdeg, aglft, rates ) {
   # start from attitude
   if( !me.is_pitch() ) {
       pitchdeg = getprop(me.noinstrument["pitch"]);
   }
   else {
       pitchdeg = me.settings.getChild("target-pitch-deg").getValue();
   }

   if( pitchdeg != targetdeg ) {
       if( targetdeg > pitchdeg ) {
           speedfps = - me.slave["ivsi"].getChild("indicated-speed-fps").getValue();
           deltaft = aglft - me.PITCHFT;
           timesec = deltaft / speedfps;

           deltadeg = targetdeg - pitchdeg;
           ratedegps = deltadeg / timesec;

           stepdeg = ratedegps * rates;
           pitchdeg = pitchdeg + stepdeg;
       }

       # maximum
       else {
           pitchdeg = targetdeg;
       }
   }

   me.modepitch( pitchdeg );
}

# cannot make a settimer on a member function
autolandcron = func {
   autopilotsystem.autoland();
}

# autoland mode
Autopilot.autoland = func {
   me.goaround();

   verticalmode2 = "";      

   # to catch the go around
   rates = me.GOAROUNDSEC;

   if( me.is_autoland() ) {
       verticalmode2 = "goaround-armed";

       # cron runs without autopilot engagement
       if( me.is_engaged() ) {
           aglft = me.slave["radioaltimeter"].getChild("indicated-altitude-ft").getValue();

           # armed
           if( me.is_land_armed() ) {
               if( aglft <= me.AUTOLANDFT ) {
                   me.ap.getChild("vertical").setValue("autoland");
               }
           }

           # engaged
           if( me.is_landing() ) {
               # touch down
               if( aglft < constantaero.AGLTOUCHFT ) {

                   # gently reduce pitch
                   if( getprop(me.noinstrument["pitch"]) > 1.0 ) {
                       rates = me.TOUCHSEC;

                       # 1 deg / s
                       pitchdeg = me.settings.getChild("target-pitch-deg").getValue();
                       pitchdeg = pitchdeg - 0.2;
                       me.modepitch( pitchdeg );
                       me.autothrottlesystem.atdiscspeedmode2();
                   }

                   # safe on ground
                   else {
                       rates = me.SAFESEC;

                       # disable autopilot
                       verticalmode2 = "";
                       me.apdiscexport();
                       me.autothrottlesystem.atdiscexport();

                       # reset trims
                       setprop("/controls/flight/elevator-trim",0.0);
                       setprop("/controls/flight/rudder-trim",0.0);
                       setprop("/controls/flight/aileron-trim",0.0);
                   }

                   # pilot must activate autothrottle
                   me.autothrottlesystem.idle();
               }
 
               # triggers below 1500 ft
               elsif( aglft > me.AUTOLANDFT ) {
                   me.ap.getChild("vertical").setValue("autoland-armed");
               }

               # approach
               else {
                   # if activated below 1500 ft
                   me.apdischorizontal();

                   if( aglft < me.LANDINGFT ) {
                       rates = me.FLARESEC;

                       # landing pitch (flare) :
                       # - not above 100 ft, because outside of glide slope (autoland red light).
                       # - vertical-speed-with-throttle removes the rebound at touch down of
                       # vertical-speed-hold.
                       if( aglft < me.FLAREFT ) {
                           # possible nav errors below 100 ft (example KJFK 22L, EGLL 27R) :
                           # heading hold avoids roll outside the runway.
                           if( !me.ap.getChild("real-nav").getValue() ) {
                               if( !me.is_magnetic() ) {
                                   me.landheadingdeg = getprop(me.noinstrument["magnetic"]);
                               }
                               me.heading(me.landheadingdeg);
                               me.apactivatemode("heading","dg-heading-hold");
                           }
                           me.modepitch( me.FLAREDEG );
                           me.verticalspeed(me.TOUCHFPM);
                           me.autothrottlesystem.atactivatemode("speed","vertical-speed-with-throttle");
                       }

                       # tip to landing pitch :
                       # - sooner at 10 deg reduces the rebound.
                       # - cannot go back, when rebound.
                       # - glide slope with throttle is less prone to lose pitch
                       # to catch the glide slope below.
                       elsif( !me.autothrottlesystem.is_lock_vertical() ) {
                           me.apactivatemode("heading","nav1-hold");
                           me.targetpitch( me.LANDINGDEG, aglft, rates );
                           me.autothrottlesystem.atactivatemode("speed","gs1-with-throttle");
                       } 
                   }

                   # glide slope : cannot go back when then aircraft climbs again
                   # (rebound caused by landing pitch), otherwise will crash to catch the glide slope.
                   elsif( !me.autothrottlesystem.is_lock_glide() ) {
                       me.apactivatemode("heading","nav1-hold");
                       me.modeglide();

                       # near VREF (no wind)
                       me.targetwind();
                       me.autothrottlesystem.atactivatemode("speed","speed-with-throttle");
                   }

                   # pilot must activate autothrottle
                   me.autothrottlesystem.atengage();
               }
           }

           me.apengage();
       }
   }
   else {
       if( me.is_glide() ) {
           verticalmode2 = "goaround-armed";      
       }
   }

   me.ap.getChild("vertical2").setValue(verticalmode2);

   # re-schedule the next call
   if( me.is_goaround() ) {
       settimer(autolandcron, rates);
   }
}

Autopilot.is_landing = func {
   verticalmode = me.ap.getChild("vertical").getValue();
   if( verticalmode == "autoland" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_land_armed = func {
   verticalmode = me.ap.getChild("vertical").getValue();
   if( verticalmode == "autoland-armed" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_autoland = func {
   if( me.is_landing() or me.is_land_armed() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autopilot autoland
Autopilot.aplandexport = func {
   if( !me.is_autoland() ) {
       me.apactivatemode("vertical","autoland-armed");
   }
   else {
       me.apdiscvertical();
   }

   me.apengage();

   if( !me.is_goaround() ) {
       me.autoland();
   }
}

Autopilot.is_turbulence = func {
   verticalmode = me.ap.getChild("vertical").getValue();
   if( verticalmode == "turbulence" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autopilot turbulence mode
Autopilot.apturbulenceexport = func {
   if( !me.is_turbulence() ) {
       me.magneticheading();
       me.apactivatemode2("heading","dg-heading-hold","");
       me.attitudepitch();
       me.apactivatemode2("altitude","pitch-hold","turbulence");
   }
   else {
       me.apdiscverticalmode2();
       me.apdischeading(); 
   }

   me.apengage();
}


# -------------
# ALTITUDE MODE
# -------------

# disconnect autopilot altitude
Autopilot.apdiscaltitude = func {
   me.ap.getChild("altitude").setValue("");

   # switch to speed hold
   if( me.autothrottlesystem != nil ) {
       me.autothrottlesystem.discmaxclimb();
   }
}

# altitude button lights, when the dialed altitude is reached.
# altimeter light, when the dialed altitude is reached.
Autopilot.altitudelight = func {
   if( me.is_engaged() ) {
       if( me.is_altitude_hold() or me.is_altitude_acquire() ) {
           altft = me.ap.getChild("altitude-select").getValue();

           # altimeter light within 1200 ft
           minft = altft - me.ALTIMETERFT;
           setprop("/systems/autopilot/altimeter/target-min-ft",minft);
           maxft = altft + me.ALTIMETERFT;
           setprop("/systems/autopilot/altimeter/target-max-ft",maxft);

           # no altimeter light within 50 ft
           minft = altft - me.LIGHTFT;
           setprop("/systems/autopilot/altimeter/light-min-ft",minft);
           maxft = altft + me.LIGHTFT;
           setprop("/systems/autopilot/altimeter/light-max-ft",maxft);
       }
   }
}

Autopilot.altitudelight_on = func ( altitudeft, targetft ) {
   if( altitudeft < targetft - me.ALTIMETERFT or
       altitudeft > targetft + me.ALTIMETERFT ) {
       result = constant.FALSE;
   }
   else {
       result = constant.TRUE;
   }

   return result;
}

# cannot make a settimer on a class member
altitudeacquirecron = func {
   autopilotsystem.altitudeacquire();
}

# altitude acquire
Autopilot.altitudeacquire = func {
   if( me.is_engaged() ) {
       if( me.is_altitude_acquire() ) {
           me.altitudelight();

           altitudeft = me.slave["altimeter"].getChild("indicated-altitude-ft").getValue();
           if( altitudeft > getprop("/systems/autopilot/altimeter/target-max-ft") ) {
               speedfpm = -me.ACQUIREFPM;
               mode = "vertical";
           }
           elsif( altitudeft < getprop("/systems/autopilot/altimeter/target-min-ft") ) {
               speedfpm = me.ACQUIREFPM;
               mode = "vertical";
           }

           # capture
           elsif( altitudeft > getprop("/systems/autopilot/altimeter/light-max-ft") or
                  altitudeft < getprop("/systems/autopilot/altimeter/light-min-ft") ) {
               if( !me.is_altitude_hold() ) {
                   me.apactivatemode("altitude","altitude-hold");
               }
               mode = "capture";
           }

           # at level
           else {
               me.apactivatemode2("altitude","altitude-hold","");
               mode = "";
           }

           # default to vertical speed hold 800 ft/min, if comes from altitude hold;
           if( mode == "vertical" ) {
               if( me.is_altitude_hold() ) {
                   # pilot can change
                   me.modeverticalspeed( speedfpm );
               }
           }

           # nav1 can switch to magnetic
           me.apengagealtitude();

           # otherwise keep the previous vertical mode (if any),
           # which is supposed to reach the capture level, by pilot action

           # re-schedule the next call
           if( mode != "" ) {
               settimer(altitudeacquirecron, me.ALTACQUIRESEC);
           }
       }
   }
}

Autopilot.selectfpm = func( altitudeft, targetft ) {
   if( altitudeft > targetft ) {
       speedfpm = me.DESCENTFPM;
   }
   else {
       speedfpm = me.CLIMBFPM;
   }

   me.verticalspeed(speedfpm);
}

Autopilot.is_lock_altitude = func {
   altitudemode = me.locks.getChild("altitude").getValue();
   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle altitude hold (ctrl-A)
Autopilot.aptogglealtitudeexport = func {
   if( !me.no_voltage() ) {
       if( !me.is_vertical_speed() or me.is_altitude_acquire() ) {
           me.apenable();
           me.apverticalexport();
       }
       me.apaltitudeexport();

       # avoid many manual operations
       if( me.is_vertical_speed() ) {
           altitudeft = me.slave["altimeter"].getChild("indicated-altitude-ft").getValue();
           targetft = me.ap.getChild("altitude-select").getValue();
           me.selectfpm( altitudeft, targetft );
       }
   }
}

Autopilot.apaltitudeselectexport = func {
   if( me.is_altitude_acquire() ) {
       altitudeft = me.ap.getChild("altitude-select").getValue();
       me.apaltitude(altitudeft);
   }
}

Autopilot.is_altitude_hold = func {
   altitudemode = me.ap.getChild("altitude").getValue();
   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_altitude_acquire = func {
   verticalmode = me.ap.getChild("vertical").getValue();
   if( verticalmode == "altitude-acquire" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autopilot altitude acquire
Autopilot.apaltitudeexport = func {
   if( !me.is_altitude_acquire() ) {
       me.apactivatemode("vertical","altitude-acquire");
       me.apaltitudeselectexport();

       me.apengage();

       me.altitudeacquire();
   }
   else {
       me.apdiscvertical();

       me.apengage();
   }
}

Autopilot.apaltitude = func( altitudeft ) {
   me.settings.getChild("target-altitude-ft").setValue(altitudeft);
}

# toggle altitude hold (ctrl-T)
Autopilot.aptogglealtitudeholdexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_altitude() ) {
           me.apdiscaltitude();
           me.apengage();
       }
       else {
           me.apenable();
           me.apaltitudeholdexport();
       }
   }
}

# autopilot altitude hold
Autopilot.apaltitudeholdexport = func {
   if( !me.is_altitude_hold() ) {
       altitudeft = me.slave["altimeter"].getChild("indicated-altitude-ft").getValue();
       me.apaltitude(altitudeft);
       me.apactivatemode2("altitude","altitude-hold","");
   }
   else {
       me.apdiscverticalmode2();
   }

   me.apengage();

   me.altitudelight();
}

Autopilot.has_altitude_hold = func {
   result = me.is_engaged();

   if( result ) {
       if( !me.is_altitude_hold() or me.is_altitude_acquire() ) {
           result = constant.FALSE;
       }
       else {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.modeglide = func {
    me.ap.getChild("altitude").setValue("gs1-hold");
}

Autopilot.is_lock_glide = func {
   altitudemode = me.locks.getChild("altitude").getValue();
   if( altitudemode == "gs1-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle glide slope (ctrl-G)
Autopilot.aptoggleglideexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_glide() ) {
           me.apdiscverticalmode2();
           me.apengage();
       }
       else {
           me.apenable();
           me.apglideexport();
       }
   }
}

Autopilot.is_glide = func {
   altitudemode = me.ap.getChild("altitude").getValue();
   if( altitudemode == "gs1-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autopilot glide slope
Autopilot.apglideexport = func {
   altitudemode = me.ap.getChild("altitude").getValue();
   if( !me.is_glide() ) {
       me.apactivatemode("altitude","gs1-hold");
       me.apactivatemode2("heading","nav1-hold","");
       me.apsendnavexport();
   }
   else {
       me.apdiscverticalmode2();
       me.modevorloc();
   }

   me.apengage();

   if( !me.is_goaround() ) {
       me.autoland();
   }
}

Autopilot.attitudepitch = func {
   pitchdeg = getprop(me.noinstrument["pitch"]);
   me.pitch( pitchdeg );
}

Autopilot.pitch = func( pitchdeg ) {
   me.settings.getChild("target-pitch-deg").setValue(pitchdeg);
}

Autopilot.modepitch = func( pitchdeg ) {
   me.pitch( pitchdeg );
   me.ap.getChild("altitude").setValue("pitch-hold");
}

Autopilot.is_lock_pitch = func {
   altitudemode = me.locks.getChild("altitude").getValue();
   if( altitudemode == "pitch-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle pitch hold (ctrl-P)
Autopilot.aptogglepitchexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_pitch() ) {
           me.apdiscaltitude();
           me.apengage();
       }
       else {
           me.apenable();
           me.appitchexport();
       }
   }
}

Autopilot.is_pitch = func {
   altitudemode = me.ap.getChild("altitude").getValue();
   if( altitudemode == "pitch-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autopilot pitch hold
Autopilot.appitchexport = func {
   if( !me.is_pitch() or me.is_turbulence() ) {
       me.attitudepitch();
       me.apactivatemode("altitude","pitch-hold");
       if( !me.is_altitude_acquire() ) {
           me.apdiscvertical();
       }
   }
   else {
       me.apdiscverticalmode2();
   }

   me.apengage();
}

# sonic vertical speed
Autopilot.sonicverticalspeed = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();
   if( speedmach <= me.SONICMACH ) {
       mode = "vertical-speed-hold-sub";
   }
   else {
       mode = "vertical-speed-hold-super";
   }
   me.sonic.getChild("altitude").setValue(mode);
}

Autopilot.verticalspeed = func( speedfpm ) {
   me.settings.getChild("vertical-speed-fpm").setValue(speedfpm);
}

Autopilot.modeverticalspeed = func( speedfpm ) {
   me.verticalspeed(speedfpm);
   me.apactivatemode("altitude","vertical-speed-hold");
}

Autopilot.modeverticalspeedhold = func {
   speedfps = me.slave["ivsi"].getChild("indicated-speed-fps").getValue();
   speedfpm = speedfps * constant.MINUTETOSECOND;
   me.modeverticalspeed(speedfpm);
}

Autopilot.is_lock_vertical = func {
   altitudemode = me.locks.getChild("altitude").getValue();
   if( altitudemode == "vertical-speed-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_vertical_speed = func {
   altitudemode = me.ap.getChild("altitude").getValue();
   if( altitudemode == "vertical-speed-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autopilot vertical speed hold
Autopilot.apverticalexport = func {
   if( !me.is_vertical_speed() or me.autothrottlesystem.is_maxclimb() ) {
       if( !me.is_altitude_acquire() ) {
           me.apdiscverticalmode2();
       }
       me.modeverticalspeedhold();
   }

   else {
       me.apdiscaltitude();
   }

   me.apengage();
}

Autopilot.is_speed_pitch = func {
   altitudemode = me.ap.getChild("altitude").getValue();
   if( altitudemode == "speed-with-pitch" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# speed with pitch
Autopilot.apspeedpitchexport = func {
   # only if no autothrottle
   if( !me.is_speed_pitch() ) {
       if( !me.autothrottlesystem.is_engaged() ) {
           me.autothrottlesystem.holdspeed();
           me.apactivatemode2("altitude","speed-with-pitch","");
       }

       # default to pitch hold if autothrottle
       else {
           me.appitchexport();
       }
   }
   else {
       me.apdiscverticalmode2();
   }

   me.apengage();
}

Autopilot.is_mach_pitch = func {
   altitudemode = me.ap.getChild("altitude").getValue();
   if( altitudemode == "mach-with-pitch" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# mach with pitch
Autopilot.apmachpitchexport = func {
   # only if no autothrottle
   if( !me.is_mach_pitch() ) {
       if( !me.autothrottlesystem.is_engaged() ) {
           me.autothrottlesystem.holdmach();
           me.apactivatemode2("altitude","mach-with-pitch","");
       }

       # default to pitch hold if autothrottle
       else {
           me.appitchexport();
       }
   }

   else {
       me.apdiscverticalmode2();
   }

   me.apengage();
}

# cannot make a settimer on a member function
maxclimbcron = func {
   autopilotsystem.maxclimb();
}

# max climb mode (includes max cruise mode)
Autopilot.maxclimb = func {
   if( me.autothrottlesystem.is_maxclimb() ) {          
       if( me.is_engaged() ) {
           me.autothrottlesystem.maxclimb();
       }

       # re-schedule the next call
       settimer(maxclimbcron, me.MAXCLIMBSEC);
   }
}

# max climb mode
Autopilot.apmaxclimbexport = func {
   if( me.autothrottlesystem.is_maxclimb() ) {          
       me.apdiscaltitude();
   }

   # holds pitch and VMO with throttle
   else {
       if( !me.is_altitude_acquire() ) {
           me.apdiscverticalmode2();
       }
       me.modeverticalspeedhold();
       me.autothrottlesystem.atactivatemode("speed2","maxclimb");
       me.maxclimb();
   }          

   me.apengage();
}


# ---------------
# HORIZONTAL MODE
# ---------------

Autopilot.apdischorizontalmode2 = func {
   me.apdischorizontal();
   me.apdischeading();
}

# disconnect horizontal mode
Autopilot.apdischorizontal = func {
   me.ap.getChild("horizontal").setValue("");
}

Autopilot.is_waypoint = func {
   id = me.waypoints[0].getChild("id").getValue();
   if( id != nil and id != "" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.locktrue = func {
   me.locks.getChild("heading").setValue("true-heading-hold");
}

Autopilot.is_lock_true = func {
   headingmode = me.locks.getChild("heading").getValue();
   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_true = func {
   headingmode = me.ap.getChild("heading").getValue();
   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.inslight = func {
   # pilot must activate himself the mode
   if( !me.is_ins() ) {
       if( me.is_lock_true() ) {

           # restore the previous heading mode
           if( me.is_waypoint() ) {
               if( !me.is_true() ) {
                   me.apengage();
               }

               # FG limitation : cannot activate true heading alone with waypoint.
               else {
                   me.apinsexport();
               }
           }
       }
   }

   # no more waypoint
   else {

       # keeps the current heading mode
       if( !me.is_waypoint() ) {
           me.apdischorizontal();
       }
   }
}

Autopilot.is_ins = func {
   horizontalmode = me.ap.getChild("horizontal").getValue();
   if( horizontalmode == "ins" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# ins mode
Autopilot.apinsexport = func {
   if( !me.is_ins() ) {
       if( me.is_waypoint() ) {
           me.apactivatemode2("heading","true-heading-hold","ins");
       }
   }
   else {
       me.apdischorizontalmode2();
   }

   me.apengage();
}


# ------------
# HEADING MODE
# ------------

# disconnect heading mode
Autopilot.apdischeading = func {
   me.ap.getChild("heading").setValue("");

   if( me.is_turbulence() ) {
       me.apdiscvertical();
   }
}

Autopilot.trueheading = func( headingdeg ) {
   me.settings.getChild("true-heading-deg").setValue(headingdeg);
}

# sonic true mode
Autopilot.sonictrueheading = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();
   if( speedmach <= me.SONICMACH ) {
       mode = "true-heading-hold-sub";
   }
   else {
       mode = "true-heading-hold-super";
   }

   me.sonic.getChild("heading").setValue(mode);

   # not real : FG default keyboard changes autopilot heading
   if( me.istrackheading() ) {
       headingdeg = me.settings.getChild("true-heading-deg").getValue();
       me.channels[me.engaged_channel].getChild("heading-true-select").setValue(headingdeg);
   }
}

# sonic magnetic mode
Autopilot.sonicmagneticheading = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();
   if( speedmach <= me.SONICMACH ) {
       mode = "dg-heading-hold-sub";
   }
   else {
      mode = "dg-heading-hold-super";
   }

   me.sonic.getChild("heading").setValue(mode);

   # not real : FG default keyboard changes autopilot heading
   if( me.istrackheading() ) {
       headingdeg = me.settings.getChild("heading-bug-deg").getValue();
       me.channels[me.engaged_channel].getChild("heading-select").setValue(headingdeg);
   }
}

Autopilot.heading = func( headingdeg ) {
   me.settings.getChild("heading-bug-deg").setValue(headingdeg);
}

# magnetic heading
Autopilot.magneticheading = func {
   headingdeg = getprop(me.noinstrument["magnetic"]);
   me.heading(headingdeg);
}

# heading hold
Autopilot.apheadingholdexport = func {
   mode = me.ap.getChild("horizontal").getValue();
   if( mode != "magnetic" ) {
       me.magneticheading();
       me.apactivatemode2("heading","dg-heading-hold","magnetic");
   }
   else {
       me.apdischorizontalmode2();
   }

   me.apengage();
}

Autopilot.lockmagnetic = func {
   me.locks.getChild("heading").setValue("dg-heading-hold");
}

Autopilot.is_lock_magnetic = func {
   headingmode = me.locks.getChild("heading").getValue();
   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_magnetic = func {
   headingmode = me.ap.getChild("heading").getValue();
   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle heading hold (ctrl-H)
Autopilot.aptoggleheadingexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_magnetic() ) {
           me.apdischorizontalmode2();
           me.apengage();
       }
       else {
           me.apenable();
           me.apheadingexport();
       }
   }
}

Autopilot.istrackheading = func {
   if( me.ap.getChild("horizontal").getValue() == "track-heading" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
  }

  return result;
}

Autopilot.apsendheadingexport = func {
   if( me.istrackheading() ) {
       if( me.is_engaged() ) {
           if( !me.channels[me.engaged_channel].getChild("track-push").getValue() ) {
               me.apactivatemode("heading","dg-heading-hold");
               headingdeg = me.channels[me.engaged_channel].getChild("heading-select").getValue();
               me.heading(headingdeg);
           }
           else {
               me.apactivatemode("heading","true-heading-hold");
               headingdeg = me.channels[me.engaged_channel].getChild("heading-true-select").getValue();
               me.trueheading(headingdeg);
           }
       }
   }
}

# autopilot heading
Autopilot.apheadingexport = func {
   if( !me.istrackheading() ) {
       me.apactivatemode("horizontal","track-heading");
       me.apsendheadingexport();
   }
   else {
       me.apdischorizontalmode2();
   }

   me.apengage();
}

Autopilot.is_vor = func {
   horizontalmode = me.ap.getChild("horizontal").getValue();
   if( horizontalmode == "vor" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# VOR loc
Autopilot.modevorloc = func {
   if( me.is_nav() and !me.is_glide() ) {
       me.ap.getChild("horizontal").setValue("vor");
   }
}

Autopilot.locknav1 = func {
   me.locks.getChild("heading").setValue("nav1-hold");
}

Autopilot.sendnav = func( index, target ) {
   freqmhz = getprop("/instrumentation/nav[" ~ index ~ "]/frequencies/selected-mhz");
   setprop("/instrumentation/nav[" ~ target ~ "]/frequencies/selected-mhz",freqmhz);
   freqmhz = getprop("/instrumentation/nav[" ~ index ~ "]/frequencies/standby-mhz");
   setprop("/instrumentation/nav[" ~ target ~ "]/frequencies/standby-mhz",freqmhz);
   radialdeg = getprop("/instrumentation/nav[" ~ index ~ "]/radials/selected-deg");
   setprop("/instrumentation/nav[" ~ target ~ "]/radials/selected-deg",radialdeg);
}

Autopilot.apsendnavexport = func {
   if( me.is_engaged() ) {
       index = me.engaged_channel + 1;
       me.sendnav( index, 0 );
   }
}

Autopilot.is_lock_nav = func {
   headingmode = me.locks.getChild("heading").getValue();
   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle nav 1 hold (ctrl-N)
Autopilot.aptogglenav1export = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_nav() ) {
           me.apdischorizontalmode2();
           me.apengage();
       }
       else {
           me.apenable();
           me.apvorlocexport();
       }
   }
}

Autopilot.is_nav = func {
   headingmode = me.ap.getChild("heading").getValue();
   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autopilot vor localizer
Autopilot.apvorlocexport = func {
   if( !me.is_nav() ) {
       me.apactivatemode2("heading","nav1-hold","");
       me.modevorloc();
       me.apsendnavexport();
   }
   else {
       me.apdischorizontalmode2();
   }

   me.apengage();
}


# ============
# AUTOTHROTTLE
# ============

Autothrottle = {};

Autothrottle.new = func {
   obj = { parents : [Autothrottle],

           ap : nil,
           engines : nil,
           channels : nil,
           locks : nil,
           mouse : nil,
           settings : nil,

           SPEEDACQUIRESEC : 2.0,

           MAXMACH : 2.02,
           CRUISEMACH : 2.0,
           CLIMBMACH : 1.7,
           LIGHTKT : 10.0,

           slave : { "altimeter" : nil, "asi" : nil, "electric" : nil, "mach" : nil }
         };

# autopilot initialization
   obj.init();

   return obj;
}

Autothrottle.init = func {
   me.ap = props.globals.getNode("/controls/autoflight");
   me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
   me.channels = props.globals.getNode("/controls/autoflight").getChildren("autothrottle");
   me.locks = props.globals.getNode("/autopilot/locks");
   me.mouse = props.globals.getNode("/devices/status/mice/mouse").getChildren("button");
   me.settings = props.globals.getNode("/autopilot/settings");

   propname = getprop("/systems/autopilot/slave/altimeter");
   me.slave["altimeter"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/asi");
   me.slave["asi"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/electric");
   me.slave["electric"] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/mach");
   me.slave["mach"] = props.globals.getNode(propname);

   me.atdiscexport();
}

Autothrottle.schedule = func {
   me.iaslight();
   me.releasedatum();
}

# ias light, when discrepancy with the autothrottle
Autothrottle.iaslight = func {
   if( me.is_engaged() ) {
       if( me.is_speed_throttle() ) {
           speedkt = me.settings.getChild("target-speed-kt").getValue();

           # ias light within 10 kt
           minkt = speedkt - me.LIGHTKT;
           setprop("/systems/autopilot/airspeed/light-min-kt",minkt);
           maxkt = speedkt + me.LIGHTKT;
           setprop("/systems/autopilot/airspeed/light-max-kt",maxkt);
       }
   }
}

Autothrottle.is_maxcruise = func {
    speed2 = me.ap.getChild("speed2").getValue();
    if( speed2 == "maxcruise" ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Autothrottle.is_maxclimb = func {
    speed2 = me.ap.getChild("speed2").getValue();
    if( speed2 == "maxclimb" or speed2 == "maxcruise" ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Autothrottle.discmaxclimb = func {
    if( me.is_maxclimb() ) {
        # switch to speed hold
        me.atdiscspeed2();
    }
}

# max climb mode
Autothrottle.maxclimb = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();

   # climb
   if( speedmach < me.CLIMBMACH ) {
       vmokt = me.slave["asi"].getChild("vmo-kt").getValue();

       # catches the VMO with autothrottle
       me.speed(vmokt);
       me.atactivatemode("speed","speed-with-throttle");

       if( me.is_maxcruise() ) {
           me.atactivatemode("speed2","maxclimb");
       }
   }

   # cruise
   else {
       mmomach = me.slave["mach"].getChild("mmo-mach").getValue();

       # cruise at Mach 2.0-2.02 (reduce fuel consumption)          
       if( mmomach > me.MAXMACH ) {
           mmomach = me.MAXMACH;
       }

       # TO DO : control TMO over 128C
       # catches the MMO with autothrottle
       me.mach(mmomach);

       altft = me.slave["altimeter"].getChild("indicated-altitude-ft").getValue();
       if( speedmach > me.CRUISEMACH or altft > constantaero.MAXCRUISEFT ) {
           me.atactivatemode2("speed","mach-with-throttle","maxcruise");
       }
       else {
           me.atactivatemode2("speed","mach-with-throttle","maxclimb");
       }
   }

   me.atengage();
}

Autothrottle.no_voltage = func {
   if( !me.slave["electric"].getChild("autopilot1").getValue() and
       !me.slave["electric"].getChild("autopilot2").getValue() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# disconnect if no voltage (cannot disable the autopilot !)
Autothrottle.voltage = func() {
   voltage1 = me.slave["electric"].getChild("autopilot1").getValue();
   voltage2 = me.slave["electric"].getChild("autopilot2").getValue();

   if( !voltage1 or !voltage2 ) {
       # disconnect autothrottle 1
       if( !voltage1 ) {
           channel = me.channels[0].getChild("engage").getValue();
           if( channel ) {
               me.channels[0].getChild("engage").setValue(constant.FALSE);
               channel = me.channels[1].getChild("engage").getValue();
               if( !channel ) {
                   me.atdiscexport();
               }
           }
       }

       # disconnect autothrottle 2
       if( !voltage2 ) {
           channel = me.channels[1].getChild("engage").getValue();
           if( channel ) {
               me.channels[1].getChild("engage").setValue(constant.FALSE);
               channel = me.channels[0].getChild("engage").getValue();
               if( !channel ) {
                   me.atdiscexport();
               }
           }
       }
   }
}

# idle throttle
Autothrottle.idle = func {
   if( me.is_engaged() ) {
       for(i=0; i<=3; i=i+1) {
           me.engines[i].getChild("throttle").setValue(0);
       }
   }
}

# full foward throttle
Autothrottle.full = func {
  for(i=0; i<=3; i=i+1) {
      me.engines[i].getChild("throttle").setValue(1);
   }
}

Autothrottle.goaround = func {
   count = 0;
   for( i=0; i<=3; i=i+1 ) {
        if( me.engines[i].getChild("throttle-manual").getValue() == 1.0 ) {
            count = count + 1;
        }
   }

   # 2 throttles full foward during an autoland or glide slope
   if( count >= 2 ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# check compatibility
# - autopilot channel 1
# - autopilot channel 2
Autothrottle.atdiscincompatible = func {
    apchannel1 = arg[0];
    apchannel2 = arg[1];

    # disconnect autothrottle, if not compatible
    if( me.is_maxclimb() ) {
        channel1 = me.channels[0].getChild("engage").getValue();
        channel2 = me.channels[1].getChild("engage").getValue();

        # same channel if maxclimb or maxcruise mode
        if( ( apchannel1 and apchannel2 ) or ( apchannel1 and channel2 ) or ( apchannel2 and channel1 ) ) {
            me.atdiscexport();
        }
    }
}

# disconnect speed 2 mode
Autothrottle.atdiscspeed2 = func {
   me.ap.getChild("speed2").setValue("");
}

# disconnect speed mode
Autothrottle.atdiscspeed = func {
   me.ap.getChild("speed").setValue("");
}

# disconnect autothrottle
Autothrottle.atdiscspeedmode2 = func {
   me.atdiscspeed();
   me.atdiscspeed2();
}

# disconnect autothrottle
Autothrottle.atdiscexport = func {
   me.atdiscspeedmode2();

   me.channels[0].getChild("engage").setValue(constant.FALSE);
   me.channels[1].getChild("engage").setValue(constant.FALSE);

   me.atengage();
}

Autothrottle.is_disc = func {
   speedmode = me.ap.getChild("speed").getValue();
   speedmode2 = me.ap.getChild("speed2").getValue();

   if( speedmode == "" and speedmode2 == "" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autothrottle.atactivatemode2 = func( property, value, value2 ) {
   if( property == "speed" ) {
       me.ap.getChild("speed2").setValue(value2);
   }

   me.ap.getChild(property).setValue(value);
}

Autothrottle.atactivatemode = func( property, value ) {
   me.ap.getChild(property).setValue(value);
}

Autothrottle.is_engaged = func {
   if( me.channels[0].getChild("engage").getValue() or
       me.channels[1].getChild("engage").getValue() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autothrottle.atengage = func {
   if( me.is_engaged() ) {
       mode = me.ap.getChild("speed").getValue();
   }
   else {
      mode = "";
   }

   me.locks.getChild("speed").setValue(mode);

   me.iaslight();
}

Autothrottle.atenable = func {
   if( !me.is_engaged() ) {
        me.channels[0].getChild("engage").setValue(constant.TRUE);
   }
}

# activate autothrottle
Autothrottle.atexport = func {
   channel1 = me.channels[0].getChild("engage").getValue();
   channel2 = me.channels[1].getChild("engage").getValue();

   # only 1 channel in max climb or max cruise mode
   if( channel1 and channel2 ) {
       if( me.is_maxclimb() ) {
           me.channels[1].getChild("engage").setValue(constant.FALSE);
       }
   }

   # IAS hold is default on activation
   elsif( channel1 or channel2 ) {
       if( me.is_disc() ) {
           me.atspeedholdexport();
       }
       else {
           me.atengage();
       }
   }

   else {
       me.atengage();
   }
}

# cannot make a settimer on a class member
speedacquirecron = func {
   autothrottlesystem.speedacquire();
}

Autothrottle.speedacquire = func {
   if( me.is_engaged() ) {
       if( me.is_speed_acquire() ) {
           minkt = getprop("/systems/autopilot/airspeed/light-min-kt");
           maxkt = getprop("/systems/autopilot/airspeed/light-max-kt");
           speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();

           # swaps to speed hold
           if( speedkt > minkt and speedkt < maxkt ) {
               me.atdiscspeed2();
           }
           else {
               settimer(speedacquirecron,me.SPEEDACQUIRESEC);
           }
       }
   }
}

Autothrottle.speed = func( speedkt ) {
   me.settings.getChild("target-speed-kt").setValue(speedkt);
}

Autothrottle.atspeedselectexport = func {
   if( me.is_speed_acquire() ) {
       speedkt = me.ap.getChild("speed-select").getValue();
       me.speed(speedkt);
   }
}

Autothrottle.is_speed_acquire = func {
   speed2mode = me.ap.getChild("speed2").getValue();
   if( speed2mode == "speed-acquire" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autothrottle
Autothrottle.atspeedexport = func {
   if( !me.is_speed_acquire() ) {
       me.atactivatemode2("speed","speed-with-throttle","speed-acquire");
       me.atspeedselectexport();
   }
   else{
       me.atdiscspeedmode2();
   }

   me.atengage();

   me.speedacquire();
}

Autothrottle.is_lock_vertical = func {
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode == "vertical-speed-with-throttle" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autothrottle.is_lock_glide = func {
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode == "gs1-with-throttle" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autothrottle.is_lock_throttle = func {
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode == "speed-with-throttle" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle autothrottle (ctrl-S)
Autothrottle.attogglespeedexport = func {
   if( !me.no_voltage() ) {
       # disable speed hold, if any
       if( me.is_lock_throttle() ) {
           me.atdiscexport();
       }
       else {
           me.atenable();
           me.atspeedexport();
       }
   }
}

Autothrottle.mach = func( speedmach ) {
   me.settings.getChild("target-mach").setValue(speedmach);
}

# hold mach
Autothrottle.holdmach = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();
   me.mach(speedmach);
}

Autothrottle.is_mach_throttle = func {
   speedmode = me.ap.getChild("speed").getValue();
   if( speedmode == "mach-with-throttle" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# mach hold
Autothrottle.atmachexport = func {
   if( !me.is_mach_throttle() ) {
       me.holdmach();
       me.atactivatemode("speed","mach-with-throttle","");
   }
   else{
       me.atdiscspeedmode2();
   }

   me.atengage();
}

# hold speed
Autothrottle.holdspeed = func {
   speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();
   me.speed(speedkt);
}

Autothrottle.is_speed_throttle = func {
   speedmode = me.ap.getChild("speed").getValue();
   if( speedmode == "speed-with-throttle" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autothrottle.is_speed_hold = func {
   speed2mode = me.ap.getChild("speed2").getValue();
   if( speed2mode == "" and me.is_speed_throttle() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# speed hold
Autothrottle.atspeedholdexport = func {
   if( !me.is_speed_hold() ) {
       me.holdspeed();
       me.atactivatemode2("speed","speed-with-throttle","");
   }
   else{
       me.atdiscspeedmode2();
   }

   me.atengage();
}

# spring returns to center, once released by hand
Autothrottle.releasedatum = func {
   if( me.ap.getNode("datum/speed").getValue() != 0.0 ) {
       # no mouse left click
       if( !me.mouse[0].getValue() ) {
           me.ap.getNode("datum/speed").setValue(0.0);
       }
   }
}

# datum adjust of autothrottle, argument :
# - step : plus/minus 1
Autothrottle.datumatexport = func( sign ) {
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode != "" and speedmode != nil ) {
       result = constant.TRUE;

       # plus/minus 0.06 Mach (real)
       if( speedmode == "mach-with-throttle" ) {
           # 0.006 Mach per second (real)
           value = 0.006 * sign;
           step = 1.0 * sign;
       }
       # plus/minus 22 kt (real)
       elsif( speedmode == "speed-with-throttle" ) {
           # 2 kt per second (real) : 1 kt per key
           value = 1.0 * sign;
           step = 0.454545 * sign;
       }
       # default (touches cursor)
       else {
           step = 1.0 * sign;
       }

       # limited to plus/minus 10 steps
       datum = me.ap.getNode("datum/speed").getValue();
       if( datum == nil ) {
           datum = step;
       }
       else {
           datumold = datum;
           datum = datum + step;

           # maximum value of cursor
           if( datum > 10.0 and datumold < 10.0 ) {
               maxstep = 10.0 - datumold;
               ratio = maxstep / step;
               value = ratio * value;
               datum = 10.0;
           }
           # minimum value of cursor
           elsif( datum < -10.0 and datumold > -10.0 ) {
               maxstep = -10.0 - datumold;
               ratio = maxstep / step;
               value = ratio * value;
               datum = -10.0;
           }
       }

       if( datum >= -10.0 and datum <= 10.0 ) {
           if( speedmode == "mach-with-throttle" ) {
               targetmach = me.settings.getChild("target-mach").getValue();
               targetmach = targetmach + value;
               me.mach(targetmach);
           }
           elsif( speedmode == "speed-with-throttle" ) {
               targetkt = me.settings.getChild("target-speed-kt").getValue();
               targetkt = targetkt + value;
               me.speed(targetkt);
           }

           me.ap.getNode("datum/speed").setValue(datum);
       }
   }

   else {
       result = constant.FALSE;
   }

   return result;
}


# ===============================
# GROUND PROXIMITY WARNING SYSTEM
# ===============================

Gpws = {};

Gpws.new = func {
   obj = { parents : [Gpws],

           slave : { "radioaltimeter" : nil }
         };

   obj.init();

   return obj;
};

Gpws.init = func {
   propname = getprop("/systems/gpws/slave/radio-altimeter");
   me.slave["radioaltimeter"] = props.globals.getNode(propname);

   # reads the user customization, JSBSim has an offset of 11 ft
   decisionft = me.slave["radioaltimeter"].getChild("dial-decision-ft").getValue();
   decisionft = decisionft + constantaero.AGLFT;
   me.slave["radioaltimeter"].getChild("decision-ft").setValue(decisionft);
}

Gpws.schedule = func {
    if( getprop("/systems/gpws/serviceable") ) {
        if( !getprop("/systems/gpws/decision-height") ) {
            decisionft = me.slave["radioaltimeter"].getChild("decision-ft").getValue();
            aglft = me.slave["radioaltimeter"].getChild("indicated-altitude-ft").getValue();

            # reset the DH light
            if( aglft > decisionft ) {
                setprop("/systems/gpws/decision-height",constant.TRUE);
            }
        }
    }
}
