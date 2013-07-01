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
  me.is_autopilot_engaged = 0;
  me.is_turbulence = 0;
  me.is_altitude_aquire = 0;
  me.is_altitude_aquiring = 0;
  me.is_holding_altitude = 0;
  me.is_max_climb_aquire = 0;
  me.is_max_cruise = 0;
  me.discexport();
}

Autopilot.display = func(vartype, varvalue) {
  me.itself['autoflight'].getChild(vartype).setValue(varvalue);
}

#===AUTOPILOT DISCONNECT===#

Autopilot.discexport = func {
  me.disclanding();
  me.discheading();
  me.discvertical();
  me.discaquire();
  me.itself['channel'][0].getChild('engage').setValue(0);
  me.itself['channel'][1].getChild('engage').setValue(0);
  me.channelengage[0] = 0;
  me.channelengage[1] = 0;
  me.apengage();
}

Autopilot.discaquire = func {
  me.is_max_climb_aquire = 0;
  me.is_vor_aquire = 0;
  me.is_land_aquire = 0;
  me.is_gs_aquire = 0;
  me.is_altitude_aquire = 0;
  me.is_altitude_aquiring = 0;
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
  me.disclanding();
  me.itself['autoflight'].getChild('heading').setValue('');
  me.display('heading-display', '');
  me.display('vor-aquire', 0);
  me.discroutemanager();
  me.apengage();
}

Autopilot.discvertical = func {
  me.is_altitude_aquire = 0;
  me.is_altitude_aquiring = 0;
  me.is_holding_altitude = 0;
  me.is_max_climb_aquire = 0;
  me.is_gs_lock = 0;
  me.disclanding();
  if ( autothrottlesystem.is_max_climb or me.is_max_cruise ) {
    me.is_max_cruise = 0;
    autothrottlesystem.atdiscmaxclimbexport();
  }
  me.itself['autoflight'].getChild('altitude').setValue('');
  me.display('altitude-display', '');
  me.display('altitude-aquire', 0);
  me.display('gs-aquire', 0);
  me.apengage();
}

Autopilot.disclanding = func {
  me.is_land_aquire = 0;
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
   #Copys navigation[index] to nav[target]
   var freqmhz = 0.0;
   var radialdeg = 0.0;
   freqmhz = getprop('/instrumentation/nav[' ~ index ~ ']/frequencies/selected-mhz');
   setprop('/instrumentation/nav[' ~ target ~ ']/frequencies/selected-mhz',freqmhz);
   freqmhz = getprop('/instrumentation/nav[' ~ index ~ ']/frequencies/standby-mhz');
   setprop('/instrumentation/nav[' ~ target ~ ']/frequencies/standby-mhz',freqmhz);
   radialdeg = getprop('/instrumentation/nav[' ~ index ~ ']/radials/selected-deg');
   setprop('/instrumentation/nav[' ~ target ~ ']/radials/selected-deg',radialdeg);
}

#===ALTIMETER LIGHT===#

Autopilot.altimeterlight = func {
  var altsetting = me.itself['autoflight'].getChild('altitude-select').getValue();
  me.itself['altimeter'].getChild('light-min-ft').setValue(altsetting - me.ALTIMETERFT);
  me.itself['altimeter'].getChild('light-max-ft').setValue(altsetting - me.ALTIMETERFT);
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
    } elsif ( me.is_autopilot_engaged ) {
      #This resets the trim on ground while turning off the autopilot. Comes in handy.
      me.resettrim();
    }
  }

  #This is what most functions read, they do not care if AP1 or AP2 is engaged.
  if ( me.channelengage[0] or me.channelengage[1] ) {
    me.is_autopilot_engaged = 1;
    me.apsendnavexport();
    me.setstartuphold();
    me.apengage();
  } else {
    me.is_autopilot_engaged = 0;
    me.discexport();
  }

}

#===AUTPILOT LOCK SETTING===#
#This function copies the temporary lock to the real autopilot lock that the autopilot.xml reads

