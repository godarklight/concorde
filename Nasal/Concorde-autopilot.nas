#This was completely scrapped and re-written. Started 13-May-2013.

# =========
# AUTOPILOT
# =========

#===AUTOPILOT STARTUP/INIT===#

Autopilot = {};

Autopilot.new = func {
   var obj = { parents : [Autopilot,System],

               autothrottlesystem : nil,

               VLGSAQUIREDEFLECTION : 1,                      # When to engage VL and GL modes (degrees difference)
               TARGETFT : 1200.0,                             # When to engage AA mode from VS (altitude aquire light comes on)
               ALTIMETERFT : 50.0,                            # When the altitude aquire light goes out

               TOUCHFPM : -300.0,                             # autoland vertical speed
               AUTOLANDFT : 1500.0,                           # altitude for LA mode
               LANDINGFT : 800.0,                             # Adjusts to the landing pitch
               PITCHFT : 500.0,                               # Reaches the landing pitch
               LANDINGDEG : 7.5,                              # Landing pitch
               FLAREFT : 80.0,                                # Leaves glide slope
               WPTNM : 4.0,                                   # Distance to swap to next waypoint
               VORNM : 3.0,                                   # Distance to inhibate VOR
               GOAROUNDDEG : 15.0,                            # Pitch on go-around
               LANDINGSEC : 3,                                # How long it takes to pitch down after landing
         };

# autopilot initialization
   obj.init();
   return obj;
};

Autopilot.init = func {
   me.inherit_system("/systems/autopilot");
   me.channelengage = {0:0, 1:0};
   me.reinitexport();
   me.apdiscexport();
}

Autopilot.reinitexport = func {
   #NAV 0 is reserved for autopilot
   #On startup, copy NAV1 to co-pilots NAV2, then copy NAV0 to pilots NAV1
   me.sendnav( 1, 2 );
   me.sendnav( 0, 1 );
}

Autopilot.display = func(vartype, varvalue) {
  if ( vartype == "altitude" ) {
    me.itself["autoflight"].getChild("altitude-display").setValue(varvalue);
  }
  if ( vartype == "heading" ) {
    me.itself["autoflight"].getChild("heading-display").setValue(varvalue);
  }
  if ( vartype == "landing" ) {
    me.itself["autoflight"].getChild("land-display").setValue(varvalue);
  }
  if ( vartype == "altitude-aquire" ) {
    me.itself["autoflight"].getChild("altitude-aquire").setValue(varvalue);
  }
  if ( vartype == "land-aquire" ) {
    me.itself["autoflight"].getChild("land-aquire").setValue(varvalue);
  }
  if ( vartype == "vor-aquire" ) {
    me.itself["autoflight"].getChild("vor-aquire").setValue(varvalue);
  }
  if ( vartype == "gs-aquire" ) {
    me.itself["autoflight"].getChild("gs-aquire").setValue(varvalue);
  }
}

#===AUTOPILOT DISCONNECT===#

Autopilot.apdiscexport = func {
  me.apdischeading();
  me.apdiscvertical();
  me.discaquire();
  me.apdisclandmode();
}

Autopilot.discaquire = func {
  me.is_vor_aquire = 0;
  me.is_land_aquire = 0;
  me.is_gs_aquire = 0;
  me.is_altitude_aquire = 0;
  me.display("vor-aquire", 0);
  me.display("land-aquire", 0);
  me.display("gs-aquire", 0);
  me.display("altitude-aquire", 0);
}

Autopilot.apdiscroutemanager = func {
  me.itself['settings'].getChild("gps-driving-true-heading").setValue(0);
}

Autopilot.apdisclandmode = func {
  me.is_land_aquire = 0;
  me.is_landing = 0;
  me.display("land-aquire", 0);
}

Autopilot.apdischeading = func {
  me.is_holding_heading = 0;
  me.is_holding_altitude = 0;
  me.is_vor_lock = 0;
  me.itself["autoflight"].getChild("heading-display").setValue('');
  me.itself["autoflight"].getChild("vor-aquire").setValue(0);
  me.apdiscroutemanager();
  me.itself["locks"].getChild("heading").setValue("");
}

