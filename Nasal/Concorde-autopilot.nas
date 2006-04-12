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
           electricalsystem : nil,
 
           ap : nil,
           channels : nil,
           waypoints : nil,

           AUTOPILOTSEC : 3.0,                            # refresh rate
           ALTACQUIRESEC : 2.0,
           MAXCLIMBSEC : 1.0,

           AUTOPILOTSONIC : 1.0,                          # Mach where the PID changes
           CLIMBFPM : 2000.0,
           ACQUIREFPM : 800.0,
           DESCENTFPM : -1000.0,
           TRANSITIONFT : 25000.0,                        # altitude for Mach speed
           COEFVOR : 0.0,
           COEFWPT : 0.0,
           ROLLDEG : 2.0,

# autoland
           SAFESEC : 1.0,
           GOAROUNDSEC : 1.0,
           TOUCHSEC : 0.2,
           FLARESEC : 0.1,
           LANDINGKG : 19000.0,                           # max fuel for landing
           LANDINGDEG : 10.0,                             # landing pitch
# If 10 degrees, vertical speed, too high to catch the glide slope, cannot be recovered during the last 100 ft.
# If no pitch control, sudden swap to 10 deg causes a rebound, worsened by the ground effect.
# Ignoring the glide slope at 200-300 ft, with a pitch of 10 degrees, would be simpler;
# but the glide slope following is implicit until 100 ft (red autoland light).
# Note that these values depends of FDM.
           FLAREDEG : 8.5,
           AUTOLANDFEET : 1500.0,
           FLAREFEET : 500.0,                             # starts the flare pitch
           PITCHFEET : 100.0,                             # reaches the flare pitch
           LANDFEET : 100.0,                              # controls the landing vertical speed
           VREFLANDINGKT : 162.0,
           VREFEMPTYKT : 152.0,
           TOUCHFPM : -750.0,
           landheadingdeg : 0.0,

# slaves
           slave : [ nil, nil, nil, nil, nil, nil, nil, nil, nil ],
           altimeter : 0,
           asi : 1,
           dme : 2,
           ins : 3,
           ivsi : 4,
           mach : 5,
           nav : 6,
           radioaltimeter : 7,
           weight : 8
         };

# autopilot initialization
   obj.init();

   return obj;
};

Autopilot.init = func {
   me.ap = props.globals.getNode("/controls").getChildren("autoflight");
   me.channels = props.globals.getNode("/controls/autoflight").getChildren("autopilot");
   me.waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");

   propname = getprop("/systems/autopilot/slave/altimeter");
   me.slave[me.altimeter] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/asi");
   me.slave[me.asi] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/dme");
   me.slave[me.dme] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/ins");
   me.slave[me.ins] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/ivsi");
   me.slave[me.ivsi] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/mach");
   me.slave[me.mach] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/nav");
   me.slave[me.nav] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/radio-altimeter");
   me.slave[me.radioaltimeter] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/weight");
   me.slave[me.weight] = props.globals.getNode(propname);

   # 3 NM at 450 kt 
   me.COEFWPT = 3 * constant.HOURTOSECOND / 450;
   # 3 NM at 250 kt 
   me.COEFVOR = 3 * constant.HOURTOSECOND / 250;

   me.apdiscexport();
}

Autopilot.set_relation = func( autothrottle, electrical ) {
   me.autothrottlesystem = autothrottle;
   me.electricalsystem = electrical;
}

Autopilot.schedule = func {
   me.supervisor();
}

Autopilot.supervisor = func {
   me.inslight();

   # waypoint transition
   if( me.is_engaged() ) {
       mode = getprop("/controls/autoflight/horizontal");
       if( mode == "ins" ) {
           me.waypointroll();
       }

       # VOR transition
       elsif( mode == "vor" ) {
           me.vorroll();
       }
   }

   # more sensitive at supersonic speed
   lock = getprop("/autopilot/locks/heading");
   if( lock == "dg-heading-hold" ) {
       me.sonicmagneticheading();

       # not real : FG default keyboard changes autopilot heading
       if( getprop("/controls/autoflight/horizontal") == "track-heading" ) {
           headingdeg = getprop("/autopilot/settings/heading-bug-deg");
           setprop("/controls/autoflight/heading-select",headingdeg);
       }
   }

   elsif( lock == "true-heading-hold" ) {
       me.sonictrueheading();
   }
   else {
       me.apdischeadingsonic();
   }

   lock2 = getprop("/autopilot/locks/altitude");
   if( lock2 == "vertical-speed-hold" ) {
       me.sonicverticalspeed();
   }
   else {
       me.apdiscaltitudesonic();
   }

   # disconnect autopilot if no voltage (TO DO by FG)
   me.voltage();
}

# disconnect if no voltage (cannot disable the autopilot !)
Autopilot.voltage = func {
   voltage1 = me.electricalsystem.has_autopilot1();
   voltage2 = me.electricalsystem.has_autopilot2();

   if( !voltage1 or !voltage2 ) {
       # not yet in hand of copilot
       if( !getprop("/systems/autopilot/state/virtual-autopilot") ) {

           # disconnect autopilot 1
           if( !voltage1 ) {
               channel = me.channels[0].getChild("engage").getValue();
               if( channel ) {
                   me.channels[0].getChild("engage").setValue(constant.FALSE);
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
                   me.channels[1].getChild("engage").setValue(constant.FALSE);
                   channel = me.channels[0].getChild("engage").getValue();
                   if( !channel ) {
                       me.apdiscexport();
                   }
               }
           }

           me.autothrottlesystem.voltage( voltage1, voltage2 );
       }
   }

   # only if no voltage
   me.clearcopilot( voltage1, voltage2 );
}

# for 4 engines flame out
Autopilot.virtualcopilot = func {
   if( getprop("/systems/autopilot/state/virtual-copilot") ) {

       # clear autopilot
       if( !getprop("/systems/autopilot/state/virtual-autopilot") ) {
           me.apdiscexport();
           me.autothrottlesystem.atdiscexport();
           setprop("/systems/autopilot/state/virtual-autopilot",constant.TRUE);
       }

       # hold current heading and speed
       me.apenable();

       if( getprop("/autopilot/locks/heading") != "dg-heading-hold") {
           me.apheadingholdexport();
       }

       altitudemode = getprop("/autopilot/locks/altitude");
       altitudeft = noinstrument.get_altitude_ft();
       if( altitudeft > me.TRANSITIONFT and altitudemode != "mach-with-pitch" ) {
           me.apmachpitchexport();
       }
       elsif( altitudeft <= me.TRANSITIONFT and altitudemode != "speed-with-pitch" ) {
           me.apspeedpitchexport();
       }
   }
}

