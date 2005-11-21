# Like the real Concorde : see http://www.concordesst.com.

# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by sched are called from cron


# current nasal version doesn't accept :
# - more than multiplication on 1 line.
# - variable with hyphen or underscore.
# - boolean (can only test IF TRUE); replaced by strings.
# - object oriented classes.


# ==========================
# AUTOPILOT AND AUTOTHROTTLE 
# ==========================

AUTOPILOTSEC = 3.0;
AUTOPILOTSONIC = 1.0;

# watchdog
autopilotschedule = func {
   # more sensitive at supersonic speed
   lock = getprop("/autopilot/locks/heading");
   if( lock == "dg-heading-hold" ) {
       sonicmagneticheading();
   }
   elsif( lock == "true-heading-hold" ) {
       sonictrueheading();
   }

   lock2 = getprop("/autopilot/locks/altitude");
   if( lock2 == "vertical-speed-hold" ) {
       sonicverticalspeed();
   }

   # disconnect autopilot if no voltage (TO DO by FG)
   autopilotvoltage();

   # waypoint transition
   mode = getprop("/autopilot/locks/horizontal");
   if( mode == "ins" ) {
       waypointroll(lock);
   }

   # VOR transition
   elsif( mode == "vor" ) {
       vorroll(lock);
   }
}

# disconnect if no voltage (cannot disable the autopilot !)
autopilotvoltage = func {
   voltage1 = getprop("/systems/electrical/outputs/autopilot1");
   voltage2 = getprop("/systems/electrical/outputs/autopilot2");

   if( voltage1 == 0.0 or voltage2 == 0.0 ) {
       # not yet in hand of copilot
       if( !getprop("/autopilot/internal/state/virtual-autopilot") ) {
           apchannels = props.globals.getNode("/autopilot/locks/channel").getChildren("ap");
           atchannels = props.globals.getNode("/autopilot/locks/channel").getChildren("at");

           # disconnect autopilot 1
           if( voltage1 == 0.0 ) {
               channel = apchannels[0].getChild("on").getValue();
               if( channel == "on" ) {
                   apchannels[0].getChild("on").setValue("");
                   channel = apchannels[1].getChild("on").getValue();
                   if( channel != "on" ) {
                       apdiscexport();
                   }
               }

               # disconnect autothrottle 1
               channel = atchannels[0].getChild("on").getValue();
               if( channel == "on" ) {
                   atchannels[0].getChild("on").setValue("");
                   channel = atchannels[1].getChild("on").getValue();
                   if( channel != "on" ) {
                       atdiscthrottleexport();
                   }
               }
           }

           # disconnect autopilot 2
           if( voltage2 == 0.0 ) {
               channel = apchannels[1].getChild("on").getValue();
               if( channel == "on" ) {
                   apchannels[1].getChild("on").setValue("");
                   channel = apchannels[0].getChild("on").getValue();
                   if( channel != "on" ) {
                       apdiscexport();
                   }
               }

               # disconnect autothrottle 2
               channel = atchannels[1].getChild("on").getValue();
               if( channel == "on" ) {
                   atchannels[1].getChild("on").setValue("");
                   channel = atchannels[0].getChild("on").getValue();
                   if( channel != "on" ) {
                       atdiscthrottleexport();
                   }
               }
           }
       }
   }

   # only if no voltage
   clearcopilot( voltage1, voltage2 );
}

# for 4 engines flame out
virtualcopilot = func {
   if( getprop("/autopilot/internal/state/virtual-copilot") ) {
       # clear autopilot
       if( !getprop("/autopilot/internal/state/virtual-autopilot") ) {
           apdiscexport();
           atdiscthrottleexport();
           setprop("/autopilot/internal/state/virtual-autopilot",1.0);
       }

       # hold current heading and speed
       horizontalmode = getprop("/autopilot/locks/horizontal");
       if( horizontalmode != "magnetic" ) {
           apheadingholdexport();
       }

       altitudemode = getprop("/autopilot/locks/altitude");
       altitudeft = getprop("/position/altitude-ft");
       if( altitudeft > 25000.0 and altitudemode != "mach-with-pitch" ) {
           apmachpitchexport();
       }
       elsif( altitudeft <= 25000.0 and altitudemode != "speed-with-pitch" ) {
           apspeedpitchexport();
       }
   }
}

# disable virtual copilot
clearcopilot = func( voltage1, voltage2 ) {
   if( getprop("/autopilot/internal/state/virtual-copilot") ) {
       # returns to real mode, once voltages are normal
       if( voltage1 != 0.0 and voltage2 != 0.0 ) {
           setprop("/autopilot/internal/state/virtual-autopilot",0.0);
           setprop("/autopilot/internal/state/virtual-copilot",0.0);
       }

       # disconnect button pressed
       else {
           virtualcopilot();
       }
   }
}

# virtual copilot
apcopilotexport = func {
   if( !getprop("/autopilot/internal/state/virtual-copilot") ) {
       setprop("/autopilot/internal/state/virtual-autopilot",0.0);
       setprop("/autopilot/internal/state/virtual-copilot",1.0);

       virtualcopilot();
   }

   # keep the buttons pressed by the copilot
   else {
       clearcopilot( 1.0, 1.0 );
   }
}

