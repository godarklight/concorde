# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ===
# VMO
# ===

VMO = {};

VMO.new = func {
   obj = { parents : [VMO],

           weight : Weight.new(),

           weightlb : 0.0,

# lowest CG
           find0 : "",
           vminkt0 : 0.0,
           vmaxkt0 : 0.0,
           altminft0 : 0.0,
           altmaxft0 : 0.0,
           vmokt0 : 0.0,
# CG
           find : "",
           vminkt : 0.0,
           vmaxkt : 0.0,
           altminft : 0.0,
           altmaxft : 0.0,
           vmokt : 0.0
         };

   return obj;
};

VMO.schedule = func( altitudeft ) {
       me.weightlb = me.weight.getweightlb();

       me.speed105t( altitudeft );
       me.speed165t( altitudeft );

       vmokt0 = me.interpolatealtitude0( altitudeft );
       vmokt = me.interpolatealtitude( altitudeft );

       # interpolate between 105 and 165 t
       vmokt = me.interpolateweight( vmokt, vmokt0 );

       return vmokt;
}  

VMO.interpolateft = func( find, vmokt, vmaxkt, vminkt, altmaxft, altminft, altitudeft ) {
   if( find == "true" ) {
       offsetkt = vmaxkt - vminkt;
       offsetft = altmaxft - altminft;
       stepft = altitudeft - altminft;
       ratio = stepft / offsetft;
       stepkt = offsetkt * ratio;
       vmokt = vminkt + stepkt;
   }

   return vmokt;
}

VMO.interpolatealtitude0 = func( altitudeft ) {
   vmokt = me.interpolateft( me.find0, me.vmokt0, me.vmaxkt0, me.vminkt0, me.altmaxft0, me.altminft0, altitudeft );

   return vmokt;
}

VMO.interpolatealtitude = func( altitudeft ) {
   vmokt = me.interpolateft( me.find, me.vmokt, me.vmaxkt, me.vminkt, me.altmaxft, me.altminft, altitudeft );

   return vmokt;
}

# interpolate between 105 and 165 t
VMO.interpolateweight = func( vmokt, vmokt0 ) {
   if( me.weightlb > me.weight.WEIGHTMINLB and me.weightlb < me.weight.WEIGHTMLAXLB ) {
       offsetkt = vmokt - vmokt0;
       stepweight = me.weightlb - me.weight.WEIGHTMINLB;
       offsetweight = me.weight.WEIGHTMLAXLB - me.weight.WEIGHTMINLB;
       ratio = stepweight / offsetweight;
       stepkt = offsetkt * ratio;
       vmokt = vmokt0 + stepkt;
   }
   elsif( me.weightlb <= me.weight.WEIGHTMINLB ) {
       vmokt = vmokt0;
   }

   return vmokt;
}

# below 105 t
VMO.speed105t = func( altitudeft ) {
   me.find0 = "";
   if( me.weightlb < me.weight.WEIGHTMLAXLB ) {
       me.find0 = "true";
       # at startup, altitude may be negativ
       if( altitudeft <= 0 ) {
           me.find0 = "false";
           me.vmokt0 = 300;
       }
       # different
       elsif( altitudeft > 0 and altitudeft <= 4500 ) {
           me.vminkt0 = 300;
           me.vmaxkt0 = 385;
           me.altminft0 = 0;
           me.altmaxft0 = 4500;
       }
       elsif ( altitudeft > 4500 and altitudeft <= 6000 ) {
           me.vminkt0 = 385;
           me.vmaxkt0 = 390;
           me.altminft0 = 4500;
           me.altmaxft0 = 6000;
       }
       elsif ( altitudeft > 6000 and altitudeft <= 34500 ) {
           me.find0 = "false";
           me.vmokt0 = 390;
       }
       elsif ( altitudeft > 34500 and altitudeft <= 43000 ) {
           me.vminkt0 = 390;
           me.vmaxkt0 = 520;
           me.altminft0 = 34500;
           me.altmaxft0 = 43000;
       }
       # identical
       elsif ( altitudeft > 43000 and altitudeft <= 44000 ) {
           me.vminkt0 = 520;
           me.vmaxkt0 = 530;
           me.altminft0 = 43000;
           me.altmaxft0 = 44000;
       }
       elsif ( altitudeft > 44000 and altitudeft <= 51000 ) {
           me.find0 = "false";
           me.vmokt0 = 530;
       }
       elsif ( altitudeft > 51000 and altitudeft <= 60000 ) {
           me.vminkt0 = 530;
           me.vmaxkt0 = 430;
           me.altminft0 = 51000;
           me.altmaxft0 = 60000;
       }
       else {
           me.find0 = "false";
           me.vmokt0 = 430;
       }
   }
}