Autopilot.apengage = func {
    #Engage the autopilot from the current settings
    me.itself['locks'].getChild('heading').setValue(me.itself['autoflight'].getChild('heading').getValue());
    me.itself['locks'].getChild('altitude').setValue(me.itself['autoflight'].getChild('altitude').getValue());
}

#===AUTOPILOT MODES===#
#These functions control the temporary lock in autoflight

#---ROLL---#
Autopilot.modewinglevel = func {
  me.itself['autoflight'].getChild('heading').setValue('wing-leveler');
  me.apengage();
}

Autopilot.modemagneticheading = func {
  me.itself['autoflight'].getChild('heading').setValue('dg-heading-hold');
  me.apengage();
}

Autopilot.modemagneticheadingrudder = func {
  me.itself['autoflight'].getChild('heading').setValue('dg-heading-hold-rudder');
  me.apengage();
}

Autopilot.modetrueheading = func {
  me.itself['autoflight'].getChild('heading').setValue('true-heading-hold');
  me.apengage();
}

Autopilot.modevorlock = func {
  me.itself['autoflight'].getChild('heading').setValue('nav1-hold');
  me.apengage();
}

#---PITCH---#

Autopilot.modeturbulence = func {
  #Turbulence mode is just wing leveler + pitch hold.
  #Does not need to call apengage because the modes have it set.
  me.is_turbulence = 1;
  me.modewinglevel();
  me.holdpitch();
  me.modepitch();
}

Autopilot.modepitch = func {
  me.itself['autoflight'].getChild('altitude').setValue('pitch-hold');
  me.apengage();
}

Autopilot.modeverticalspeed = func {
  me.itself['autoflight'].getChild('altitude').setValue('vertical-speed-hold');
  me.apengage();
}

Autopilot.modealtitudehold = func {
  me.itself['autoflight'].getChild('altitude').setValue('altitude-hold');
  me.apengage();
}

Autopilot.modeglidescope = func {
  me.itself['autoflight'].getChild('altitude').setValue('gs1-hold');
  me.apengage();
}

Autopilot.modespeedpitch = func {
  me.itself['autoflight'].getChild('altitude').setValue('');
  autothrottlesystem.modespeedpitch();
  me.apengage();
}

Autopilot.modemachpitch = func {
  me.itself['autoflight'].getChild('altitude').setValue('mach-with-pitch-trim');
  me.apengage();
}

Autopilot.modemaxclimb = func {
    me.display('altitude-display', 'CL');
    autothrottlesystem.display('speed-display', '');
    me.is_max_cruise = 0;
    me.is_max_climb_aquire = 0;
    autothrottlesystem.is_max_climb = 1;
    var max_airspeed = me.dependency['airspeed'][0].getChild('vmo-kt').getValue();
    autothrottlesystem.speed(max_airspeed);
    me.modespeedpitch();
    autothrottlesystem.full();
}

Autopilot.modemaxcruise = func {
  me.display('altitude-display', 'CR');
  autothrottlesystem.display('speed-display', '');
  autothrottlesystem.mach(2.02);
  autothrottlesystem.modemach();
  me.setverticalspeed(50);
  me.modeverticalspeed();
  autothrottlesystem.is_max_climb = 0;
  me.is_max_cruise = 1;
}

#===AUTOPILOT LANDING MODE===#

#Witness the difficult-to-land concorde do a perfect landing first time every time.