# avoid strong roll near a waypoint
# - heading hold
waypointroll = func {
    lock = arg[0];

    waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
    distance = waypoints[0].getChild("dist").getValue();
    # next waypoint
    if( distance != nil ) {
        speednmps =  getprop("/velocities/airspeed-kt") / 3600;
        # 3 NM at 450 kt 
        rangenm = speednmps * 24.0;
        # restores after waypoint pop
        if( lock == "dg-heading-hold" ) {
            wpt = waypoints[0].getChild("id").getValue();
            lastwpt = getprop("/autopilot/internal/state/waypoint");
            if( wpt != lastwpt ) {
                modetrueheading();
            }
        }
        # avoids strong roll
        elsif( distance < rangenm ) {
            rolldeg =  getprop("/orientation/roll-deg");
            # 2 time steps
            stepnm = speednmps * AUTOPILOTSEC;
            stepnm = stepnm * 2.0;
            if( distance < stepnm or rolldeg < -2.0 or rolldeg > 2.0 ) {
                # switches to heading hold
                if( lock == "true-heading-hold" ) {
                    magneticheading();
                    modemagneticheading();
                    wpt = waypoints[0].getChild("id").getValue();
                    setprop("/autopilot/internal/state/waypoint",wpt);
                }
            }
        }
    }
}

# avoid strong roll near a VOR
# - heading hold
vorroll = func {
    lock = arg[0];

    if( getprop("/instrumentation/dme[0]/in-range") ) {
        speednmps =  getprop("/velocities/airspeed-kt") / 3600;
        # 3 NM at 250 kt 
        rangenm = speednmps * 43.0;
        # restores after waypoint pop
        if( getprop("/instrumentation/dme[0]/indicated-distance-nm") > rangenm ) {
            # restores after VOR
            if( lock == "dg-heading-hold" ) {
                apdischeadingsonic();
                setprop("/autopilot/locks/heading","nav1-hold");
            }
        }
        # avoids strong roll
        else {
            # switches to heading hold
             if( lock == "nav1-hold" ) {
                magneticheading();
                modemagneticheading();
            }
        }
    }
}

# autopilot initialization
initautopilot = func {
   apdiscexport();
   atdiscthrottleexport();
}


# ===============
# AUTOPILOT MODES
# ===============

# check compatibility
# - autothrottle channel 1
# - autothrottle channel 2
apdiscincompatible = func {
    atchannel1 = arg[0];
    atchannel2 = arg[1];

    # disable one of the channels
    channels = props.globals.getNode("/autopilot/locks/channel").getChildren("ap");
    channel1 = channels[0].getChild("on").getValue();
    channel2 = channels[1].getChild("on").getValue();

    if( channel1 == "on" and channel2 == "on" ) {
        if( atchannel1 == "on" and atchannel2 == "" ) {
            channels[1].getChild("on").setValue("");

            state = "1";
        }
        elsif( atchannel1 == "" and atchannel2 == "on" ) {
            channels[0].getChild("on").setValue("");

            state = "2";
        }

        setprop("/autopilot/internal/state/ap",state);
    }
}

# disconnect autopilot
apdiscexport = func {
   apdischeadingexport();
   apdiscverticalexport();
   apdischorizontalexport();
   apdiscaltitudeexport();
   apdiscaltitude2export();
}

# disconnect all channels
apdiscchannel = func {
   ap = props.globals.getNode("/autopilot").getChildren("locks");
   altitude = ap[0].getChild("altitude").getValue();
   altitude2 = ap[0].getChild("altitude2").getValue();
   heading = ap[0].getChild("heading").getValue();
   vertical = ap[0].getChild("vertical").getValue();
   horizontal = ap[0].getChild("horizontal").getValue();
   channels = props.globals.getNode("/autopilot/locks/channel").getChildren("ap");
   channel1 = channels[0].getChild("on").getValue();
   channel2 = channels[1].getChild("on").getValue();

   if( altitude == "" and altitude2 == "" and heading == "" and vertical == "" and horizontal == "" ) {
       channels[0].getChild("on").setValue("");
       channels[1].getChild("on").setValue("");

       setprop("/autopilot/internal/state/ap","");
   }
}

# activate a mode, and engage a channel
# - property
# - value
apactivatemode = func {
   property = arg[0];
   value = arg[1];

   setprop(property, value);

   # one SUPPOSES that activation of an autopilot mode engages 1 channel
   channels = props.globals.getNode("/autopilot/locks/channel").getChildren("ap");
   channel1 = channels[0].getChild("on").getValue();
   channel2 = channels[1].getChild("on").getValue();

   # engage channel 1 by default
   if( channel1 != "on" and channel2 != "on" ) {
       channels[0].getChild("on").setValue("on");

       setprop("/autopilot/internal/state/ap","1");
   }

   # remove 2nd channel of autoland after a goaround
   elsif( channel1 == "on" and channel2 == "on" ) {
       ap = props.globals.getNode("/autopilot").getChildren("locks");
       vertical = ap[0].getChild("vertical").getValue();

       if( vertical != "autoland" and vertical != "autoland-armed" ) {
           channel2 = "";

           channels[1].getChild("on").setValue("");

           setprop("/autopilot/internal/state/ap","1");
       }
   }

   atdiscincompatible( channel1, channel2 );
}