# above 165 t
VMO.speed165t = func( altitudeft ) {
   me.find = "";
   if( me.weightlb > me.weight.WEIGHTMINLB ) {
       me.find  = "true";
       # at startup, altitude may be negativ
       if( altitudeft <= 0 ) {
           me.find = "false";
           me.vmokt = 300;
       }
       elsif( altitudeft > 0 and altitudeft <= 4000 ) {
           me.vminkt = 300;
           me.vmaxkt = 395;
           me.altminft = 0;
           me.altmaxft = 4000;
       }
       elsif ( altitudeft > 4000 and altitudeft <= 6000 ) {
           me.vminkt = 395;
           me.vmaxkt = 400;
           me.altminft = 4000;
           me.altmaxft = 6000;
       }
       elsif ( altitudeft > 6000 and altitudeft <= 32000 ) {
            me.find = "false";
            me.vmokt = 400;
       }
       elsif ( altitudeft > 32000 and altitudeft <= 43000 ) {
            me.vminkt = 400;
            me.vmaxkt = 520;
            me.altminft = 32000;
            me.altmaxft = 43000;
       }
       elsif ( altitudeft > 43000 and altitudeft <= 44000 ) {
            me.vminkt = 520;
            me.vmaxkt = 530;
            me.altminft = 43000;
            me.altmaxft = 44000;
        }
        elsif ( altitudeft > 44000 and altitudeft <= 51000 ) {
            me.find = "false";
            me.vmokt = 530;
        }
        elsif ( altitudeft > 51000 and altitudeft <= 60000 ) {
            me.vminkt = 530;
            me.vmaxkt = 430;
            me.altminft = 51000;
            me.altmaxft = 60000;
        }
        else {
            me.find = "false";
            me.vmokt = 430;
        }
   }
}


# ==============
# AIRSPEED METER
# ==============

Airspeed = {};

Airspeed.new = func {
   obj = { parents : [Airspeed],

           vmo : VMO.new(),

# slaves
           slave : [ nil ],
           altimeter : 0,
         };

   obj.init();

   return obj;
};

Airspeed.init = func {
   propname = getprop("/instrumentation/airspeed-indicator[0]/slave/altimeter");
   me.slave[me.altimeter] = props.globals.getNode(propname);
}

# maximum operating speed (kt)
Airspeed.schedule = func {
   altitudeft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
   if( altitudeft != nil ) {
       vmokt = me.vmo.schedule( altitudeft ) ;

       # captain + standby (?)
       setprop("/instrumentation/airspeed-indicator[0]/vmo-kt", vmokt);
       setprop("/instrumentation/airspeed-standby/vmo-kt", vmokt);

       # overspeed
       maxkt = vmokt + 10;
       setprop("/instrumentation/airspeed-indicator/overspeed-kt", maxkt);
   }
}  


# =================
# CENTER OF GRAVITY
# =================

CenterGravity= {};

CenterGravity.new = func {
   obj = { parents : [CenterGravity],

# slaves
           slave : [ nil ],
           mach : 0,

           weight : Weight.new(),

           C0stationin : 736.22,                   # 18.7 m from nose
           C0in : 1089,                            # C0  90'9"

           NONEMIN : 0.0,                          # 105 t curve is not complete
           NONEMAX : 100.0,                        # exterme forward cureve is not complete

# lowest CG
           find0 : "",
           corrmin0 : 0.0,
           corrmax0 : 0.0,
           machmin0 : 0.0,
           machmax0 : 0.0,
           cgmin0 : 0.0,
# CG
           find : "",
           corrmin : 0.0,
           corrmax : 0.0,
           machmin : 0.0,
           machmax : 0.0,
           cgmin : 0.0,
# forward CG
           cgmax : 0.0
         };

   obj.init();

   return obj;
};

CenterGravity.init = func {
   propname = getprop("/instrumentation/cg[0]/slave/mach");
   me.slave[me.mach] = props.globals.getNode(propname);
}

# center of gravity
CenterGravity.schedule = func {
   # many jbsim, when relocation of aircraft !
   fdms = props.globals.getNode("/fdm").getChildren("jsbsim");
   last = size(fdms) - 1;
   # not feet, inches !
   cgxin = fdms[last].getNode("inertia/cg-x-ft").getValue();
   # % of aerodynamic chord C0 (18.7 m from nose).
   cgxin = cgxin - me.C0stationin;
   setprop("/instrumentation/cg/cg-x-in", cgxin);
   # C0 = 90'9".
   cgfraction = cgxin / me.C0in;
   cgpercent = cgfraction * 100;
   setprop("/instrumentation/cg/percent", cgpercent);

   me.corridorcg();
}  

# normal below 105 t, extreme above 165 t
CenterGravity.min = func( speedmach ) {
    me.find0 = "true";

    if( speedmach <= 0.82 ) {
        me.find0 = "false";
        me.cgmin0 = me.NONEMIN;
    }
    elsif ( speedmach > 0.82 and speedmach <= 0.92 ) {
        me.corrmin0 = 52.0;
        me.corrmax0 = 53.5;
        me.machmin0 = 0.82;
        me.machmax0 = 0.92;
    }
    elsif ( speedmach > 0.92 and speedmach <= 1.15 ) {
        me.corrmin0 = 53.5;
        me.corrmax0 = 55.0;
        me.machmin0 = 0.92;
        me.machmax0 = 1.15;
    }
    elsif ( speedmach > 1.15 and speedmach <= 1.5 ) {
       me.corrmin0 = 55.0;
       me.corrmax0 = 56.5;
       me.machmin0 = 1.15;
       me.machmax0 = 1.5;
    }
    elsif ( speedmach > 1.5 and speedmach <= 2.2 ) {
       me.corrmin0 = 56.5;
       me.corrmax0 = 57.25;
       me.machmin0 = 1.5;
       me.machmax0 = 2.2;
    }
    else {
       me.find0 = "false";
       me.cgmin0 = 57.25;
    }
}