# disable virtual copilot
Autopilot.clearcopilot = func( voltage1, voltage2 ) {
   if( getprop("/systems/autopilot/state/virtual-copilot") ) {

       # returns to real mode, once voltages are normal
       if( voltage1 and voltage2 ) {
           setprop("/systems/autopilot/state/virtual-autopilot",constant.FALSE);
           setprop("/systems/autopilot/state/virtual-copilot",constant.FALSE);
       }

       # disconnect button pressed
       else {
           me.virtualcopilot();
       }
   }
}

# virtual copilot
Autopilot.apcopilotexport = func {
   if( !getprop("/systems/autopilot/state/virtual-copilot") ) {
       setprop("/systems/autopilot/state/virtual-autopilot",constant.FALSE);
       setprop("/systems/autopilot/state/virtual-copilot",constant.TRUE);

       me.virtualcopilot();
   }

   # keep the buttons pressed by the copilot
   else {
       me.clearcopilot( constant.TRUE, constant.TRUE );
   }
}

# avoid strong roll near a waypoint
Autopilot.waypointroll = func {
    lock = getprop("/autopilot/locks/heading");

    distance = me.waypoints[0].getChild("dist").getValue();

    # next waypoint
    if( distance != nil ) {

        # 3 NM at 450 kt 
        speedkt = me.slave[me.asi].getChild("indicated-speed-kt").getValue();
        speednmps =  speedkt / constant.HOURTOSECOND;
        rangenm = speednmps * me.COEFWPT;

        # restores after waypoint pop
        if( lock == "dg-heading-hold" ) {
            wpt = me.waypoints[0].getChild("id").getValue();
            lastwpt = getprop("/systems/autopilot/state/waypoint");
            if( wpt != lastwpt ) {
                me.locktrueheading();
            }
        }

        # avoids strong roll
        elsif( distance < rangenm ) {
            # 2 time steps
            stepnm = speednmps * me.AUTOPILOTSEC;
            stepnm = stepnm * 2.0;

            # switches to heading hold
            rolldeg =  getprop("/orientation/roll-deg");
            if( distance < stepnm or rolldeg < - me.ROLLDEG or rolldeg > me.ROLLDEG ) {
                if( lock == "true-heading-hold" ) {
                    me.magneticheading();
                    me.lockmagneticheading();
                    wpt = me.waypoints[0].getChild("id").getValue();
                    setprop("/systems/autopilot/state/waypoint",wpt);
                }
            }
        }
    }
}

# avoid strong roll near a VOR
Autopilot.vorroll = func {
    lock = getprop("/autopilot/locks/heading");

    # near VOR
    if( me.slave[me.dme].getChild("in-range").getValue() ) {

        # 3 NM at 250 kt 
        speedkt = me.slave[me.asi].getChild("indicated-speed-kt").getValue();
        speednmps =  speedkt / constant.HOURTOSECOND;
        rangenm = speednmps * me.COEFVOR;

        # restores after VOR
        if( me.slave[me.dme].getChild("indicated-distance-nm").getValue() > rangenm ) {
            if( lock == "dg-heading-hold" ) {
                me.locknav1();
            }

            setprop("/systems/autopilot/state/vor-engage",constant.FALSE);
        }

        # avoids strong roll
        else {
            # switches to heading hold
             if( lock == "nav1-hold" ) {
                 # except if mode has just been engaged, leaving a VOR :
                 # EGLL 27R, then leaving LONDON VOR 113.60 on its 260 deg radial (SID COMPTON 3).
                 if( !getprop("/systems/autopilot/state/vor-engage") or
                     ( getprop("/systems/autopilot/state/vor-engage") and
                       me.slave[me.nav].getChild("from-flag").getValue() ) ) { 
                     me.magneticheading();
                     me.lockmagneticheading();
                 }
            }
        }
    }
}

# ---------------
# AUTOPILOT MODES
# ---------------

# disconnect autopilot
Autopilot.apdiscexport = func {
   me.apdischeading();
   me.apdiscvertical();
   me.apdischorizontal();
   me.apdiscaltitude();

   me.channels[0].getChild("engage").setValue(constant.FALSE);
   me.channels[1].getChild("engage").setValue(constant.FALSE);
}

# activate a mode, and engage a channel
# - property
# - value
Autopilot.apactivatemode = func {
   property = arg[0];
   value = arg[1];

   setprop(property, value);

   channel1 = me.channels[0].getChild("engage").getValue();
   channel2 = me.channels[1].getChild("engage").getValue();

   # remove 2nd channel of autoland after a goaround
   if( channel1 and channel2 ) {
       vertical = me.ap[0].getChild("vertical").getValue();

       if( vertical != "autoland" and vertical != "autoland-armed" ) {
           channel2 = constant.FALSE;
           me.channels[1].getChild("engage").setValue(channel2);
       }
   }

   me.autothrottlesystem.atdiscincompatible( channel1, channel2 );
}

Autopilot.apenable = func {
   if( !me.is_engaged() ) {
       me.channels[0].getChild("engage").setValue(constant.TRUE);
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
       altitudemode = getprop("/controls/autoflight/altitude");
       headingmode = getprop("/controls/autoflight/heading");
   }
   else {
       altitudemode = "";
       headingmode = "";
   }

   setprop("/autopilot/locks/altitude",altitudemode);
   setprop("/autopilot/locks/heading",headingmode);

   me.supervisor();
}

