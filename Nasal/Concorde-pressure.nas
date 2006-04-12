# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ==============
# PRESSURIZATION
# ==============

Pressurization = {};

Pressurization.new = func {
   obj = { parents : [Pressurization],

           electricalsystem : nil,
           airbleedsystem : nil,

           diffpressureinstrument : Differentialpressure.new(),
#           cabininstrument : Cabinaltitude.new(),

           PRESSURIZEMBARPM : 18.0,                   # human physiology tolerates 18 mbar per minute until 8000 ft.
           PRESSURIZEINHGPM : 0.0,                    # 18 mbar/minute = 0.53 inhg/minute
           PRESSURIZESEC : 5.0,                       # sampling
           PRESSURIZEMBAR : 0.0,
           PRESSURIZEINHG : 0.0,
           PRESSURIZEFTPM : 0.0,                      # max descent speed around 6000 feet/minute.
           PRESSURIZEMININHG : 22.25,                 # 8000 ft (standard atmosphere)
           PRESSURIZEMAXFT : 8000.0,
           aglft : 0.0,                               # ISA default
           altseaft : 0.0,
           seainhg : 29.92,
           pressureinhg : 29.92,
           cabininhg : 29.92,
           targetinhg : 29.92,
           outflowinhg : 0.0,
           pressurenode : nil,
           staticport : "",

# slaves
           slave : [ nil, nil ],
           altimeter : 0,
           radioaltimeter : 1
         };

   obj.init();

   return obj;
};

Pressurization.init = func {
    propname = getprop("/systems/pressurization/slave/altimeter");
    me.slave[me.altimeter] = props.globals.getNode(propname);
    propname = getprop("/systems/pressurization/slave/radio-altimeter");
    me.slave[me.radioaltimeter] = props.globals.getNode(propname);

    me.PRESSURIZEINHGPM = me.PRESSURIZEMBARPM * constant.MBARTOINHG;
    me.PRESSURIZEMBAR = me.PRESSURIZEMBARPM / ( constant.MINUTETOSECOND / me.PRESSURIZESEC );
    me.PRESSURIZEINHG = me.PRESSURIZEMBAR * constant.MBARTOINHG;
    me.PRESSURIZEFTPM = 7000.0 / ( constant.MINUTETOSECOND / me.PRESSURIZESEC );

    me.pressurenode = props.globals.getNode("/systems/pressurization");

    me.staticport = getprop("/systems/pressurization/static-port");
    me.staticport = me.staticport ~ "/pressure-inhg";

    me.diffpressureinstrument.set_rate( me.PRESSURIZESEC );
}

Pressurization.set_relation = func( airbleed, electrical ) {
   me.airbleedsystem = airbleed;
   me.electricalsystem = electrical;
}

# leak when no pressurization
Pressurization.cabinleak = func {
   # ignored !
}

Pressurization.last = func {
    me.aglft = me.slave[me.radioaltimeter].getChild("indicated-altitude-ft").getValue();
    me.altseaft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
    me.seainhg = noinstrument.get_sea_inhg();              # avoids lengthy computations
    me.pressureinhg = getprop(me.staticport);
#    me.cabininhg = getprop("/instrumentation/cabin-altitude/cabin-inhg");
    me.cabininhg = me.pressurenode.getChild("pressure-inhg").getValue();

    # filters startup
    if( me.aglft == nil or me.altseaft == nil or me.seainhg == nil or me.pressureinhg == nil ) {
        me.aglft = 0.0;
        me.altseaft = 0.0;
        me.seainhg = 29.92;
        me.pressureinhg = 29.92;

        me.targetinhg = 29.92;
        me.outflowinhg = 0.0;

        startup = "true";
     }
     else {
        startup = "false";
     }

     return startup;
}

