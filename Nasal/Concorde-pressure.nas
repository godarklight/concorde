# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ==============
# PRESSURIZATION
# ==============

Pressurization = {};

Pressurization.new = func {
   var obj = { parents : [Pressurization,System],

           diffpressure : Differentialpressure.new(),

           controls : nil,
           emergency : nil,
           engines : nil,
           internal : nil,
           pressurenode : nil,
           valves : nil,
           systems : nil,

           PRESSURIZESEC : 5.0,                       # sampling
           INERTIASEC : 1.2,                          # inertia of discharge valve

           speedup : 1.0,

           DEPRESSURIZEINHGPM : 10.0,                 # 10 inhg/minute (guess)
           LEAKINHGPM : 0.01,                         # 0.01 inhg/minute if no pressurization

           PRESSURIZEINHGPM : 0.0,                    # 18 mbar/minute = 0.53 inhg/minute

           MININHG : 19.82,                           # 11000 ft

           DEPRESSURIZEINHG : 0.0,
           LEAKINHG : 0.0,
           PRESSURIZEINHG : 0.0,                      # step
           PRESSURIZEMININHG : 0.0,                   # minimum pressure in cabine

           cabininhg : constantISA.SEA_inhg,
           DATUMINHG : constantISA.SEA_inhg,
           outflowinhg : 0.0,
           pressureinhg : constantISA.SEA_inhg,
           targetinhg : constantISA.SEA_inhg,

           THRUSTPSI : 7.0,
           THRUSTOFFPSI : 3.0,
           GROUNDPSI : 1.45,

           diffpsi : 0.0,

           UNDERPRESSUREFT : 10000.0,
           LANDINGFT : 2500.0,

           altseaft : 0.0,

           CLIMBFTPM : 2000.0,
           DESCENTFTPM : 1500.0,

           system_no : 0,

           VALVEOPEN : 100,
           VALVESHUT : 0,

           dischargevalve : [ [ 0.0, 0.0 ], [ 0.0, 0.0 ] ],

           RATIOAFT : 0.50,                             # aft discharge valve is 50 % of foward valve.

           ground : constant.TRUE,                      # ground relief valve

           staticport : ""
         };

   obj.init();

   return obj;
};

Pressurization.init = func {
    me.init_ancestor("/systems/pressurization");

    me.LEAKINHG = me.LEAKINHGPM / ( constant.MINUTETOSECOND / me.PRESSURIZESEC );
    me.DEPRESSURIZEINHG = me.DEPRESSURIZEINHGPM / ( constant.MINUTETOSECOND / me.PRESSURIZESEC );

    me.controls = props.globals.getNode("/controls/pressurization").getChildren("system");
    me.emergency = props.globals.getNode("/controls/pressurization/emergency");
    me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
    me.internal = props.globals.getNode("/systems/pressurization/internal");
    me.pressurenode = props.globals.getNode("/systems/pressurization");
    me.valves = props.globals.getNode("/systems/pressurization/valve");
    me.systems = props.globals.getNode("/systems/pressurization").getChildren("system");

    me.staticport = getprop("/systems/pressurization/static-pressure");

    me.altitudeselectorexport();
    me.initconstant();

    me.set_rate( me.PRESSURIZESEC );
}

Pressurization.set_rate = func( rates ) {
    me.PRESSURIZESEC = rates;

    me.set_rate_ancestor( me.PRESSURIZESEC );

    me.diffpressure.set_rate( me.PRESSURIZESEC );
}

Pressurization.red_pressure = func {
    var result = constant.FALSE;

    if( me.slave["altitude"].getChild("indicated-altitude-ft").getValue() >= me.UNDERPRESSUREFT ) {
        result = constant.TRUE;
    }
    else {
        result = me.diffpressure.red_pressure();
    }

    return result;
}

# engineer can change
Pressurization.altitudeselectorexport = func {
    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         me.initsystem( i );
    }
}