# activate autopilot
apexport = func {
   ap = props.globals.getNode("/autopilot").getChildren("locks");
   altitude = ap[0].getChild("altitude").getValue();
   altitude2 = ap[0].getChild("altitude2").getValue();
   heading = ap[0].getChild("heading").getValue();
   vertical = ap[0].getChild("vertical").getValue();
   horizontal = ap[0].getChild("horizontal").getValue();
   channels = props.globals.getNode("/autopilot/locks/channel").getChildren("ap");
   channel1 = channels[0].getChild("on").getValue();
   channel2 = channels[1].getChild("on").getValue();
   state = getprop("/autopilot/internal/state/ap");

   # detects initial activation
   activation = "no";
   if( channel1 == "on" and channel2 == "on" ) {

       # 2 channels only in land mode
       if( vertical == "autoland" or vertical == "autoland-armed" ) {
           state = "1+2";
       }

       # swap the channel (?)
       else {
           if( state == "1" ) {
               channels[0].getChild("on").setValue("");
               state = "2";
           }
           else {
               channels[1].getChild("on").setValue("");
               state = "1";
           }
       }
   }
   elsif ( channel1 == "on" or channel2 == "on" ) {
       if( state != "1+2" ) {
           activation = "yes";
       }
       if( channel1 == "on" ) {
           state = "1";
       }
       else {
           state = "2";
       }
   }
   else {
       state = "";
   }

   # pitch hold and heading hold is default on activation
   if( channel1 == "on" or channel2 == "on" ) {
       if( altitude == "" and altitude2 == "" and heading == "" and vertical == "" and horizontal == "" ) {
           if( activation == "yes" ) {
               appitchexport();
               apheadingholdexport();
           }
       }

       # disconnect autothrottle, if not compatible
       atdiscincompatible( channel1, channel2 );
   }

   # disconnect if no channel
   else {
       apdiscexport();
   }

   setprop("/autopilot/internal/state/ap",state);
}

# datum adjust of autopilot, arguments
# - step plus/minus 1 (fast) or 0.1 (slow)
datumapexport = func {
   sign=arg[0];

   altitudemode = getprop("/autopilot/locks/altitude");

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
   datum = getprop("/autopilot/datum/altitude");
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
           setprop("/autopilot/settings/target-pitch-deg",targetdeg);
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

       setprop("/autopilot/datum/altitude",datum);
   }
}

# ---------------
# FLIGHT DIRECTOR
# ---------------

# activate autopilot
fdexport = func {
   fds = props.globals.getNode("/instrumentation/flight-director").getChildren("fd");
   fd1 = fds[0].getChild("on").getValue();
   fd2 = fds[1].getChild("on").getValue();
   state =  getprop("/instrumentation/flight-director/state");
 
   # detects initial activation
   activation = "no";
   if( fd1 == "on" and fd2 == "on" ) {
       state = "1+2";
   }
   elsif ( fd1 == "on" or fd2 == "on" ) {
       if( state != "1+2" ) {
           activation = "yes";
       }
       if( fd1 == "on" ) {
           state = "1";
       }
       else {
           state = "2";
       }
   }
   else {
       state = "";
   }

   if( fd1 != "" or fd2 != "" ) {
       ap = props.globals.getNode("/autopilot").getChildren("locks");
       altitude = ap[0].getChild("altitude").getValue();
       altitude2 = ap[0].getChild("altitude2").getValue();
       heading = ap[0].getChild("heading").getValue();
       vertical = ap[0].getChild("vertical").getValue();
       horizontal = ap[0].getChild("horizontal").getValue();

       # pitch hold is default on activation
       if( ( altitude == "" or altitude == nil ) and ( altitude2 == "" or altitude2 == nil ) and
           ( heading == "" or heading == nil ) and ( vertical == "" or vertical == nil ) and
           ( horizontal == "" or horizontal == nil ) ) {
           if( activation == "yes" ) {
               appitchexport();
           }
       }
   }

   setprop("/instrumentation/flight-director/state",state);
}

# -------------
# VERTICAL MODE
# -------------

# disconnect vertical mode
apdiscverticalexport = func {
   setprop("/autopilot/locks/vertical","");

   apdiscchannel();
}

# disconnect altitude 2 mode
apdiscaltitude2export = func {
   setprop("/autopilot/locks/altitude2","");

   apdiscchannel();
}

# go around mode
goaround = func {
   verticalmode = getprop("/autopilot/locks/vertical");
   # 2 throttles full foward during an autoland or glide slope
   if( getprop("/autopilot/locks/altitude") == "gs1-hold" or verticalmode == "autoland" ) {
       engine = props.globals.getNode("/controls/engines").getChildren("engine");
       count = 0;
       for(i=0; i<=3; i=i+1) {
           if( engine[i].getChild("throttle").getValue() == 1 ) {
               count = count + 1;
           }
       }
       if( count >= 2 ) {
           # pitch at 15 deg and hold the wing level, until the next command of crew
           setprop("/autopilot/settings/target-pitch-deg",15);
           setprop("/autopilot/locks/altitude","pitch-hold");
           setprop("/autopilot/locks/heading","wing-leveler");
           # disable other vertical modes
           apdiscaltitude2export();
           # crew control
           atdiscspeedexport();
           # light on
           apactivatemode("/autopilot/locks/vertical","goaround");
       }
   }
   # light off
   if( verticalmode == "goaround" ) {
       if( getprop("/autopilot/settings/target-pitch-deg") != 15 or
           getprop("/autopilot/locks/altitude") != "pitch-hold" or
           getprop("/autopilot/locks/heading") != "wing-leveler" ) {
           apdiscverticalexport();
       }
   }
}