# pressurization curve has a lower slope than aircraft descent/climb profile
Pressurization.curve = func {
     speedup = getprop("/sim/speed-up");

     # pressure is slightly lower than ground, because cabin is on the gears !

     if( me.aglft > 2500.0 ) {
         # average vertical speed of 2000 feet/minute
         minutes = me.altseaft / 2000.0;
         minutes = minutes * speedup;
         me.targetinhg = me.seainhg - minutes * me.PRESSURIZEINHGPM;
         if( me.targetinhg < me.PRESSURIZEMININHG ) {
             me.targetinhg = me.PRESSURIZEMININHG;
         }
     }

     # radio altimeter works below 2500 feet
     else {
         # average landing speed of 1500 feet/minute
         minutes = ( me.altseaft - me.aglft ) / 1500.0;
         minutes = minutes * speedup;
         me.targetinhg = me.seainhg - minutes * me.PRESSURIZEINHGPM;
         if( me.targetinhg < me.PRESSURIZEMININHG ) {
             me.targetinhg = me.PRESSURIZEMININHG;
         }
     }
}

Pressurization.real = func {
      me.outflowinhg = me.targetinhg - me.cabininhg;
      if( me.cabininhg < me.targetinhg ) {
          if( me.outflowinhg > me.PRESSURIZEINHG ) {
              me.outflowinhg = me.PRESSURIZEINHG;
          }
          me.cabininhg = me.cabininhg + me.outflowinhg;
      }
      elsif( me.cabininhg > me.targetinhg ) {
          if( me.outflowinhg < -me.PRESSURIZEINHG ) {
              me.outflowinhg = -me.PRESSURIZEINHG;
          }
          me.cabininhg = me.cabininhg + me.outflowinhg;
      }
      # balance
      else {
          me.outflowinhg = 0;
          me.cabininhg = me.targetinhg;
      }
}

Pressurization.interpolation = func {
      # one supposes instrument calibrated by standard atmosphere
      if( me.outflowinhg != 0 or me.cabininhg > me.PRESSURIZEMININHG ) {
          interpol = "true";
      }

      # above 8000 ft
      else {
          interpol = "false";
      }

      return interpol;
}

# relocation in flight
Pressurization.relocation = func( interpol ) {
      lastaltft = me.pressurenode.getChild("altitude-sea-ft").getValue();

      variationftpm = lastaltft - me.altseaft;
      if( variationftpm < -me.PRESSURIZEFTPM or variationftpm > me.PRESSURIZEFTPM ) {
           me.outflowinhg = 0.0;
           me.cabininhg = me.targetinhg;
           interpol = "true";        
      }
      # relocation on ground (change of airport)
      elsif( me.aglft < constantaero.AGLTOUCHFT ) {
           me.outflowinhg = 0.0;
           me.targetinhg = me.pressureinhg;
           me.cabininhg = me.targetinhg;
           interpol = "true";
      }

      return interpol;
}

Pressurization.apply = func( interpol ) {
      me.pressurenode.getChild("atmosphere-inhg").setValue(me.pressureinhg);
      me.pressurenode.getChild("target-inhg").setValue(me.targetinhg);
      me.pressurenode.getChild("outflow-inhg").setValue(me.outflowinhg);
      me.pressurenode.getChild("altitude-sea-ft").setValue(me.altseaft);

      if( interpol != "true" ) {
          me.cabininhg = me.PRESSURIZEMININHG;
      }

      result = me.pressurenode.getChild("pressure-inhg").getValue();
      if( result != me.cabininhg ) {
          interpolate("/systems/pressurization/pressure-inhg",me.cabininhg,me.PRESSURIZESEC);
      }
#       me.cabininstrument.schedule( me.cabininhg );        
}

# cabin altitude meter
Pressurization.schedule = func {
   if( me.electricalsystem.has_specific() ) {
       if( getprop("/systems/pressurization/serviceable") and me.airbleedsystem.has_pressure() ) {
           startup = me.last();

           # real modes
           if( startup == "false" ) {
               me.curve();
               me.real();
           }

           interpol = me.interpolation();

           # artificial modes
           if( startup == "false" ) {
               interpol = me.relocation( interpol );
           }

           me.apply( interpol );
       }

       # leaks
       else {
           me.cabinleak();
       }


       # instrumentation
       me.diffpressureinstrument.schedule();
   }
}


# ===============
# CABINE ALTITUDE
# ===============

Cabinaltitude = {};

Cabinaltitude.new = func {
   obj = { parents : [Cabinaltitude]
         };
   return obj;
};