# extreme below 105 t 
CenterGravity.extrememin105t = func( weightlb, speedmach ) {
   me.find0 = "";

   if( weightlb < me.weight.WEIGHTMLAXLB ) {
       me.find0 = "true";
       if( speedmach <= 0.82 ) {
           me.find0 = "false";
           me.cgmin0 = 51.3;
       }
       elsif ( speedmach > 0.82 and speedmach <= 0.92 ) {
           me.corrmin0 = 51.3;
           me.corrmax0 = 53.0;
           me.machmin0 = 0.82;
           me.machmax0 = 0.92;
       }
       elsif ( speedmach > 0.92 and speedmach <= 1.15 ) {
           me.corrmin0 = 53.0;
           me.corrmax0 = 54.5;
           me.machmin0 = 0.92;
           me.machmax0 = 1.15;
       }
       elsif ( speedmach > 1.15 and speedmach <= 1.5 ) {
          me.corrmin0 = 54.5;
          me.corrmax0 = 56.0;
          me.machmin0 = 1.15;
          me.machmax0 = 1.5;
       }
       elsif ( speedmach > 1.5 and speedmach <= 2.2 ) {
          me.corrmin0 = 56.0;
          me.corrmax0 = 56.7;
          me.machmin0 = 1.5;
          me.machmax0 = 2.2;
       }
       else {
          me.find0 = "false";
          me.cgmin0 = 56.7;
       }
   }
}

# extreme above 165 t
CenterGravity.extrememin165t = func( weightlb, speedmach ) {
   me.find = "";

   if( weightlb > me.weight.WEIGHTMLAXLB ) {
       me.min( speedmach );
   }

   me.find = me.find0;
   me.corrmin = me.corrmin0;
   me.corrmax = me.corrmax0;
   me.machmin = me.machmin0;
   me.machmax = me.machmax0;
   me.cgmin = me.cgmin0;
}

# normal below 105 t
CenterGravity.min105t = func( weightlb, speedmach ) {
   me.find0 = "";

   if( weightlb < me.weight.WEIGHTMLAXLB ) {
       me.min( speedmach );
   }
}

# normal above 165 t
CenterGravity.min165t = func( weightlb, speedmach ) {
   me.find  = "";

   if( weightlb > me.weight.WEIGHTMINLB ) {
       me.find = "true";
       # at startup, speed may be negativ
       if( speedmach <= 0 ) {
           me.find = "false";
           me.cgmin = 51.8;
       }
       elsif( speedmach > 0 and speedmach <= 0.8 ) {
           me.find = "false";
           me.cgmin = 51.8;
       }
       elsif ( speedmach > 0.8 and speedmach <= 0.92 ) {
           me.corrmin = 51.8;
           me.corrmax = 54.0;
           me.machmin = 0.8;
           me.machmax = 0.92;
       }
       elsif ( speedmach > 0.92 and speedmach <= 1.15 ) {
           me.corrmin = 54.0;
           me.corrmax = 55.5;
           me.machmin = 0.92;
           me.machmax = 1.15;
       }
       elsif ( speedmach > 1.15 and speedmach <= 1.5 ) {
          me.corrmin = 55.5;
          me.corrmax = 57.0;
          me.machmin = 1.15;
          me.machmax = 1.5;
       }
       elsif ( speedmach > 1.5 and speedmach <= 2.2 ) {
          me.corrmin = 57.0;
          me.corrmax = 57.7;
          me.machmin = 1.5;
          me.machmax = 2.2;
       }
       else {
          me.find = "false";
          me.cgmin = 57.7;
       }
   }
}

# normal forward
CenterGravity.max = func( speedmach ) {
   me.find = "true";

   # at startup, speed may be negativ
   if( speedmach <= 0 ) {
     me.find = "false";
     me.cgmax = 53.8;
   }
   elsif( speedmach > 0 and speedmach <= 0.27 ) {
     me.find = "false";
     me.cgmax = 53.8;
   }
   elsif ( speedmach > 0.27 and speedmach <= 0.5 ) {
     me.corrmin = 53.8;
     me.corrmax = 54.0;
     me.machmin = 0.27;
     me.machmax = 0.5;
   }
   elsif ( speedmach > 0.5 and speedmach <= 0.94 ) {
     me.corrmin = 54.0;
     me.corrmax = 57.0;
     me.machmin = 0.5;
     me.machmax = 0.94;
   }
   elsif ( speedmach > 0.94 and speedmach <= 1.65 ) {
     me.corrmin = 57.0;
     me.corrmax = 59.3;
     me.machmin = 0.94;
     me.machmax = 1.65;
   }
   else {
     me.find = "false";
     me.cgmax = 59.3;
   }

   # Max performance Takeoff
   if( getprop("/instrumentation/cg/max-performance-to" ) ) {
       if( speedmach <= 0 ) {
           me.find = "false";
           me.cgmax = 54.2;
       }
       elsif( speedmach > 0 and speedmach <= 0.1 ) {
           me.find = "false";
           me.cgmax = 54.2;
       }
       elsif ( speedmach > 0.1 and speedmach <= 0.45 ) {
           me.find = "true";
           me.corrmin = 54.2;
           me.corrmax = 54.5;
           me.machmin = 0.1;
           me.machmax = 0.45;
       }
   }

   cgmax = me.interpolatemach( me.find, me.cgmax, me.corrmax, me.corrmin, me.machmax, me.machmin, speedmach );

   return cgmax;
}