# adjust target speed with wind
# - target speed (kt)
targetwind = func {
   # VREF 152-162 kt
   tankskg = getprop("/instrumentation/fuel/total-kg");
   if( tankskg > 19000 )
   {
       targetkt = 162;
   }
   else
   {
       targetkt = 152 + 10 * ( 19000 - tankskg ) / 19000;
   }

   # wind increases lift
   windkt = getprop("/environment/wind-speed-kt");
   if( windkt > 0 ) {
       winddeg = getprop("/environment/wind-from-heading-deg");
       vordeg = getprop("/instrumentation/nav/radials/target-radial-deg");
       offsetdeg = vordeg - winddeg;
       # north crossing
       if( offsetdeg > 180 ) {
           offsetdeg = offsetdeg - 360;
       }
       elsif( offsetdeg < -180 ) {
              offsetdeg = offsetdeg + 360;
       }
       # add head wind component;
       # except tail wind (too much glide)
       if( offsetdeg > -90 and offsetdeg < 90 ) {
           offsetrad = offsetdeg * DEGTORAD;
           offsetkt = windkt * math.cos( offsetrad );
           targetkt = targetkt + offsetkt;
       }
   }
   # avoid infinite gliding (too much ground effect ?)
   setprop("/autopilot/settings/target-speed-kt",targetkt);
}

# autoland mode
# (tested at 245000 lb)
autolandcron = func {
   verticalmode2 = "";      
   verticalmode = getprop("/autopilot/locks/vertical") ;
   if( verticalmode == "autoland" or verticalmode == "autoland-armed" ) {
       verticalmode2 = "goaround-armed";
       aglft = getprop("/position/altitude-agl-ft") ;
       # armed
       if( verticalmode == "autoland-armed" ) {
           if( aglft <= 1500 ) {
               verticalmode = "autoland";
               setprop("/autopilot/locks/vertical",verticalmode);
           }
           else {
               rates = 1.0;
           }
       }
       # engaged
       if( verticalmode == "autoland" ) {
           # touch down
           # JBSim indicates :
           # - 11 ft AGL on ground (Z height of center of gravity minus Z height of main landing gear)
           # - 13 ft when main wing gear touches the ground
           if( aglft < 14 ) {
               # gently reduce pitch
               if( getprop("/orientation/pitch-deg") > 1.0 ) {
                   rates = 0.2;
                   # 1 deg / s
                   pitchdeg = getprop("/autopilot/settings/target-pitch-deg");
                   pitchdeg = pitchdeg - 0.2;
                   setprop("/autopilot/settings/target-pitch-deg",pitchdeg);
                   apdiscaltitudeexport();
                   setprop("/autopilot/locks/altitude","pitch-hold");
                   apdiscaltitude2export();
               }
               # safe on ground
               else {
                   rates = 1.0;
                   # disable autopilot
                   apdiscaltitudeexport();
                   apdischeadingexport();
                   apdischorizontalexport();
  		   apdiscverticalexport();
                   verticalmode2 = "";
                   # reset trims
                   setprop("/controls/flight/elevator-trim",0.0);
                   setprop("/controls/flight/rudder-trim",0.0);
                   setprop("/controls/flight/aileron-trim",0.0);
               }
               # engine idles
               engine = props.globals.getNode("/controls/engines").getChildren("engine");
               if( engine[0].getChild("throttle").getValue != 0 ) {
                   for(i=0; i<size(engine); i=i+1) {
                       engine[i].getChild("throttle").setValue(0);
                   }
               }
           }
           # triggers below 1500 ft
           elsif( aglft > 1500 ) {
               rates = 1.0;
               verticalmode = "autoland-armed";
               setprop("/autopilot/locks/vertical",verticalmode);
           }
           else {
               # landing pitch
               if( aglft < 175 ) {
                   rates = 0.1;
                   apdiscaltitudeexport();
                   setprop("/autopilot/settings/target-pitch-deg",10);
                   setprop("/autopilot/locks/altitude","pitch-hold");
                   setprop("/autopilot/settings/vertical-speed-fpm",-750);
                   setprop("/autopilot/locks/altitude2","vertical-speed-with-throttle");
                   atdiscspeedexport();
               }
               # glide slope
               else {
                   atclearspeed2();
                   rates = 0.1;
                   apdiscaltitudeexport();
                   setprop("/autopilot/locks/altitude","gs1-hold");
                   # near VREF (no wind)
                   targetwind();
                   # pilot must activate autothrottle (IAS hold)
               }
               setprop("/autopilot/locks/heading","nav1-hold");
               apdischorizontalexport();
           }
       }
   }
   else {
       rates = 1.0;
       if( getprop("/autopilot/locks/altitude") == "gs1-hold" ) {
           verticalmode2 = "goaround-armed";      
       }
   }

   # 0.1 s improves the catch of throttle maximum, when autoland
   setprop("/autopilot/locks/vertical2",verticalmode2);
   goaround();

   # re-schedule the next call
   if( verticalmode2 == "goaround-armed" or getprop("/autopilot/locks/vertical") == "goaround" ) {
      settimer(autolandcron, rates);
   }

   apdiscchannel();
   atdiscchannel();
}

# autopilot autoland
aplandexport = func {
   verticalmode = getprop("/autopilot/locks/vertical");
   if( verticalmode != "autoland" and verticalmode != "autoland-armed" ) {
       apactivatemode("/autopilot/locks/vertical","autoland-armed");
       if( getprop("/autopilot/locks/vertical2") != "goaround-armed" ) {
           autolandcron();
       }
   }
   else {
       apdiscverticalexport();
   }
}