Pressurization.initsystem = func( index ) {
    var stepinhg = 0.0;
    var maxdiffft = 0.0;
    var altitudeft = me.systems[index].getChild("cabin-alt-ft").getValue();
    var pressurizemininhg = constantISA.pressure_inhg( altitudeft );
    var datuminhg = me.systems[index].getChild("datum-mbar").getValue() * constant.MBARTOINHG;
    var pressurizeinhgpm = me.systems[index].getChild("mbar-per-min").getValue() * constant.MBARTOINHG;

    me.systems[index].getChild("min-pressure-inhg").setValue(pressurizemininhg);

    me.systems[index].getChild("datum-inhg").setValue(datuminhg);

    me.systems[index].getChild("inhg-per-min").setValue(pressurizeinhgpm);

    stepinhg = datuminhg - pressurizemininhg;
    maxdiffft = ( stepinhg / pressurizeinhgpm ) * me.CLIMBFTPM;
    me.systems[index].getChild("max-diff-ft").setValue(maxdiffft);
}

Pressurization.initconstant = func {
    if( me.controls[0].getChild("select").getValue() ) {
        me.system_no = 0;
    }
    else {
        me.system_no = 1;
    }

    me.PRESSURIZEINHGPM = me.systems[me.system_no].getChild("inhg-per-min").getValue();
    me.DATUMINHG = me.systems[me.system_no].getChild("datum-inhg").getValue();
    me.PRESSURIZEMININHG = me.systems[me.system_no].getChild("min-pressure-inhg").getValue();

    me.PRESSURIZEINHG = me.PRESSURIZEINHGPM / ( constant.MINUTETOSECOND / me.PRESSURIZESEC );

    if( me.speedup > 1 ) {
        me.PRESSURIZEINHG = me.PRESSURIZEINHG * me.speedup;
    }
}

Pressurization.ground_relief = func {
    me.pressureinhg = getprop(me.staticport);
    me.cabininhg = me.pressurenode.getChild("pressure-inhg").getValue();
    
    me.diffpsi = ( me.cabininhg - me.pressureinhg ) * constant.INHGTOPSI;

    # opens ground relief valve if not takeoff
    me.ground = constant.FALSE;
    if( me.slave["weight"].getChild("wow").getValue() and
        me.engines[0].getChild("throttle" ).getValue() < constantaero.THROTTLEMAX and
        me.engines[1].getChild("throttle" ).getValue() < constantaero.THROTTLEMAX and
        me.engines[2].getChild("throttle" ).getValue() < constantaero.THROTTLEMAX and
        me.engines[3].getChild("throttle" ).getValue() < constantaero.THROTTLEMAX ) {
        if( me.valves.getChild("ground-auto").getValue() ) {
            if( me.diffpsi < me.GROUNDPSI ) {
                me.ground = constant.TRUE;
            }
        }
    }

    me.valves.getChild("ground-relief").setValue(me.ground);
}

Pressurization.thrust_recuperator = func {
    var thrust = constant.TRUE;
    var recuperator = constant.TRUE;

    if( me.diffpsi < me.THRUSTOFFPSI ) {
        thrust = constant.FALSE;
        recuperator = constant.FALSE;
    }
    elsif( me.diffpsi < me.THRUSTPSI ) {
        thrust = constant.FALSE;
        recuperator = constant.TRUE;
    }

    me.valves.getChild("thrust").setValue(thrust);
    me.valves.getChild("thrust-recuperator").setValue(recuperator);
}

Pressurization.flow = func( stepinhg, mininhg ) {
    var result = 0.0;

    me.pressureinhg = getprop(me.staticport);
    me.altseaft = constantISA.altitude_ft( me.pressureinhg, me.DATUMINHG );
    me.targetinhg = me.pressureinhg;
    me.cabininhg = me.pressurenode.getChild("pressure-inhg").getValue();
    result = me.cabininhg;

    if( me.targetinhg < mininhg ) {
        me.targetinhg = mininhg;
    }

    me.outflowinhg = me.cabininhg - me.targetinhg;
    me.outflowinhg = constant.clip( - stepinhg, stepinhg, me.outflowinhg );

    me.cabininhg = me.cabininhg - me.outflowinhg;

    me.apply( constant.TRUE );
}

Pressurization.depressurization = func {
    var stepinhg = me.DEPRESSURIZEINHG * me.speedup;

    # limited to 11000 ft
    me.flow( stepinhg, me.MININHG );
}