# extreme forward
CenterGravity.extrememax = func( speedmach ) {
   me.find = "true";

   # defined only within a Mach range
   if( speedmach <= 0.45 ) {
     me.find = "false";
     me.cgmax = me.NONEMAX;
   }
   elsif ( speedmach > 0.45 and speedmach <= 0.5 ) {
     me.corrmin = 54.25;
     me.corrmax = 54.4;
     me.machmin = 0.45;
     me.machmax = 0.5;
   }
   elsif ( speedmach > 0.5 and speedmach <= 0.94 ) {
     me.corrmin = 54.4;
     me.corrmax = 57.25;
     me.machmin = 0.5;
     me.machmax = 0.94;
   }
   elsif ( speedmach > 0.94 and speedmach <= 1.6 ) {
     me.corrmin = 57.25;
     me.corrmax = 59.5;
     me.machmin = 0.94;
     me.machmax = 1.6;
   }
   else {
     me.find = "false";
     me.cgmax = me.NONEMAX;
   }

   cgmax = me.interpolatemach( me.find, me.cgmax, me.corrmax, me.corrmin, me.machmax, me.machmin, speedmach );

   return cgmax;
}

CenterGravity.interpolatemach = func( find, cg, corrmax, corrmin, machmax, machmin, speedmach ) {
   if( find == "true" ) {
     offsetcg = corrmax - corrmin;
     offsetmach = machmax - machmin;
     stepmach = speedmach - machmin;
     ratio = stepmach / offsetmach;
     stepcg = offsetcg * ratio;
     cg = corrmin + stepcg;
   }

   return cg;
}

CenterGravity.interpolate0 = func( speedmach ) {
   me.cgmin0 = me.interpolatemach( me.find0, me.cgmin0, me.corrmax0, me.corrmin0, me.machmax0, me.machmin0, speedmach );
}

CenterGravity.interpolate = func( speedmach ) {
   me.cgmin = me.interpolatemach( me.find, me.cgmin, me.corrmax, me.corrmin, me.machmax, me.machmin, speedmach );
}

# interpolate between 105 and 165 t
CenterGravity.interpolateweight = func( weightlb ) {
   if( weightlb > me.weight.WEIGHTMINLB and weightlb < me.weight.WEIGHTMLAXLB ) {
       if( me.cgmin0 != me.NONEMIN and me.cgmin != me.NONEMIN ) {
           offsetcg = me.cgmin - me.cgmin0;
           stepweight = weightlb - me.weight.WEIGHTMINLB;
           offsetweight = me.weight.WEIGHTMLAXLB - me.weight.WEIGHTMINLB;
           ratio = stepweight / offsetweight;
           stepcg = offsetcg * ratio;
           cgmin = me.cgmin0 + stepcg;
       }

       # impossible values
       elsif( me.cgmin0 == me.NONEMIN ) {
           cgmin = me.cgmin;
       }
       elsif( me.cgmin == me.NONEMIN ) {
           cgmin = me.cgmin0;
       }
   }
   elsif( weightlb <= me.weight.WEIGHTMINLB ) {
       cgmin = me.cgmin0;
   }
   else {
       cgmin = me.cgmin;
   }

   return cgmin;
}

# corridor of center of gravity
CenterGravity.corridorcg = func {
   weightlb = me.weight.getweightlb();

   speedmach = me.slave[me.mach].getChild("indicated-mach").getValue();

   # ===============
   # normal corridor
   # ===============
   me.min105t( weightlb, speedmach );
   me.interpolate0( speedmach );

   me.min165t( weightlb, speedmach );
   me.interpolate( speedmach );

   # interpolate between 105 and 165 t
   cgmin = me.interpolateweight( weightlb );


   # normal corridor maximum
   # ------------------------
   cgmax = me.max( speedmach );

   setprop("/instrumentation/cg/min-percent", cgmin);
   setprop("/instrumentation/cg/max-percent", cgmax);


   # ================
   # extreme corridor
   # ================
   # CAUTION : overwrites cgmin0 !!!
   me.extrememin165t( weightlb, speedmach );
   me.interpolate( speedmach );

   me.extrememin105t( weightlb, speedmach );
   me.interpolate0( speedmach );

   # interpolate between 105 and 165 t
   cgmin = me.interpolateweight( weightlb );


   # extreme corridor maximum
   # ------------------------
   cgmax = me.extrememax( speedmach );

   setprop("/instrumentation/cg/min-extreme-percent", cgmin);
   setprop("/instrumentation/cg/max-extreme-percent", cgmax);
}  


# ==========
# MACH METER
# ==========

Machmeter= {};

Machmeter.new = func {
   obj = { parents : [Machmeter],

           vmo : VMO.new(),
           weight : Weight.new(),

           MAXMMO : 2.04,

# lowest CG
           find0 : "",
           corrmin0 : 0.0,
           corrmax0 : 0.0,
           machmax0 : 0.0,
           cgmin0 : 0.0,
           cgmax0 : 0.0,
# CG
           find : "",
           corrmin : 0.0,
           corrmax : 0.0,
           machmax : 0.0,
           cgmin : 0.0,
           cgmax : 0.0,
# foward CG
           machmin : 0.0,

# slaves
           slave : [ nil, nil ],
           altimeter : 0,
           cg : 1
         };

   obj.init();

   return obj;
};