# autopilot turbulence mode
apturbulenceexport = func {
   verticalmode = getprop("/autopilot/locks/vertical");
   if( verticalmode != "turbulence" ) {
       apactivatemode("/autopilot/locks/vertical","turbulence");
       pitchdeg = getprop("/orientation/pitch-deg");
       setprop("/autopilot/settings/target-pitch-deg",pitchdeg);
       setprop("/autopilot/locks/altitude","pitch-hold");
       headingdeg = getprop("/orientation/heading-deg");
       setprop("/autopilot/settings/true-heading-deg",headingdeg);
       modetrueheading();
       apdischorizontalexport();
   }
   else {
       apdiscverticalexport();
       apdiscaltitudeexport();
       apdischeadingexport(); 
   }
}

# -------------
# ALTITUDE MODE
# -------------

# disconnect autopilot altitude
apdiscaltitudeexport = func {
   setprop("/autopilot/locks/altitude","");
   setprop("/autopilot/locks/sonic/altitude","");

   apdiscchannel();
}

# altitude button lights, when the dialed altitude is reached.
# altimeter light, when the dialed altitude is reached.
altitudelightcron = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode == "altitude-hold" ) {
       altft = getprop("/autopilot/settings/target-altitude-ft");
       # altimeter light within 1200 ft
       minft = altft - 1200;
       setprop("/instrumentation/altimeter/target-min-ft",minft);
       maxft = altft + 1200;
       setprop("/instrumentation/altimeter/target-max-ft",maxft);
       # no altimeter light within 50 ft
       minft = altft - 50;
       setprop("/instrumentation/altimeter/light-min-ft",minft);
       maxft = altft + 50;
       setprop("/instrumentation/altimeter/light-max-ft",maxft);

       # re-schedule the next call
       settimer(altitudelightcron, 15.0);
   }
}

# autopilot altitude hold
apaltitudeexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "altitude-hold" ) {
       apdiscaltitudeexport();
       apactivatemode("/autopilot/locks/altitude","altitude-hold");
       apdiscverticalexport();
       altitudelightcron();
   }
   else {
       apdiscaltitudeexport();
   }
}

# autopilot altitude hold
apaltitudeholdexport = func {
   altitudeft = getprop("/position/altitude-ft");
   setprop("/autopilot/settings/target-altitude-ft",altitudeft);
   apdiscaltitudeexport();
   apaltitudeexport();
}

# autopilot glide slope
apglideexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "gs1-hold" ) {
       apactivatemode("/autopilot/locks/altitude","gs1-hold");
       setprop("/autopilot/locks/heading","nav1-hold");
       setprop("/autopilot/locks/altitude2","glide-slope");
       apdischorizontalexport();
       if( getprop("/autopilot/locks/vertical2") != "goaround-armed" ) {
           autolandcron();
       }
   }
   else {
       apdiscaltitudeexport();
       apdiscaltitude2export();
       modevorloc();
   }
}

# autopilot pitch hold
appitchexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "pitch-hold" ) {
       pitchdeg = getprop("/orientation/pitch-deg");
       setprop("/autopilot/settings/target-pitch-deg",pitchdeg);
       apactivatemode("/autopilot/locks/altitude","pitch-hold");
       apdiscverticalexport();
   }
   else {
       apdiscaltitudeexport();
   }
}

# sonic vertical speed
sonicverticalspeed = func {
   speedmach = getprop("/velocities/mach");
   if( speedmach <= AUTOPILOTSONIC ) {
       mode = "vertical-speed-hold-sub";
   }
   else {
       mode = "vertical-speed-hold-super";
   }
   setprop("/autopilot/locks/sonic/altitude",mode);
}

# autopilot vertical speed hold
apverticalexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "vertical-speed-hold" ) {
       speedfps = getprop("/instrumentation/inst-vertical-speed-indicator/indicated-speed-fps");
       speedfpm = speedfps * 60;
       setprop("/autopilot/settings/vertical-speed-fpm",speedfpm);
       apactivatemode("/autopilot/locks/altitude","vertical-speed-hold");
       sonicverticalspeed();
       apdiscverticalexport();
   }
   else {
       apdiscaltitudeexport();
   }
}

# speed with pitch
apspeedpitchexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");

   # only if no autothrottle
   if( altitudemode != "speed-with-pitch" ) {
       speedmode = getprop("/autopilot/locks/speed");
       speedmode2 = getprop("/autopilot/locks/speed2");
       if( ( speedmode == nil or speedmode == "" ) and ( speedmode2 == nil or speedmode2 == "" ) ) {
           speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
           setprop("/autopilot/settings/target-speed-kt",speedkt);
           apactivatemode("/autopilot/locks/altitude","speed-with-pitch");
           apdiscverticalexport();
       }

       # default to pitch hold if autothrottle
       else {
           appitchexport();
       }
   }
   else {
       apdiscaltitudeexport();
   }
}

# mach with pitch
apmachpitchexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");

   # only if no autothrottle
   if( altitudemode != "mach-with-pitch" ) {
       speedmode = getprop("/autopilot/locks/speed");
       speedmode2 = getprop("/autopilot/locks/speed2");
       if( ( speedmode == nil or speedmode == "" ) and ( speedmode2 == nil or speedmode2 == "" ) ) {
           speedmach = getprop("/velocities/mach");
           setprop("/autopilot/settings/target-mach",speedmach);
           apactivatemode("/autopilot/locks/altitude","mach-with-pitch");
           apdiscverticalexport();
       }

       # default to pitch hold if autothrottle
       else {
           appitchexport();
       }
   }

   else {
       apdiscaltitudeexport();
   }
}

# ---------------
# HORIZONTAL MODE
# ---------------

# disconnect horizontal mode
apdischorizontalexport = func {
   setprop("/autopilot/locks/horizontal","");

   apdiscchannel();
}