# leak when no pressurization
Pressurization.cabinleak = func {
    var stepinhg = me.LEAKINHG * me.speedup;

    # limited by outside pressure
    var mininhg = getprop(me.staticport);

    me.flow( stepinhg, mininhg );
}

Pressurization.last = func {
    var startup = constant.FALSE;


    me.pressureinhg = getprop(me.staticport);
    me.altseaft = constantISA.altitude_ft( me.pressureinhg, me.DATUMINHG );
    me.cabininhg = me.pressurenode.getChild("pressure-inhg").getValue();

    # filters startup
    if( me.altseaft == nil or me.pressureinhg == nil ) {
        me.altseaft = 0.0;
        me.pressureinhg = constantISA.SEA_inhg;

        me.targetinhg = constantISA.SEA_inhg;
        me.outflowinhg = 0.0;

        startup = constant.TRUE;
     }


     return startup;
}

# pressurization curve has a lower slope than aircraft descent/climb profile
Pressurization.curve = func {
     var minutes = 0.0;

     # average vertical speed of 2000 feet/minute
     if( me.altseaft > me.LANDINGFT ) {
         minutes = me.altseaft / me.CLIMBFTPM;
         minutes = minutes * me.speedup;
         me.targetinhg = me.DATUMINHG - minutes * me.PRESSURIZEINHGPM;
         if( me.targetinhg < me.PRESSURIZEMININHG ) {
             me.targetinhg = me.PRESSURIZEMININHG;
         }
     }

     # average landing speed of 1500 feet/minute
     else {
         minutes = me.altseaft / me.DESCENTFTPM;
         minutes = minutes * me.speedup;
         me.targetinhg = me.DATUMINHG - minutes * me.PRESSURIZEINHGPM;
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
      # above 8000 ft
      var interpol = constant.FALSE;

      # one supposes instrument calibrated by standard atmosphere
      if( me.outflowinhg != 0 or me.cabininhg > me.PRESSURIZEMININHG ) {
          interpol = constant.TRUE;
      }

      return interpol;
}

# relocation in flight
Pressurization.relocation = func( interpol ) {
      if( me.is_relocating() ) {
           me.outflowinhg = 0.0;
           me.cabininhg = me.targetinhg;
           interpol = constant.TRUE;        
      }

      # relocation on ground (change of airport)
      elsif( me.ground ) {
           me.outflowinhg = 0.0;
           me.targetinhg = me.pressureinhg;
           me.cabininhg = me.targetinhg;
           interpol = constant.TRUE;
      }

      # keep argument
      else {
           interpol = interpol;
      }

      return interpol;
}

Pressurization.apply = func( interpol ) {
      me.internal.getChild("atmosphere-inhg").setValue(me.pressureinhg);
      me.internal.getChild("target-inhg").setValue(me.targetinhg);
      me.internal.getChild("outflow-inhg").setValue(me.outflowinhg);
      me.internal.getChild("altitude-sea-ft").setValue(me.altseaft);

      if( !interpol ) {
          me.cabininhg = me.PRESSURIZEMININHG;
      }

      interpolate("/systems/pressurization/pressure-inhg",me.cabininhg,me.PRESSURIZESEC);
}

Pressurization.system = func {
   var interpol = constant.FALSE;
   var startup = me.last();

   # real modes
   if( !startup ) {
       me.curve();
       me.real();
   }

   interpol = me.interpolation();

   # artificial modes
   if( !startup ) {
       interpol = me.relocation( interpol );
   }

   me.apply( interpol );
}

Pressurization.discharge = func {
   var index = 0;


   # clear discharge valves
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
        for( var j = 0; j < constantaero.NBAUTOPILOTS; j=j+1 ) {
             me.dischargevalve[i][j] = me.VALVESHUT;
        }
   }


   # flight
   if( !me.ground ) {

       # aft valve is approximately 50 % of forward valve
       me.dischargevalve[me.system_no][0] = ( constant.abs( me.outflowinhg ) / me.PRESSURIZEINHG ) * me.VALVEOPEN;
       me.dischargevalve[me.system_no][1] = me.dischargevalve[me.system_no][0] * me.RATIOAFT;
   }

   # all valves open on ground
   else {
       for( var i = 0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
            for( var j = 0; j < constantaero.NBAUTOPILOTS; j=j+1 ) {
                 me.dischargevalve[i][j] = me.VALVEOPEN;
            }
       }
   }

   # depressurization through valves of system 2
   if( me.emergency.getChild("depressurization").getValue() ) {
       for( var j = 0; j < constantaero.NBAUTOPILOTS; j=j+1 ) {
            me.dischargevalve[1][j] = me.VALVEOPEN;
       }
   }
           
   # ditching closes both discharge valves
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
        if( !me.controls[i].getChild("ditching-guard").getValue() and
            me.controls[i].getChild("ditching").getValue() ) {
            for( var j = 0; j < constantaero.NBAUTOPILOTS; j=j+1 ) {
                 me.dischargevalve[i][j] = me.VALVESHUT;
            }
        }
   }

   # forces valve shut
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
        if( !me.controls[i].getChild("discharge-normal").getValue() ) {
            if( me.controls[i].getChild("discharge-fwd").getValue() ) {
                index = 0;
            }
            else {
                index = 1;
            }
 
            me.dischargevalve[i][index] = me.VALVESHUT;
        }
   }


   # apply
   for( var i = 0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
        interpolate("/systems/pressurization/system[" ~ i ~ "]/discharge-fwd-percent",
                    me.dischargevalve[i][0], me.INERTIASEC);
        interpolate("/systems/pressurization/system[" ~ i ~ "]/discharge-aft-percent",
                    me.dischargevalve[i][1], me.INERTIASEC);
   }
}

