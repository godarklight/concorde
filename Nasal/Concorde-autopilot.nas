#This was completely scrapped and re-written. Started 13-May-2013.

# =========
# AUTOPILOT
# =========

#===AUTOPILOT STARTUP/INIT===#

Autopilot = {};

Autopilot.new = func {
   var obj = { parents : [Autopilot,System],

               autothrottlesystem : nil,
               MAXCRUISEFT: 50000,
               MAXCRUISEMACH: 2.00,
               MAXMACH: 2.02,

               GROUNDAUTOPILOT: 0,                            # Enable autopilot on ground for testing
               MINAUTOPILOTFT: 50,                            # Stop autopilot from engaging on ground, causes wild trims
               VLGSAQUIREDEFLECTION : 3,                      # When to engage VL and GL modes (degrees difference)
               TARGETFT : 1200.0,                             # When to engage AA mode from VS (altitude aquire light comes on)
               ALTIMETERFT : 50.0,                            # When the altitude aquire light goes out

               AUTOLANDFT : 1500.0,                           # altitude for LA mode
               LANDINGFT : 800.0,                             # Adjusts to the landing pitch
               LANDINGDEGSEC : 20,                            # Reaches the landing pitch
               LANDINGDEG : 7.5,                              # Landing pitch
               PITCHFT : 500.0,                               # Reaches the landing pitch
               FLAREFT : 80.0,                                # Leaves glide slope
               FLAREDEG : 10,                                  # Leaves glide slope
               FLARESEC : 2,                                  # Leaves glide slope
               WPTNM : 4.0,                                   # Distance to swap to next waypoint
               VORNM : 3.0,                                   # Distance to inhibate VOR
               GOAROUNDDEG : 15.0,                            # Pitch on go-around
               LANDINGSEC : 5,                                # How long it takes to pitch down after landing
         };

# autopilot initialization
   obj.init();
   return obj;
};

Autopilot.init = func {
  me.inherit_system('/systems/autopilot');
}

Autopilot.set_relation = func(atsystem) {
  autothrottlesystem = atsystem;
}

Autopilot.reinitexport = func {
  #NAV 0 is reserved for autopilot
  #On startup, copy NAV1 to co-pilots NAV2, then copy NAV0 to pilots NAV1
  me.sendnav( 1, 2 );
  me.sendnav( 0, 1 );
  me.channelengage = {0:0, 1:0};
  me.is_turbulence = 0;
  me.is_altitude_aquire = 0;
  me.is_altitude_aquiring = 0;
  me.is_holding_altitude = 0;
  me.is_max_cruise = 0;
  me.discexport();
}

Autopilot.display = func(vartype, varvalue) {
  me.itself['autoflight'].getChild(vartype).setValue(varvalue);
}

#===AUTOPILOT DISCONNECT===#

Autopilot.discexport = func {
  me.discaquire();
  me.discheading();
  me.discvertical();
  me.itself['channel'][0].getChild('engage').setValue(0);
  me.itself['channel'][1].getChild('engage').setValue(0);
  me.channelengage[0] = 0;
  me.channelengage[1] = 0;
}

Autopilot.discaquire = func {
  me.is_vor_aquire = 0;
  me.is_land_aquire = 0;
  me.is_gs_aquire = 0;
  me.is_altitude_aquire = 0;
  me.is_land_aquire = 0;
  me.display('vor-aquire', 0);
  me.display('land-aquire', 0);
  me.display('land-display', 0);
  me.display('gs-aquire', 0);
  me.display('altitude-aquire', 0);
}

Autopilot.discroutemanager = func {
  me.itself['settings'].getChild('gps-driving-true-heading').setValue(0);
}

Autopilot.discheading = func {
  me.is_holding_heading = 0;
  me.is_vor_lock = 0;
  me.itself['locks'].getChild('heading').setValue('');
  me.display('heading-display', '');
  me.discroutemanager();
}

Autopilot.discvertical = func {
  me.disclanding();
  me.is_altitude_aquiring = 0;
  me.is_holding_altitude = 0;
  me.is_gs_lock = 0;
  if ( autothrottlesystem.is_max_climb or me.is_max_cruise ) {
    me.is_max_cruise = 0;
    autothrottlesystem.atdiscmaxclimbexport();
  }
  me.itself['locks'].getChild('altitude').setValue('');
  me.display('altitude-display', '');
}

Autopilot.disclanding = func {
  me.is_landing = 0;
  me.landing_stage = 0;
  me.display('land-display', 0);
  me.display('land-aquire', 0);
}

Autopilot.resettrim = func {
  #Reset trim after autoland
  me.dependency['flight'].getChild('elevator-trim').setValue(0);
  me.dependency['flight'].getChild('aileron-trim').setValue(0);
}

#===NAV COPY===#

Autopilot.sendnav = func( index, target ) {
   #Copys nav[index] to nav[target]. Runs on autopilot engage/pilot/copilot changes.
   var freqmhz = 0.0;
   var radialdeg = 0.0;
   freqmhz = getprop('/instrumentation/nav[' ~ index ~ ']/frequencies/selected-mhz');
   setprop('/instrumentation/nav[' ~ target ~ ']/frequencies/selected-mhz',freqmhz);
   freqmhz = getprop('/instrumentation/nav[' ~ index ~ ']/frequencies/standby-mhz');
   setprop('/instrumentation/nav[' ~ target ~ ']/frequencies/standby-mhz',freqmhz);
   radialdeg = getprop('/instrumentation/nav[' ~ index ~ ']/radials/selected-deg');
   setprop('/instrumentation/nav[' ~ target ~ ']/radials/selected-deg',radialdeg);
}

#==PID SETTINGS===#

Autopilot.configurepidsettings = func {
  #This tunes vertical speed hold to be less sensitive as you climb. It replaces a supersonic and subsonic pid, improves response all around.
  #gnd is ground, 50 is 50,000ft. Kp is clipped between gnd and 50,000ft values. Set in Concorde-init-systems.xml.
  var altimeter_ft = me.noinstrument['altitude'].getValue();
  var roll_kp_gnd = me.itself['pid'].getChild('roll-kp-gnd').getValue();
  var roll_kp_50 = me.itself['pid'].getChild('roll-kp-50').getValue();
  var pitch_kp_gnd = me.itself['pid'].getChild('pitch-kp-gnd').getValue();
  var pitch_kp_50 = me.itself['pid'].getChild('pitch-kp-50').getValue();
  var vs_kp_gnd = me.itself['pid'].getChild('vs-kp-gnd').getValue();
  var vs_kp_50 = me.itself['pid'].getChild('vs-kp-50').getValue();
  var heading_kp_gnd = me.itself['pid'].getChild('heading-kp-gnd').getValue();
  var heading_kp_50 = me.itself['pid'].getChild('heading-kp-50').getValue();
  #Yes this gives a negative value... Less sensitive as you climb, apart from heading.
  var roll_kp_diff = roll_kp_50 - roll_kp_gnd;
  var pitch_kp_diff = pitch_kp_50 - pitch_kp_gnd;
  var vs_kp_diff = vs_kp_50 - vs_kp_gnd;
  var heading_kp_diff = heading_kp_50 - heading_kp_gnd;
  var alt_factor = altimeter_ft / 50000;
  if ( alt_factor < 0 ) {
    alt_factor = 0;
  }
  if ( alt_factor > 1 ) {
    alt_factor = 1;
  }
  var roll_new_kp = roll_kp_gnd + ( roll_kp_diff * alt_factor );
  me.itself['pid'].getChild('roll-kp-current').setValue(roll_new_kp);
  var pitch_new_kp = pitch_kp_gnd + ( pitch_kp_diff * alt_factor );
  me.itself['pid'].getChild('pitch-kp-current').setValue(pitch_new_kp);
  var vs_new_kp = vs_kp_gnd + ( vs_kp_diff * alt_factor );
  me.itself['pid'].getChild('vs-kp-current').setValue(vs_new_kp);
  var heading_new_kp = heading_kp_gnd + ( heading_kp_diff * alt_factor );
  me.itself['pid'].getChild('heading-kp-current').setValue(heading_new_kp);
}