Machmeter.init = func {
   propname = getprop("/instrumentation/mach-indicator/slave/altimeter");
   me.slave[me.altimeter] = props.globals.getNode(propname);
   propname = getprop("/instrumentation/mach-indicator/slave/cg");
   me.slave[me.cg] = props.globals.getNode(propname);
}

Machmeter.interpolatecg = func( find, machmax, corrmax, corrmin, cgmax, cgmin, cgpercent ) {
   if( find == "true" ) {
     offsetmach = corrmax - corrmin;
     offsetcg = cgmax - cgmin;
     stepcg = cgpercent - cgmin;
     ratio = stepcg / offsetcg;
     stepmach = offsetmach * ratio;
     machmax = corrmin + stepmach;
   }

   return machmax;
}

# interpolate between 105 and 165 t
Machmeter.interpolateweight = func( weightlb, machmax, machmax0 ) {
   if( weightlb > me.weight.WEIGHTMINLB and weightlb < me.weight.WEIGHTMLAXLB ) {
       offsetmach = machmax - machmax0;
       stepweight = weightlb - me.weight.WEIGHTMINLB;
       offsetweight = me.weight.WEIGHTMLAXLB - me.weight.WEIGHTMINLB;
       ratio = stepweight / offsetweight;
       stepmach = offsetmach * ratio;
       machmax = machmax0 + stepmach;
   }
   elsif( weightlb <= me.weight.WEIGHTMINLB ) {
       machmax = machmax0;
   }

   return machmax;
}

# normal corridor below 105 t
Machmeter.max105t = func( weightlb, cgpercent ) {
   me.find0 = "";
   if( weightlb < me.weight.WEIGHTMLAXLB ) {
       me.find0 = "true";
       if( cgpercent <= 51.8 ) {
           me.find0 = "false";
           me.machmax0 = 0.82;
       }
       elsif ( cgpercent > 51.8 and cgpercent <= 53.5 ) {
           me.cgmin0 = 51.8;
           me.cgmax0 = 53.5;
           me.corrmin0 = 0.82;
           me.corrmax0 = 0.92;
       }
       elsif ( cgpercent > 53.5 and cgpercent <= 55.0 ) {
           me.cgmin0 = 53.5;
           me.cgmax0 = 55.0;
           me.corrmin0 = 0.92;
           me.corrmax0 = 1.15;
       }
       elsif ( cgpercent > 55.0 and cgpercent <= 56.5 ) {
          me.cgmin0 = 55.0;
          me.cgmax0 = 56.5;
          me.corrmin0 = 1.15;
          me.corrmax0 = 1.5;
       }
       elsif ( cgpercent > 56.5 and cgpercent <= 57.25 ) {
          me.cgmin0 = 56.5;
          me.cgmax0 = 57.25;
          me.corrmin0 = 1.5;
          me.corrmax0 = 2.2;
       }
       else {
          me.find0 = "false";
          me.machmax0 = 2.2;
       }
   }
}

# normal corridor above 165 t
Machmeter.max165t = func( weightlb, cgpercent ) {
   me.find  = "";
   if( weightlb > me.weight.WEIGHTMINLB ) {
       me.find  = "true";
       if( cgpercent <= 51.8 ) {
           me.find = "false";
           me.machmax = 0.8;
       }
       elsif ( cgpercent > 51.8 and cgpercent <= 54.0 ) {
           me.cgmin = 51.8;
           me.cgmax = 54.0;
           me.corrmin = 0.8;
           me.corrmax = 0.92;
       }
       elsif ( cgpercent > 54.0 and cgpercent <= 55.5 ) {
           me.cgmin = 54.0;
           me.cgmax = 55.5;
           me.corrmin = 0.92;
           me.corrmax = 1.15;
       }
       elsif ( cgpercent > 55.5 and cgpercent <= 57.0 ) {
          me.cgmin = 55.5;
          me.cgmax = 57.0;
          me.corrmin = 1.15;
          me.corrmax = 1.5;
       }
       elsif ( cgpercent > 57.0 and cgpercent <= 57.7 ) {
          me.cgmin = 57.0;
          me.cgmax = 57.7;
          me.corrmin = 1.5;
          me.corrmax = 2.2;
       }
       else {
          me.find = "false";
          me.machmax = 2.2;
       }
   }
}

Machmeter.min = func( cgpercent ) {
   me.find = "true";
   # at startup, speed may be negativ
   if( cgpercent <= 53.8 ) {
     me.find = "false";
     me.machmin = 0.0;
   }
   elsif ( cgpercent > 53.8 and cgpercent <= 54.0 ) {
     me.cgmin = 53.8;
     me.cgmax = 54.0;
     me.corrmin = 0.27;
     me.corrmax = 0.5;
   }
   elsif ( cgpercent > 54.0 and cgpercent <= 57.0 ) {
     me.cgmin = 54.0;
     me.cgmax = 57.0;
     me.corrmin = 0.5;
     me.corrmax = 0.94;
   }
   elsif ( cgpercent > 57.0 and cgpercent <= 59.3 ) {
     me.cgmin = 57.0;
     me.cgmax = 59.3;
     me.corrmin = 0.94;
     me.corrmax = 1.65;
   }
   else {
     me.find = "false";
     me.machmin = 1.65;
   }

   # Max performance Takeoff
   if( getprop("/instrumentation/cg/max-performance-to" ) ) {
       if( cgpercent <= 54.2 ) {
           me.find = "false";
           me.machmin = 0.0;
       }
       elsif ( cgpercent > 54.2 and cgpercent <= 54.5 ) {
           me.find = "true";
           me.cgmin = 54.2;
           me.cgmax = 54.5;
           me.corrmin = 0.1;
           me.corrmax = 0.45;
       }
   }
}

