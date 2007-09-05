# ==================
# CONCORDE CONSTANTS
# ==================

Constantaero = {};

Constantaero.new = func {
   obj = { parents : [Constantaero],

           FULLLB : 408000,
           LANDINGLB : 245000,
           EMPTYLB : 203000,

           MAXFPM : 7000.0,                                  # max descent rate

           APPROACHKT : 250,
           V2FULLKT : 220,
           V2EMPTYKT : 205,                                  # guess
           VRFULLKT : 195,
           LANDINGKT : 190,
           VREMPTYKT : 180,                                  # guess
           V1FULLKT : 165,
           VREFFULLKT : 162,
           VREFEMPTYKT : 152,
           V1EMPTYKT : 150,                                  # guess
           TAXIKT : 10,

           MAXCRUISEFT : 50190,                              # max cruise mode 
           APPROACHFT : 10000,                               # 250 kt
           LANDINGFT : 3000,                                 # 190 kt
           CLIMBFT : 1000,
           REHEATFT : 500,                                   # reheat off
           GEARFT : 20,                                      # gear retraction

# AGL altitude, where the gears touch the ground
           AGLTOUCHFT : 14,

# AGL altitude when on ground : radio altimeter is above gear
# (Z height of center of gravity minus Z height of main landing gear)
           AGLFT : 11
         };

   return obj;
}

Constantaero.Vkt = func( weightlb, minkt, maxkt ) {
    if( weightlb > me.FULLLB ) {
        valuekt = maxkt;
    }
    elsif( weightlb < me.EMPTYLB ) {
        valuekt = minkt;
    }
    else {
        ratio = ( me.FULLLB - weightlb ) / ( me.FULLLB - me.EMPTYLB );
        valuekt = maxkt + ( minkt - maxkt ) * ratio;
    }

    return valuekt;
}

Constantaero.Vrefkt = func( weightlb ) {
    if( weightlb > me.LANDINGLB ) {
        valuekt = me.VREFFULLKT;
    }
    else {
        ratio = ( me.FULLLB - weightlb ) / ( me.FULLLB - me.EMPTYLB );
        valuekt = me.VREFFULLKT + ( me.VREFEMPTYKT - me.VREFFULLKT ) * ratio;
    }

   return valuekt;
}


# =========
# CONSTANTS
# =========

Constant = {};

Constant.new = func {
   obj = { parents : [Constant],

           ready : 0.0,                            # waits for end of initialization

# artificial intelligence
           HUMANSEC : 1.0,                         # human reaction time

# angles
           DEG360 : 360,
           DEG180 : 180,
           DEG90 : 90,

# nasal has no boolean                             # faster than "true"/"false"
           TRUE : 1.0,
           FALSE : 0.0,

# ---------------
# unit conversion
# ---------------

# angle
           DEGTORAD : 0.0174532925199,
# length
           FEETTOMETER : 0.3048,
           METERTOFEET : 3.28083989501,
           NMTOFEET : 6076.11548556,
           FEETTONM : 0.0001645788,
# pressure
           INHGTOPSI : 0.491154077497,
           MBARTOINHG : 0.029529987508,
           PSITOINHG : 2.03602096738,
# temperature
           CELSIUSTOK : 273.15,
           CELSIUSTOF : 1.8,
           CELSIUS0TOF : 32.0,
           FTOCELSIUS : 0.0,
           F0TOCELSIUS : 0.0,
# time
           HOURTOMINUTE : 60,
           HOURTOSECOND : 3600,
           MINUTETOSECOND : 60,
# velocity
           FPSTOKT : 0.592483801296,
           MPSTOKT : 1.943844,
# weight
           GALUSTOKG : 0.0,
           GALUSTOLB : 6.6,                        # 1 US gallon = 6.6 pound
           KGTOLB : 2.20462,
           LBTOGALUS : 0.0,
           LBTOKG : 0.453592,
           TONTOLB : 2204.62,

# International Standard Atmosphere
           P0_inhg : 29.92,
           T0_degc : 15.0,

# --------
# physical
# --------
           gammaairstp : 1.4,                      # ratio of specific heats at STP
           Rpm2ps2pK : 286.0                       # gas constant 286 /m2/s2/K for air
         };

   obj.init();

   return obj;
};

Constant.init = func {
   me.GALUSTOKG = me.GALUSTOLB * me.LBTOKG;
   me.LBTOGALUS = 1 / me.GALUSTOLB;
   me.FTOCELSIUS = 1 / me.CELSIUSTOF;
   me.F0TOCELSIUS = - me.CELSIUS0TOF * me.FTOCELSIUS;
}

Constant.abs = func( value ) {
   if( value < 0 ) {
       value = - value;
   }

   return value;
}