Autopilot.apdiscvertical = func {
  me.is_gs_lock = 0;
  me.is_altitude_aquire = 0;
  me.is_altitude_aquiring = 0;
  me.is_max_climb = 0;
  me.is_max_cruise = 0;
  me.itself["autoflight"].getChild("altitude-display").setValue('');
  me.itself["autoflight"].getChild("altitude-aquire").setValue(0);
  me.itself["autoflight"].getChild("gs-aquire").setValue(0);
  me.itself["locks"].getChild("altitude").setValue("");
}

#===NAV COPY===#

Autopilot.sendnav = func( index, target ) {
   #Copys navigation[index] to nav[target]
   var freqmhz = 0.0;
   var radialdeg = 0.0;
   freqmhz = getprop("/instrumentation/nav[" ~ index ~ "]/frequencies/selected-mhz");
   setprop("/instrumentation/nav[" ~ target ~ "]/frequencies/selected-mhz",freqmhz);
   freqmhz = getprop("/instrumentation/nav[" ~ index ~ "]/frequencies/standby-mhz");
   setprop("/instrumentation/nav[" ~ target ~ "]/frequencies/standby-mhz",freqmhz);
   radialdeg = getprop("/instrumentation/nav[" ~ index ~ "]/radials/selected-deg");
   setprop("/instrumentation/nav[" ~ target ~ "]/radials/selected-deg",radialdeg);
}

#===ALTIMETER LIGHT===#

Autopilot.altimeterlight = func {
      var altsetting = me.itself["autoflight"].getChild("altitude-select").getValue();
      me.itself["altimeter"].getChild("light-min-ft").setValue(altsetting - me.ALTIMETERFT);
      me.itself["altimeter"].getChild("light-max-ft").setValue(altsetting - me.ALTIMETERFT);
}

#===AUTOPILOT CONNECT===#


Autopilot.setstartuphold = func {
  if ( me.itself["autoflight"].getChild("heading").getValue() == "" ) {
    me.display("heading", "HH");
    me.holdmagnetic();
    me.modemagneticheading();
  }
  if ( me.itself["autoflight"].getChild("altitude").getValue() == "" ) {
    me.display("altitude", "PH");
    me.holdpitch();
    me.modepitch();
  }
}

Autopilot.apchannel = func {
  var is_ap1_engaged = me.itself["channel"][0].getChild("engage").getValue();
  var is_ap2_engaged = me.itself["channel"][1].getChild("engage").getValue();
  #Stop both autopilots from being activated at the same time unless in autoland mode
  
  if ( is_ap1_engaged == 1 and me.channelengage[1] == 1 ) {
    me.itself["channel"][0].getChild("engage").setValue(0);
  } else {
    me.channelengage[0] = is_ap1_engaged;
  }
  if ( is_ap2_engaged == 1 and me.channelengage[0] == 1 ) {
    me.itself["channel"][1].getChild("engage").setValue(0);
  } else {
    me.channelengage[1] = is_ap2_engaged;
  }
}

#===AUTPILOT LOCK SETTING===#

Autopilot.apengage = func {
  if ( me.channelengage[0] == 0 and me.channelengage[1] == 0 ) {
    me.apdiscexport();
  }

  if ( me.channelengage[0] == 1 or me.channelengage[1] == 1 ) {
    me.itself["locks"].getChild("heading").setValue(me.itself["autoflight"].getChild("heading").getValue());
    me.itself["locks"].getChild("altitude").setValue(me.itself["autoflight"].getChild("altitude").getValue());
  }
}

#===AUTOPILOT MODES===#

#---ROLL---#
Autopilot.modewinglevel = func {
  me.itself["autoflight"].getChild("heading").setValue("wing-leveler");
  me.apengage();
}