# cabin altitude in feet, arguments
# - cabin pressure in inhg
Cabinaltitude.schedule = func( cabininhg ) {
   # optimization (cruise)
   if( cabininhg == pressuresystem.PRESSURIZEMININHG ) {
       cabinaltft = pressuresystem.PRESSURIZEMAXFT;
   }

   # one supposes instrument calibrated by standard atmosphere
   else {
       ratio = cabininhg / 29.92;

   # guess below sea level
       found = "true";
       if( ratio > 1.09 ) {
           found = "false";
       }
       elsif( ratio > 1.0 and ratio <= 1.09 ) {
           altmaxm = 0;
           altminm = -900;
           minfactor = 1.0;
           maxfactor = 1.09;
       }

       # standard atmosphere
       elsif( ratio > 0.898 and ratio <= 1.0 ) {
           altmaxm = 900;
           altminm = 0;
           minfactor = 0.898;
           maxfactor = 1.0;
       }
       elsif( ratio > 0.804 and ratio <= 0.898 ) {
           altmaxm = 1800;
           altminm = 900;
           minfactor = 0.804;
           maxfactor = 0.898;
       }
       elsif( ratio > 0.719 and ratio <= 0.804 ) {
           altmaxm = 2700;
           altminm = 1800;
           minfactor = 0.719;
           maxfactor = 0.804;
       }
       elsif( ratio > 0.641 and ratio <= 0.719 ) {
           altmaxm = 3600;
           altminm = 2700;
           minfactor = 0.641;
           maxfactor = 0.719;
       }
       elsif( ratio > 0.570 and ratio <= 0.641 ) {
           altmaxm = 4500;
           altminm = 3600;
           minfactor = 0.570;
           maxfactor = 0.641;
       }
       elsif( ratio > 0.506 and ratio <= 0.570 ) {
           altmaxm = 5400;
           altminm = 4500;
           minfactor = 0.506;
           maxfactor = 0.570;
       }
       elsif( ratio > 0.447 and ratio <= 0.506 ) {
           altmaxm = 6300;
           altminm = 5400;
           minfactor = 0.447;
           maxfactor = 0.506;
       }
       elsif( ratio > 0.394 and ratio <= 0.447 ) {
           altmaxm = 7200;
           altminm = 6300;
           minfactor = 0.394;
           maxfactor = 0.447;
       }
       elsif( ratio > 0.347 and ratio <= 0.394 ) {
           altmaxm = 8100;
           altminm = 7200;
           minfactor = 0.347;
           maxfactor = 0.394;
       }
       elsif( ratio > 0.304 and ratio <= 0.347 ) {
           altmaxm = 9000;
           altminm = 8100;
           minfactor = 0.304;
           maxfactor = 0.347;
       }
       elsif( ratio > 0.266 and ratio <= 0.304 ) {
           altmaxm = 9900;
           altminm = 9000;
           minfactor = 0.266;
           maxfactor = 0.304;
       }
       elsif( ratio > 0.231 and ratio <= 0.266 ) {
           altmaxm = 10800;
           altminm = 9900;
           minfactor = 0.231;
           maxfactor = 0.266;
       }
       elsif( ratio > 0.201 and ratio <= 0.231 ) {
           altmaxm = 11700;
           altminm = 10800;
           minfactor = 0.201;
           maxfactor = 0.231;
       }
       elsif( ratio > 0.174 and ratio <= 0.201 ) {
           altmaxm = 12600;
           altminm = 11700;
           minfactor = 0.174;
           maxfactor = 0.201;
       }
       elsif( ratio > 0.151 and ratio <= 0.174 ) {
           altmaxm = 13500;
           altminm = 12600;
           minfactor = 0.151;
           maxfactor = 0.174;
       }
       elsif( ratio > 0.131 and ratio <= 0.151 ) {
           altmaxm = 14400;
           altminm = 13500;
           minfactor = 0.131;
           maxfactor = 0.151;
       }
       elsif( ratio > 0.114 and ratio <= 0.131 ) {
           altmaxm = 15300;
           altminm = 14400;
           minfactor = 0.114;
           maxfactor = 0.131;
       }
       elsif( ratio > 0.099 and ratio <= 0.114 ) {
           altmaxm = 16200;
           altminm = 15300;
           minfactor = 0.099;
           maxfactor = 0.114;
       }
       elsif( ratio > 0.086 and ratio <= 0.099 ) {
           altmaxm = 17100;
           altminm = 16200;
           minfactor = 0.086;
           maxfactor = 0.099;
       }
       elsif( ratio > 0.075 and ratio <= 0.086 ) {
          altmaxm = 18000;
          altminm = 17100;
          minfactor = 0.075;
          maxfactor = 0.086;
       }
       elsif( ratio > 0.065 and ratio <= 0.075 ) {
           altmaxm = 18900;
           altminm = 18000;
           minfactor = 0.065;
           maxfactor = 0.075;
       }
       else {
           found = "false";
       }

       if( found == "true" ) {
           step = maxfactor - ratio;
           delta = maxfactor - minfactor;
           deltam = altmaxm - altminm;
           coeff = step / delta ;
           cabinaltm = altminm + deltam * coeff;
           cabinaltft = cabinaltm * constant.METERTOFEET;
       }
       # out of range
       else {
           cabininhg = 29.92;
           cabinaltft = 0;
       }
   }

   setprop("/instrumentation/cabin-altitude/cabin-inhg",cabininhg);
   setprop("/instrumentation/cabin-altitude/indicated-altitude-ft",cabinaltft);
}