Constant.rates = func( steps ) {
   speedup = getprop("/sim/speed-up");
   if( speedup > 1 ) {
       steps = steps / speedup;
   }

   return steps;
}

Constant.clip = func( min, max, value ) {
   if( value < min ) {
       value = min;
   }
   elsif( value > max ) {
       value = max;
   }

   return value;
}

# north crossing
Constant.crossnorth = func( offsetdeg ) {
   if( offsetdeg > me.DEG180 ) {
       offsetdeg = offsetdeg - me.DEG360;
   }
   elsif( offsetdeg < - me.DEG180 ) {
       offsetdeg = offsetdeg + me.DEG360;
   }

   return offsetdeg;
}

Constant.fahrenheit_to_celsius = func ( degf ) {
   degc = me.FTOCELSIUS * degf + me.F0TOCELSIUS;

   return degc;
}

# speed of sound : v^2 = dP/dRo = gamma x R x T, where
# P = pressure
# Ro = density
# gamma = cp/cv, ratio of specific heats
# R = absolute gas constant
# T = temperature
Constant.newtonsoundmps= func( temperaturedegc ) {
    TK = temperaturedegc + me.CELSIUSTOK;
    dPdRoNewton = me.Rpm2ps2pK * TK;
    dPdRo = me.gammaairstp * dPdRoNewton;
    speedmps = math.sqrt(dPdRo);

    return speedmps;
}

Constant.system_ready = func {
    # if there is electrical power, there should be also hydraulics
    if( !me.ready ) {
        me.ready = getprop("/systems/electrical/power/specific");
    }

    return me.ready;
}


# ---------------------------------
# International Standard Atmosphere
# ---------------------------------

Constant.altitude_ft = func( pressureinhg, datuminhg ) {
   # calibrated by standard atmosphere
   ratio = pressureinhg / datuminhg;

   # guess below sea level
   found = me.TRUE;
   if( ratio > 1.09 ) {
       found = me.FALSE;
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
       found = me.FALSE;
   }

   if( found ) {
       step = maxfactor - ratio;
       delta = maxfactor - minfactor;
       coeff = step / delta ;
       cabinaltm = altminm + 900 * coeff;
       altitudeft = cabinaltm * me.METERTOFEET;
   }
   # out of range
   else {
       pressureinhg = datuminhg;
       altitudeft = 0;
   }


   return altitudeft;
}