Autopilot.modeland = func {
  var current_ft = me.dependency['radio-altimeter'][0].getChild('indicated-altitude-ft').getValue();
  #Start autolanding at 1500ft
  #First stage is to fly the ILS normally from 1500ft to 1000ft but reduce speed to VREF + 10knots.
  if ( me.landing_stage == 1 ) {
    if ( current_ft < me.LANDINGFT ) {
      me.holdpitch();
      me.modepitch();
      autothrottlesystem.modeglidescope();
      interpolate('/autopilot/settings/target-pitch-deg', me.LANDINGDEG, me.LANDINGDEGSEC);
      me.landing_stage = 2;
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
      autothrottlesystem.atengage();
      autothrottlesystem.idle();  
      #Wheel 2 and 4 are the back left and right of the main gear.
      var wheel2onground = me.dependency['gear'][2].getChild('wow').getValue();
      var wheel4onground = me.dependency['gear'][4].getChild('wow').getValue();
      if ( wheel2onground and wheel4onground ) {
        me.landing_stage = 4;
        autothrottlesystem.setreverse(1);
        me.holdmagnetic();
        me.modemagneticheadingrudder();
      }
    }
  }
  #Forth stage is the rollout and pitchdown and activate thrust reverse.
  if ( me.landing_stage == 4 ) {
    interpolate('/autopilot/settings/target-pitch-deg', 0, me.LANDINGSEC);
    var wheel0onground = me.dependency['gear'][0].getChild('wow').getValue();
    if ( wheel0onground ) {
      me.discvertical();
      me.landing_stage = 5;
    }
  }
  #Fifth stage is the thrust reverse
  if ( me.landing_stage == 5 ) {
    if ( autothrottlesystem.is_reversed() ) {
      autothrottlesystem.full();
      me.landing_stage = 6;
    }
  }
  #Fifth stage is the disconnect and reset AP
  if ( me.landing_stage == 6 ) {
    varspeed = me.dependency['gear'][0].getChild('rollspeed-ms').getValue();
    if ( varspeed < 20 ) {
      autothrottlesystem.setreverse(0);
      autothrottlesystem.idle();
      autothrottlesystem.atdiscexport();
      me.itself['channel'][0].getChild('engage').setValue(0);
      me.itself['channel'][1].getChild('engage').setValue(0);
      me.apchannel();
      me.resettrim();
      me.is_landing = 0;
      me.landing_stage = 0;
    }
  }
}

#===AUTOPILOT MODE SETTINGS===#
#These actually control the autopilot settings

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
#These are the functions called from the model xml

Autopilot.apexport = func {
  me.apchannel();
  me.apengage();
}