Pressurization.schedule = func {
   var running = constant.FALSE;

   me.speedup = getprop("/sim/speed-up");

   if( me.slave["electric"].getChild("specific").getValue() ) {
       if( me.pressurenode.getChild("serviceable").getValue() ) {
           running = constant.TRUE;

           me.initconstant();
           me.ground_relief();

           if( me.emergency.getChild("depressurization").getValue() ) {
               me.depressurization();
           }

           elsif( me.slave["air"].getChild("pressurization").getValue() ) {
               me.system();
           }

           me.thrust_recuperator();
           me.discharge();
       }
   }


   # leaks
   if( !running ) {
        me.cabinleak();
   }


   # energy provided by differential pressure
   me.diffpressure.schedule();
}


# =====================
# DIFFERENTIAL PRESSURE
# =====================

Differentialpressure = {};

Differentialpressure.new = func {
   var obj = { parents : [Differentialpressure],

           instrument : nil,

           DIFFSEC : 5.0,

           OVERPRESSUREPSI : 11.0,

           staticport : ""                         # energy provided by differential pressure
         };

   obj.init();

   return obj;
};

Differentialpressure.init = func {
    me.instrument = props.globals.getNode("/instrumentation/differential-pressure");

    me.staticport = me.instrument.getChild("static-pressure").getValue();
}

Differentialpressure.set_rate = func( rates ) {
    me.DIFFSEC = rates;
}

Differentialpressure.red_pressure = func {
    var result = constant.FALSE;

    if( me.instrument.getChild("differential-psi").getValue() >= me.OVERPRESSUREPSI ) {
        result = constant.TRUE;
    }

    return result;
}

Differentialpressure.schedule = func {
   var cabininhg = getprop("/systems/pressurization/pressure-inhg");
   var pressureinhg = getprop(me.staticport);
   var diffpsi = ( cabininhg - pressureinhg ) * constant.INHGTOPSI;

   interpolate("/instrumentation/differential-pressure/differential-psi",diffpsi,me.DIFFSEC);
}


# =========
# AIR BLEED
# =========

Airbleed = {};

Airbleed.new = func {
   var obj = { parents : [Airbleed,System],

           airconditioning : Airconditioning.new(),

           AIRSEC : 1.0,                              # refresh rate

           OVERPSI : 85.0,                            # overpressure
           MAXPSI : 65.0,                             # maximum pressure
           GROUNDPSI : 35.0,                          # ground supply pressure
           NOPSI : 0.0,

           valves : nil,
           bleeds : nil,
           airbleed : nil,

           adjacent : { 0 : 1, 1 : 0, 2 : 3, 3 : 2  }
         };

   obj.init();

   return obj;
};