# speed of sound
Machmeter.getsoundkt = func {
   # simplification
   speedkt = noinstrument.get_speed_kt();
   if( speedkt > 50 ) {
       speedmach = noinstrument.get_mach();
       soundkt = speedkt / speedmach;
   }
   else {
       # speed of sound : v^2 = dP/dRo = gamma x R x T, where
       # P = pressure
       # Ro = density
       # gamma = cp/cv, ratio of specific heats
       # R = absolute gas constant
       # T = temperature
       TK = noinstrument.get_degc() + constant.CELSIUSTOK;
       dPdRoNewton = constant.Rpm2ps2pK * TK;
       dPdRo = constant.gammaairstp * dPdRoNewton;
       soundkt = math.sqrt(dPdRo) * constant.MPSTOKT;
   }

   return soundkt;
}

# Mach corridor
Machmeter.schedule = func {
   # =============
   # MMO
   # =============
   altitudeft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
   if( altitudeft != nil ) {
       vmokt = me.vmo.schedule( altitudeft ) ;

       # speed of sound
       soundkt = me.getsoundkt();

       # mach number
       mmomach = vmokt / soundkt;
       # MMO Mach 2.04
       if( mmomach > me.MAXMMO ) {
           mmomach = me.MAXMMO;
       }
       # always mach number (= makes the consumption constant)
       elsif( altitudeft >= constantaero.MAXCRUISEFT ) {
           mmomach = me.MAXMMO;
           vmokt = mmomach * soundkt;
       }

       setprop("/instrumentation/mach-indicator/mmo-mach", mmomach);

       # overspeed
       maxmach = mmomach + 0.04;
       setprop("/instrumentation/mach-indicator/overspeed-mach", maxmach);
   }


   cgpercent = me.slave[me.cg].getChild("percent").getValue();
   weightlb = me.weight.getweightlb();


   # ================
   # corridor maximum
   # ================
   me.max105t( weightlb, cgpercent );
   me.max165t( weightlb, cgpercent );

   machmax0 = me.interpolatecg( me.find0, me.machmax0, me.corrmax0, me.corrmin0, me.cgmax0, me.cgmin0, cgpercent );
   machmax = me.interpolatecg( me.find, me.machmax, me.corrmax, me.corrmin, me.cgmax, me.cgmin, cgpercent );

   # interpolate between 105 and 165 t
   machmax = me.interpolateweight( weightlb, machmax, machmax0 );


   # ================
   # corridor minimum
   # ================
   me.min( cgpercent );

   machmin = me.interpolatecg( me.find, me.machmin, me.corrmax, me.corrmin, me.cgmax, me.cgmin, cgpercent );

   setprop("/instrumentation/mach-indicator/min", machmin);
   setprop("/instrumentation/mach-indicator/max", machmax);
}


# ======
# WEIGHT
# ======
Weight = {};

Weight.new = func {
   obj = { parents : [Weight],
           WEIGHTMINLB : 0,
           WEIGHTMLAXLB : 0
         };

    obj.init();

   return obj;
};

Weight.init = func {
   me.WEIGHTMINLB = 105 * constant.TONTOLB;
   me.WEIGHTMLAXLB = 165 * constant.TONTOLB;
}

Weight.getweightlb = func {
   # many jbsim, when relocation of aircraft !
   fdms = props.globals.getNode("/fdm").getChildren("jsbsim");
   last = size(fdms) - 1;

   weightlb = fdms[last].getNode("inertia/weight-lbs").getValue();
   return weightlb;
}


# ==========================
# INERTIAL NAVIGATION SYSTEM
# ==========================

Inertial = {};

Inertial.new = func {
   obj = { parents : [Inertial],

           electricalsystem : nil,

           MAXXTKNM : 999.99,
           bearingdeg : 0.0,
           waypoint : ""
         };
   return obj;
};

Inertial.set_relation = func( electrical ) {
   me.electricalsystem = electrical;
}

Inertial.track = func {
   # new waypoint
   id = getprop("/autopilot/route-manager/wp[0]/id");
   if( id != me.waypoint and id != nil ) {
       me.waypoint = id;

       # initial track
       me.bearingdeg = getprop("/autopilot/settings/true-heading-deg");
       setprop("/instrumentation/ins/leg-true-course-deg",me.bearingdeg);
   }

   # deviation from initial track
   if( me.waypoint != "" ) {
       truedeg = getprop("/autopilot/settings/true-heading-deg");
       offsetdeg = truedeg - me.bearingdeg;
       offsetdeg = constant.crossnorth( offsetdeg );

       distancenm = getprop("/autopilot/route-manager/wp/dist");
       offsetrad = offsetdeg * constant.DEGTORAD;
       offsetnm = math.sin( offsetrad ) * distancenm;

       if( offsetnm > me.MAXXTKNM ) {
           offsetnm = me.MAXXTKNM;
       }
       elsif( offsetnm < - me.MAXXTKNM ) {
           offsetnm = - me.MAXXTKNM;
       }

       setprop("/instrumentation/ins/leg-course-deviation-deg",offsetdeg);
       setprop("/instrumentation/ins/leg-course-error-nm",offsetnm);
   }
}