# ins light
inslightschedule = func {
   insmode = "false";
   # new waypoint
   if( getprop("/autopilot/locks/horizontal") != "ins" ) {
       if( getprop("/autopilot/locks/heading") == "true-heading-hold" ) {
           waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
           distance = waypoints[0].getChild("dist").getValue();
           if( distance != nil and distance != 0.0 ) {
               insmode = "true";
               apactivatemode("/autopilot/locks/horizontal","ins");
           }
       }
   }
   # no more waypoint
   else {
       waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
       if( waypoints[0].getChild("dist").getValue() == 0.0 ) {
           apdischorizontalexport();
       }
       else {
           insmode = "true";
       }
   }

   # ground speed from waypoint
   if( insmode == "true" )
   {
       waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
       distnm = waypoints[0].getChild("dist").getValue();
       timesec = getprop("/sim/time/elapsed-sec");
       # no waypoint
       if( distnm == nil or distnm == 0.0 ) {
           groundkt = 9999;
      }
       else {
           lastdistnm = getprop("/instrumentation/ins/last-wp-nm");
           lasttimesec = getprop("/instrumentation/ins/last-time-s");
           if( lastdistnm != nil and lasttimesec != nil ) {
               deltanm = lastdistnm - distnm;
               deltafeet = deltanm * NMTOFEET;
               deltasec = timesec - lasttimesec;
               groundfps = deltafeet / deltasec;
               groundkt = groundfps * FPSTOKT;
               # speed up
               speedup = getprop("/sim/speed-up");
               groundkt = groundkt / speedup;
               if( groundkt < 0 ) {
                   groundkt = - groundkt;
               }
           }
           else {
               groundkt = 9999;
           }
       }
       setprop("/instrumentation/ins/last-wp-nm",distnm);
       setprop("/instrumentation/ins/last-time-s",timesec);
       setprop("/instrumentation/ins/ground-speed-kt",groundkt);
   }
}

# ins mode
apinsexport = func {
   horizontalmode = getprop("/autopilot/locks/horizontal");

   if( horizontalmode != "ins" ) {
       waypoint = getprop("/autopilot/route-manager/wp[0]/id");
       if( waypoint != "" ) {
           activatetrueheading();
           setprop("/autopilot/locks/horizontal","ins");
       }
   }
   else {
       apdischeadingexport(); 
       apdischorizontalexport();
   }
}

# ------------
# HEADING MODE
# ------------

# disconnect heading sonic
apdischeadingsonic = func {
   setprop("/autopilot/locks/sonic/heading","");
}

# disconnect heading mode
apdischeadingexport = func {
   setprop("/autopilot/locks/heading","");

   apdischeadingsonic();
   apdiscchannel();
}

# activate true heading hold
activatetrueheading = func {
    apactivatemode("/autopilot/locks/heading","true-heading-hold");
    sonictrueheading();
}

# autopilot magnetic heading
apmagheadingexport = func {
   headingmode = getprop("/autopilot/locks/heading");
   horizontalmode = getprop("/autopilot/locks/horizontal");
   if( headingmode != "dg-heading-hold" or horizontalmode == "magnetic" ) {
       apactivatemode("/autopilot/locks/heading","dg-heading-hold");
       sonicmagneticheading();
       apdischorizontalexport();
   }
   else {
       apdischeadingexport(); 
   }
}

# sonic true mode
sonictrueheading = func {
   speedmach = getprop("/velocities/mach");
   if( speedmach <= AUTOPILOTSONIC ) {
       mode = "true-heading-hold-sub";
   }
   else {
       mode = "true-heading-hold-super";
   }
   setprop("/autopilot/locks/sonic/heading",mode);
}

# true heading mode
modetrueheading = func {
    setprop("/autopilot/locks/heading","true-heading-hold");
    sonictrueheading();
}

# sonic magnetic mode
sonicmagneticheading = func {
   speedmach = getprop("/velocities/mach");
   if( speedmach <= AUTOPILOTSONIC ) {
       mode = "dg-heading-hold-sub";
   }
   else {
       mode = "dg-heading-hold-super";
   }
   setprop("/autopilot/locks/sonic/heading",mode);
}

# magnetic heading mode
modemagneticheading = func {
   setprop("/autopilot/locks/heading","dg-heading-hold");
   sonicmagneticheading();
}

# magnetic heading
magneticheading = func {
   headingdeg = getprop("/orientation/heading-magnetic-deg");
   setprop("/autopilot/settings/heading-bug-deg",headingdeg);
}

# heading hold
apheadingholdexport = func {
   magneticheading();

   mode = getprop("/autopilot/locks/horizontal");
   if( mode != "magnetic" ) {
       apactivatemode("/autopilot/locks/horizontal","magnetic");
       setprop("/autopilot/locks/heading","dg-heading-hold");
       sonicmagneticheading();
   }
   else {
       apdischeadingexport(); 
       apdischorizontalexport();
   }
}

# autopilot heading
apheadingexport = func {
   headingmode = getprop("/autopilot/locks/heading");
   horizontalmode = getprop("/autopilot/locks/horizontal");
   if( ( headingmode != "dg-heading-hold" and headingmode != "true-heading-hold" ) or
       horizontalmode == "ins" or horizontalmode == "vor" ) {
       trackpush = getprop("/autopilot/settings/track-push");
       if( trackpush == nil or !trackpush ) {
           apmagheadingexport();
       }
       else {
           activatetrueheading();
           apdischorizontalexport();
       }
   }
   elsif( headingmode == "dg-heading-hold" ) {
       apmagheadingexport();
   }
   else {
       apdischeadingexport(); 
       apdischorizontalexport();
   }
}