# =====================
# DIFFERENTIAL PRESSURE
# =====================

Differentialpressure = {};

Differentialpressure.new = func {
   obj = { parents : [Differentialpressure],
           DIFFSEC : 5.0,
           staticport : ""                         # energy provided by differential pressure
         };

   obj.init();

   return obj;
};

Differentialpressure.init = func {
    me.staticport = getprop("/instrumentation/differential-pressure/static-port");
    me.staticport = me.staticport ~ "/pressure-inhg";
}

Differentialpressure.set_rate = func( rates ) {
    me.DIFFSEC = rates;
}

Differentialpressure.schedule = func {
#   cabininhg = getprop("/instrumentation/cabin-altitude/cabin-inhg");
   cabininhg = getprop("/systems/pressurization/pressure-inhg");
   pressureinhg = getprop(me.staticport);
   diffpsi = ( cabininhg - pressureinhg ) * constant.INHGTOPSI;

   result = getprop("/instrumentation/differential-pressure/differential-psi");
   if( result != diffpsi ) {
       interpolate("/instrumentation/differential-pressure/differential-psi",diffpsi,me.DIFFSEC);
   }
}


# =========
# AIR BLEED
# =========

Airbleed = {};

Airbleed.new = func {
   obj = { parents : [Airbleed],
           MAXPSI : 65.0,                             # maximum pressure
           GROUNDPSI : 35.0,                          # ground supply pressure
           AIRSEC : 1.0,                              # refresh rate
           engines : nil,
           valves : nil,
           bleeds : nil
         };

   obj.init();

   return obj;
};

Airbleed.init = func {
    me.engines = props.globals.getNode("/engines/").getChildren("engine");
    me.valves = props.globals.getNode("/controls/pneumatic/").getChildren("engine");
    me.bleeds = props.globals.getNode("/systems/air-bleed/").getChildren("engine");
}

Airbleed.set_rate = func( rates ) {
    me.AIRSEC = rates;
}

# adjacent engine
Airbleed.adjacent = func( engine ) {
    if( engine == 0 ) {
        result = 1;
    }
    elsif( engine == 1 ) {
        result = 0;
    }
    elsif( engine == 2 ) {
        result = 3;
    }
    elsif( engine == 3 ) {
        result = 2;
    }

    # should never happen
    else {
        result = 0;
    }

    return result;
}

# connection with delay by ground operator
Airbleed.slowschedule = func {
    aglft = noinstrument.get_agl_ft();
    speedkt = noinstrument.get_speed_kt();
    if( aglft >=  15 or speedkt >= 15 ) {

        # door stays open, has forgotten to call for disconnection !
        setprop("/systems/air-bleed/ground-service-psi",constant.FALSE);
    }
}

