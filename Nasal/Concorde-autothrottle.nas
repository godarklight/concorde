# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by sched are called from cron
# HUMAN : functions ending by human are called by artificial intelligence


# Like the real Concorde : see http://www.concordesst.com.



# ============
# AUTOTHROTTLE
# ============

Autothrottle = {};

Autothrottle.new = func {
   obj = { parents : [Autothrottle,System],

           airspeed : nil,
           ap : nil,
           auto : nil,
           autothrottles : nil,
           engines : nil,
           channels : nil,
           locks : nil,
           mouse : nil,
           settings : nil,

           SPEEDACQUIRESEC : 2.0,

           MAXMACH : 2.02,
           CRUISEMACH : 2.0,
           CLIMBMACH : 1.7,
           LIGHTKT : 10.0
         };

# autopilot initialization
   obj.init();

   return obj;
}

Autothrottle.init = func {
   me.airspeed = props.globals.getNode("/systems/autothrottle/airspeed");
   me.ap = props.globals.getNode("/controls/autoflight");
   me.auto = props.globals.getNode("/systems/autothrottle");
   me.autothrottles = props.globals.getNode("/autopilot/locks/autothrottle").getChildren("engine");
   me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
   me.channels = props.globals.getNode("/controls/autoflight").getChildren("autothrottle");
   me.locks = props.globals.getNode("/autopilot/locks");
   me.mouse = props.globals.getNode("/devices/status/mice/mouse").getChildren("button");
   me.settings = props.globals.getNode("/autopilot/settings");

   me.init_ancestor("/systems/autothrottle");

   me.atdiscexport();
}

Autothrottle.schedule = func {
   # disconnect autothrottle if no voltage (TO DO by FG)
   me.voltage();

   me.autothrottleswitch();
}

Autothrottle.autothrottleswitch = func {
   speedmode = me.locks.getChild("speed").getValue();

   for( i = 0; i <= 3; i = i+1 ) {
        if( me.engines[i].getChild("autothrottle").getValue() and
            !me.engines[i].getChild("throttle-off").getValue() ) {
            mode = speedmode;
        }
        else {
            mode = "";
        }
        me.autothrottles[i].setValue( mode );
   }
}

Autothrottle.slowschedule = func {
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
           me.airspeed.getChild("light-min-kt").setValue(minkt);
           maxkt = speedkt + me.LIGHTKT;
           me.airspeed.getChild("light-max-kt").setValue(maxkt);
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
   if( ( !me.slave["electric"].getChild("autopilot", 0).getValue() and
         !me.slave["electric"].getChild("autopilot", 1).getValue() ) or
       ( !me.auto.getChild("serviceable", 0).getValue() and
         !me.auto.getChild("serviceable", 1).getValue() ) ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# disconnect if no voltage (cannot disable the autopilot !)
Autothrottle.voltage = func() {
   voltage1 = me.slave["electric"].getChild("autopilot", 0).getValue();
   voltage2 = me.slave["electric"].getChild("autopilot", 1).getValue();

   if( voltage1 ) {
       voltage1 = me.auto.getChild("serviceable", 0).getValue();
   }
   if( voltage2 ) {
       voltage2 = me.auto.getChild("serviceable", 1).getValue();
   }

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

Autothrottle.speedacquire = func {
   if( me.is_engaged() ) {
       if( me.is_speed_acquire() ) {
           minkt = me.airspeed.getChild("light-min-kt").getValue();
           maxkt = me.airspeed.getChild("light-max-kt").getValue();
           speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();

           # swaps to speed hold
           if( speedkt > minkt and speedkt < maxkt ) {
               me.atdiscspeed2();
           }
           else {
               settimer(func { me.speedacquire(); },me.SPEEDACQUIRESEC);
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

Autothrottle.has_lock = func {
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode != "" and speedmode != nil ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
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

Autothrottle.is_lock_speed = func {
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
       if( me.is_lock_speed() ) {
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

Autothrottle.is_lock_mach = func {
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode == "mach-with-throttle" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
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
   if( me.has_lock() ) {
       result = constant.TRUE;

       # plus/minus 0.06 Mach (real)
       if( me.is_lock_mach() ) {
           # 0.006 Mach per second (real)
           value = 0.006 * sign;
           step = 1.0 * sign;
       }
       # plus/minus 22 kt (real)
       elsif( me.is_lock_speed() ) {
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
           if( me.is_lock_mach() ) {
               targetmach = me.settings.getChild("target-mach").getValue();
               targetmach = targetmach + value;
               me.mach(targetmach);
           }
           elsif( me.is_lock_speed() ) {
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