# VOR loc
modevorloc = func {
   headingmode = getprop("/autopilot/locks/heading");
   altitudemode = getprop("/autopilot/locks/altitude");
   if( headingmode == "nav1-hold" and altitudemode != "gs1-hold" ) {
       setprop("/autopilot/locks/horizontal","vor");
   }
}

# autopilot vor localizer
apvorlocexport = func {
   headingmode = getprop("/autopilot/locks/heading");
   if( headingmode != "nav1-hold" ) {
       apdischeadingsonic();
       apactivatemode("/autopilot/locks/heading","nav1-hold");
       modevorloc();
   }
   else {
       apdischeadingexport(); 
       apdischorizontalexport();
   }
}

# ----------
# SPEED MODE
# ----------

# clear speed 2 mode
atclearspeed2 = func {
   setprop("/autopilot/locks/speed2","");
}

# disconnect speed 2 mode
atdiscspeed2export = func {
   atclearspeed2();
   atdiscchannel();
}

# max climb mode (includes max cruise mode)
maxclimbcron = func {
   speedmode = getprop("/autopilot/locks/speed2");
   if( speedmode == "maxclimb" or speedmode == "maxcruise" ) {          
       speedmach = getprop("/velocities/mach");
       if( speedmach < 1.7 ) {
           vmokt = getprop("/instrumentation/airspeed-indicator/vmo-kt");
           maxkt = getprop("/instrumentation/airspeed-indicator/overspeed-kt");
           # may be out of order
           speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
           # catches the VMO with autothrottle
           if( speedkt < maxkt ) {
               setprop("/autopilot/settings/target-speed-kt",vmokt);
               atactivatemode("/autopilot/locks/speed","speed-with-throttle");
           }
           # then holds the VMO with pitch
           else {
              setprop("/autopilot/settings/target-speed-kt",vmokt);
              apactivatemode("/autopilot/locks/altitude","speed-with-pitch");
              atdiscspeedexport();
           }

           if( speedmode == "maxcruise" ) {
               atactivatemode("/autopilot/locks/speed2","maxclimb");
           }
       }
       else {
           mmomach = getprop("/instrumentation/mach-indicator/mmo-mach");
           # cruise at Mach 2.0-2.02 (reduce fuel consumption)          
           if( mmomach > 2.02 ) {
               mmomach = 2.02;
           }
           # TO DO : control TMO over 128C
           # catches the MMO with autothrottle
           setprop("/autopilot/settings/target-mach",mmomach);
           atactivatemode("/autopilot/locks/speed","mach-with-throttle");

           altft = getprop("/instrumentation/altimeter/indicated-altitude-ft");
           if( speedmach > 2 or altft > 50190 ) {
               atactivatemode("/autopilot/locks/speed2","maxcruise");
           }
           else {
               atactivatemode("/autopilot/locks/speed2","maxclimb");
           }
       }

       # re-schedule the next call (1st is CL)
       settimer(maxclimbcron, 1.0);
   }

   atdiscchannel();
}

# max climb mode
apmaxclimbexport = func {
   speedmode = getprop("/autopilot/locks/speed2");
   if( speedmode == "maxclimb" or speedmode == "maxcruise" ) {
       # switch to speed hold
       atdiscspeed2export();
       holdspeed();
   }
   else {
       atactivatemode("/autopilot/locks/speed2","maxclimb");
       maxclimbcron();
   }          
}

# =================
# AUTOTHROTTLE MODE
# =================

# check compatibility
# - autopilot channel 1
# - autopilot channel 2
atdiscincompatible = func {
    apchannel1 = arg[0];
    apchannel2 = arg[1];

    # disconnect autothrottle, if not compatible
    ap = props.globals.getNode("/autopilot").getChildren("locks");
    speed2 = ap[0].getChild("speed2").getValue();

    if( speed2 == "maxclimb" or speed2 == "maxcruise" ) {
        channels = props.globals.getNode("/autopilot/locks/channel").getChildren("at");
        channel1 = channels[0].getChild("on").getValue();
        channel2 = channels[1].getChild("on").getValue();

        # same channel if maxclimb or maxcruise mode
        if( ( apchannel1 == "on" and apchannel2 == "on" ) or
            ( apchannel1 == "on" and channel2 == "on" ) or
            ( apchannel2 == "on" and channel1 == "on" ) ) {
            atdiscthrottleexport();
        }
    }
}

# clear speed mode
atclearspeed = func {
   setprop("/autopilot/locks/speed","");
}

# disconnect speed mode
atdiscspeedexport = func {
   atclearspeed();
   atdiscchannel();
}

# disconnect autothrottle
atdiscthrottleexport = func {
   atdiscspeedexport();
   atdiscspeed2export();
}

# disconnect all channels
atdiscchannel = func {
   ap = props.globals.getNode("/autopilot").getChildren("locks");
   speed = ap[0].getChild("speed").getValue();
   speed2 = ap[0].getChild("speed2").getValue();
   channels = props.globals.getNode("/autopilot/locks/channel").getChildren("at");
   channel1 = channels[0].getChild("on").getValue();
   channel2 = channels[1].getChild("on").getValue();

   if( speed == "" and speed2 == "" ) {
       channels[0].getChild("on").setValue("");
       channels[1].getChild("on").setValue("");

       setprop("/autopilot/internal/state/at","");
   }
}