# detects loss of all engines
Airbleed.schedule = func {
   if( getprop("/systems/air-bleed/serviceable") ) {

       # ground supply
       groundpsi = getprop("/systems/air-bleed/ground-service-psi");

       # ===============================
       # bleed valve limits the pressure
       # ===============================
       for( i = 0; i < 4; i = i+1 ) {
            if( me.engines[i].getChild("running").getValue() and
                me.valves[i].getChild("bleed-valve").getValue() ) {
                pressurepsi = me.engines[i].getChild("n1").getValue();
                # maximum 65 PSI
                if( pressurepsi > me.MAXPSI ) {
                    pressurepsi = me.MAXPSI;
                }
                # minimum ground
                elsif( pressurepsi < me.GROUNDPSI ) {
                    pressurepsi = me.GROUNDPSI;
                }
            }
            else {
                pressurepsi = 0.0;
            }

            result = me.bleeds[i].getChild("bleed-psi").getValue();
            if( result != pressurepsi ) {
                interpolate("/systems/air-bleed/engine[" ~ i ~ "]/bleed-psi",pressurepsi,me.AIRSEC);
            }

            # ===========
            # cross bleed
            # ===========
            bleedpsi = pressurepsi;
            if( me.valves[i].getChild("cross-bleed-valve").getValue() and bleedpsi == 0.0 ) {
                pressurepsi = 0.0;
                # adjacent engine
                a = me.adjacent(i);
                if( me.valves[a].getChild("cross-bleed-valve").getValue() ) {
                    pressurepsi = me.bleeds[a].getChild("bleed-psi").getValue();
                }
                # ground supply
                if( pressurepsi == 0.0 ) {
                    pressurepsi = groundpsi;
                }
            }
            else {
                pressurepsi = bleedpsi;
            }

            result = me.bleeds[i].getChild("cross-psi").getValue();
            if( result != pressurepsi ) {
                interpolate("/systems/air-bleed/engine[" ~ i ~ "]/cross-psi",pressurepsi,me.AIRSEC);
            }

            # ==================
            # conditioning valve
            # ==================
            crosspsi = pressurepsi;
            if( me.valves[i].getChild("conditioning-valve").getValue() ) {
                pressurepsi = crosspsi;
            }
            else {
                pressurepsi = 0.0;
            }

            result = me.bleeds[i].getChild("conditioning-psi").getValue();
            if( result != pressurepsi ) {
                interpolate("/systems/air-bleed/engine[" ~ i ~ "]/conditioning-psi",pressurepsi,me.AIRSEC);
            }
       }

       # jet pump only when landing gear down
       if( getprop("/gear/gear[0]/position-norm") == 1.0 ) {
           for( i = 0; i < 4; i = i+1 ) {
                me.bleeds[i].getChild("jet-pump").setValue(constant.TRUE);
           }
       }
       else {
           for( i = 0; i < 4; i = i+1 ) {
                me.bleeds[i].getChild("jet-pump").setValue(constant.FALSE);
           }
       }

       # pressurization doesn't see the 4 distinct groups : will get the result after the interpolate
       pressurepsi = 0.0;
       for( i = 0; i < 4; i = i+1 ) {
            condpsi = me.bleeds[i].getChild("conditioning-psi").getValue();
            if( condpsi > pressurepsi ) {
                pressurepsi = condpsi;
            }
       }
    }
    else {
       pressurepsi = 0.0;
    }

    # for pressurization
    setprop("/systems/air-bleed/pressure-psi",pressurepsi);
}

Airbleed.has_pressure = func {
    if( getprop("/systems/air-bleed/pressure-psi") >= me.GROUNDPSI ) { 
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Airbleed.groundserviceexport = func {
    aglft = noinstrument.get_agl_ft();
    speedkt = noinstrument.get_speed_kt();

    if( aglft <  15 and speedkt < 15 ) {
        supply = getprop("/systems/air-bleed/ground-supply");
        if( supply ) {
            pressurepsi = 0.0;
            setprop("/systems/air-bleed/ground-supply",constant.FALSE);
        }
        else {
            pressurepsi = 35.0;
            setprop("/systems/air-bleed/ground-supply",constant.TRUE);
        }

        setprop("/systems/air-bleed/ground-service-psi",pressurepsi);
    }
}
