# current nasal version doesn't accept :
# - boolean (can only test IF TRUE); replaced by strings.



# ==================
# CONCORDE CONSTANTS
# ==================

ConstantAero = {};

ConstantAero.new = func {
   obj = { parents : [ConstantAero],

# AGL altitude when on ground : radio altimeter is above gear
# (Z height of center of gravity minus Z height of main landing gear)
           AGLFT : 11,
# AGL altitude, where the gears touch the ground
           AGLTOUCHFT : 14,

# Concorde
           MAXCRUISEFT : 50190                                   # max cruise mode 
         };

   return obj;
}


# =========
# CONSTANTS
# =========

Constant = {};

Constant.new = func {
   obj = { parents : [Constant],

# angles
           DEG360 : 360,
           DEG180 : 180,
           DEG90 : 90,
# no boolean
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
           HOURTOMINUTE : 60.0,
           HOURTOSECOND : 3600.0,
           MINUTETOSECOND : 60.0,
# velocity
           FPSTOKT : 0.592483801296,
           MPSTOKT : 1.943844,
# weight
           GALUSTOLB : 6.6,                        # 1 US gallon = 6.6 pound
           LBTOGALUS : 0.0,
           LBTOKG : 0.453592,
           TONTOLB : 2204.62,

# --------
# formulas
# --------
           gammaairstp : 1.4,                      # ratio of specific heats at STP
           P0_inhg : 29.92,                        # ISA sea level pressure
           Rpm2ps2pK : 286.0                       # gas constant 286 /m2/s2/K for air
         };

   obj.init();

   return obj;
};

Constant.init = func {
   me.LBTOGALUS = 1 / me.GALUSTOLB;
   me.FTOCELSIUS = 1 / me.CELSIUSTOF;
   me.F0TOCELSIUS = - me.CELSIUS0TOF * me.FTOCELSIUS;
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