# ins fuel (not real, for FDM debug)
Inertial.fuel = func {
   groundfps = getprop("/instrumentation/ins/ground-speed-fps");
   groundkt = groundfps * constant.FPSTOKT;
   if( groundkt != nil ) {
       # subsonic average
       if( groundkt < 100 ) {
           groundkt = 480;
           kgph = 20000;
       }
       else {
           kgph = getprop("/instrumentation/fuel/fuel-flow-kg_ph");
       }
       waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
       distnm = waypoints[0].getChild("dist").getValue();
       # waypoint
       if( distnm != nil ) {
           totalkg = getprop("/instrumentation/fuel/total-kg");
           ratio = distnm / groundkt;
           fuelkg = kgph * ratio;
           fuelkg = totalkg - fuelkg;
           if( fuelkg < 0 ) {
               fuelkg = 0;
           }
           waypoints[0].getChild("fuel-kg").setValue(fuelkg);
           # next
           distnm = waypoints[1].getChild("dist").getValue();
           if( distnm != nil ) {
               ratio = distnm / groundkt;
               fuelkg = kgph * ratio;
               fuelkg = totalkg - fuelkg;
               if( fuelkg < 0 ) {
                   fuelkg = 0;
               }
               waypoints[1].getChild("fuel-kg").setValue(fuelkg);
               # last
               distnm = getprop("/autopilot/route-manager/wp-last/dist"); 
               if( distnm != nil ) {
                   ratio = distnm / groundkt;
                   fuelkg = kgph * ratio;
                   fuelkg = totalkg - fuelkg;
                   if( fuelkg < 0 ) {
                       fuelkg = 0;
                   }
                   setprop("/autopilot/route-manager/wp-last/fuel-kg",fuelkg);
               }
           }
       }
   } 
}

Inertial.slowschedule = func {
   if( me.electricalsystem.has_specific() ) {
       me.fuel();
   } 
}

Inertial.schedule = func {
   if( me.electricalsystem.has_specific() ) {
       me.track();
   } 
}


# ===========
# TEMPERATURE
# ===========

Temperature = {};

Temperature.new = func {
   obj = { parents : [Temperature],

           electricalsystem : nil,

# slaves
           slave : [ nil ],
           altimeter : 0
         };

   obj.init();

   return obj;
};

Temperature.init = func {
   propname = getprop("/instrumentation/temperature/slave/altimeter");
   me.slave[me.altimeter] = props.globals.getNode(propname);
}

Temperature.set_relation = func( electrical ) {
   me.electricalsystem = electrical;
}

# International Standard Atmosphere temperature
Temperature.isa = func {
   altft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue(); 
   altmeter = altft * constant.FEETTOMETER;

   # guess below sea level
   found = "true";
   if( altmeter <= 0 ) {
      found = "false";
      isadegc = 15.0;
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
       found = "false";
       # factor 0.75 (stratosphere)
       isadegc = -57.0;
   }
   else {
       found = "false";
       # overflow
       isadegc = -57.0;
   }

   if( found == "true" ) {
       delta = minfactor - maxfactor;
       deltameter = altmeter - minmeter;
       coeff = deltameter / 900 ;
       factor = maxfactor + delta * coeff;
       # 15 degc at sea level
       isadegk = (constant.CELSIUSTOK + 15) * factor;
       isadegc = isadegk - constant.CELSIUSTOK;
   }

   setprop("/instrumentation/temperature/isa-degc",isadegc);
}

# total maximum temperature
Temperature.tmo = func {
   # TMO 127C at Mach 2.02 :
   # - cold atmosphere : static temperature < -55C.
   # - hot atmosphere : static temperature > -51C (Max Cruise mode).
   #
   # linear is supposed
   speedmach = noinstrument.get_mach();
   if( speedmach >= 1.0 ) {
       stepmach = 2.02 - speedmach;
       deltamach = 2.02 - 1.0;
       deltadegc = 127 - ( - 53 );
       tmodegc = oatdegc + deltadegc * ( 1 - stepmach / deltamach );
    }
   else {
       tmodegc = oatdegc;
   }
   setprop("/instrumentation/temperature/indicated-tmo-degc",tmodegc);
}

# maximum total temperature
Temperature.schedule = func {
   if( me.electricalsystem.has_specific() ) {
# relies on JSBSim
#       me.tmo();
        me.isa();
   }
}


# =============
# MARKER BEACON
# =============

Markerbeacon = {};

Markerbeacon.new = func {
   obj = { parents : [Markerbeacon]
         };
   return obj;
};

# test of marker beacon lights
Markerbeacon.testexport = func {
   testmarker();
}

# cannot make a settimer on class member
testmarker = func {
   outer = getprop("/instrumentation/marker-beacon/test-outer");
   middle = getprop("/instrumentation/marker-beacon/test-middle");
   inner = getprop("/instrumentation/marker-beacon/test-inner");
   if( ( outer == nil or outer != "on" ) and ( middle == nil or middle != "on") and
       ( inner == nil or inner != "on" ) ) {
       setprop("/instrumentation/marker-beacon/test-outer","on");
       end = "false";
   }
   elsif( outer == "on" ) {
       setprop("/instrumentation/marker-beacon/test-outer","");
       setprop("/instrumentation/marker-beacon/test-middle","on");
       end = "false";
   }
   elsif( middle == "on" ) {
       setprop("/instrumentation/marker-beacon/test-middle","");
       setprop("/instrumentation/marker-beacon/test-inner","on");
       end = "false";
   }
   else  {
       setprop("/instrumentation/marker-beacon/test-inner","");
       end = "true";
   }

   # re-schedule the next call
   if( end == "false" ) {
       settimer(testmarker, 1.5);
   }
}