Airbleed.init = func {
    me.init_ancestor("/systems/air-bleed");

    me.valves = props.globals.getNode("/controls/pneumatic/").getChildren("engine");
    me.bleeds = props.globals.getNode("/systems/air-bleed/").getChildren("engine");
    me.airbleed = props.globals.getNode("/systems/air-bleed/");
}

Airbleed.set_rate = func( rates ) {
    me.AIRSEC = rates;

    me.airconditioning.set_rate( me.AIRSEC );
}

Airbleed.amber_air = func {
    var result = constant.FALSE;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.bleeds[i].getChild("cross-psi").getValue() >= me.OVERPSI ) {
             result = constant.TRUE;
             break;
         }
    }

    if( !result ) {
        result = me.airconditioning.amber_air();
    }

    return result; 
}

Airbleed.red_doors = func {
    var result = constant.FALSE;

    if( me.airbleed.getChild("ground-service").getChild("door").getValue() ) {
        result = constant.TRUE;
    }
    else {
        result = me.airconditioning.red_doors();
    }

    return result; 
}

Airbleed.slowschedule = func {
    me.door();

    me.airconditioning.slowschedule();
}

# detects loss of all engines
Airbleed.schedule = func {
   var pressurepsi = 0.0;
   var bleedpsi = 0.0;
   var crosspsi = 0.0;
   var condpsi = 0.0;
   var a = 0;
   var pressurization = constant.FALSE;
   var serviceable = me.airbleed.getChild("serviceable").getValue();


   # ground supply
   groundpsi = me.airbleed.getNode("ground-service").getChild("pressure-psi").getValue();

   # ===============================
   # bleed valve limits the pressure
   # ===============================
   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( serviceable and
            me.slave["engine"][i].getChild("running").getValue() and
            me.valves[i].getChild("bleed-valve").getValue() ) {
            # maximum 65 PSI
            pressurepsi = me.MAXPSI;
        }
        else {
            pressurepsi = me.NOPSI;
        }

        me.apply("/systems/air-bleed/engine[" ~ i ~ "]/bleed-psi",pressurepsi);

        # ===========
        # cross bleed
        # ===========
        bleedpsi = pressurepsi;
        if( me.valves[i].getChild("cross-bleed-valve").getValue() and bleedpsi == me.NOPSI ) {
            pressurepsi = me.NOPSI;
            # adjacent engine
            a = me.adjacent[i];
            if( me.valves[a].getChild("cross-bleed-valve").getValue() ) {
                pressurepsi = me.bleeds[a].getChild("bleed-psi").getValue();
            }
            # ground supply
            if( pressurepsi == me.NOPSI ) {
                pressurepsi = groundpsi;
            }
        }
        else {
            pressurepsi = bleedpsi;
        }

        me.apply("/systems/air-bleed/engine[" ~ i ~ "]/cross-psi",pressurepsi);

        # ==================
        # conditioning valve
        # ==================
        crosspsi = pressurepsi;
        if( me.valves[i].getChild("conditioning-valve").getValue() ) {
            pressurepsi = crosspsi;
        }
        else {
            pressurepsi = me.NOPSI;
        }

        me.apply("/systems/air-bleed/engine[" ~ i ~ "]/conditioning-psi",pressurepsi);
   }

   # jet pump only when landing gear down
   if( me.slave["gear"].getChild("position-norm").getValue() == constantaero.GEARDOWN ) {
       for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
            me.bleeds[i].getChild("jet-pump").setValue(constant.TRUE);
       }
   }
   else {
       for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
            me.bleeds[i].getChild("jet-pump").setValue(constant.FALSE);
       }
   }

   # pressurization doesn't see the 4 distinct groups : will get the result after the interpolate
   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        condpsi = me.bleeds[i].getChild("conditioning-psi").getValue();
        if( condpsi >= me.MAXPSI ) {
            pressurization = constant.TRUE;
            break;
        }
   }
   me.airbleed.getChild("pressurization").setValue(pressurization);

   me.airconditioning.schedule();
}