# activate autopilot
Autopilot.apexport = func {
   altitude = me.ap[0].getChild("altitude").getValue();
   heading = me.ap[0].getChild("heading").getValue();
   vertical = me.ap[0].getChild("vertical").getValue();
   horizontal = me.ap[0].getChild("horizontal").getValue();
   channel1 = me.channels[0].getChild("engage").getValue();
   channel2 = me.channels[1].getChild("engage").getValue();

   # 2 channels only in land mode
   if( channel1 and channel2 ) {
       if( vertical != "autoland" and vertical != "autoland-armed" ) {
           me.channels[1].getChild("engage").setValue(constant.FALSE);
       }
   }

   # pitch hold and heading hold is default on activation
   elsif( channel1 or channel2 ) {
       if( altitude == "" and heading == "" and vertical == "" and horizontal == "" ) {
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

# datum adjust of autopilot, arguments
# - step plus/minus 1 (fast) or 0.1 (slow)
Autopilot.datumapexport = func( sign ) {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "" and altitudemode != nil ) {
       result = constant.TRUE;

       # plus/minus 11 deg
       if( altitudemode == "pitch-hold" ) {
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
       # plus/minus 6000 ft/min (real)
       elsif( altitudemode == "vertical-speed-hold" ) {
           # 80 or 800 ft/min per second (real) : 10 or 100 ft/min per key
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
               step = 0.16667 * sign;
           }
           else {
               value = 100.0 * sign;
               step = 0.16667 * sign;
           }
       }
       # default (touches cursor)
       else {
           step = 1.0 * sign;
       }

       # limited to plus/minus 10 steps
       datum = getprop("/controls/autoflight/datum/altitude");
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
           if( altitudemode == "pitch-hold" ) {
               targetdeg = getprop("/autopilot/settings/target-pitch-deg");
               targetdeg = targetdeg + value;
               me.pitch( targetdeg );
           }
           elsif( altitudemode == "altitude-hold" ) {
               targetft = getprop("/autopilot/settings/target-altitude-ft");
               targetft = targetft + value;
               setprop("/autopilot/settings/target-altitude-ft",targetft);
           }
           elsif( altitudemode == "speed-with-pitch" ) {
               targetkt = getprop("/autopilot/settings/target-speed-kt");
               targetkt = targetkt + value;
               setprop("/autopilot/settings/target-speed-kt",targetkt);
           }
           elsif( altitudemode == "mach-with-pitch" ) {
               targetmach = getprop("/autopilot/settings/target-mach");
               targetmach = targetmach + value;
               setprop("/autopilot/settings/target-mach",targetmach);
           }
           elsif( altitudemode == "vertical-speed-hold" ) {
               targetfpm = getprop("/autopilot/settings/vertical-speed-fpm");
               if( targetfpm == nil ) {
                   targetfpm = 0.0;
               }
               targetfpm = targetfpm + value;
               setprop("/autopilot/settings/vertical-speed-fpm",targetfpm);
           }

           setprop("/controls/autoflight/datum/altitude",datum);
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
   fds = props.globals.getNode("/controls/autoflight").getChildren("flight-director");
   fd1 = fds[0].getChild("engage").getValue();
   fd2 = fds[1].getChild("engage").getValue();

   if( fd1 or fd2 ) {
       altitude = me.ap[0].getChild("altitude").getValue();
       heading = me.ap[0].getChild("heading").getValue();
       vertical = me.ap[0].getChild("vertical").getValue();
       horizontal = me.ap[0].getChild("horizontal").getValue();

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

# disconnect vertical mode
Autopilot.apdiscvertical = func {
   setprop("/controls/autoflight/vertical","");
}

# go around mode
Autopilot.goaround = func {
   verticalmode = getprop("/controls/autoflight/vertical");

   # cron runs without autopilot engagement
   if( me.is_engaged() ) {

       # 2 throttles full foward during an autoland or glide slope
       if( getprop("/controls/autoflight/altitude") == "gs1-hold" or verticalmode == "autoland" ) {
           if( me.autothrottlesystem.goaround() ) {
               setprop("/controls/autoflight/heading","wing-leveler");

               # pitch at 15 deg and hold the wing level, until the next command of crew
               me.modepitch( 15 );

               # crew control
               me.autothrottlesystem.atdiscexport();

               # throttle is being changed by autothrottle
               me.autothrottlesystem.full();

               # light on
               me.apactivatemode("/controls/autoflight/vertical","goaround");

               me.apengage();
           }
       }
   }

   # light off
   if( verticalmode == "goaround" ) {
       if( getprop("/controls/autoflight/altitude") != "pitch-hold" or
           getprop("/controls/autoflight/heading") != "wing-leveler" ) {
           me.apdiscvertical();
       }
   }
}

# CAUTION, avoids concurrent crons (stack overflow Nasal error) :
# one may activate glide slope, then arm autoland = 2 calls.
Autopilot.is_goaround = func {
   if( getprop("/controls/autoflight/vertical2") == "goaround-armed" or
       getprop("/controls/autoflight/vertical") == "goaround" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.clampkg = func ( vallanding, valempty ) {
    tankskg = me.slave[me.weight].getChild("total-kg").getValue();
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
   windkt = me.slave[me.ins].getChild("wind-speed-kt").getValue();
   if( windkt > 0 ) {
       winddeg = me.slave[me.ins].getChild("wind-from-heading-deg").getValue();
       vordeg = me.slave[me.nav].getNode("radials").getChild("target-radial-deg").getValue();
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
   setprop("/autopilot/settings/target-speed-kt",targetkt);
}

# smooth the rebound of pitch hold during the flare
Autopilot.targetpitch = func( targetdeg, aglft, rates ) {
   # start from attitude
   if( getprop("/controls/autoflight/altitude") != "pitch-hold" ) {
       pitchdeg = getprop("/orientation/pitch-deg");
   }
   else {
       pitchdeg = getprop("/autopilot/settings/target-pitch-deg");
   }

   if( pitchdeg != targetdeg ) {
       if( targetdeg > pitchdeg ) {
           speedfps = - me.slave[me.ivsi].getChild("indicated-speed-fps").getValue();
           deltaft = aglft - me.PITCHFEET;
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

   verticalmode = getprop("/controls/autoflight/vertical") ;
   verticalmode2 = "";      

   # to catch the go around
   rates = me.GOAROUNDSEC;

   if( verticalmode == "autoland" or verticalmode == "autoland-armed" ) {
       verticalmode2 = "goaround-armed";

       # cron runs without autopilot engagement
       if( me.is_engaged() ) {
           aglft = me.slave[me.radioaltimeter].getChild("indicated-altitude-ft").getValue();

           # armed
           if( verticalmode == "autoland-armed" ) {
               if( aglft <= me.AUTOLANDFEET ) {
                   verticalmode = "autoland";
                   setprop("/controls/autoflight/vertical",verticalmode);
               }
           }

           # engaged
           if( verticalmode == "autoland" ) {
               # touch down
               if( aglft < constantaero.AGLTOUCHFT ) {

                   # gently reduce pitch
                   if( getprop("/orientation/pitch-deg") > 1.0 ) {
                       rates = me.TOUCHSEC;

                       # 1 deg / s
                       pitchdeg = getprop("/autopilot/settings/target-pitch-deg");
                       pitchdeg = pitchdeg - 0.2;
                       me.modepitch( pitchdeg );
                       me.autothrottlesystem.atdiscthrottle();
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
               elsif( aglft > me.AUTOLANDFEET ) {
                   verticalmode = "autoland-armed";
                   setprop("/controls/autoflight/vertical",verticalmode);
               }

               # approach
               else {
                   mode = getprop("/controls/autoflight/speed");

                   # if activated below 1500 ft
                   me.apdischorizontal();

                   if( aglft < me.FLAREFEET ) {
                       rates = me.FLARESEC;

                       # landing pitch (flare) :
                       # - not above 100 ft, because outside of glide slope (autoland red light).
                       # - vertical-speed-with-throttle removes the rebound at touch down of vertical-speed-hold.
                       # - possible glide slope (real ?) errors below 100 ft (example KJFK 22L, EGLL 27R) :
                       # heading hold avoids roll outside the runway.
                       if( aglft < me.LANDFEET ) {
                           if( getprop("/controls/autoflight/heading") != "dg-heading-hold" ) {
                                  me.landheadingdeg = getprop("/orientation/heading-magnetic-deg");
                           }
                           setprop("/autopilot/settings/heading-bug-deg",me.landheadingdeg);
                           me.apactivatemode("/controls/autoflight/heading","dg-heading-hold");
                           me.modepitch( me.LANDINGDEG );
                           setprop("/autopilot/settings/vertical-speed-fpm",me.TOUCHFPM);
                           me.autothrottlesystem.atactivatemode("/controls/autoflight/speed","vertical-speed-with-throttle");
                       }

                       # tip to landing pitch :
                       # - sooner at 10 deg reduces the rebound.
                       # - cannot go back, when rebound.
                       # - possible glide slope (real ?) errors below 200 ft (example RJAA 34) :
                       # glide slope with throttle is less prone to lose pitch to catch the glide slope below.
                       elsif( mode != "vertical-speed-with-throttle" ) {
                           me.apactivatemode("/controls/autoflight/heading","nav1-hold");
                           me.targetpitch( me.FLAREDEG, aglft, rates );
                           me.autothrottlesystem.atactivatemode("/controls/autoflight/speed","gs1-with-throttle");
                       } 
                   }

                   # glide slope : cannot go back when then aircraft climbs again (rebound caused by landing pitch),
                   # otherwise will crash to catch the glide slope.
                   elsif( mode != "gs1-with-throttle" ) {
                       me.apactivatemode("/controls/autoflight/heading","nav1-hold");
                       me.modeglide();

                       # near VREF (no wind)
                       me.targetwind();
                       me.autothrottlesystem.atactivatemode("/controls/autoflight/speed","speed-with-throttle");
                   }

                   # pilot must activate autothrottle
                   me.autothrottlesystem.atengage();
               }
           }

           me.apengage();
       }
   }
   else {
       if( getprop("/controls/autoflight/altitude") == "gs1-hold" ) {
           verticalmode2 = "goaround-armed";      
       }
   }

   setprop("/controls/autoflight/vertical2",verticalmode2);

   # re-schedule the next call
   if( me.is_goaround() ) {
       settimer(autolandcron, rates);
   }
}

# autopilot autoland
Autopilot.aplandexport = func {
   verticalmode = getprop("/controls/autoflight/vertical");
   if( verticalmode != "autoland" and verticalmode != "autoland-armed" ) {
       me.apactivatemode("/controls/autoflight/vertical","autoland-armed");
   }
   else {
       me.apdiscvertical();
   }

   me.apengage();

   if( !me.is_goaround() ) {
       me.autoland();
   }
}

# autopilot turbulence mode
Autopilot.apturbulenceexport = func {
   verticalmode = getprop("/controls/autoflight/vertical");
   if( verticalmode != "turbulence" ) {
       me.apactivatemode("/controls/autoflight/vertical","turbulence");
       me.attitudepitch();
       setprop("/controls/autoflight/altitude","pitch-hold");
       me.magneticheading();
       setprop("/controls/autoflight/heading","dg-heading-hold");
       me.apdischorizontal();
   }
   else {
       me.apdiscvertical();
       me.apdiscaltitude();
       me.apdischeading(); 
   }

   me.apengage();
}

# -------------
# ALTITUDE MODE
# -------------

# disconnect autopilot altitude
Autopilot.apdiscaltitude = func {
   setprop("/controls/autoflight/altitude","");
   setprop("/autopilot/locks/altitude","");

   me.apdiscaltitudesonic();
}

Autopilot.apdiscaltitudesonic = func {
   setprop("/autopilot/locks/sonic/altitude","");
}

# altitude button lights, when the dialed altitude is reached.
# altimeter light, when the dialed altitude is reached.
Autopilot.altitudelight = func {
   if( me.is_engaged() ) {

       altitudemode = getprop("/controls/autoflight/altitude");
       verticalmode = getprop("/controls/autoflight/vertical");

       if( altitudemode == "altitude-hold" or verticalmode == "altitude-acquire" ) {
           altft = getprop("/autopilot/settings/target-altitude-ft");

           # altimeter light within 1200 ft
           minft = altft - 1200;
           setprop("/systems/autopilot/altimeter/target-min-ft",minft);
           maxft = altft + 1200;
           setprop("/systems/autopilot/altimeter/target-max-ft",maxft);

           # no altimeter light within 50 ft
           minft = altft - 50;
           setprop("/systems/autopilot/altimeter/light-min-ft",minft);
           maxft = altft + 50;
           setprop("/systems/autopilot/altimeter/light-max-ft",maxft);
       }
   }
}

# cannot make a settimer on a class member
altitudeacquirecron = func {
   autopilotsystem.altitudeacquire();
}

# altitude acquire
Autopilot.altitudeacquire = func {
   if( me.is_engaged() ) {
       verticalmode = getprop("/controls/autoflight/vertical");
       if( verticalmode == "altitude-acquire" ) {
           altitudemode = getprop("/controls/autoflight/altitude");
           me.altitudelight();

           altitudeft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
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
               if( altitudemode != "altitude-hold" ) {
                   me.apactivatemode("/controls/autoflight/altitude","altitude-hold");
               }
               mode = "capture";
           }

           # at level
           else {
               me.apdiscvertical();
               mode = "";
           }

           # default to vertical speed hold 800 ft/min, if comes from altitude hold;
           if( mode == "vertical" ) {
               if( altitudemode == "altitude-hold" ) {
                   # pilot can change
                   me.modeverticalspeed( speedfpm );
               }
           }

           me.apengage();

           # otherwise keep the previous vertical mode (if any),
           # which is supposed to reach the capture level, by pilot action

           # re-schedule the next call
           if( mode != "" ) {
               settimer(altitudeacquirecron, me.ALTACQUIRESEC);
           }
       }
   }
}

# toggle altitude hold (ctrl-A)
Autopilot.aptogglealtitudeexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");

   # disable speed hold, if any
   if( altitudemode == "altitude-hold" ) {
       me.apdiscaltitude();
       me.apdiscvertical();
   }

   # must toggle the mode
   else {
       altitudemode = getprop("/controls/autoflight/altitude");
       verticalmode = getprop("/controls/autoflight/vertical");
       if( altitudemode != "vertical-speed-hold" or verticalmode == "altitude-acquire" ) {
           me.apenable();
           me.apverticalexport();
       }
       me.apaltitudeexport();

       # avoid many manual operations
       altitudemode = getprop("/controls/autoflight/altitude");
       if( altitudemode == "vertical-speed-hold" ) {
           altitudeft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
           targetft = getprop("/autopilot/settings/target-altitude-ft");
           if( altitudeft > targetft ) {
               speedfpm = me.DESCENTFPM;
           }
           else {
               speedfpm = me.CLIMBFPM;
           }
           setprop("/autopilot/settings/vertical-speed-fpm",speedfpm);
       }
   }
}

# autopilot altitude acquire
Autopilot.apaltitudeexport = func {
   # only if a previous mode for the capture
   altitudemode = getprop("/controls/autoflight/altitude");
   if( altitudemode != "" ) {
       verticalmode = getprop("/controls/autoflight/vertical");
       if( verticalmode != "altitude-acquire" ) {
           me.apdiscvertical();
           altitudeft = getprop("/controls/autoflight/altitude-select");
           setprop("/autopilot/settings/target-altitude-ft",altitudeft);
           setprop("/controls/autoflight/vertical","altitude-acquire");
       }
       else {
           me.apdiscvertical();
       }

       me.apengage();

       me.altitudeacquire();
   }
}

# autopilot altitude hold
Autopilot.apaltitudeholdexport = func {
   altitudemode = getprop("/controls/autoflight/altitude");
   if( altitudemode != "altitude-hold" ) {
       altitudeft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
       setprop("/autopilot/settings/target-altitude-ft",altitudeft);
       me.apactivatemode("/controls/autoflight/altitude","altitude-hold");
       me.apdiscvertical();
   }
   else {
       me.apdiscaltitude();
       me.apdiscvertical();
   }

   me.apengage();

   me.altitudelight();
}

Autopilot.is_altitude_hold = func {
   result = me.is_engaged();

   if( result ) {
       altitudemode = getprop("/controls/autoflight/altitude");
       verticalmode = getprop("/controls/autoflight/vertical");
       if( altitudemode != "altitude-hold" or verticalmode != "" ) {
           result = constant.FALSE;
       }
       else {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.modeglide = func {
    setprop("/controls/autoflight/altitude","gs1-hold");
}

# toggle glide slope (ctrl-G)
Autopilot.aptoggleglideexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");

   # disable speed hold, if any
   if( altitudemode == "gs1-hold" ) {
       me.apdiscaltitude();
       me.apdiscvertical();
   }
   else {
       me.apenable();
       me.apglideexport();
   }
}

# autopilot glide slope
Autopilot.apglideexport = func {
   altitudemode = getprop("/controls/autoflight/altitude");
   if( altitudemode != "gs1-hold" ) {
       me.apactivatemode("/controls/autoflight/altitude","gs1-hold");
       setprop("/controls/autoflight/heading","nav1-hold");
       me.apdischorizontal();
   }
   else {
       me.apdiscaltitude();
       me.apdiscvertical();
       me.modevorloc();
   }

   me.apengage();

   if( !me.is_goaround() ) {
       me.autoland();
   }
}

Autopilot.attitudepitch = func {
   pitchdeg = getprop("/orientation/pitch-deg");
   setprop("/autopilot/settings/target-pitch-deg",pitchdeg);
}

Autopilot.pitch = func( pitchdeg ) {
   setprop("/autopilot/settings/target-pitch-deg",pitchdeg);
}

Autopilot.modepitch = func( pitchdeg ) {
   me.pitch( pitchdeg );
   setprop("/controls/autoflight/altitude","pitch-hold");
}

# toggle pitch hold (ctrl-P)
Autopilot.aptogglepitchexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");

   # disable speed hold, if any
   if( altitudemode == "pitch-hold" ) {
       me.apdiscaltitude();
   }
   else {
       me.apenable();
       me.appitchexport();
   }
}

# autopilot pitch hold
Autopilot.appitchexport = func {
   altitudemode = getprop("/controls/autoflight/altitude");
   if( altitudemode != "pitch-hold" ) {
       me.attitudepitch();
       me.apactivatemode("/controls/autoflight/altitude","pitch-hold");
       me.apdiscvertical();
   }
   else {
       me.apdiscaltitude();
       me.apdiscvertical();
   }

   me.apengage();
}

# sonic vertical speed
Autopilot.sonicverticalspeed = func {
   speedmach = me.slave[me.mach].getChild("indicated-mach").getValue();
   if( speedmach <= me.AUTOPILOTSONIC ) {
       mode = "vertical-speed-hold-sub";
   }
   else {
       mode = "vertical-speed-hold-super";
   }
   setprop("/autopilot/locks/sonic/altitude",mode);
}

Autopilot.modeverticalspeed = func( speedfpm ) {
   setprop("/autopilot/settings/vertical-speed-fpm",speedfpm);
   me.apactivatemode("/controls/autoflight/altitude","vertical-speed-hold");
}

# autopilot vertical speed hold
Autopilot.apverticalexport = func {
   altitudemode = getprop("/controls/autoflight//altitude");
   if( altitudemode != "vertical-speed-hold" ) {
       speedfps = me.slave[me.ivsi].getChild("indicated-speed-fps").getValue();
       speedfpm = speedfps * constant.MINUTETOSECOND;
       me.modeverticalspeed(speedfpm);
       me.apdiscvertical();
   }
   else {
       me.apdiscaltitude();
       me.apdiscvertical();
   }

   me.apengage();
}

# speed with pitch
Autopilot.apspeedpitchexport = func {
   altitudemode = getprop("/controls/autoflight/altitude");

   # only if no autothrottle
   if( altitudemode != "speed-with-pitch" ) {
       if( !me.autothrottlesystem.is_engaged() ) {
           me.autothrottlesystem.holdspeed();
           me.apactivatemode("/controls/autoflight/altitude","speed-with-pitch");
           me.apdiscvertical();
       }

       # default to pitch hold if autothrottle
       else {
           me.appitchexport();
       }
   }
   else {
       me.apdiscaltitude();
       me.apdiscvertical();
   }

   me.apengage();
}

# mach with pitch
Autopilot.apmachpitchexport = func {
   altitudemode = getprop("/controls/autoflight/altitude");

   # only if no autothrottle
   if( altitudemode != "mach-with-pitch" ) {
       if( !me.autothrottlesystem.is_engaged() ) {
           me.autothrottlesystem.holdmach();
           me.apactivatemode("/controls/autoflight/altitude","mach-with-pitch");
           me.apdiscvertical();
       }

       # default to pitch hold if autothrottle
       else {
           me.appitchexport();
       }
   }

   else {
       me.apdiscaltitude();
       me.apdiscvertical();
   }

   me.apengage();
}

# ---------------
# HORIZONTAL MODE
# ---------------

# disconnect horizontal mode
Autopilot.apdischorizontal = func {
   setprop("/controls/autoflight/horizontal","");
}

Autopilot.inslight = func {
   # pilot must activate himself the mode
   if( getprop("/controls/autoflight/horizontal") != "ins" ) {
       if( getprop("/autopilot/locks/heading") == "true-heading-hold" ) {

           # restore the previous heading mode
           distance = me.waypoints[0].getChild("dist").getValue();
           if( distance != nil and distance != 0.0 ) {
               me.apengage();
           }
       }
   }

   # no more waypoint
   else {

       # keeps the current heading mode
       if( me.waypoints[0].getChild("dist").getValue() == 0.0 ) {
           me.apdischorizontal();
       }
   }
}

# ins mode
Autopilot.apinsexport = func {
   horizontalmode = getprop("/controls/autoflight/horizontal");

   if( horizontalmode != "ins" ) {
       if( me.waypoints[0].getChild("id").getValue() != "" ) {
           me.apactivatemode("/controls/autoflight/heading","true-heading-hold");
           setprop("/controls/autoflight/horizontal","ins");
       }
   }
   else {
       me.apdischeading(); 
       me.apdischorizontal();
   }

   me.apengage();
}

# ------------
# HEADING MODE
# ------------

# disconnect heading mode
Autopilot.apdischeading = func {
   setprop("/controls/autoflight/heading","");
   setprop("/autopilot/locks/heading","");

   me.apdischeadingsonic();
}

# disconnect heading sonic
Autopilot.apdischeadingsonic = func {
   setprop("/autopilot/locks/sonic/heading","");
}

# sonic true mode
Autopilot.sonictrueheading = func {
   speedmach = me.slave[me.mach].getChild("indicated-mach").getValue();
   if( speedmach <= me.AUTOPILOTSONIC ) {
       mode = "true-heading-hold-sub";
   }
   else {
       mode = "true-heading-hold-super";
   }
   setprop("/autopilot/locks/sonic/heading",mode);
}

# true heading mode
Autopilot.locktrueheading = func {
    setprop("/autopilot/locks/heading","true-heading-hold");
}

# sonic magnetic mode
Autopilot.sonicmagneticheading = func {
   speedmach = me.slave[me.mach].getChild("indicated-mach").getValue();
   if( speedmach <= me.AUTOPILOTSONIC ) {
       mode = "dg-heading-hold-sub";
   }
   else {
       mode = "dg-heading-hold-super";
   }
   setprop("/autopilot/locks/sonic/heading",mode);
}

# magnetic heading mode
Autopilot.lockmagneticheading = func {
   setprop("/autopilot/locks/heading","dg-heading-hold");
}

# magnetic heading
Autopilot.magneticheading = func {
   headingdeg = getprop("/orientation/heading-magnetic-deg");
   setprop("/autopilot/settings/heading-bug-deg",headingdeg);
}

# heading hold
Autopilot.apheadingholdexport = func {
   mode = getprop("/controls/autoflight/horizontal");
   if( mode != "magnetic" ) {
       me.magneticheading();
       me.apactivatemode("/controls/autoflight/horizontal","magnetic");
       setprop("/controls/autoflight/heading","dg-heading-hold");
   }
   else {
       me.apdischeading(); 
       me.apdischorizontal();
   }

   me.apengage();
}

# toggle heading hold (ctrl-H)
Autopilot.aptoggleheadingexport = func {
   headingmode = getprop("/autopilot/locks/heading");

   # disable speed hold, if any
   if( headingmode == "dg-heading-hold" ) {
       me.apdischeading();
       me.apdischorizontal();
   }
   else {
       me.apenable();
       me.apheadingexport();
   }
}

# autopilot heading
Autopilot.apheadingexport = func {
   horizontalmode = getprop("/controls/autoflight/horizontal");
   if( horizontalmode != "track-heading" ) {
       me.apactivatemode("/controls/autoflight/horizontal","track-heading");
       if( !getprop("/controls/autoflight/track-push") ) {
           headingdeg = getprop("/controls/autoflight/heading-select");
           setprop("/autopilot/settings/heading-bug-deg",headingdeg);
           setprop("/controls/autoflight/heading","dg-heading-hold");
       }
       else {
           setprop("/controls/autoflight/heading","true-heading-hold");
       }
   }
   else {
       me.apdischeading(); 
       me.apdischorizontal();
   }

   me.apengage();
}

# VOR loc
Autopilot.modevorloc = func {
   headingmode = getprop("/controls/autoflight/heading");
   altitudemode = getprop("/controls/autoflight/altitude");
   if( headingmode == "nav1-hold" and altitudemode != "gs1-hold" ) {
       setprop("/controls/autoflight/horizontal","vor");
       setprop("/systems/autopilot/state/vor-engage",constant.TRUE);
   }
}

Autopilot.locknav1 = func {
   setprop("/autopilot/locks/heading","nav1-hold");
}

# toggle nav 1 hold (ctrl-N)
Autopilot.aptogglenav1export = func {
   headingmode = getprop("/autopilot/locks/heading");

   # disable speed hold, if any
   if( headingmode == "nav1-hold" ) {
       me.apdischeading();
       me.apdischorizontal();
   }
   else {
       me.apenable();
       me.apvorlocexport();
   }
}

# autopilot vor localizer
Autopilot.apvorlocexport = func {
   headingmode = getprop("/controls/autoflight/heading");
   if( headingmode != "nav1-hold" ) {
       me.apdischeadingsonic();
       me.apdischorizontal();
       me.apactivatemode("/controls/autoflight/heading","nav1-hold");
       me.modevorloc();
   }
   else {
       me.apdischeading(); 
       me.apdischorizontal();
   }

   me.apengage();
}

# ----------
# SPEED MODE
# ----------

# cannot make a settimer on a member function
maxclimbcron = func {
   autopilotsystem.maxclimb();
}

# max climb mode (includes max cruise mode)
Autopilot.maxclimb = func {
   speedmode = getprop("/controls/autoflight/speed2");
   if( speedmode == "maxclimb" or speedmode == "maxcruise" ) {          
       if( me.is_engaged() ) {

           # holds the VMO / MMO with pitch
           if( !me.autothrottlesystem.maxclimb( speedmode ) ) {
               altitudeft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
               if( altitudeft > me.TRANSITIONFT ) {
                   me.apmachpitchexport();
                   mmomach = me.slave[me.mach].getChild("mmo-mach").getValue();
                   setprop("/autopilot/settings/target-mach",mmomach);
               }
               else {
                   me.apspeedpitchexport();
                   vmokt = me.slave[me.asi].getChild("vmo-kt").getValue();
                   setprop("/autopilot/settings/target-speed-kt",vmokt);
               }

               # disable max climb
               me.autothrottlesystem.atdiscthrottle();
               me.autothrottlesystem.atengage();
           }
       }

       # re-schedule the next call
       settimer(maxclimbcron, me.MAXCLIMBSEC);
   }
}

# max climb mode
Autopilot.apmaxclimbexport = func {
   speedmode = getprop("/controls/autoflight/speed2");
   if( speedmode == "maxclimb" or speedmode == "maxcruise" ) {
       # switch to speed hold
       me.autothrottlesystem.atdiscspeed2();
       me.autothrottlesystem.holdspeed();
   }
   else {
       me.autothrottlesystem.atactivatemode("/controls/autoflight/speed2","maxclimb");
       me.maxclimb();
   }          
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

           SPEEDACQUIRESEC : 2.0,

           MAXMACH : 2.02,
           CRUISEMACH : 2.0,
           CLIMBMACH : 1.7,

# slaves
           slave : [ nil, nil, nil ],
           altimeter : 0,
           asi : 1,
           mach : 2
         };

# autopilot initialization
   obj.init();

   return obj;
}

Autothrottle.init = func {
   me.ap = props.globals.getNode("/controls").getChildren("autoflight");
   me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
   me.channels = props.globals.getNode("/controls/autoflight").getChildren("autothrottle");

   propname = getprop("/systems/autopilot/slave/altimeter");
   me.slave[me.altimeter] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/asi");
   me.slave[me.asi] = props.globals.getNode(propname);
   propname = getprop("/systems/autopilot/slave/mach");
   me.slave[me.mach] = props.globals.getNode(propname);

   me.atdiscexport();
}

Autothrottle.schedule = func {
   me.iaslight();
}

# ias light, when discrepancy with the autothrottle
Autothrottle.iaslight = func {
   if( me.is_engaged() ) {
       speedmode = getprop("/controls/autoflight/speed");
       if( speedmode == "speed-with-throttle" ) {
           speedkt = getprop("/autopilot/settings/target-speed-kt");

           # ias light within 10 kt
           minkt = speedkt - 10;
           setprop("/systems/autopilot/airspeed/light-min-kt",minkt);
           maxkt = speedkt + 10;
           setprop("/systems/autopilot/airspeed/light-max-kt",maxkt);
       }
   }
}

# max climb mode
Autothrottle.maxclimb = func( speedmode ) {
   result = constant.TRUE;
   speedmach = me.slave[me.mach].getChild("indicated-mach").getValue();

   # climb
   if( speedmach < me.CLIMBMACH ) {
       vmokt = me.slave[me.asi].getChild("vmo-kt").getValue();
       maxkt = me.slave[me.asi].getChild("overspeed-kt").getValue();
       speedkt = me.slave[me.asi].getChild("indicated-speed-kt").getValue();      # may be out of order

       # catches the VMO with autothrottle
       if( speedkt < maxkt ) {
            setprop("/autopilot/settings/target-speed-kt",vmokt);
            me.atactivatemode("/controls/autoflight/speed","speed-with-throttle");
       }

       # then holds the VMO with pitch
       else {
            result = constant.FALSE;
            me.atdiscspeed();
       }

       if( speedmode == "maxcruise" ) {
           me.atactivatemode("/controls/autoflight/speed2","maxclimb");
       }
   }

   # cruise
   else {
       mmomach = me.slave[me.mach].getChild("mmo-mach").getValue();

       # cruise at Mach 2.0-2.02 (reduce fuel consumption)          
       if( mmomach > me.MAXMACH ) {
           mmomach = me.MAXMACH;
       }

       # TO DO : control TMO over 128C
       # catches the MMO with autothrottle
       setprop("/autopilot/settings/target-mach",mmomach);
       me.atactivatemode("/controls/autoflight/speed","mach-with-throttle");

       altft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
       if( speedmach > me.CRUISEMACH or altft > constantaero.MAXCRUISEFT ) {
           me.atactivatemode("/controls/autoflight/speed2","maxcruise");
       }
       else {
           me.atactivatemode("/controls/autoflight/speed2","maxclimb");
       }
   }

   if( result ) {
       me.atengage();
   }

   return result;
}

# disconnect if no voltage (cannot disable the autopilot !)
Autothrottle.voltage = func( voltage1, voltage2 ) {
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
       if( me.engines[0].getChild("throttle").getValue != 0 ) {
           for(i=0; i<=3; i=i+1) {
               me.engines[i].getChild("throttle").setValue(0);
           }
       }
   }
}

# full foward throttle
Autothrottle.full = func {
  if( me.engines[0].getChild("throttle").getValue != 1 ) {
      for(i=0; i<=3; i=i+1) {
          me.engines[i].getChild("throttle").setValue(1);
      }
   }
}

Autothrottle.goaround = func {
   count = 0;
   for( i=0; i<=3; i=i+1 ) {
        child = me.engines[i].getChild("throttle-manual");
        # may not work with Cygwin
        if( child == nil ) {
            print("cannot override control.Throttleaxis");
        }
        elsif( child.getValue() == 1.0 ) {
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
    speed2 = me.ap[0].getChild("speed2").getValue();

    if( speed2 == "maxclimb" or speed2 == "maxcruise" ) {
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
   setprop("/controls/autoflight/speed2","");
}

# disconnect speed mode
Autothrottle.atdiscspeed = func {
   setprop("/controls/autoflight/speed","");
   setprop("/autopilot/locks/speed","");
}

# disconnect autothrottle
Autothrottle.atdiscthrottle = func {
   me.atdiscspeed();
   me.atdiscspeed2();
}

# disconnect autothrottle
Autothrottle.atdiscexport = func {
   me.atdiscthrottle();

   me.channels[0].getChild("engage").setValue(constant.FALSE);
   me.channels[1].getChild("engage").setValue(constant.FALSE);

   me.atengage();
}

# activate a mode
# - property
# - value
Autothrottle.atactivatemode = func {
   property = arg[0];
   value = arg[1];

   setprop(property, value);
}

Autothrottle.is_enabled = func {
   result = me.is_engaged();

   if( result ) {
       speedmode = getprop("/controls/autoflight/speed");
       speedmode2 = getprop("/controls/autoflight/speed2");
       if( ( speedmode == nil or speedmode == "" ) and ( speedmode2 == nil or speedmode2 == "" ) ) {
           result = constant.FALSE;
       }
       else {
           result = constant.TRUE;
       }
   }

   return result;
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
       mode = getprop("/controls/autoflight/speed");
   }
   else {
      mode = "";
   }

   setprop("/autopilot/locks/speed",mode);

   me.iaslight();
}

Autothrottle.atenable = func {
   if( !me.is_engaged() ) {
        me.channels[0].getChild("engage").setValue(constant.TRUE);
   }
}

# activate autothrottle
Autothrottle.atexport = func {
   ap = props.globals.getNode("/controls").getChildren("autoflight");
   speed = me.ap[0].getChild("speed").getValue();
   speed2 = me.ap[0].getChild("speed2").getValue();
   channel1 = me.channels[0].getChild("engage").getValue();
   channel2 = me.channels[1].getChild("engage").getValue();

   # only 1 channel in max climb or max cruise mode
   if( channel1 and channel2 ) {
       if( speed2 == "maxclimb" or speed2 == "maxcruise" ) {
           me.channels[1].getChild("engage").setValue(constant.FALSE);
       }
   }

   # IAS hold is default on activation
   elsif( channel1 or channel2 ) {
       if( speed == "" and speed2 == "" ) {
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
       speed2mode = getprop("/controls/autoflight/speed2");
       if( speed2mode == "speed-acquire" ) {
           minkt = getprop("/systems/autopilot/airspeed/light-min-kt");
           maxkt = getprop("/systems/autopilot/airspeed/light-max-kt");
           speedkt = me.slave[me.asi].getChild("indicated-speed-kt").getValue();

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

# autothrottle
Autothrottle.atspeedexport = func {
   speed2mode = getprop("/controls/autoflight/speed2");
   if( speed2mode != "speed-acquire" ) {
       setprop("/controls/autoflight/speed2","speed-acquire");
       speedkt = getprop("/controls/autoflight/speed-select");
       setprop("/autopilot/settings/target-speed-kt",speedkt);
       me.atactivatemode("/controls/autoflight/speed","speed-with-throttle");
   }
   else{
       me.atdiscthrottle();
   }

   me.atengage();

   me.speedacquire();
}

# toggle autothrottle (ctrl-S)
Autothrottle.attogglespeedexport = func {
   speedmode = getprop("/autopilot/locks/speed");

   # disable speed hold, if any
   if( speedmode == "speed-with-throttle" ) {
       me.atdiscexport();
   }
   else {
       me.atenable();
       me.atspeedexport();
   }
}

# hold mach
Autothrottle.holdmach = func {
   speedmach = me.slave[me.mach].getChild("indicated-mach").getValue();
   setprop("/autopilot/settings/target-mach",speedmach);
}

# mach hold
Autothrottle.atmachexport = func {
   speedmode = getprop("/controls/autoflight/speed");
   if( speedmode != "mach-with-throttle" ) {
       me.holdmach();
       me.atactivatemode("/controls/autoflight/speed","mach-with-throttle");
       me.atdiscspeed2();
   }
   else{
       me.atdiscthrottle();
   }

   me.atengage();
}

# hold speed
Autothrottle.holdspeed = func {
   speedkt = me.slave[me.asi].getChild("indicated-speed-kt").getValue();
   setprop("/autopilot/settings/target-speed-kt",speedkt);
}

# speed hold
Autothrottle.atspeedholdexport = func {
   speedmode = getprop("/controls/autoflight/speed");
   speed2mode = getprop("/controls/autoflight/speed2");
   if( speed2mode != "" or speedmode != "speed-with-throttle" ) {
       me.holdspeed();
       me.atactivatemode("/controls/autoflight/speed","speed-with-throttle");
       me.atdiscspeed2();
   }
   else{
       me.atdiscthrottle();
   }

   me.atengage();
}

# datum adjust of autothrottle, argument :
# - step : plus/minus 1
Autothrottle.datumatexport = func( sign ) {
   speedmode = getprop("/autopilot/locks/speed");
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
       datum = getprop("/controls/autoflight/datum/speed");
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
               targetmach = getprop("/autopilot/settings/target-mach");
               targetmach = targetmach + value;
               setprop("/autopilot/settings/target-mach",targetmach);
           }
           elsif( speedmode == "speed-with-throttle" ) {
               targetkt = getprop("/autopilot/settings/target-speed-kt");
               targetkt = targetkt + value;
               setprop("/autopilot/settings/target-speed-kt",targetkt);
           }

           setprop("/controls/autoflight/datum/speed",datum);
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

# slaves
           slave : [ nil ],
           radioaltimeter : 0
         };

   obj.init();

   return obj;
};

Gpws.init = func {
   propname = getprop("/systems/gpws/slave/radio-altimeter");
   me.slave[me.radioaltimeter] = props.globals.getNode(propname);

   # reads the user customization, JSBSim has an offset of 11 ft
   decisionft = me.slave[me.radioaltimeter].getChild("dial-decision-ft").getValue();
   decisionft = decisionft + constantaero.AGLFT;
   me.slave[me.radioaltimeter].getChild("decision-ft").setValue(decisionft);
}

Gpws.schedule = func {
    if( getprop("/systems/gpws/serviceable") ) {
        if( !getprop("/systems/gpws/decision-height") ) {
            decisionft = me.slave[me.radioaltimeter].getChild("decision-ft").getValue();
            aglft = me.slave[me.radioaltimeter].getChild("indicated-altitude-ft").getValue();

            # reset the DH light
            if( aglft > decisionft ) {
                setprop("/systems/gpws/decision-height",constant.TRUE);
            }
        }
    }
}