# activate a mode, and engage a channel
# - property
# - value
atactivatemode = func {
   property = arg[0];
   value = arg[1];

   setprop(property, value);

   # one SUPPOSES that activation of an autothrottle mode engages the channel
   ap = props.globals.getNode("/autopilot").getChildren("locks");
   speed2 = ap[0].getChild("speed2").getValue();
   channels = props.globals.getNode("/autopilot/locks/channel").getChildren("at");
   channel1 = channels[0].getChild("on").getValue();
   channel2 = channels[1].getChild("on").getValue();

   # only 1 channel in max climb or max cruise mode
   state = "";
   if( speed2 == "maxclimb" or speed2 == "maxcruise" ) {
       apchannels = props.globals.getNode("/autopilot/locks/channel").getChildren("ap");
       apchannel1 = apchannels[0].getChild("on").getValue();
       apchannel2 = apchannels[1].getChild("on").getValue();

       # revert autopilot, if not compatible with autothrottle
       if( apchannel1 != "on" and apchannel2 != "on" ) {
           apdiscincompatible( "on", "" );
       }

       # same channel than autopilot
       if( apchannel1 == "on" and ( channel1 != "on" or channel2 != "" ) ) {
           channels[0].getChild("on").setValue("on");
           channels[1].getChild("on").setValue("");

           state = "1";
       }
       elsif( apchannel2 == "on" and ( channel1 != "" or channel2 != "on" ) ) {
           channels[0].getChild("on").setValue("");
           channels[1].getChild("on").setValue("on");

           state = "2";
       }

       # 1 default channel
       elsif( ( channel1 != "on" and channel2 != "on" ) or
              ( channel1 == "on" and channel2 == "on" ) ) {
           channels[0].getChild("on").setValue("on");
           channels[1].getChild("on").setValue("");

           state = "1";
       }
   }

   # engage all channels by default
   elsif( channel1 != "on" and channel2 != "on" ) {
       channels[0].getChild("on").setValue("on");
       channels[1].getChild("on").setValue("on");
 
       state = "1+2";
   }

   if( state != "" ) {
       setprop("/autopilot/internal/state/at",state);
   }
}

# activate autothrottle
atexport = func {
   ap = props.globals.getNode("/autopilot").getChildren("locks");
   speed = ap[0].getChild("speed").getValue();
   speed2 = ap[0].getChild("speed2").getValue();
   channels = props.globals.getNode("/autopilot/locks/channel").getChildren("at");
   channel1 = channels[0].getChild("on").getValue();
   channel2 = channels[1].getChild("on").getValue();
   state = getprop("/autopilot/internal/state/at");

   # detects initial activation
   activation = "no";
   if( channel1 == "on" and channel2 == "on" ) {

       # only 1 channel in max climb or max cruise mode
       if( speed2 != "maxclimb" and speed2 != "maxcruise" ) {
           state = "1+2";
       }

       # swap the channel
       else {
           if( state == "1" ) {
               channels[0].getChild("on").setValue("");
               state = "2";
           }
           else {
               channels[1].getChild("on").setValue("");
               state = "1";
           }
       }
   }
   elsif ( channel1 == "on" or channel2 == "on" ) {
       if( state != "1+2" ) {
           activation = "yes";
       }
       if( channel1 == "on" ) {
           state = "1";
       }
       else {
           state = "2";
       }
   }
   else {
       state = "";
   }

   # IAS hold is default on activation
   if( channel1 == "on" or channel2 == "on" ) {
       if( speed == "" and speed2 == "" ) {
           if( activation == "yes" ) {
               speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
                setprop("/autopilot/settings/target-speed-kt",speedkt);
                ap[0].getChild("speed").setValue("speed-with-throttle");
           }
       }
   }
   else {
       atdiscthrottleexport();
   }

   setprop("/autopilot/internal/state/at",state);
}

# autothrottle
atspeedexport = func {
   speed2mode = getprop("/autopilot/locks/speed2");
   if( speed2mode != "speed-acquire" ) {
       setprop("/autopilot/locks/speed2","speed-acquire");
       speedkt = getprop("/autopilot/settings/dial-speed-kt");
       setprop("/autopilot/settings/target-speed-kt",speedkt);
       atactivatemode("/autopilot/locks/speed","speed-with-throttle");
   }
   else{
       atdiscthrottleexport();
   }
}

# mach hold
atmachexport = func {
   speedmode = getprop("/autopilot/locks/speed");
   if( speedmode != "mach-with-throttle" ) {
       speedmach = getprop("/velocities/mach");
       setprop("/autopilot/settings/target-mach",speedmach);
       atactivatemode("/autopilot/locks/speed","mach-with-throttle");
       atdiscspeed2export();
   }
   else{
       atdiscthrottleexport();
   }
}

# hold speed
holdspeed = func {
   speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
   setprop("/autopilot/settings/target-speed-kt",speedkt);
}

# speed hold
atspeedholdexport = func {
   speedmode = getprop("/autopilot/locks/speed");
   speed2mode = getprop("/autopilot/locks/speed2");
   if( speed2mode != "" or speedmode != "speed-with-throttle" ) {
       holdspeed();
       atactivatemode("/autopilot/locks/speed","speed-with-throttle");
       atdiscspeed2export();
   }
   else{
       atdiscthrottleexport();
   }
}

# datum adjust of autothrottle, argument :
# - step : plus/minus 1
datumatexport = func {
   sign=arg[0];

   speedmode = getprop("/autopilot/locks/speed");

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
   datum = getprop("/autopilot/datum/speed");
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

       setprop("/autopilot/datum/speed",datum);
   }
}