Airbleed.apply = func( path, value ) {
    interpolate(path,value,me.AIRSEC);
}

# connection with delay by ground operator
Airbleed.door = func {
    if( me.is_moving() ) {
        # door stays open, has forgotten to call for disconnection !
        me.airbleed.getNode("ground-service").getChild("pressure-psi").setValue(me.NOPSI);
    }
}

Airbleed.groundserviceexport = func {
    var pressurepsi = 0.0;

    if( !me.is_moving() ) {
        supply = me.airbleed.getNode("ground-service").getChild("door").getValue();

        if( supply ) {
            pressurepsi = me.NOPSI;
        }
        else {
            pressurepsi = me.GROUNDPSI;
        }

        me.airbleed.getNode("ground-service").getChild("door").setValue(!supply);
        me.airbleed.getNode("ground-service").getChild("pressure-psi").setValue(pressurepsi);
    }
}

Airbleed.reargroundserviceexport = func {
    me.airconditioning.groundservice();
}


# =================
# AIR CONDITIONNING
# =================

Airconditioning = {};

Airconditioning.new = func {
   var obj = { parents : [Airconditioning,System],

           AIR60SEC : 60.0,                           # warming rate
           VALVESEC : 5.0,
           AIRSEC : 1.0,                              # refresh rate

           speedup : 1.0,

           MINPSI : 65.0,                             # minimum pressure for air conditioning
           NOPSI : 0.0,

           NORMALKGPH : 4200.0,
           NOMASSKGPH : 0.0,

           VALVEH : 1.0,                              # opened : hot air maximum
           VALVEC : 0.0,                              # shut : cold air only

           temperature_valve : 0.0,
           ground_supply : constant.FALSE,

           PRIMARYDEGC : 150.0,
           OVERDEGC : 120.0,                          # duct over temperature
           DUCTDEGC : 30.0,                           # selector range
           DUCTMINDEGC : 5.0,

           ramairdegc : 0.0,

           WARMINGDEGCPMIN : 0.5,                     # cabin
           COOLINGDEGCPMIN : 0.1,                     # isolation

           valves : nil,
           bleeds : nil,
           groups : nil,
           conditioning : nil,

           thegroup : { "1" : 0, "2" : 1, "3" : 2, "4" : 3 },
           thetemperature : { "1" : "flight-deck-degc", "2" : "cabin-fwd-degc", "3" : "cabin-rear-degc",
                              "4" : "cabin-rear-degc" }
         };

   obj.init();

   return obj;
};

Airconditioning.init = func {
    me.init_ancestor("/systems/air-bleed");

    me.valves = props.globals.getNode("/controls/temperature/").getChildren("group");
    me.bleeds = props.globals.getNode("/systems/air-bleed/").getChildren("engine");
    me.groups = props.globals.getNode("/systems/temperature/").getChildren("group");
    me.conditioning = props.globals.getNode("/systems/temperature/");
}

Airconditioning.set_rate = func( rates ) {
    me.AIRSEC = rates;
}

Airconditioning.amber_air = func {
    var result = constant.FALSE;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.groups[i].getChild("duct-degc").getValue() >= me.OVERDEGC ) {
             result = constant.TRUE;
             break;
         }
    }

    return result; 
}

Airconditioning.red_doors = func {
    var result = me.conditioning.getChild("ground-service").getChild("door").getValue();

    return result; 
}