Autopilot.modemagneticheading = func {
  me.itself["autoflight"].getChild("heading").setValue("dg-heading-hold");
  me.apengage();
}

Autopilot.modetrueheading = func {
  me.itself["autoflight"].getChild("heading").setValue("true-heading-hold");
  me.apengage();
}

Autopilot.modevorlock = func {
  me.itself["autoflight"].getChild("heading").setValue("nav1-hold");
  me.apengage();
}

#---PITCH---#

Autopilot.modeturbulence = func {
  me.apdischeading();
  me.apdiscvertical();
  me.apdisclandmode();
  me.holdmagnetic();
  me.modemagneticheading();
  me.holdpitch();
  me.modepitch();
  me.apengage();
}

Autopilot.modepitch = func {
  me.itself["autoflight"].getChild("altitude").setValue("pitch-hold");
  me.apengage();
}

Autopilot.modeverticalspeed = func {
  me.itself["autoflight"].getChild("altitude").setValue("vertical-speed-hold");
  me.apengage();
}

Autopilot.modealtitudehold = func {
  me.itself["autoflight"].getChild("altitude").setValue("altitude-hold");
  me.apengage();
}

Autopilot.modeglidescope = func {
  me.itself["autoflight"].getChild("altitude").setValue("gs1-hold");
  me.apengage();
}

Autopilot.modespeedpitch = func {
  me.itself["autoflight"].getChild("altitude").setValue("speed-with-pitch-changes");
  me.apengage();
}

Autopilot.modemachpitch = func {
  me.itself["autoflight"].getChild("altitude").setValue("mach-with-pitch-changes");
  me.apengage();
}

#===AUTOPILOT LANDING MODE===#

Autopilot.modeland = func {
  me.is_land_aquire = 1;
}

#===AUTOPILOT MODE SETTINGS===#

#---ROLL---#

Autopilot.setmagnetic = func(magnetic) {
  me.itself["settings"].getChild("heading-bug-deg").setValue(magnetic);
}

Autopilot.holdmagnetic = func {
  me.itself["settings"].getChild("heading-bug-deg").setValue(me.noinstrument["magnetic"].getValue());
}

Autopilot.settrue = func(trueheadingdeg) {
  me.itself["settings"].getChild("true-heading-deg").setValue(trueheadingdeg);
}

#---PITCH---#
Autopilot.setpitch = func(varpitch) {
  me.itself["settings"].getChild("target-pitch-deg").setValue(varpitch);
}

Autopilot.holdpitch = func {
  me.itself["settings"].getChild("target-pitch-deg").setValue(me.noinstrument["pitch"].getValue());
}

Autopilot.setverticalspeed = func(verticalspeed) {
  me.itself["settings"].getChild("vertical-speed-fpm").setValue(verticalspeed);
}

Autopilot.holdverticalspeed = func {
  var verticalspeed = me.dependency["ivsi"][0].getChild("indicated-speed-fps").getValue();
  verticalspeed = verticalspeed * 60;
  me.itself["settings"].getChild("vertical-speed-fpm").setValue(verticalspeed);
}

Autopilot.setaltitude = func(altitude) {
  me.itself["settings"].getChild("target-altitude-ft").setValue(altitude);
}

Autopilot.holdaltitude = func {
  me.itself["settings"].getChild("target-altitude-ft").setValue(me.dependency["altimeter"][0].getChild("indicated-altitude-ft").getValue());
}

#===AUTOPILOT EXPORTS===#

Autopilot.apexport = func {
  me.apchannel();
  me.setstartuphold();
  me.apengage();
}

Autopilot.apinsexport = func {
  if ( me.itself['route-manager'].getChild("active").getValue() == 1 ) {
    me.apdischeading();
    me.itself['settings'].getChild("gps-driving-true-heading").setValue(1);
    me.modetrueheading();
    me.display("heading", "IN");
  }
}