#===AUTOPILOT CONNECT===#


Autopilot.setstartuphold = func {
  if ( me.itself['autoflight'].getChild('heading').getValue() == '' ) {
    me.apheadingholdexport();
  }
  if ( me.itself['autoflight'].getChild('altitude').getValue() == '' ) {
    me.appitchexport();
  }
}

Autopilot.apchannel = func {
  # Enables the autopilot if one of the channels are active
  var current_ft = me.dependency['radio-altimeter'][0].getChild('indicated-altitude-ft').getValue();
  var is_ap1_engaged = me.itself['channel'][0].getChild('engage').getValue();
  var is_ap2_engaged = me.itself['channel'][1].getChild('engage').getValue();
  #Stop both channels from being activated at the same time unless in autoland mode
  if (( is_ap1_engaged and me.channelengage[1] ) and ( ! me.is_land_aquire or me.is_landing )) {
    me.itself['channel'][0].getChild('engage').setValue(0);
  } else {
    me.channelengage[0] = is_ap1_engaged;
  }
  if (( is_ap2_engaged and me.channelengage[0] ) and ( ! me.is_land_aquire or me.is_landing )) {
    me.itself['channel'][1].getChild('engage').setValue(0);
  } else {
    me.channelengage[1] = is_ap2_engaged;
  }

  #Enabling autopilot on ground causes wild trimming, so disable it unless config set.
  if ( current_ft < me.MINAUTOPILOTFT ) {
    if ( ! me.GROUNDAUTOPILOT ) {
    gui.popupTip("Cannot engage the autopilot while on the ground!");
    me.itself['channel'][0].getChild('engage').setValue(0);
    me.itself['channel'][1].getChild('engage').setValue(0);
    me.channelengage[0] = 0;
    me.channelengage[1] = 0;
    } elsif ( me.is_autopilot_engaged() ) {
      #This resets the trim on ground while turning off the autopilot. Comes in handy.
      me.resettrim();
    }
  }

  #This is what most functions read, they do not care if AP1 or AP2 is engaged.
  if ( me.channelengage[0] or me.channelengage[1] ) {
    me.apsendnavexport();
    me.setstartuphold();
  } else {
    me.discexport();
  }

# avoid strong roll near a waypoint
Autopilot.lockwaypointroll = func {
    var distancenm = me.itself["waypoint"][0].getChild("dist").getValue();

    # next waypoint
    if( distancenm != nil ) {
        var lastnm = me.itself["state"].getChild("waypoint-nm").getValue();

        # avoids strong roll
        if( distancenm < me.WPTNM ) {

            # pop waypoint, enough soon to avoid banking on release
            # into the opposite direction of the next waypoint
            var rolldeg =  me.noinstrument["roll"].getValue();
            if( distancenm > lastnm or math.abs(rolldeg) > me.ROLLDEG ) {
                if( me.is_lock_true() ) {
                    me.itself["route-manager"].getChild("input").setValue("@DELETE0");
                    me.resetprediction( "true-heading-hold1" );
                }
            }
        }

        # new waypoint
        elsif( distancenm > lastnm ) {
            me.resetprediction( "true-heading-hold1" );
        }

        me.itself["state"].getChild("waypoint-nm").setValue(distancenm);
    }
}

Autopilot.is_autopilot_engaged = func {
  if ( me.channelengage[0] or me.channelengage[1] ) {
    return 1
  } else {
    return 0
  }
}

#===AUTOPILOT MODES===#
#These functions control the temporary lock in autoflight

#---ROLL---#
Autopilot.modewinglevel = func {
  me.discheading();
  me.itself['locks'].getChild('heading').setValue('wing-leveler');
}

Autopilot.modemagneticheading = func {
  me.discheading();
  me.itself['locks'].getChild('heading').setValue('dg-heading-hold');
}

Autopilot.modenavrudder = func {
  me.discheading();
  me.itself['locks'].getChild('heading').setValue('nav1-rudder');
}

Autopilot.modenavruddergnd = func {
  me.discheading();
  me.itself['locks'].getChild('heading').setValue('nav1-rudder-gnd');
}

Autopilot.modetrueheading = func {
  me.discheading();
  me.itself['locks'].getChild('heading').setValue('true-heading-hold');
}

Autopilot.modevorlock = func {
  me.discheading();
  me.itself['locks'].getChild('heading').setValue('nav1-hold');
}

#---PITCH---#

Autopilot.modeturbulence = func {
  #Turbulence mode is just wing leveler + pitch hold.
  me.discheading();
  me.discvertical();
  me.is_turbulence = 1;
  me.modewinglevel();
  me.holdpitch();
  me.modepitch();
}

Autopilot.modepitch = func {
  me.discvertical();
  me.itself['locks'].getChild('altitude').setValue('pitch-hold');
}

Autopilot.modeverticalspeed = func {
  me.discvertical();
  me.itself['locks'].getChild('altitude').setValue('vertical-speed-hold');
}

Autopilot.modealtitudehold = func {
  me.discvertical();
  me.itself['locks'].getChild('altitude').setValue('altitude-hold');
}

Autopilot.modeglidescope = func {
  me.discvertical();
  me.itself['locks'].getChild('altitude').setValue('gs1-hold');
}

Autopilot.modespeedpitch = func {
  me.discvertical();
  me.itself['locks'].getChild('altitude').setValue('');
  autothrottlesystem.modespeedpitch();
}

Autopilot.modemachpitch = func {
  me.discvertical();
  me.itself['locks'].getChild('altitude').setValue('mach-with-pitch-trim');
}

Autopilot.modemaxclimb = func {
  me.discvertical();
  me.is_max_cruise = 0;
  autothrottlesystem.is_max_climb = 1;
  var max_airspeed = me.dependency['airspeed'][0].getChild('vmo-kt').getValue();
  autothrottlesystem.speed(max_airspeed);
  me.modespeedpitch();
  autothrottlesystem.full();
  me.display('altitude-display', 'CL');
  autothrottlesystem.display('speed-display', '');
}

Autopilot.modemaxcruise = func {
  me.discvertical();
  autothrottlesystem.display('speed-display', '');
  autothrottlesystem.mach(2.02);
  autothrottlesystem.modemach();
  me.setverticalspeed(50);
  me.modeverticalspeed();
  autothrottlesystem.is_max_climb = 0;
  me.is_max_cruise = 1;
  me.display('altitude-display', 'CR');
}

#===AUTOPILOT LANDING MODE===#

Autopilot.modeland = func {
  var current_ft = me.dependency['radio-altimeter'][0].getChild('indicated-altitude-ft').getValue();
  #Start autolanding at 1500ft
  #First stage is to fly the ILS normally from 1500ft to 1000ft but reduce speed to VREF + 10knots (180knots as workaround).
  if ( me.landing_stage == 1 ) {
    if ( current_ft < me.LANDINGFT ) {
      me.holdpitch();
      me.modepitch();
      autothrottlesystem.modeglidescope();
      interpolate('/autopilot/settings/target-pitch-deg', me.LANDINGDEG, me.LANDINGDEGSEC);
      #These get wiped when changing AP mode. Reset them
      me.is_vor_lock = 1;
      me.is_gs_lock = 1;
      me.is_landing = 1;
      me.landing_stage = 2;
      me.display('land-display', 1);
    }
  }

  #Second stage is to pitch to 7.5 degrees from 800-500ft and fly the glidescope with throttle.
  if ( me.landing_stage == 2 ) {
    #Slowly pitch to the landing pitch.
    if ( current_ft < me.PITCHFT ) {
      interpolate('/autopilot/settings/target-pitch-deg', me.LANDINGDEG, 0);
      me.landing_stage = 3;
    }
  }
  #Third stage is to flare
  if ( me.landing_stage == 3 ) {
    if ( current_ft < me.FLAREFT ) {
      interpolate('/autopilot/settings/target-pitch-deg', me.FLAREDEG, me.FLARESEC);
      autothrottlesystem.atdiscspeed();
      autothrottlesystem.idle();
      me.modenavrudder();
      #These get wiped when changing AP mode. Reset them
      me.display('land-display', 1);
      me.is_landing = 1;
      me.landing_stage = 4;
      
    }
  }
  #Forth stage is detecting touchdown and reverse
  if ( me.landing_stage == 4 ) {
      #Wheel 2 and 4 are the back left and right of the main gear.
      var wheel2onground = me.dependency['gear'][2].getChild('wow').getValue();
      var wheel4onground = me.dependency['gear'][4].getChild('wow').getValue();
      if ( wheel2onground and wheel4onground ) {
        autothrottlesystem.setreverse(1);
        interpolate('/autopilot/settings/target-pitch-deg', 0, me.LANDINGSEC);
        #These get wiped when changing AP mode. Reset them
        me.display('land-display', 1);
        me.is_landing = 1;
        me.landing_stage = 5;
      }
  }
  
  #Fifth stage is the rollout and pitchdown and activate thrust reverse.
  if ( me.landing_stage == 5 ) {
    var wheel0onground = me.dependency['gear'][0].getChild('wow').getValue();
    if ( wheel0onground ) {
      me.discvertical();
      me.modenavruddergnd();
      #These get wiped when changing AP mode. Reset them
      me.display('land-display', 1);
      me.is_landing = 1;
      me.landing_stage = 6;
    }
  }
  #Sixth stage is the thrust reverse
  if ( me.landing_stage == 6 ) {
    if ( autothrottlesystem.is_reversed() ) {
      autothrottlesystem.full();
      me.landing_stage = 7;
    }
  }
  #Seventh stage is the disconnect and reset AP
  if ( me.landing_stage == 7 ) {
    var varspeed = getprop('/velocities/groundspeed-kt');
    if ( varspeed < 20 ) {
      autothrottlesystem.setreverse(0);
      autothrottlesystem.idle();
      me.resettrim();
      me.disclanding();
      me.discexport();
    }
  }
}

# spring returns to center, once released by hand
Autopilot.releasedatum = func {
   if( me.itself["autoflight"].getNode("datum/altitude").getValue() != 0.0 ) {
       # no mouse left click
       if( !me.itself["mouse"][constantaero.AP1].getValue() ) {
           me.itself["autoflight"].getNode("datum/altitude").setValue(0.0);
       }
   }
}

# datum adjust of autopilot, arguments
# - step plus/minus 1 (fast) or 0.1 (slow)
Autopilot.datumapexport = func( sign ) {
   var maxcruise = constant.FALSE;
   var value = 0.0;
   var step = 0.0;
   var datum = 0.0;
   var datumold = 0.0;
   var maxstep = 0.0;
   var ratio = 0.0;
   var targetfpm = 0.0;
   var targerdeg = 0.0;
   var targetkt = 0.0;
   var targetft = 0.0;
   var targetmach = 0.0;
   var result = constant.FALSE;


   if( me.has_lock_altitude() ) {
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
       elsif( me.is_lock_pitch() ) {
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
       elsif( me.is_lock_altitude() ) {
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
       elsif( me.is_lock_speed_pitch() ) {
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
       elsif( me.is_lock_mach_pitch() ) {
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
       datum = me.itself["autoflight"].getNode("datum/altitude").getValue();
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
               targetfpm = me.itself["settings"].getChild("vertical-speed-fpm").getValue();
               if( targetfpm == nil ) {
                   targetfpm = 0.0;
               }
               targetfpm = targetfpm + value;
               me.verticalspeed(targetfpm);
           }
           elsif( me.is_lock_pitch() ) {
               targetdeg = me.itself["settings"].getChild("target-pitch-deg").getValue();
               targetdeg = targetdeg + value;
               me.pitch( targetdeg );
           }
           elsif( me.is_lock_altitude() ) {
               targetft = me.itself["settings"].getChild("target-altitude-ft").getValue();
               targetft = targetft + value;
               me.apaltitude(targetft);
           }
           elsif( me.is_lock_speed_pitch() ) {
               targetkt = me.itself["settings"].getChild("target-speed-kt").getValue();
               targetkt = targetkt + value;
               me.autothrottlesystem.speed(targetkt);
           }
           elsif( me.is_lock_mach_pitch() ) {
               targetmach = me.itself["settings"].getChild("target-mach").getValue();
               targetmach = targetmach + value;
               me.autothrottlesystem.mach(targetmach);
           }

           me.itself["autoflight"].getNode("datum/altitude").setValue(datum);
       }
   }


   return result;
}


# ---------------
# FLIGHT DIRECTOR
# ---------------

# activate autopilot
Autopilot.fdexport = func {
   var altitude = "";
   var heading = "";
   var vertical = "";
   var horizontal = "";
   var fd1 = me.itself["flight-director"][constantaero.AP1].getChild("engage").getValue();
   var fd2 = me.itself["flight-director"][constantaero.AP2].getChild("engage").getValue();

   if( fd1 or fd2 ) {
       altitude = me.itself["autoflight"].getChild("altitude").getValue();
       heading = me.itself["autoflight"].getChild("heading").getValue();
       vertical = me.itself["autoflight"].getChild("vertical").getValue();
       horizontal = me.itself["autoflight"].getChild("horizontal").getValue();

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
   me.itself["autoflight"].getChild("vertical").setValue("");
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
               me.itself["autoflight"].getChild("heading").getValue() != "wing-leveler" ) {
               me.apdiscvertical();
           }
       }
   }
}

Autopilot.is_going_around = func {
   var result = constant.FALSE;

   if( me.itself["autoflight"].getChild("vertical").getValue() == "goaround" ) {
       result = constant.TRUE;
   }

   return result;
}

# CAUTION, avoids concurrent crons (stack overflow Nasal error) :
# one may activate glide slope, then arm autoland = 2 calls.
Autopilot.is_goaround = func {
   var result = constant.FALSE;

   if( me.itself["autoflight"].getChild("vertical2").getValue() == "goaround-armed" or me.is_going_around() ) {
       result = constant.TRUE;
   }

   return result;
}

# adjust target speed with wind
# - target speed (kt)
Autopilot.targetwind = func {
   # VREF 152-162 kt
   var weightlb = me.dependency["weight"].getChild("weight-lb").getValue();
   var targetkt = constantaero.Vrefkt( weightlb );
   var windkt = me.dependency["ins"][constantaero.AP1].getNode("computed/wind-speed-kt").getValue();

   # wind increases lift
   if( windkt > 0 ) {
       var winddeg = me.dependency["ins"][constantaero.AP1].getNode("computed/wind-from-heading-deg").getValue();
       var vordeg = me.get_nav().getNode("radials").getChild("target-radial-deg").getValue();
       var offsetdeg = vordeg - winddeg;

       offsetdeg = constant.crossnorth( offsetdeg );

       # add head wind component;
       # except tail wind (too much glide)
       if( offsetdeg > -constant.DEG90 and offsetdeg < constant.DEG90 ) {
           var offsetrad = offsetdeg * constant.DEGTORAD;
           var offsetkt = windkt * math.cos( offsetrad );

           targetkt = targetkt + offsetkt;
       }
   }

   # avoid infinite gliding (too much ground effect ?)
   me.autothrottlesystem.speed(targetkt);
}

# smooth the rebound of pitch hold during the flare
Autopilot.targetpitch = func( targetdeg, aglft, rates ) {
   var pitchdeg = 0.0;
   var speedfps = 0.0;
   var deltaft = 0.0;
   var timesec = 0.0;
   var deltadeg = 0.0;
   var ratedegps = 0.0;
   var stepdeg = 0.0;

   # start from attitude
   if( !me.is_pitch() ) {
       pitchdeg = me.noinstrument["pitch"].getValue();
   }
   else {
       pitchdeg = me.itself["settings"].getChild("target-pitch-deg").getValue();
   }

   if( pitchdeg != targetdeg ) {
       if( targetdeg > pitchdeg ) {
           speedfps = - me.get_ivsi().getChild("indicated-speed-fps").getValue();
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

# autoland mode
Autopilot.autoland = func {
   var aglft = 0.0;
   var pitchdeg = 0.0;
   var verticalmode2 = "";      

   # to catch the go around
   var rates = me.GOAROUNDSEC;

   me.goaround();

   if( me.is_autoland() ) {
       verticalmode2 = "goaround-armed";

       # cron runs without autopilot engagement
       if( me.is_engaged() ) {
           aglft = me.get_radioaltimeter().getChild("indicated-altitude-ft").getValue();

           # armed
           if( me.is_land_armed() ) {
               if( aglft <= me.AUTOLANDFT ) {
                   me.itself["autoflight"].getChild("vertical").setValue("autoland");
               }
           }

           # engaged
           if( me.is_landing() ) {
               # touch down
               if( aglft < constantaero.AGLTOUCHFT ) {

                   # gently reduce pitch
                   if( me.noinstrument["pitch"].getValue() > 1.0 ) {
                       rates = me.TOUCHSEC;

                       # 1 deg / s
                       pitchdeg = me.itself["settings"].getChild("target-pitch-deg").getValue();
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
                       me.dependency["flight"].getChild("elevator-trim").setValue(0.0);
                       me.dependency["flight"].getChild("rudder-trim").setValue(0.0);
                       me.dependency["flight"].getChild("aileron-trim").setValue(0.0);
                   }

                   # pilot must activate autothrottle
                   me.autothrottlesystem.idle();
               }
 
               # triggers below 1500 ft
               elsif( aglft > me.AUTOLANDFT ) {
                   me.itself["autoflight"].getChild("vertical").setValue("autoland-armed");
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
                           if( !me.itself["autoflight"].getChild("real-nav").getValue() ) {
                               if( !me.is_magnetic() ) {
                                   me.landheadingdeg = me.noinstrument["magnetic"].getValue();
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

   me.itself["autoflight"].getChild("vertical2").setValue(verticalmode2);

   # re-schedule the next call
   if( me.is_goaround() ) {
       settimer(func { me.autoland(); }, rates);
   }
}

Autopilot.landlight = func {
   var land2 = constant.FALSE;
   var land3 = constant.FALSE;
   var channel1 = constant.FALSE;
   var channel2 = constant.FALSE;

   if( me.is_landing() ) {
       channel1 = me.itself["channel"][constantaero.AP1].getChild("engage").getValue();
       channel2 = me.itself["channel"][constantaero.AP2].getChild("engage").getValue();

       if( channel1 or channel2 ) {
           land2 = constant.TRUE;
       }
       if( channel1 and channel2 ) {
           land3 = constant.TRUE;
       }
   }

   me.itself["state"].getChild("land2").setValue(land2);
   me.itself["state"].getChild("land3").setValue(land3);
}

Autopilot.is_landing = func {
   var result = constant.FALSE;
   var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();

   if( verticalmode == "autoland" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_land_armed = func {
   var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();
   var result = constant.FALSE;

   if( verticalmode == "autoland-armed" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_autoland = func {
   var result = constant.FALSE;

   if( me.is_landing() or me.is_land_armed() ) {
       result = constant.TRUE;
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
   var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();
   var result = constant.FALSE;

   if( verticalmode == "turbulence" ) {
       result = constant.TRUE;
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
   me.itself["autoflight"].getChild("altitude").setValue("");

   # switch to speed hold
   if( me.autothrottlesystem != nil ) {
       me.autothrottlesystem.discmaxclimb();
   }
}

# altitude button lights, when the dialed altitude is reached.
# altimeter light, when the dialed altitude is reached.
Autopilot.altitudelight = func {
   var altft = 0.0;
   var minft = 0.0;
   var maxft = 0.0;

   if( me.is_engaged() ) {
       if( me.is_altitude_hold() or me.is_altitude_acquire() ) {
           altft = me.itself["autoflight"].getChild("altitude-select").getValue();

           # altimeter light within 1200 ft
           minft = altft - me.ALTIMETERFT;
           me.itself["altimeter"].getChild("target-min-ft").setValue(minft);
           maxft = altft + me.ALTIMETERFT;
           me.itself["altimeter"].getChild("target-max-ft").setValue(maxft);

           # no altimeter light within 50 ft
           minft = altft - me.LIGHTFT;
           me.itself["altimeter"].getChild("light-min-ft").setValue(minft);
           maxft = altft + me.LIGHTFT;
           me.itself["altimeter"].getChild("light-max-ft").setValue(maxft);
       }
   }
}

Autopilot.altitudelight_on = func ( altitudeft, targetft ) {
   var result = constant.TRUE;

   if( altitudeft < targetft - me.ALTIMETERFT or
       altitudeft > targetft + me.ALTIMETERFT ) {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.altitudeacquire = func {
   var altitudeft = 0.0;
   var speedfpm = 0.0;
   var mode = "";

   if( me.is_engaged() ) {
       if( me.is_altitude_acquire() ) {
           me.altitudelight();

           altitudeft = me.get_altimeter().getChild("indicated-altitude-ft").getValue();
           if( altitudeft > me.itself["altimeter"].getChild("target-max-ft").getValue() ) {
               speedfpm = -me.ACQUIREFPM;
               mode = "vertical";
           }
           elsif( altitudeft < me.itself["altimeter"].getChild("target-min-ft").getValue() ) {
               speedfpm = me.ACQUIREFPM;
               mode = "vertical";
           }

           # capture
           elsif( altitudeft > me.itself["altimeter"].getChild("light-max-ft").getValue() or
                  altitudeft < me.itself["altimeter"].getChild("light-min-ft").getValue() ) {
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
               settimer(func { me.altitudeacquire(); }, me.ALTACQUIRESEC);
           }
       }
   }
}

Autopilot.selectfpm = func( altitudeft, targetft ) {
   var speedfpm = me.CLIMBFPM;

   if( altitudeft > targetft ) {
       speedfpm = me.DESCENTFPM;
   }

   me.verticalspeed(speedfpm);
}

Autopilot.has_lock_altitude = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode != "" and altitudemode != nil ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_lock_altitude = func {
   var altitudemode = me.itself["locks"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle altitude hold (ctrl-A)
Autopilot.aptogglealtitudeexport = func {
   var altitudeft = 0.0;
   var targetft = 0.0;

   if( !me.no_voltage() ) {
       if( !me.is_vertical_speed() or me.is_altitude_acquire() ) {
           me.apenable();
           me.apverticalexport();
       }
       me.apaltitudeexport();

       # avoid many manual operations
       if( me.is_vertical_speed() ) {
           altitudeft = me.get_altimeter().getChild("indicated-altitude-ft").getValue();
           targetft = me.itself["autoflight"].getChild("altitude-select").getValue();
           me.selectfpm( altitudeft, targetft );
       }
   }
}

Autopilot.apaltitudeselectexport = func {
   var altitudeft = 0.0;

   if( me.is_altitude_acquire() ) {
       altitudeft = me.itself["autoflight"].getChild("altitude-select").getValue();
       me.apaltitude(altitudeft);
   }
}

Autopilot.is_altitude_hold = func {
   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
   var result = constant.FALSE;

   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_altitude_acquire = func {
   var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();
   var result = constant.FALSE;

#---ROLL---#

Autopilot.setmagnetic = func(magnetic) {
  me.itself['settings'].getChild('heading-bug-deg').setValue(magnetic);
}

Autopilot.holdmagnetic = func {
  me.itself['settings'].getChild('heading-bug-deg').setValue(me.noinstrument['magnetic'].getValue());
}

Autopilot.settrue = func(trueheadingdeg) {
  me.itself['settings'].getChild('true-heading-deg').setValue(trueheadingdeg);
}

#---PITCH---#
Autopilot.setpitch = func(varpitch) {
  me.itself['settings'].getChild('target-pitch-deg').setValue(varpitch);
}

Autopilot.holdpitch = func {
  me.itself['settings'].getChild('target-pitch-deg').setValue(me.noinstrument['pitch'].getValue());
}

Autopilot.setverticalspeed = func(verticalspeed) {
  me.itself['settings'].getChild('vertical-speed-fpm').setValue(verticalspeed);
}

Autopilot.holdverticalspeed = func {
  var verticalspeed = me.dependency['ivsi'][0].getChild('indicated-speed-fps').getValue();
  verticalspeed = verticalspeed * 60;
  me.itself['settings'].getChild('vertical-speed-fpm').setValue(verticalspeed);
  me.itself['settings'].getChild('vertical-speed-fpm').setValue(verticalspeed);
}

Autopilot.setaltitude = func(altitude) {
  me.itself['settings'].getChild('target-altitude-ft').setValue(altitude);
}

Autopilot.holdaltitude = func {
  me.itself['settings'].getChild('target-altitude-ft').setValue(me.dependency['altimeter'][0].getChild('indicated-altitude-ft').getValue());
}

#===AUTOPILOT EXPORTS===#
#These are the functions called from the model xml (button presses)

Autopilot.apexport = func {
  me.apchannel();
}

Autopilot.apinsexport = func {
  if ( me.is_autopilot_engaged() ) {
    if ( me.itself['route-manager'].getChild('active').getValue() == 1 ) {
      me.itself['settings'].getChild('gps-driving-true-heading').setValue(1);
      me.modetrueheading();
      me.display('heading-display', 'IN');
    }
  }
}

Autopilot.apsendheadingexport = func {
  if ( ! me.is_holding_heading ) {
    var gps_driving_heading = me.itself['settings'].getChild('gps-driving-true-heading').getValue();
    if ( me.channelengage[0] ) {
      me.setmagnetic(me.itself['channel'][0].getChild('heading-select').getValue());
      if ( ! gps_driving_heading ) {
        me.settrue(me.itself['channel'][0].getChild('heading-select').getValue());
      }
    }
    if ( me.channelengage[1] ) {
      me.setmagnetic(me.itself['channel'][1].getChild('heading-select').getValue());
      if ( ! gps_driving_heading ) {
        me.settrue(me.itself['channel'][1].getChild('heading-select').getValue());
      }
    }
  }
}

Autopilot.apsendnavexport = func {
    if ( me.channelengage[0] ) {
      me.sendnav(1,0);
    }
    if ( me.channelengage[1] ) {
      me.sendnav(2,0);
    }
}

Autopilot.apheadingexport = func {
  if ( me.is_autopilot_engaged() ) {
    var radinsmode1 = getprop('/instrumentation/hsi[0]/ins-source');
    var radinsmode2 = getprop('/instrumentation/hsi[1]/ins-source');
    me.is_holding_heading = 0;
    me.apsendheadingexport();
    if ( me.channelengage[0] ) {
      if ( radinsmode1 ) {
        me.modetrueheading(); 
      } else {
        me.modemagneticheading();
      }
    }
    if ( me.channelengage[1] ) {
      if ( radinsmode2 ) {
        me.modetrueheading(); 
      } else {
        me.modemagneticheading();
      }
    }
    me.display('heading-display', 'TH');
  }
}

Autopilot.apheadingholdexport = func {
  if ( me.is_autopilot_engaged() ) {
    me.holdmagnetic();
    me.modemagneticheading();
    me.is_holding_heading = 1;
    me.display('heading-display', 'HH');
  }
}

Autopilot.apturbulenceexport = func {
  if ( me.is_autopilot_engaged() ) {
    me.modeturbulence();
    me.display('heading-display', 'TU');
  }
}

Autopilot.apvorlocexport = func {
  if ( me.is_autopilot_engaged() and ! me.is_vor_lock ) {
    if ( ! me.is_vor_aquire) {
      me.is_vor_aquire = 1;
      me.display('vor-aquire', 1);
    } else {
      if ( ! me.is_land_aquire and ! me.is_landing and ! me.is_gs_aquire and ! me.is_gs_lock ) {
        me.is_vor_aquire = 0;
        me.display('vor-aquire', 0);
      }
    }
  }
}

Autopilot.appitchexport = func {
  if ( me.is_autopilot_engaged() ) {
    me.holdpitch();
    me.modepitch();
    me.display('altitude-display', 'PH');
  }
}

Autopilot.apmachpitchexport = func {
  if ( me.is_autopilot_engaged() ) {
    if ( ! autothrottlesystem.is_autothrottle_engaged ) {
      autothrottlesystem.holdmach(); #The pitch function reads /autopilot/settings, easy to set from here.
      me.modemachpitch();
      me.display('altitude-display', 'MP');
    } else {
      gui.popupTip("Disable autothrottle before engaging mach with pitch");
    }
  }
}

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
   me.itself["autoflight"].getChild("horizontal").setValue("");
}

Autopilot.is_waypoint = func {
   var result = constant.FALSE;

   if( me.route_active() ) {
       var id = me.itself["waypoint"][0].getChild("id").getValue();

       if( id != nil and id != "" ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.route_active = func {
   var result = constant.FALSE;

   # autopilot/route-manager/wp is updated only once airborne
   if( me.itself["route-manager"].getChild("active").getValue() and
       me.itself["route-manager"].getChild("airborne").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.locktrue = func {
   me.itself["locks"].getChild("heading").setValue("true-heading-hold");
}

Autopilot.is_lock_true = func {
   var headingmode = me.itself["locks"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_true = func {
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.inslight = func {
   var activation = constant.FALSE;
   var id = ["", "", ""];

   # TEMPORARY work around for 2.0.0
   if( me.route_active() ) {
       activation = constant.TRUE;

       # each time, because the route can change
       var wp = me.itself["route"].getChildren("wp");
       var current_wp = me.itself["route-manager"].getChild("current-wp").getValue();
       var nb_wp = size(wp);

       # route manager doesn't update these fields
       if( nb_wp >= 1 ) {
           id[0] = wp[current_wp].getChild("id").getValue();

           # default
           id[1] = "";
           id[2] = id[0];
       }

       if( current_wp + 1 < nb_wp ) {
           id[1] = wp[current_wp + 1].getChild("id").getValue();
       }

       if( nb_wp > 0 ) {
           id[2] = wp[nb_wp-1].getChild("id").getValue();
       }
   }

   me.itself["waypoint"][0].getChild("id").setValue( id[0] );
   me.itself["waypoint"][1].getChild("id").setValue( id[1] );
   me.itself["route-manager"].getNode("wp-last").getNode("id",constant.DELAYEDNODE).setValue( id[2] );


   # no more waypoint
   if( me.is_ins() ) {

       # simulate an INS failure, by holding the magnetic heading
       # (cannot hold the true heading, when there are still waypoints).
       if( me.ins_failure() ) {
           me.apdischorizontal();
           me.magneticheading();
           me.lockmagnetic();
       }

       # keeps the current heading mode
       elsif( !me.is_waypoint() ) {
           me.apdischorizontal();
       }
   }

   # waypoint
   elsif( me.is_waypoint() ) {
       # real behaviour : INS input doesn't toggle autopilot
       if( !me.itself["autoflight"].getChild("fg-waypoint").getValue() ) {
           # keep current heading mode, if any
           if( !me.is_true() ) {
               me.apengage();
           }

           # already in true heading mode : keep display coherent
           elsif( !me.is_ins() ) {
               me.apinsexport();
           }
       }

       # Feedback requested by user : activation of route toggles autopilot
       elsif( !me.routeactive ) {
           # only when route is being activated (otherwise cannot leave INS mode)
           if( !me.is_ins() ) {
               me.apinsexport();
           }
       }
   }


   me.routeactive = activation;
}

Autopilot.ins_failure = func {
   var index = 0;
   var result = constant.FALSE;

   if( me.has_engaged() ) {
       # INS 2
       if( me.get_hsi().getChild("nav-ins2").getValue() ) {
           index = 1;
       }

       # INS 1
       else {
           index = 0;
       }

       if( me.dependency["ins"][index].getNode("light/warning").getValue() ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.is_ins = func {
   var horizontalmode = me.itself["autoflight"].getChild("horizontal").getValue();
   var result = constant.FALSE;

   if( horizontalmode == "ins" ) {
       result = constant.TRUE;
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
   me.itself["autoflight"].getChild("heading").setValue("");

   if( me.is_turbulence() ) {
       me.apdiscvertical();
   }
}

# correction of prediction filter oscillations
Autopilot.predictioncorrection = func( name, node, mode, mindeg ) {
   # disabled, when it amplifies oscillations :
   # - speed up.
   # - supersonic cruise
   if( !me.itself["pid"].getChild("prediction-filter").getValue() or
       me.noinstrument["speed-up"].getValue() > 1.0 or
       me.is_supersonicpid( mode ) ) {
       me.resetprediction( name );
   }


   else {
       var erroraheaddeg = 0.0;
       var errordeg = 0.0;
       var offsetdeg = 0.0;
       var deltastablesec = 0.0;
       var deltalaunchsec = 0.0;
       var path = "";


       var filter = node.getChild("prediction-filter").getValue();

       var stablesec = node.getChild("stable-sec").getValue();
       var launchsec = node.getChild("launch-sec").getValue();
       var timesec = me.noinstrument["time"].getValue();

       if( stablesec > 0.0 ) {
           deltastablesec = timesec - stablesec;
       }
       if( launchsec > 0.0 ) {
           deltalaunchsec = timesec - launchsec;
       }


       path = me.itself["config"][me.PIDSUPERSONIC].getNode(name).getChild("input").getValue();
       erroraheaddeg = props.globals.getNode(path).getValue();

       path = me.itself["config"][me.PIDSUBSONIC].getNode(name).getChild("input").getValue();
       errordeg = props.globals.getNode(path).getValue();

       offsetdeg = errordeg - erroraheaddeg;
       offsetdeg = math.abs( offsetdeg );


       # would bank into the opposite direction, when engaged
       if( deltalaunchsec <= me.PREDICTIONSEC ) {
           deltastablesec = 0.0;

           # enable filter later on a plausible prediction
           mode = me.PIDSUPERSONIC;
       }

       # filter amplifies oscillations, once in cruise
       elsif( offsetdeg < mindeg and deltastablesec > me.STABLESEC ) {
           # disable filter in cruise
           mode = me.PIDSUPERSONIC;
       }

       # hysteresis, once stable
       elsif( !filter and offsetdeg < ( 2 * mindeg ) and deltastablesec > me.STABLESEC ) {
           # will enable filter on a higher offset
           mode = me.PIDSUPERSONIC;
       }

       # filter not yet stable
       else {
           deltastablesec = 0.0;
       }


       me.setprediction( name, node, mode );


       # reset timers
       if( deltastablesec <= 0.0 ) {
           me.setpredictionstability( node, timesec );
       }

       if( deltalaunchsec <= 0.0 ) {
           me.setpredictionlaunch( node, timesec );
       }
   }
}

Autopilot.setprediction = func( name, node, mode ) {
   var result = constant.FALSE;
   var child = node.getChild("input");
   var currentpath = child.getAliasTarget().getPath();
   var path = me.itself["config"][mode].getNode(name).getChild("input").getValue();

   # update only on change
   if( currentpath != path ) {
       child.unalias();
       child.alias( path );

       # feedback on filter activity
       node.getChild("prediction-filter").setValue( me.is_subsonicpid( mode ) );

       result = constant.TRUE;
   }

   return result;
}

Autopilot.resetprediction = func( name ) {
   var node = me.itself["pid"].getNode(name);

   if( me.setprediction( name, node, me.PIDSUPERSONIC ) ) {
       me.setpredictionstability( node, 0.0 );
       me.setpredictionlaunch( node, 0.0 );
   }
}

Autopilot.setpredictionstability = func( node, stablesec ) {
   node.getChild("stable-sec").setValue( stablesec );
}

Autopilot.setpredictionlaunch = func( node, launchsec ) {
   node.getChild("launch-sec").setValue( launchsec );
}

Autopilot.trueheading = func( headingdeg ) {
   me.itself["settings"].getChild("true-heading-deg").setValue(headingdeg);
}

# sonic true mode
Autopilot.sonictrueheading = func {
   var name = "true-heading-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );
   node.getChild("u_min").setValue( me.itself["config"][mode].getNode(name).getChild("u_min").getValue() );
   node.getChild("u_max").setValue( me.itself["config"][mode].getNode(name).getChild("u_max").getValue() );

   # prediction filter may bank into the opposite direction, when engaged
   me.predictioncorrection( name, node, mode, me.OSCTRACKDEG );

   name = "true-heading-hold3";
   node = me.itself["pid"].getNode(name);
   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );

   # not real : FG default keyboard changes autopilot heading
   if( me.is_lock_true() and me.istrackheading() ) {
       headingdeg = me.itself["settings"].getChild("true-heading-deg").getValue();
       me.itself["channel"][me.engaged_channel].getChild("heading-true-select").setValue(headingdeg);
   }
}

# sonic magnetic mode
Autopilot.sonicmagneticheading = func {
   var name = "dg-heading-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );
   node.getChild("u_min").setValue( me.itself["config"][mode].getNode(name).getChild("u_min").getValue() );
   node.getChild("u_max").setValue( me.itself["config"][mode].getNode(name).getChild("u_max").getValue() );

   # prediction filter amplifies oscillations
   if( me.is_autoland() or !me.istrackheading() ) {
       me.resetprediction( name );
   }

   else {
       me.predictioncorrection( name, node, mode, me.OSCTRACKDEG );
   }

   name = "dg-heading-hold3";
   node = me.itself["pid"].getNode(name);
   node.getChild("Kp").setValue( me.itself["config"][mode].getNode(name).getChild("Kp").getValue() );

   # not real : FG default keyboard changes autopilot heading
   if( me.is_lock_magnetic() and me.istrackheading() ) {
       headingdeg = me.itself["settings"].getChild("heading-bug-deg").getValue();
       me.itself["channel"][me.engaged_channel].getChild("heading-select").setValue(headingdeg);
   }
}

# sonic nav mode
Autopilot.sonicnavheading = func {
   var name = "nav-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   # prediction filter amplifies oscillations
   if( me.is_autoland() or me.is_glide() ) {
       me.resetprediction( name );
   }

   else {
       me.predictioncorrection( name, node, mode, me.OSCNAVDEG );
   }
}

Autopilot.sonicheadingmode = func {
   var magpid = constant.FALSE;
   var truepid = constant.FALSE;
   var navpid = constant.FALSE;

   if( me.is_lock_magnetic() ) {
       me.sonicmagneticheading();
       magpid = constant.TRUE;
   }

   elsif( me.is_lock_true() ) {
       me.sonictrueheading();
       truepid = constant.TRUE;
   }

   elsif( me.is_lock_nav() ) {
       me.sonicnavheading();
       navpid = constant.TRUE;
   }

   if( !magpid ) {
       me.resetprediction( "dg-heading-hold1" );
   }
   if( !truepid ) {
       me.resetprediction( "true-heading-hold1" );
   }
   if( !navpid ) {
       me.resetprediction( "nav-hold1" );
   }
}

Autopilot.heading = func( headingdeg ) {
   me.itself["settings"].getChild("heading-bug-deg").setValue(headingdeg);
}

# magnetic heading
Autopilot.magneticheading = func {
   var headingdeg = me.noinstrument["magnetic"].getValue();

   me.heading(headingdeg);
}

# heading hold
Autopilot.apheadingholdexport = func {
   var mode = me.itself["autoflight"].getChild("horizontal").getValue();

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
   me.itself["locks"].getChild("heading").setValue("dg-heading-hold");
}

Autopilot.is_lock_magnetic = func {
   var headingmode = me.itself["locks"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_magnetic = func {
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.has_lock_heading = func {
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();
   var result = constant.FALSE;

   if( headingmode != "" and headingmode != nil ) {
       result = constant.TRUE;
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
           me.apheadingholdexport();
       }
   }
}

Autopilot.istrackheading = func {
   var result = constant.FALSE;

   if( me.itself["autoflight"].getChild("horizontal").getValue() == "track-heading" ) {
       result = constant.TRUE;
   }

  return result;
}

Autopilot.apsendheadingexport = func {
   var headingdeg = 0.0;

   if( me.istrackheading() ) {
       if( me.is_engaged() ) {
           if( !me.itself["channel"][me.engaged_channel].getChild("track-push").getValue() ) {
               me.apactivatemode("heading","dg-heading-hold");
               headingdeg = me.itself["channel"][me.engaged_channel].getChild("heading-select").getValue();
               me.heading(headingdeg);
           }
           else {
               me.apactivatemode("heading","true-heading-hold");
               headingdeg = me.itself["channel"][me.engaged_channel].getChild("heading-true-select").getValue();
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
   var horizontalmode = me.itself["autoflight"].getChild("horizontal").getValue();
   var result = constant.FALSE;

   if( horizontalmode == "vor" ) {
       result = constant.TRUE;
   }

   return result;
}

# VOR loc
Autopilot.modevorloc = func {
   if( me.is_nav() and !me.is_glide() ) {
       me.itself["autoflight"].getChild("horizontal").setValue("vor");
   }
}

Autopilot.apspeedpitchexport = func {
  if ( me.is_autopilot_engaged() ) {
    if ( ! autothrottlesystem.is_autothrottle_engaged ) {
      autothrottlesystem.holdspeed(); #The pitch function reads /autopilot/settings, easy to set from here.
      me.modespeedpitch();
      me.display('altitude-display', 'IP');
    } else {
      gui.popupTip("Disable autothrottle before engaging speed with pitch");
    }
  }
}

Autopilot.sendnav = func( index, target ) {
   var freqmhz = 0.0;
   var radialdeg = 0.0;

   freqmhz = me.dependency["nav"][index].getNode("frequencies/selected-mhz").getValue();
   me.dependency["nav"][target].getNode("frequencies/selected-mhz").setValue(freqmhz);
   freqmhz = me.dependency["nav"][index].getNode("frequencies/standby-mhz").getValue();
   me.dependency["nav"][target].getNode("frequencies/standby-mhz").setValue(freqmhz);
   radialdeg = me.dependency["nav"][index].getNode("radials/selected-deg").getValue();
   me.dependency["nav"][target].getNode("radials/selected-deg").setValue(radialdeg);
}

Autopilot.apaltitudeexport = func {
  if ( me.is_autopilot_engaged() and ! me.is_altitude_aquiring ) {
    if ( ! me.is_altitude_aquire ) {
      me.is_altitude_aquire = 1;
      me.display('altitude-aquire', 1);
    } else {
      me.is_altitude_aquire = 0;
      me.display('altitude-aquire', 0);
    }
  }
}

Autopilot.aplandexport = func {
  if ( me.is_autopilot_engaged() and ! me.is_landing ) {
    if ( ! me.is_land_aquire ) {
      if ( me.is_vor_aquire or me.is_vor_lock ) {
        if ( ! me.is_gs_aquire and ! me.is_gs_lock ) {
          me.is_gs_aquire = 1;
          me.display('gs-aquire', 1);
        }
        me.is_land_aquire = 1;
        me.landing_stage = 0;
        me.display('land-aquire', 1);
      }
    } else {
      me.is_land_aquire = 0;
      me.display('land-aquire', 0);
    }
  }
}

Autopilot.apglideexport = func {
  if ( me.is_autopilot_engaged() and !me.is_gs_lock ) {
  if ( ! me.is_gs_aquire ) {
    if ( ! me.is_vor_aquire and ! me.is_vor_lock ) {
      me.is_vor_aquire = 1;
      me.display('vor-aquire', 1);
    }
    me.is_gs_aquire = 1;
    me.display('gs-aquire', 1);
  } else {
    if ( ! me.is_land_aquire and ! me.is_landing ) {
      me.is_gs_aquire = 0;
      me.display('gs-aquire', 0);
    }
  }
  }
}

Autopilot.apverticalexport = func {
  if ( me.is_autopilot_engaged() ) {
    me.holdverticalspeed();
    me.modeverticalspeed();
    me.display('altitude-display', 'VS');
  }
}

Autopilot.schedule = func {
  if ( me.is_autopilot_engaged() ) {
    
  #Max climb -> Max cruise
  if ( autothrottlesystem.is_max_climb ) {
  var current_mach = me.dependency['mach'][0].getChild('indicated-mach').getValue();
  var current_ft = me.dependency['altimeter'][0].getChild('indicated-altitude-ft').getValue();
    if (( current_ft > me.MAXCRUISEFT ) or ( current_mach > me.MAXCRUISEMACH )) {
      me.modemaxcruise();
    }
  }

  #Max cruise -> Max climb (Not sure if this ever engages as it requires a magic desent or slow, but it's in the old code so I'll keep it)
  if ( me.is_max_cruise ) {
  var current_mach = me.dependency['mach'][0].getChild('indicated-mach').getValue();
  var current_ft = me.dependency['altimeter'][0].getChild('indicated-altitude-ft').getValue();
    if (( current_ft < me.MAXCRUISEFT ) and ( current_mach < me.MAXCRUISEMACH )) {
      me.modemaxclimb();
    }  
  }
  
  #AA mode armed -> engage
  if ( me.is_altitude_aquire ) {
    var target_ft = me.itself['autoflight'].getChild('altitude-select').getValue();
    var current_ft = me.dependency['altimeter'][0].getChild('indicated-altitude-ft').getValue();
    var target_min_ft = target_ft - me.TARGETFT;
    var target_max_ft = target_ft + me.TARGETFT;
    if ( current_ft < target_max_ft and current_ft > target_min_ft ) {
      me.setaltitude(target_ft);
      me.modealtitudehold();
      me.is_altitude_aquire = 0;
      me.is_altitude_aquiring = 1;
      me.display('altitude-aquire', 0);
      me.display('altitude-display', 'AA');
    }
  }
  #AA mode engage -> AH mode engage
  if ( me.is_altitude_aquiring ) {
    var target_ft = me.itself['autoflight'].getChild('altitude-select').getValue();
    var current_ft = me.dependency['altimeter'][0].getChild('indicated-altitude-ft').getValue();
    var light_min_ft = target_ft - me.ALTIMETERFT;
    var light_max_ft = target_ft + me.ALTIMETERFT;
    if ( current_ft < light_max_ft and current_ft > light_min_ft ) {
      me.is_altitude_aquiring = 0;
      me.is_holding_altitude = 1;
      me.display('altitude-display', 'AH');
    }
  }
  #VL mode armed -> VL mode engage
  if ( me.is_vor_aquire ) {
    var vor_in_range = me.dependency['nav'][0].getChild('in-range').getBoolValue();
    var vor_signal = me.dependency['nav'][0].getChild('signal-quality-norm').getValue();
    if ( vor_in_range and vor_signal > 0.9 ) {
      me.modevorlock();
      me.display('vor-aquire', 0);
      me.display('heading-display', 'VL');
      me.is_vor_aquire = 0;
      me.is_vor_lock = 1;
    }
  }
  #GL mode armed -> GL mode engage. Requires VL.
  if ( me.is_vor_lock and me.is_gs_aquire ) {
    var gs_in_range = me.dependency['nav'][0].getChild('gs-in-range').getBoolValue();
    if ( gs_in_range ) {
      var temp_is_land_aquire = me.is_land_aquire;
      me.modeglidescope();
      if ( temp_is_land_aquire = 1 ) {
        me.display('land-aquire', 1);
        me.is_land_aquire = 1;
      }
      me.display('gs-aquire', 0);
      me.display('gs-aquire', 0);
      me.display('altitude-display', 'GL');
      me.is_gs_lock = 1;
      me.is_gs_aquire = 0;
     }
  }
  #LA mode armed -> LA mode engage. Requires VL+GL.
  if ( me.is_land_aquire and me.is_vor_lock and me.is_gs_lock ) {
    var current_ft = me.dependency['radio-altimeter'][0].getChild('indicated-altitude-ft').getValue();
    if ( current_ft < me.AUTOLANDFT ) {
      me.discaquire();
      me.is_landing = 1;
      me.landing_stage = 1;
      me.display('heading-display', '');
      me.display('altitude-display', '');
      me.display('land-display', 1);
      autothrottlesystem.display('speed-display', '');
      var current_weight = me.dependency["weight"].getChild("weight-lb").getValue();
      #Vref is a little too slow, it sometimes makes the next stage pitch down to 7.5 degrees.
      #var vref = Constantaero.Vrefkt( current_weight ) + 10;
      vref = 180;
      autothrottlesystem.speed(vref);
    }
  }
  #LA mode scheduler. I realise this flares 0 to 1 second after FLAREFT.
  if ( me.is_landing ) {
    me.modeland();
  }
  }
  #Update the PID settings. This calls the function for infinite autopilot tuning vs altitude.
  me.configurepidsettings();
}