Airconditioning.slowschedule = func {
   var flowkgph = 0.0;
   var targetdegc = 0.0;
   var currentdegc = 0.0;
   var location = "";


   # group 4
   var flow4kgph = me.groups[me.thegroup["4"]].getChild("flow-kgph").getValue();
   var target4degc = me.selectordegc( me.thegroup["4"] );


   me.door();
   me.ground_supply = me.conditioning.getNode("ground-service").getChild("door").getValue();

   me.ramairdegc = me.noinstrument["temperature"].getValue();
   me.speedup = getprop("/sim/speed-up");

 
   for( var i = 0; i < 3; i = i+1 ) {
        flowkgph = me.groups[i].getChild("flow-kgph").getValue();
        targetdegc = me.selectordegc( i );

        location = "";


        # ===========
        # flight deck
        # ===========
        if( i == me.thegroup["1"] ) {
            # group 1 failed
            if( !me.valves[i].getChild("on").getValue() ) {
                me.closevalve();
            }

            else {
                location = me.thetemperature["1"];
            }
        }


        # =============
        # forward cabin
        # =============
        elsif( i == me.thegroup["2"] ) {
            # group 1 failed
            if( !me.valves[me.thegroup["1"]].getChild("on").getValue() ) {
                location = me.thetemperature["1"];
            }

            # group 2 failed
            elsif( !me.valves[i].getChild("on").getValue() ) {
                me.closevalve();
            }

            else {
                location = me.thetemperature["2"];
            }
        }


        # ==========
        # rear cabin
        # ==========
        elsif( i == me.thegroup["3"] ) {
            # group 1 failed
            if( !me.valves[me.thegroup["1"]].getChild("on").getValue() ) {
                location = me.thetemperature["2"];

                me.control( me.thegroup["4"], me.thetemperature["4"], flow4kgph, target4degc );
            }

            # group 2 failed
            elsif( !me.valves[me.thegroup["2"]].getChild("on").getValue() ) {
                location = me.thetemperature["2"];

                me.control( me.thegroup["4"], me.thetemperature["4"], flow4kgph, target4degc );
            }

            # group 3 + 4 : supposes 1 group is enough
            else {
                location = me.thetemperature["3"];

                # group 3 slaved to rotary selector 4
                if( me.valves[i].getChild("on").getValue() ) {
                    targetdegc = target4degc;
                }

                # group 3 alone
                if( me.is_off( flow4kgph ) ) {
                    me.closevalve();
                    me.adjustvalve( me.thegroup["4"] );
                }

                # group 4 alone
                elsif( me.is_off( flowkgph ) ) {
                     me.control( me.thegroup["4"], location, flow4kgph, target4degc );

                     location = "";

                     me.closevalve();
                     me.adjustvalve( i );
                }

                # group 4
                else {
                     currentdegc = me.conditioning.getChild(location).getValue();
                     targetdegc = me.warmingdegc( flow4kgph, currentdegc, target4degc );

                     me.adjustvalve( me.thegroup["4"] );
                }
            }
        }


        # temperature control
        me.control( i, location, flowkgph, targetdegc );
   }
}

Airconditioning.schedule = func {
   var groundpsi = 0.0;
   var condpsi = 0.0;
   var oldductdegc = 0.0;
   var ductdegc = 0.0;
   var inletdegc = 0.0;
   var flowkgph = 0.0;
   var coef = 0.0;
   var serviceable = me.conditioning.getChild("serviceable").getValue();

   # external air
   me.ramairdegc = me.noinstrument["temperature"].getValue();

   # ground supply
   groundpsi = me.conditioning.getNode("ground-service").getChild("pressure-psi").getValue();

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        oldductdegc = me.groups[i].getChild("duct-degc").getValue();

        if( serviceable ) {
            condpsi = me.bleeds[i].getChild("conditioning-psi").getValue();
            if( condpsi < me.MINPSI ) {
                condpsi = groundpsi;
            }
        }
        else {
            condpsi = me.NOPSI;
        }

        if( condpsi >= me.MINPSI ) {
            flowkgph = me.NORMALKGPH;
            inletdegc = me.PRIMARYDEGC;
            ductdegc = me.mixingdegc( i );
        }
        else {
            coef = condpsi / me.MINPSI;

            flowkgph = coef * me.NORMALKGPH;
            inletdegc = me.coolingdegc( coef, me.PRIMARYDEGC );
            ductdegc = me.coolingdegc( coef, oldductdegc );
        }

        me.apply("/systems/temperature/group[" ~ i ~ "]/flow-kgph",flowkgph);

        # one supposes quick cooling by RAM air, when no mass flow.
        me.apply("/systems/temperature/group[" ~ i ~ "]/inlet-degc",inletdegc);
        me.apply("/systems/temperature/group[" ~ i ~ "]/duct-degc",ductdegc);
   }
}