Autopilot.apsendheadingexport = func {
  if ( ! me.is_holding_heading ) {
    if ( me.channelengage[0] ) {
      me.settrue(me.itself["channel"][0].getChild("heading-select").getValue());
      me.setmagnetic(me.itself["channel"][0].getChild("heading-true-select").getValue());
    }
    if ( me.channelengage[1] ) {
      me.settrue(me.itself["channel"][1].getChild("heading-select").getValue());
      me.setmagnetic(me.itself["channel"][1].getChild("heading-true-select").getValue());
    }
  }
}

Autopilot.apheadingexport = func {
  me.apdischeading();
  me.apsendheadingexport();
  me.display("heading", "TH");
  if ( me.channelengage[0] ) {
    if ( me.itself["channel"][0].getChild("track-push").getValue() ) {
      me.modetrueheading();
    } else {
      me.modemagneticheading();
    }
  }
  if ( me.channelengage[1] ) {
    if ( me.itself["channel"][1].getChild("track-push").getValue() ) {
      me.modetrueheading();
    } else {
      me.modemagneticheading();
    }
  }
}

Autopilot.apheadingholdexport = func {
  me.apdischeading();
  me.is_holding_heading = 1;
  me.display("heading", "HH");
  me.holdmagnetic();
  me.modemagneticheading();
}

Autopilot.apturbulenceexport = func {
  me.apdischeading();
  me.apdiscvertical();
  me.display("heading", "TU");
  me.modeturbulence();
}

Autopilot.apvorlocexport = func {
  if ( ! me.is_vor_aquire and ! me.is_vor_lock ) {
    me.is_vor_aquire = 1;
    me.display("vor-aquire", 1);
  } else {
    if ( ! me.is_land_aquire and ! me.is_landing and ! me.is_gs_aquire and ! me.is_gs_lock ) {
      me.is_vor_aquire = 0;
      me.display("vor-aquire", 0);
    }
  }
}

Autopilot.appitchexport = func {
  me.apdiscvertical();
  me.display("altitude", "PH");
  me.holdpitch();
  me.modepitch();
}

Autopilot.apmachpitchexport = func {
  me.apdiscvertical();
  me.display("altitude", "MP");
  me.modemachpitch();
}

Autopilot.apmaxclimbexport = func {
  me.apdiscvertical();
  me.is_max_climb = 1;
  me.display("altitude", "CL");
  me.modemaxclimb();
}

Autopilot.apspeedpitchexport = func {
  me.apdiscvertical();
  me.display("altitude", "IP");
  me.modespeedpitch();
}

Autopilot.apaltitudeholdexport = func {
  me.apdiscvertical();
  me.is_holding_altitude = 1;
  me.display("altitude", "AH");
  me.holdaltitude();
  me.modealtitudehold();
}

Autopilot.aplandexport = func {
    if ( ! me.is_land_aquire and ! me.is_landing ) {
      if ( me.is_vor_aquire or me.is_vor_lock ) {
        if ( !me.is_gs_aquire or me.is_gs_lock ) {
          me.is_gs_aquire = 1;
          me.display("gs-aquire", 1);
        }
        me.is_land_aquire = 1;
        me.display("land-aquire", 1);
      }
  } else {
    me.is_land_aquire = 0;
    me.display("land-aquire", 0);
  }
}

Autopilot.apglideexport = func {
  if ( ! me.is_gs_aquire and ! me.is_gs_lock ) {
    if ( !me.is_gs_aquire or me.is_gs_lock ) {
      me.is_vor_aquire = 1;
      me.display("vor-aquire", 1);
    }
    me.is_gs_aquire = 1;
    me.display("gs-aquire", 1);
  } else {
    if ( ! me.is_land_aquire and ! me.is_landing ) {
      me.is_gs_aquire = 0;
      me.display("gs-aquire", 0);
    }
  }
}

Autopilot.apverticalexport = func {
  me.apdiscvertical();
  me.display("altitude", "VS");
  me.holdverticalspeed();
  me.modeverticalspeed();
}