# =======
# GENERIC
# =======

Generic = {};

Generic.new = func {
   obj = { parents : [Generic],
           generic : aircraft.light.new("/instrumentation/generic",[1.5,0.2])
         };

   obj.generic.toggle();

   return obj;
};


# =============
# NO INSTRUMENT
# =============

NoInstrument = {};

NoInstrument.new = func {
   obj = { parents : [NoInstrument],
         };
   return obj;
}

# document the absence of instrument
NoInstrument.get_agl_ft = func {
   aglft = getprop("/position/altitude-agl-ft");
   return aglft;
}

NoInstrument.get_altitude_ft = func {
   altft = getprop("/position/altitude-ft");
   return altft;
}

NoInstrument.get_speed_kt = func {
   speedkt = getprop("velocities/airspeed-kt");
   return speedkt;
}

NoInstrument.get_mach = func {
   speedmach = getprop("velocities/mach");
   return speedmach;
}
 
NoInstrument.get_degc = func {
   degc = getprop("/environment/temperature-degc");
   return degc;
}
 
NoInstrument.get_sea_inhg = func {
   seainhg = getprop("/environment/pressure-sea-level-inhg");
   return seainhg;
}


# =====
# DOORS
# =====

Doors = {};

Doors.new = func {
   obj = { parents : [Doors],
# door closed
           flightdeck : aircraft.door.new("controls/doors/flight-deck", 10.0),
# deck out
           engineerdeck : aircraft.door.new("controls/doors/engineer-deck", 4.0)
         };

# user customization
   obj.init();

   return obj;
};

Doors.init = func {
   if( !getprop("/controls/doors/flight-deck/closed") ) {
       me.flightdeck.toggle();
   }
   if( !getprop("/controls/doors/engineer-deck/out") ) {
       me.engineerdeck.toggle();
   }
}

Doors.flightdeckexport = func {
   me.flightdeck.toggle();
}

Doors.engineerdeckexport = func {
   me.engineerdeck.toggle();
}


# ====
# TCAS
# ====

Traffic = {};

Traffic.new = func {
   obj = { parents : [Traffic],

           aircrafts : nil,
           traffics : nil,
           nbtraffics : 0,

           NOTRAFFIC : 9999,

           electricalsystem : nil,

# slaves
           slave : [ nil ],
           altimeter : 0
         };

   obj.init();

   return obj;
};

Traffic.set_relation = func( electrical ) {
   me.electricalsystem = electrical;
}

Traffic.init = func {
   propname = getprop("/instrumentation/tcas/slave/altimeter");
   me.slave[me.altimeter] = props.globals.getNode(propname);

   me.aircrafts = props.globals.getNode("/ai/models").getChildren("aircraft");
   me.traffics = props.globals.getNode("/instrumentation/tcas/traffics").getChildren("traffic");

   me.clear();
}

Traffic.clear = func {
   for( i=me.nbtraffics; i < size(me.traffics); i=i+1 ) {
        me.traffics[i].getNode("distance-nm").setValue(me.NOTRAFFIC);
   }
}

# tcas
Traffic.schedule = func {
   me.nbtraffics = 0;

   if( me.electricalsystem.has_specific() ) {
       if( getprop("/instrumentation/tcas/serviceable") ) {
           altitudeft = me.slave[me.altimeter].getChild("indicated-altitude-ft").getValue();
           if( altitudeft == nil ) {
               altitudeft = 0.0;
           }

           for( i=0; i < size(me.aircrafts); i=i+1 ) {
                # instrument limitation
                if( me.nbtraffics < size(me.traffics) ) {
                    # destroyed aircraft
                    if( me.aircrafts[i] != nil ) {
                        radarinrange = me.aircrafts[i].getNode("radar/in-range",1).getValue();
                        if( radarinrange ) {
                            rangenm = me.aircrafts[i].getNode("radar/range-nm").getValue();
                            me.traffics[me.nbtraffics].getNode("distance-nm").setValue(rangenm);
                            # relative altitude
                            levelft = me.aircrafts[i].getNode("position/altitude-ft").getValue();
                            levelft = levelft - altitudeft;
                            me.traffics[me.nbtraffics].getNode("level-ft",1).setValue(levelft);
                            xshift = me.aircrafts[i].getNode("radar/x-shift").getValue();
                            me.traffics[me.nbtraffics].getNode("x-shift",1).setValue(xshift);
                            yshift = me.aircrafts[i].getNode("radar/y-shift").getValue();
                            me.traffics[me.nbtraffics].getNode("y-shift",1).setValue(yshift);
                            rotation = me.aircrafts[i].getNode("radar/rotation").getValue();
                            me.traffics[me.nbtraffics].getNode("rotation",1).setValue(rotation);
                            me.traffics[me.nbtraffics].getNode("index",1).setValue(i);
                            me.nbtraffics = me.nbtraffics + 1;
                        }
                    }
               }
           }
       }
   }

   # no traffic
   me.clear();
   setprop("/instrumentation/tcas/nb-traffics",me.nbtraffics);
}