Airconditioning.apply = func( path, value ) {
    interpolate(path,value,me.AIRSEC);
}

Airconditioning.groundservice = func {
    var pressurepsi = 0.0;

    if( !me.is_moving() ) {
        supply = me.conditioning.getNode("ground-service").getChild("door").getValue();

        if( supply ) {
            pressurepsi = me.NOPSI;
        }
        else {
            pressurepsi = me.MINPSI;
        }

        me.conditioning.getNode("ground-service").getChild("door").setValue(!supply);
        me.conditioning.getNode("ground-service").getChild("pressure-psi").setValue(pressurepsi);
    }
}

# connection with delay by ground operator
Airconditioning.door = func {
    if( me.is_moving() ) {
        # door stays open, has forgotten to call for disconnection !
        me.conditioning.getNode("ground-service").getChild("pressure-psi").setValue(me.NOPSI);
    }
}

Airconditioning.control = func( index, location, flowkgph, targetdegc ) {
    var currentdegc = 0.0;

    if( location != "" ) {
        currentdegc = me.conditioning.getChild(location).getValue();
        targetdegc = me.warmingdegc( flowkgph, currentdegc, targetdegc );

        interpolate("/systems/temperature/" ~ location,targetdegc,me.AIR60SEC);
    }

    me.adjustvalve( index );
}

Airconditioning.is_off = func( flowkgph ) {
   var result = constant.FALSE;

   if( flowkgph < me.NORMALKGPH ) {
       result = constant.TRUE;
   }

   return result;
}

Airconditioning.warmingdegc = func( flowkgph, currentdegc, targetdegc ) {
   var stepdegc = 0.0;
   var diffdegc = 0.0;
   var off = me.is_off( flowkgph );

   # heat loss
   if( off ) {
       targetdegc = me.ramairdegc;
       stepdegc = me.speedup * me.COOLINGDEGCPMIN;
   }

   # air conditioning
   else {
       stepdegc = me.speedup * me.WARMINGDEGCPMIN;
   }

   diffdegc = targetdegc - currentdegc;

   # warming
   if( diffdegc > stepdegc ) {
       targetdegc = currentdegc + stepdegc;
       me.temperature_valve = me.VALVEH;
   }

   # cooling
   elsif( diffdegc < - stepdegc ) {
       targetdegc = currentdegc - stepdegc;
       me.temperature_valve = me.VALVEC;
   }

   # temperature reached
   else {
       me.temperature_valve = ( targetdegc - me.DUCTMINDEGC ) / me.DUCTDEGC;
   }

   # close valve
   if( off or me.ground_supply ) {
       me.temperature_valve = me.VALVEC;
   }

   return targetdegc;
}

# rough duct temperature
Airconditioning.coolingdegc = func( coef, targetdegc ) {
   var resultdegc = me.ramairdegc + coef * ( targetdegc - me.ramairdegc );

   return resultdegc;
}

Airconditioning.mixingdegc = func( index ) {
   var resultdegc = 0.0;
   var valve = me.groups[index].getChild("temperature-valve").getValue();

   # warming
   if( valve == me.VALVEH ) {
       resultdegc = me.DUCTMINDEGC + me.DUCTDEGC;
   }

   # cooling
   elsif( valve == me.VALVEC ) {
       resultdegc = me.DUCTMINDEGC;
   }

   # temperature regulation
   else {
       resultdegc = me.selectordegc( index );
   }

   return resultdegc;
}

Airconditioning.selectordegc = func( index ) {
   var selector = me.valves[index].getChild("temperature-selector").getValue();

   # - cold : 5°C.
   # - hot  : 35°C.
   var targetdegc = me.DUCTMINDEGC + ( selector / 3.0 ) * me.DUCTDEGC;

   return targetdegc;
}

Airconditioning.closevalve = func {
   me.temperature_valve = me.VALVEC;
}

Airconditioning.adjustvalve = func( index ) {
   interpolate("/systems/temperature/group[" ~ index ~ "]/temperature-valve",
               me.temperature_valve, me.VALVESEC);
}
