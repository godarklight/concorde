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

#===AUTOPILOT MODE SETTINGS===#
#These actually control the autopilot settings.

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
  if ( me.is_autopilot_engaged() ) {
    if ( autothrottlesystem.is_autothrottle_engaged ) {
      me.modemaxclimb();
      me.display('altitude-display', 'CL');
      autothrottlesystem.display('speed-display', '');
    } else {
      gui.popupTip("Engage autothrottle before engaging max climb");
    }
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

Autopilot.apaltitudeholdexport = func {
  if ( me.is_autopilot_engaged() ) {
    me.is_holding_altitude = 1;
    me.holdaltitude();
    me.modealtitudehold();
    me.display('altitude-display', 'AH');
  }
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