Constant.pressure_inhg = func( altitudeft ) {
   altitudem = altitudeft * me.FEETTOMETER;

   # guess below sea level
   found = me.TRUE;
   if( altitudem < -900 ) {
       found = me.FALSE;
   }
   elsif( altitudem < 0 and altitudem >= -900 ) {
       altmaxm = 0;
       altminm = -900;
       minfactor = 1.0;
       maxfactor = 1.09;
   }

   # standard atmosphere
   elsif( altitudem < 900.0 and altitudem >= 0 ) {
       altmaxm = 900;
       altminm = 0;
       minfactor = 0.898;
       maxfactor = 1.0;
   }
   elsif( altitudem < 1800.0 and altitudem >= 900 ) {
       altmaxm = 1800;
       altminm = 900;
       minfactor = 0.804;
       maxfactor = 0.898;
   }
   elsif( altitudem < 2700.0 and altitudem >= 1800 ) {
       altmaxm = 2700;
       altminm = 1800;
       minfactor = 0.719;
       maxfactor = 0.804;
   }
   elsif( altitudem < 3600.0 and altitudem >= 2700 ) {
       altmaxm = 3600;
       altminm = 2700;
       minfactor = 0.641;
       maxfactor = 0.719;
   }
   elsif( altitudem < 4500.0 and altitudem >= 3600 ) {
       altmaxm = 4500;
       altminm = 3600;
       minfactor = 0.570;
       maxfactor = 0.641;
   }
   elsif( altitudem < 5400.0 and altitudem >= 4500 ) {
       altmaxm = 5400;
       altminm = 4500;
       minfactor = 0.506;
       maxfactor = 0.570;
   }
   elsif( altitudem < 6300.0 and altitudem >= 5400 ) {
       altmaxm = 6300;
       altminm = 5400;
       minfactor = 0.447;
       maxfactor = 0.506;
   }
   elsif( altitudem < 7200.0 and altitudem >= 6300 ) {
       altmaxm = 7200;
       altminm = 6300;
       minfactor = 0.394;
       maxfactor = 0.447;
   }
   elsif( altitudem < 8100.0 and altitudem >= 7200 ) {
       altmaxm = 8100;
       altminm = 7200;
       minfactor = 0.347;
       maxfactor = 0.394;
   }
   elsif( altitudem < 9000.0 and altitudem >= 8100 ) {
       altmaxm = 9000;
       altminm = 8100;
       minfactor = 0.304;
       maxfactor = 0.347;
   }
   elsif( altitudem < 9900.0 and altitudem >= 9000 ) {
       altmaxm = 9900;
       altminm = 9000;
       minfactor = 0.266;
       maxfactor = 0.304;
   }
   elsif( altitudem < 10800.0 and altitudem >= 9900 ) {
       altmaxm = 10800;
       altminm = 9900;
       minfactor = 0.231;
       maxfactor = 0.266;
   }
   elsif( altitudem < 11700.0 and altitudem >= 10800 ) {
       altmaxm = 11700;
       altminm = 10800;
       minfactor = 0.201;
       maxfactor = 0.231;
   }
   elsif( altitudem < 12600.0 and altitudem >= 11700 ) {
       altmaxm = 12600;
       altminm = 11700;
       minfactor = 0.174;
       maxfactor = 0.201;
   }
   elsif( altitudem < 13500.0 and altitudem >= 12600 ) {
       altmaxm = 13500;
       altminm = 12600;
       minfactor = 0.151;
       maxfactor = 0.174;
   }
   elsif( altitudem < 14400.0 and altitudem >= 13500 ) {
       altmaxm = 14400;
       altminm = 13500;
       minfactor = 0.131;
       maxfactor = 0.151;
   }
   elsif( altitudem < 15300.0 and altitudem >= 14400 ) {
       altmaxm = 15300;
       altminm = 14400;
       minfactor = 0.114;
       maxfactor = 0.131;
   }
   elsif( altitudem < 16200.0 and altitudem >= 15300 ) {
       altmaxm = 16200;
       altminm = 15300;
       minfactor = 0.099;
       maxfactor = 0.114;
   }
   elsif( altitudem < 17100.0 and altitudem >= 16200 ) {
       altmaxm = 17100;
       altminm = 16200;
       minfactor = 0.086;
       maxfactor = 0.099;
   }
   elsif( altitudem < 18000.0 and altitudem >= 17100 ) {
       altmaxm = 18000;
       altminm = 17100;
       minfactor = 0.075;
       maxfactor = 0.086;
   }
   elsif( altitudem < 18900.0 and altitudem >= 18000 ) {
       altmaxm = 18900;
       altminm = 18000;
       minfactor = 0.065;
       maxfactor = 0.075;
   }
   else {
       found = me.FALSE;
   }

   if( found ) {
       step = altmaxm - altitudem;
       delta = maxfactor - minfactor;
       coeff = step / 900 ;
       pressureinhg = me.P0_inhg * ( minfactor + delta * coeff );
   }
   # out of range
   else {
       pressureinhg = me.P0_inhg;
   }


   return pressureinhg;
}

Constant.temperature_degc = func( altitudeft ) {
   altmeter = altitudeft * me.FEETTOMETER;


   found = me.TRUE;

   # guess below sea level
   if( altmeter <= -900 ) {
      found = me.FALSE;
      isadegc = me.T0_degc;
   }
   elsif( altmeter > -900 and altmeter <= 0 ) {
       maxfactor = 1.02;
       minfactor = 1.0;
       minmeter = -900;
   }

   # standard atmosphere
   elsif( altmeter > 0 and altmeter <= 900 ) {
       maxfactor = 1.0;
       minfactor = 0.98;
       minmeter = 0;
   }
   elsif( altmeter > 900 and altmeter <= 1800 ) {
       maxfactor = 0.98;
       minfactor = 0.96;
       minmeter = 900;
   }
   elsif( altmeter > 1800 and altmeter <= 2700 ) {
       maxfactor = 0.96;
       minfactor = 0.94;
       minmeter = 1800;
   }
   elsif( altmeter > 2700 and altmeter <= 3600 ) {
       maxfactor = 0.94;
       minfactor = 0.92;
       minmeter = 2700;
   }
   elsif( altmeter > 3600 and altmeter <= 4500 ) {
       maxfactor = 0.92;
       minfactor = 0.90;
       minmeter = 3600;
   }
   elsif( altmeter > 4500 and altmeter <= 5400 ) {
       maxfactor = 0.90;
       minfactor = 0.88;
       minmeter = 4500;
   }
   elsif( altmeter > 5400 and altmeter <= 6300 ) {
       maxfactor = 0.88;
       minfactor = 0.86;
       minmeter = 5400;
   }
   elsif( altmeter > 6300 and altmeter <= 7200 ) {
       maxfactor = 0.86;
       minfactor = 0.84;
       minmeter = 6300;
   }
   elsif( altmeter > 7200 and altmeter <= 8100 ) {
       maxfactor = 0.84;
       minfactor = 0.82;
       minmeter = 7200;
   }
   elsif( altmeter > 8100 and altmeter <= 9000 ) {
       maxfactor = 0.82;
       minfactor = 0.80;
       minmeter = 8100;
   }
   elsif( altmeter > 9000 and altmeter <= 9900 ) {
       maxfactor = 0.80;
       minfactor = 0.78;
       minmeter = 9000;
   }
   elsif( altmeter > 9900 and altmeter <= 10800 ) {
       maxfactor = 0.78;
       minfactor = 0.76;
       minmeter = 9900;
   }
   elsif( altmeter > 10800 and altmeter <= 11700 ) {
       maxfactor = 0.76;
       minfactor = 0.75;
       minmeter = 10800;
   }
   elsif( altmeter > 10800 and altmeter <= 18900 ) {
       found = me.FALSE;
       # factor 0.75 (stratosphere)
       isadegc = -57.0;
   }
   else {
       found = me.FALSE;
       # overflow
       isadegc = -57.0;
   }

   if( found ) {
       delta = minfactor - maxfactor;
       deltameter = altmeter - minmeter;
       coeff = deltameter / 900 ;
       factor = maxfactor + delta * coeff;

       # 15 degc at sea level
       isadegk = (me.CELSIUSTOK + me.T0_degc) * factor;
       isadegc = isadegk - me.CELSIUSTOK;
   }


   return isadegc;
}