Autopilot.apinsexport = func {
  if ( me.is_autopilot_engaged ) {
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
  if ( me.is_autopilot_engaged ) {
    var radinsmode1 = getprop('/instrumentation/hsi[0]/ins-source');
    var radinsmode2 = getprop('/instrumentation/hsi[1]/ins-source');
    me.is_holding_heading = 0;
    me.apsendheadingexport();
    me.display('heading-display', 'TH');
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
  }
}

Autopilot.apheadingholdexport = func {
  if ( me.is_autopilot_engaged ) {
    me.is_holding_heading = 1;
    me.display('heading-display', 'HH');
    me.holdmagnetic();
    me.modemagneticheading();
  }
}

Autopilot.apturbulenceexport = func {
  if ( me.is_autopilot_engaged ) {
    me.display('heading-display', 'TU');
    me.modeturbulence();
  }
}

Autopilot.apvorlocexport = func {
  if ( me.is_autopilot_engaged ) {
  if ( ! me.is_vor_aquire and ! me.is_vor_lock ) {
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
  if ( me.is_autopilot_engaged ) {
  me.discvertical();
  me.display('altitude-display', 'PH');
  me.holdpitch();
  me.modepitch();
  }
}

Autopilot.apmachpitchexport = func {
  if ( me.is_autopilot_engaged ) {
  me.discvertical();
  me.display('altitude-display', 'MP');
  autothrottlesystem.holdmach();
  me.modemachpitch();
  }
}

Autopilot.apmaxclimbexport = func {
  if ( me.is_autopilot_engaged ) {
  me.discvertical();
  #To prevent the concorde from desending in max climb mode, I changed this to an aquire mode.
  #I cannot find information on what happens when the concorde is at 250knots and VMO is 380knots.
  #This stops the concorde from crashing into the ground while not near VMO.
  #Max climb is just a fancy way of saying, "speed-with-pitch-trim" with speed set at VMO.

  var current_airspeed = me.dependency['airspeed'][0].getChild('indicated-speed-kt').getValue();
  var max_airspeed = me.dependency['airspeed'][0].getChild('vmo-kt').getValue();
  autothrottlesystem.atdiscspeed();
  autothrottlesystem.atengage();
  if ( current_airspeed > (max_airspeed - 10) ) {
    me.modemaxclimb();
  } else {
    me.is_max_climb_aquire = 1;
    me.setverticalspeed(0);
    me.modeverticalspeed();
  }
  me.display('altitude-display', 'CL');
  autothrottlesystem.display('speed-display', '');
  }
}

Autopilot.apspeedpitchexport = func {
  if ( me.is_autopilot_engaged ) {
  me.discvertical();
  me.display('altitude-display', 'IP');
  autothrottlesystem.holdspeed();
  me.modespeedpitch();
  }
}

Autopilot.apaltitudeholdexport = func {
  if ( me.is_autopilot_engaged ) {
  me.discvertical();
  me.is_holding_altitude = 1;
  me.display('altitude-display', 'AH');
  me.holdaltitude();
  me.modealtitudehold();
  }
}

Autopilot.aplandexport = func {
  if ( me.is_autopilot_engaged ) {
    if ( ! me.is_land_aquire and ! me.is_landing ) {
      if ( me.is_vor_aquire or me.is_vor_lock ) {
        if ( !me.is_gs_aquire and !me.is_gs_lock ) {
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
  if ( me.is_autopilot_engaged ) {
  if ( ! me.is_gs_aquire and ! me.is_gs_lock ) {
    if ( !me.is_vor_aquire and !me.is_vor_lock ) {
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
  if ( me.is_autopilot_engaged ) {
    if ( me.is_altitude_aquire ) {
      me.discvertical();
    } else {
      me.discvertical();
      me.is_altitude_aquire = 1;
    }
  me.display('altitude-display', 'VS');
  me.holdverticalspeed();
  me.modeverticalspeed();
  }
}

Autopilot.apaltitudeexport = func {
  if ( me.is_autopilot_engaged ) {
  if ( ! me.is_altitude_aquire and ! me.is_altitude_aquiring ) {
  me.is_holding_altitude = 0;
  me.is_altitude_aquire = 1;
  me.display('altitude-aquire', 1);
  var target_ft = me.itself['autoflight'].getChild('altitude-select').getValue();
  me.setaltitude(target_ft);
  var target_min_ft = target_ft - me.TARGETFT;
  var target_max_ft = target_ft + me.TARGETFT;
  var light_min_ft = target_ft - me.ALTIMETERFT;
  var light_max_ft = target_ft + me.ALTIMETERFT;
  me.itself['altimeter'].getChild('target-min-ft').setValue(target_min_ft);
  me.itself['altimeter'].getChild('target-max-ft').setValue(target_max_ft);
  me.itself['altimeter'].getChild('light-min-ft').setValue(light_min_ft);
  me.itself['altimeter'].getChild('light-max-ft').setValue(light_max_ft);
  } elsif ( ! me.is_altitude_aquiring ) {
    me.is_altitude_aquire = 0;
    me.display('altitude-aquire', 0);
  }
  }
}

Autopilot.schedule = func {
  if ( me.is_autopilot_engaged ) {
  #Engage max when faster than VMO. Stops concorde from desending in climb mode (which is weird).
    if ( me.is_max_climb_aquire ) {
    var current_airspeed = me.dependency['airspeed'][0].getChild('indicated-speed-kt').getValue();
    var max_airspeed = me.dependency['airspeed'][0].getChild('vmo-kt').getValue();
    if ( current_airspeed > ( max_airspeed - 20 )) {
      me.modemaxclimb();
    }
  }

  #Max cruise, Not completely sure on this mode, But I feel like it should be mach-with-throttle and vertical-speed-hold set at 50fpm.
  if ( autothrottlesystem.is_max_climb ) {
  var current_mach = me.dependency['mach'][0].getChild('indicated-mach').getValue();
  var current_ft = me.dependency['altimeter'][0].getChild('indicated-altitude-ft').getValue();
    if (( current_ft > me.MAXCRUISEFT ) or ( current_mach > me.MAXCRUISEMACH )) {
      me.modemaxcruise();
    }
  }

  #Max cruise, Not completely sure on this mode, But I feel like it should be mach-with-throttle and vertical-speed-hold set at 50fpm.
  if ( me.is_max_cruise ) {
  var current_mach = me.dependency['mach'][0].getChild('indicated-mach').getValue();
  var current_ft = me.dependency['altimeter'][0].getChild('indicated-altitude-ft').getValue();
    if (( current_ft < me.MAXCRUISEFT ) and ( current_mach < me.MAXCRUISEMACH )) {
      me.modemaxclimb();
    }  
  }
  
  if ( me.is_altitude_aquire ) {
    var current_ft = me.dependency['altimeter'][0].getChild('indicated-altitude-ft').getValue();
    var target_ft = me.itself['autoflight'].getChild('altitude-select').getValue();
    var target_min_ft = me.itself['altimeter'].getChild('target-min-ft').getValue();
    var target_max_ft = me.itself['altimeter'].getChild('target-max-ft').getValue();
    var light_min_ft = me.itself['altimeter'].getChild('light-min-ft').getValue();
    var light_max_ft = me.itself['altimeter'].getChild('light-max-ft').getValue();
    if ( current_ft < target_max_ft and current_ft > target_min_ft and ! me.is_altitude_aquiring ) {
      me.discvertical();
      me.is_altitude_aquire = 1;
      me.is_altitude_aquiring = 1;
      me.modealtitudehold();
      me.display('altitude-aquire', 0);
      me.display('altitude-display', 'AA');
      me.apengage();
    }
    if ( current_ft < light_max_ft and current_ft > light_min_ft and me.is_altitude_aquiring ) {
      me.is_altitude_aquiring = 0;
      me.is_altitude_aquire = 0;
      me.is_holding_altitude = 1;
      me.display('altitude-display', 'AH');
    }
  }
  if ( me.is_vor_aquire ) {
    var vor_in_range = me.dependency['nav'][0].getChild('in-range').getBoolValue();
    var vor_signal = me.dependency['nav'][0].getChild('signal-quality-norm').getValue();
    if ( vor_in_range and vor_signal > 0.9 ) {
      me.modevorlock();
      me.display('vor-aquire', 0);
      me.display('heading-display', 'VL');
      me.is_vor_aquire = 0;
      me.is_vor_lock = 1;
      me.apengage();
    }
  }
  if ( me.is_vor_lock and me.is_gs_aquire ) {
    var gs_in_range = me.dependency['nav'][0].getChild('gs-in-range').getBoolValue();
    if ( gs_in_range ) {
      me.discvertical();
      me.modeglidescope();
      me.display('gs-aquire', 0);
      me.display('altitude-display', 'GL');
      me.is_gs_lock = 1;
      me.is_gs_aquire = 0;
      me.apengage();
     }
  }

  if ( me.is_land_aquire and me.is_vor_lock and me.is_gs_lock ) {
    var current_ft = me.dependency['radio-altimeter'][0].getChild('indicated-altitude-ft').getValue();
    if ( current_ft < me.AUTOLANDFT ) {
      me.is_land_aquire = 0;
      me.is_landing = 1;
      me.landing_stage = 1;
      me.display('heading-display', '');
      me.display('altitude-display', '');
      me.display('land-aquire', 0);
      me.display('land-display', 1);
      autothrottlesystem.display('speed-display', '');
      var current_weight = me.dependency["weight"].getChild("weight-lb").getValue();
      #Vref is a little too slow, it sometimes makes the next stage pitch down to 7.5 degrees.
      #var vref = Constantaero.Vrefkt( current_weight ) + 10;
      vref = 180;
      autothrottlesystem.speed(vref);
    }
  }

  if ( me.is_landing ) {
    me.modeland();
  }
  }
  me.configurepidsettings();
}