Autopilot.apaltitudeexport = func {
  if ( ! me.is_altitude_aquire and ! me.is_altitude_aquiring ) {
  me.is_holding_altitude = 0;
  me.is_altitude_aquire = 1;
  me.display("altitude-aquire", 1);
  var target_ft = me.itself["autoflight"].getChild("altitude-select").getValue();
  var target_min_ft = target_ft - me.TARGETFT;
  var target_max_ft = target_ft + me.TARGETFT;
  var light_min_ft = target_ft - me.ALTIMETERFT;
  var light_max_ft = target_ft + me.ALTIMETERFT;
  me.itself["altimeter"].getChild("target-min-ft").setValue(target_min_ft);
  me.itself["altimeter"].getChild("target-max-ft").setValue(target_max_ft);
  me.itself["altimeter"].getChild("light-min-ft").setValue(light_min_ft);
  me.itself["altimeter"].getChild("light-max-ft").setValue(light_max_ft);
  } else if ( ! me.is_altitude_aquiring ) {
    me.is_altitude_aquire = 0;
    me.display("altitude-aquire", 0);
  }
}

Autopilot.schedule = func {
  if ( me.is_max_climb ) {
    #me.autothrottlesystem.setspeed(me.noinstrument);
  }
  if ( me.is_altitude_aquire ) {
    var current_ft = me.dependency["altimeter"][0].getChild("indicated-altitude-ft").getValue();
    var target_ft = me.itself["autoflight"].getChild("altitude-select").getValue();
    var target_min_ft = me.itself["altimeter"].getChild("target-min-ft").getValue();
    var target_max_ft = me.itself["altimeter"].getChild("target-max-ft").getValue();
    var light_min_ft = me.itself["altimeter"].getChild("light-min-ft").getValue();
    var light_max_ft = me.itself["altimeter"].getChild("light-max-ft").getValue();
    if ( current_ft < target_max_ft and current_ft > target_min_ft and ! me.is_altitude_aquiring ) {
      me.apdiscvertical();
      me.is_altitude_aquire = 1;
      me.is_altitude_aquiring = 1;
      me.modealtitudehold();
      me.display("altitude-aquire", 0);
      me.display("altitude", "AA");
      me.apengage();
    }
    if ( current_ft < light_max_ft and current_ft > light_min_ft and me.is_altitude_aquiring ) {
      me.is_altitude_aquiring = 0;
      me.is_altitude_aquire = 0;
      me.is_holding_altitude = 1;
      me.display("altitude", "AH");
    }
  }
  if ( me.is_vor_aquire ) {
    var vor_in_range = me.dependency["nav"][0].getChild("in-range").getBoolValue();
    if ( vor_in_range ) {
      var current_needle_diff = me.dependency["nav"][0].getChild("heading-needle-deflection").getValue();
      var min_needle_diff = 0 - me.VLGSAQUIREDEFLECTION;
      var max_needle_diff = me.VLGSAQUIREDEFLECTION;
      if ( current_needle_diff > min_needle_diff and current_needle_diff < max_needle_diff ) {
        me.apdischeading();
        me.modevorlock();
        me.display("vor-aquire", 0);
        me.display("heading", "VL");
        me.is_vor_lock = 1;
        me.apengage();
      }
    }
  }
  if ( me.is_vor_lock and me.is_gs_aquire ) {
    var gs_in_range = me.dependency["nav"][0].getChild("gs-in-range").getBoolValue();
    if ( gs_in_range ) {
      var current_needle_diff = me.dependency["nav"][0].getChild("gs-needle-deflection").getValue();
      var min_needle_diff = current_needle_diff - me.VLGSAQUIREDEFLECTION;
      var max_needle_diff = current_needle_diff + me.VLGSAQUIREDEFLECTION;
      if ( current_needle_diff > min_needle_diff and current_needle_diff < max_needle_diff ) {
        me.apdiscvertical();
        me.modeglidescope();
        me.display("gs-aquire", 0);
        me.display("altitude", "GL");
        me.is_gs_lock = 1;
        me.apengage();
      }
    }
  }
}