# ======
# SYSTEM
# ======

# for inheritance, the system must be the last of parents.
System = {};

# not called by child classes !!!
System.new = func {
   obj = { parents : [System],

           SYSSEC : 0.0,                               # to be defined !

           RELOCATIONFT : 0.0,                         # max descent speed around 6000 feet/minute.

           altseaft : 0.0,

           noinstrument : {},
           slave : {}
         };

   return obj;
};

System.init_ancestor = func( path ) {
   obj = System.new();

   me.SYSSEC = obj.SYSSEC;
   me.RELOCATIONFT = obj.RELOCATIONFT;
   me.altseaft = obj.altseaft;
   me.noinstrument = obj.noinstrument;
   me.slave = obj.slave;

   me.loadtree( path ~ "/slave" );
   me.loadprop( path ~ "/noinstrument" );
}

System.set_rate_ancestor = func( rates ) {
   me.SYSSEC = rates;

   me.RELOCATIONFT = constantaero.MAXFPM / ( constant.MINUTETOSECOND / me.SYSSEC );
}

# property access is faster through its node, than parsing its string
System.loadtree = func( path ) {
   if( props.globals.getNode(path) != nil ) {
       children = props.globals.getNode(path).getChildren();
       foreach( c; children ) {
          name = c.getName();
          subchildren = c.getChildren();

          # <slave>
          #  <engine>
          #   <component>/engines</component>
          #   <subcomponent>engine</subcomponent>
          #  </engine>
          if( size(subchildren) > 0 ) {
              component = c.getChild("component").getValue();
              subcomponent = c.getChild("subcomponent").getValue();
              me.slave[name] = props.globals.getNode(component).getChildren(subcomponent);
          }

          #  <altimeter>/instrumentation/altimeter[0]</altimeter>
          # </slave>
          else {
              value = c.getValue();
              me.slave[name] = props.globals.getNode(value);
          }
      }
   }
}

System.loadprop = func( path ) {
   if( props.globals.getNode(path) != nil ) {
       children = props.globals.getNode(path).getChildren();
       foreach( c; children ) {
          name = c.getName();
          subchildren = c.getChildren();

          # <noinstrument>
          #  <cloud>
          #   <component>/environment/clouds</component>
          #   <subcomponent>layer</subcomponent>
          #  </cloud>
          if( size(subchildren) > 0 ) {
              component = c.getChild("component").getValue();
              subcomponent = c.getChild("subcomponent").getValue();
              me.noinstrument[name] = props.globals.getNode(component).getChildren(subcomponent);
          }

          #  <agl>/position/altitude-agl-ft</agl>
          # </noinstrument>
          else {
              value = c.getValue();
              me.noinstrument[name] = props.globals.getNode(value);
          }
       }
   }
}

System.is_moving = func {
   # must exist in XML
   aglft = me.noinstrument["agl"].getValue();
   speedkt = me.noinstrument["airspeed"].getValue();

   if( aglft >=  constantaero.AGLTOUCHFT or speedkt >= constantaero.TAXIKT ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

System.is_relocating = func {
   # must exist in XML
   altft = me.noinstrument["altitude"].getValue();

   # relocation in flight, or at another airport
   variationftpm = altft - me.altseaft;
   if( variationftpm < - me.RELOCATIONFT or variationftpm > me.RELOCATIONFT ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   me.altseaft = altft;

   return result;
}
