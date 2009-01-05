# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ===
# VMO
# ===

VMO = {};

VMO.new = func {
   var obj = { parents : [VMO],

           Talt105ft : [ 0, 4500, 6000, 34500, 43000, 44000, 51000, 60000 ],
           Talt165ft : [ 0, 4000, 6000, 32000, 43000, 44000, 51000, 60000 ],
           Tspeed105kt : [ 300, 385, 390, 390, 520, 530, 530, 430 ],
           Tspeed165kt : [ 300, 395, 400, 400, 520, 530, 530, 430 ],

           CEILING : 7,
           UNDERSEA : 0,

           weightlb : 0.0,

# lowest CG
           find0 : constant.FALSE,
           vminkt0 : 0.0,
           vmaxkt0 : 0.0,
           altminft0 : 0.0,
           altmaxft0 : 0.0,
           vmokt0 : 0.0,
# CG
           find : constant.FALSE,
           vminkt : 0.0,
           vmaxkt : 0.0,
           altminft : 0.0,
           altmaxft : 0.0,
           vmokt : 0.0
         };

   obj.init();

   return obj;
};

VMO.init = func {
}

VMO.getvmokt = func( altitudeft, acweightlb ) {
   me.weightlb = acweightlb;

   me.speed105t( altitudeft );
   me.speed165t( altitudeft );

   var vmokt0 = me.interpolatealtitude0( altitudeft );
   var vmokt = me.interpolatealtitude( altitudeft );

   # interpolate between 105 and 165 t
   vmokt = constantaero.interpolateweight( me.weightlb, vmokt, vmokt0 );

   return vmokt;
}  

VMO.interpolatealtitude0 = func( altitudeft ) {
   var vmokt = constantaero.interpolate( me.find0, me.vmokt0, me.vmaxkt0, me.vminkt0,
                                         me.altmaxft0, me.altminft0, altitudeft );

   return vmokt;
}

VMO.interpolatealtitude = func( altitudeft ) {
   var vmokt = constantaero.interpolate( me.find, me.vmokt, me.vmaxkt, me.vminkt,
                                         me.altmaxft, me.altminft, altitudeft );

   return vmokt;
}

# below 105 t
VMO.speed105t = func( altitudeft ) {
   me.find0 = constant.FALSE;

   if( !constantaero.weight_above( me.weightlb ) ) {
       me.find0 = constant.TRUE;

       # at startup, altitude may be negativ
       if( altitudeft <= me.Talt105ft[me.UNDERSEA] ) {
           me.find0 = constant.FALSE;
           me.vmokt0 = me.Tspeed105kt[me.UNDERSEA];
       }

       elsif( altitudeft > me.Talt105ft[me.CEILING] ) {
           me.find0 = constant.FALSE;
           me.vmokt0 = me.Tspeed105kt[me.CEILING];
       }

       else {
           var j = 0;

           for( var i = 0; i < me.CEILING; i = i+1 ) {
                j = i+1;

                if( altitudeft > me.Talt105ft[i] and altitudeft <= me.Talt105ft[j] ) {
                    me.vminkt0 = me.Tspeed105kt[i];
                    me.vmaxkt0 = me.Tspeed105kt[j];
                    me.altminft0 = me.Talt105ft[i];
                    me.altmaxft0 = me.Talt105ft[j];

                    break;
                }
           }
       }
   }
}

# above 165 t
VMO.speed165t = func( altitudeft ) {
   me.find = constant.FALSE;

   if( !constantaero.weight_below( me.weightlb ) ) {
       me.find  = constant.TRUE;

       # at startup, altitude may be negativ
       if( altitudeft <= me.Talt165ft[me.UNDERSEA] ) {
           me.find = constant.FALSE;
           me.vmokt = me.Tspeed165kt[me.UNDERSEA];
       }

       elsif( altitudeft > me.Talt165ft[me.CEILING] ) {
           me.find = constant.FALSE;
           me.vmokt = me.Tspeed165kt[me.CEILING];
       }

       else {
           var j = 0;

           for( var i = 0; i < me.CEILING; i = i+1 ) {
                j = i+1;

                if( altitudeft > me.Talt165ft[i] and altitudeft <= me.Talt165ft[j] ) {
                    me.vminkt = me.Tspeed165kt[i];
                    me.vmaxkt = me.Tspeed165kt[j];
                    me.altminft = me.Talt165ft[i];
                    me.altmaxft = me.Talt165ft[j];

                    break;
                }
           }
       }
   }
}


# ==============
# AIRSPEED METER
# ==============

Airspeed = {};

Airspeed.new = func {
   var obj = { parents : [Airspeed,System],

               vmo : VMO.new()
         };

   obj.init();

   return obj;
};

Airspeed.init = func {
   me.inherit_system("/instrumentation/airspeed-indicator[0]");
}

# maximum operating speed (kt)
Airspeed.schedule = func {
   var weightlb = 0.0;
   var vmokt = 0.0;
   var altitudeft = me.noinstrument["altitude"].getValue();

   if( altitudeft != nil ) {
       weightlb = me.dependency["weight"].getChild("weight-lb").getValue();
       vmokt = me.vmo.getvmokt( altitudeft, weightlb ) ;

       # captain
       me.itself["root"].getChild("vmo-kt").setValue(vmokt);
   }
}  


# =================
# CENTER OF GRAVITY
# =================

Centergravity= {};

Centergravity.new = func {
   var obj = { parents : [Centergravity,System],

           C0stationin : 736.22,                   # 18.7 m from nose
           C0in : 1089,                            # C0  90'9"

           NONEMIN : 0.0,                          # 105 t curve is not complete
           NONEMAX : 100.0,                        # exterme forward cureve is not complete

# lowest CG
           find0 : constant.FALSE,
           corrmin0 : 0.0,
           corrmax0 : 0.0,
           machmin0 : 0.0,
           machmax0 : 0.0,
           cgmin0 : 0.0,

# CG
           find : constant.FALSE,
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

Centergravity.init = func {
   me.inherit_system("/instrumentation/cg[0]");
}

Centergravity.red_cg = func {
   var result = constant.FALSE;
   var percent = me.itself["root"].getChild("percent").getValue();

   if( percent <= me.itself["root"].getChild("min-percent").getValue() or
       percent >= me.itself["root"].getChild("max-percent").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Centergravity.takeoffexport = func {
   me.schedule();
}

Centergravity.schedule = func {
   var cgfraction = 0.0;
   var cgpercent = 0.0;
   var cgxin = me.itself["root"].getChild("cg-x-in").getValue();

   # % of aerodynamic chord C0 (18.7 m from nose).
   cgxin = cgxin - me.C0stationin;
   me.itself["root"].getChild("cg-c0-in").setValue(cgxin);

   # C0 = 90'9".
   cgfraction = cgxin / me.C0in;
   cgpercent = cgfraction * 100;
   me.itself["root"].getChild("percent").setValue(cgpercent);

   me.corridorcg();
}  

# corridor of center of gravity
Centergravity.corridorcg = func {
   var cgmin = 0.0;
   var cgmax = 0.0;
   var weightlb = me.dependency["weight"].getChild("weight-lb").getValue();
   var speedmach = me.dependency["mach"].getChild("indicated-mach").getValue();

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

   me.itself["root"].getChild("min-percent").setValue(cgmin);
   me.itself["root"].getChild("max-percent").setValue(cgmax);


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

   me.itself["root"].getChild("min-extreme-percent").setValue(cgmin);
   me.itself["root"].getChild("max-extreme-percent").setValue(cgmax);
}  

# normal below 105 t, extreme above 165 t
Centergravity.min = func( speedmach ) {
    me.find0 = constant.TRUE;

    if( speedmach <= constantaero.T105mach[constantaero.CGREST] ) {
        me.find0 = constant.FALSE;
        me.cgmin0 = me.NONEMIN;
    }

    elsif( speedmach > constantaero.T105mach[constantaero.CG105] ) {
       me.find0 = constant.FALSE;
       me.cgmin0 = constantaero.Tcgmin105[constantaero.CG105];
    }

    else {
       var j = 0;

       for( var i = 0; i < constantaero.CG105; i = i+1 ) {
            j = i+1;

            if( speedmach > constantaero.T105mach[i] and speedmach <= constantaero.T105mach[j] ) {
                me.corrmin0 = constantaero.Tcgmin105[i];
                me.corrmax0 = constantaero.Tcgmin105[j];
                me.machmin0 = constantaero.T105mach[i];
                me.machmax0 = constantaero.T105mach[j];

                break;
            }
       }
    }
}

# extreme below 105 t 
Centergravity.extrememin105t = func( weightlb, speedmach ) {
   me.find0 = constant.FALSE;

   if( !constantaero.weight_above( weightlb ) ) {
       me.find0 = constant.TRUE;

       if( speedmach <= constantaero.T105mach[constantaero.CGREST] ) {
           me.find0 = constant.FALSE;
           me.cgmin0 = constantaero.Tcgmin105ext[constantaero.CGREST];
       }

       elsif( speedmach > constantaero.T105mach[constantaero.CG105] ) {
           me.find0 = constant.FALSE;
           me.cgmin0 = constantaero.Tcgmin105ext[constantaero.CG105];
       }

       else {
          var j = 0;

          for( var i = 0; i < constantaero.CG105; i = i+1 ) {
               j = i+1;

               if( speedmach > constantaero.T105mach[i] and speedmach <= constantaero.T105mach[j] ) {
                   me.corrmin0 = constantaero.Tcgmin105ext[i];
                   me.corrmax0 = constantaero.Tcgmin105ext[j];
                   me.machmin0 = constantaero.T105mach[i];
                   me.machmax0 = constantaero.T105mach[j];

                   break;
               }
          }
       }
   }
}

# extreme above 165 t
Centergravity.extrememin165t = func( weightlb, speedmach ) {
   me.find = constant.FALSE;

   if( constantaero.weight_above( weightlb ) ) {
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
Centergravity.min105t = func( weightlb, speedmach ) {
   me.find0 = constant.FALSE;

   if( !constantaero.weight_above( weightlb ) ) {
       me.min( speedmach );
   }
}

# normal above 165 t
Centergravity.min165t = func( weightlb, speedmach ) {
   me.find  = constant.FALSE;

   if( !constantaero.weight_below( weightlb ) ) {
       me.find = constant.TRUE;

       # at startup, speed may be negativ
       if( speedmach <= constantaero.T165mach[constantaero.CGREST] ) {
           me.find = constant.FALSE;
           me.cgmin = constantaero.Tcgmin165[constantaero.CGREST];
       }

       elsif( speedmach > constantaero.T165mach[constantaero.CG165] ) {
           me.find = constant.FALSE;
           me.cgmin = constantaero.Tcgmin165[constantaero.CG165];
       }

       else {
          var j = 0;

          for( var i = 0; i < constantaero.CG165; i = i+1 ) {
               j = i+1;

               if( speedmach > constantaero.T165mach[i] and speedmach <= constantaero.T165mach[j] ) {
                   me.corrmin = constantaero.Tcgmin165[i];
                   me.corrmax = constantaero.Tcgmin165[j];
                   me.machmin = constantaero.T165mach[i];
                   me.machmax = constantaero.T165mach[j];

                   break;
               }
          }
       }
   }
}

# normal forward
Centergravity.max = func( speedmach ) {
   var cgmax = 0.0;

   me.find = constant.TRUE;

   # at startup, speed may be negativ
   if( speedmach <= constantaero.Tmaxmach[constantaero.CGREST] ) {
       me.find = constant.FALSE;
       me.cgmax = constantaero.Tcgmax[constantaero.CGREST];
   }

   elsif( speedmach > constantaero.Tmaxmach[constantaero.CGMAX] ) {
      me.find = constant.FALSE;
      me.cgmax = constantaero.Tcgmax[constantaero.CGMAX];
   }

   else {
      var j = 0;

      for( var i = 0; i < constantaero.CGMAX; i = i+1 ) {
           j = i+1;

           if( speedmach > constantaero.Tmaxmach[i] and speedmach <= constantaero.Tmaxmach[j] ) {
               me.corrmin = constantaero.Tcgmax[i];
               me.corrmax = constantaero.Tcgmax[j];
               me.machmin = constantaero.Tmaxmach[i];
               me.machmax = constantaero.Tmaxmach[j];

               break;
           }
      }
   }

   # Max performance Takeoff
   if( me.itself["root"].getChild("max-performance-to" ).getValue() ) {
       if( speedmach <= constantaero.Tperfmach[constantaero.CGREST] ) {
           me.find = constant.FALSE;
           me.cgmax = constantaero.Tcgperf[constantaero.CGREST];
       }

       else {
           var j = 0;

           for( var i = 0; i < constantaero.CGPERF; i = i+1 ) {
                j = i+1;

                if( speedmach > constantaero.Tperfmach[i] and speedmach <= constantaero.Tperfmach[j] ) {
                    me.corrmin = constantaero.Tcgperf[i];
                    me.corrmax = constantaero.Tcgperf[j];
                    me.machmin = constantaero.Tperfmach[i];
                    me.machmax = constantaero.Tperfmach[j];

                    break;
                }
           }
       }
   }

   cgmax = constantaero.interpolate( me.find, me.cgmax, me.corrmax, me.corrmin,
                                     me.machmax, me.machmin, speedmach );

   return cgmax;
}

# extreme forward
Centergravity.extrememax = func( speedmach ) {
   var cgmax = 0.0;

   me.find = constant.TRUE;

   # defined only within a Mach range
   if( speedmach <= constantaero.Tmaxextmach[constantaero.CGREST] ) {
       me.find = constant.FALSE;
       me.cgmax = me.NONEMAX;
   }

   elsif( speedmach > constantaero.Tmaxextmach[constantaero.CGMAXEXT] ) {
      me.find = constant.FALSE;
      me.cgmax = me.NONEMAX;
   }

   else {
      var j = 0;

      for( var i = 0; i < constantaero.CGMAXEXT; i = i+1 ) {
           j = i+1;

           if( speedmach > constantaero.Tmaxextmach[i] and speedmach <= constantaero.Tmaxextmach[j] ) {
               me.corrmin = constantaero.Tcgmaxext[i];
               me.corrmax = constantaero.Tcgmaxext[j];
               me.machmin = constantaero.Tmaxextmach[i];
               me.machmax = constantaero.Tmaxextmach[j];

               break;
           }
      }
   }

   cgmax = constantaero.interpolate( me.find, me.cgmax, me.corrmax, me.corrmin,
                                     me.machmax, me.machmin, speedmach );

   return cgmax;
}

Centergravity.interpolate0 = func( speedmach ) {
   me.cgmin0 = constantaero.interpolate( me.find0, me.cgmin0, me.corrmax0, me.corrmin0,
                                         me.machmax0, me.machmin0, speedmach );
}

Centergravity.interpolate = func( speedmach ) {
   me.cgmin = constantaero.interpolate( me.find, me.cgmin, me.corrmax, me.corrmin,
                                        me.machmax, me.machmin, speedmach );
}

# interpolate between 105 and 165 t
Centergravity.interpolateweight = func( weightlb ) {
   var cgmin = me.cgmin;

   if( constantaero.weight_inside( weightlb ) ) {
       if( me.cgmin0 != me.NONEMIN and me.cgmin != me.NONEMIN ) {
           cgmin = constantaero.interpolate_weight( weightlb, me.cgmin, me.cgmin0 );
       }

       # impossible values
       elsif( me.cgmin0 == me.NONEMIN ) {
           cgmin = me.cgmin;
       }
       elsif( me.cgmin == me.NONEMIN ) {
           cgmin = me.cgmin0;
       }
   }
   elsif( constantaero.weight_below( weightlb ) ) {
       cgmin = me.cgmin0;
   }

   return cgmin;
}


# ==========
# MACH METER
# ==========

Machmeter= {};

Machmeter.new = func {
   var obj = { parents : [Machmeter,System],

           vmo : VMO.new(),

           MAXMMO : 2.04,
           GROUNDKT : 50.0,

# lowest CG
           find0 : constant.FALSE,
           corrmin0 : 0.0,
           corrmax0 : 0.0,
           machmax0 : 0.0,
           cgmin0 : 0.0,
           cgmax0 : 0.0,
# CG
           find : constant.FALSE,
           corrmin : 0.0,
           corrmax : 0.0,
           machmax : 0.0,
           cgmin : 0.0,
           cgmax : 0.0,
# foward CG
           machmin : 0.0
         };

   obj.init();

   return obj;
};

Machmeter.init = func {
   me.inherit_system("/instrumentation/mach-indicator");
}

# Mach corridor
Machmeter.schedule = func {
   var vmokt = 0.0;
   var soundkt = 0.0;
   var mmomach = 0.0;
   var cgpercent = 0.0;
   var machmax = 0.0;
   var machmax0 = 0.0;
   var machmin = 0.0;
   var weightlb = me.dependency["weight"].getChild("weight-lb").getValue();
   var altitudeft = me.dependency["altimeter"].getChild("indicated-altitude-ft").getValue();

   # ===
   # MMO
   # ===
   if( altitudeft != nil ) {
       vmokt = me.vmo.getvmokt( altitudeft, weightlb ) ;

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

       me.itself["root"].getChild("mmo-mach").setValue(mmomach);
   }


   # ================
   # corridor maximum
   # ================
   cgpercent = me.dependency["cg"].getChild("percent").getValue();

   me.max105t( weightlb, cgpercent );
   me.max165t( weightlb, cgpercent );

   machmax0 = constantaero.interpolate( me.find0, me.machmax0, me.corrmax0, me.corrmin0, me.cgmax0, me.cgmin0, cgpercent );
   machmax = constantaero.interpolate( me.find, me.machmax, me.corrmax, me.corrmin, me.cgmax, me.cgmin, cgpercent );

   # interpolate between 105 and 165 t
   machmax = constantaero.interpolateweight( weightlb, machmax, machmax0 );


   # ================
   # corridor minimum
   # ================
   me.min( cgpercent );

   machmin = constantaero.interpolate( me.find, me.machmin, me.corrmax, me.corrmin, me.cgmax, me.cgmin, cgpercent );

   me.itself["root"].getChild("min").setValue(machmin);
   me.itself["root"].getChild("max").setValue(machmax);
}

# normal corridor below 105 t
Machmeter.max105t = func( weightlb, cgpercent ) {
   me.find0 = constant.FALSE;

   if( !constantaero.weight_above( weightlb ) ) {
       me.find0 = constant.TRUE;

       if( cgpercent <= constantaero.Tcgmin105[constantaero.CGREST] ) {
           me.find0 = constant.FALSE;
           me.machmax0 = constantaero.T105mach[constantaero.CGREST];
       }

       elsif( cgpercent > constantaero.Tcgmin105[constantaero.CG105] ) {
          me.find0 = constant.FALSE;
          me.machmax0 = constantaero.T105mach[constantaero.CG105];
       }

       else {
          var j = 0;

          for( var i = 0; i < constantaero.CG105; i = i+1 ) {
               j = i+1;

               if( cgpercent > constantaero.Tcgmin105[i] and cgpercent <= constantaero.Tcgmin105[j] ) {
                   me.cgmin0 = constantaero.Tcgmin105[i];
                   me.cgmax0 = constantaero.Tcgmin105[j];
                   me.corrmin0 = constantaero.T105mach[i];
                   me.corrmax0 = constantaero.T105mach[j];

                   break;
               }
          }
       }
   }
}

# normal corridor above 165 t
Machmeter.max165t = func( weightlb, cgpercent ) {
   me.find  = constant.FALSE;

   if( !constantaero.weight_below( weightlb ) ) {
       me.find  = constant.TRUE;

       if( cgpercent <= constantaero.Tcgmin165[constantaero.CGFLY] ) {
           me.find = constant.FALSE;
           me.machmax = constantaero.T165mach[constantaero.CGFLY];
       }

       elsif( cgpercent > constantaero.Tcgmin165[constantaero.CG165] ) {
          me.find = constant.FALSE;
          me.machmax = constantaero.T165mach[constantaero.CG165];
       }

       else {
          var j = 0;

          for( var i = constantaero.CGFLY; i < constantaero.CG165; i = i+1 ) {
               j = i+1;

               if( cgpercent > constantaero.Tcgmin165[i] and cgpercent <= constantaero.Tcgmin165[j] ) {
                   me.cgmin = constantaero.Tcgmin165[i];
                   me.cgmax = constantaero.Tcgmin165[j];
                   me.corrmin = constantaero.T165mach[i];
                   me.corrmax = constantaero.T165mach[j];

                   break;
               }
          }
       }
   }
}

Machmeter.min = func( cgpercent ) {
   me.find = constant.TRUE;

   # at startup, speed may be negativ
   if( cgpercent <= constantaero.Tcgmax[constantaero.CGREST] ) {
       me.find = constant.FALSE;
       me.machmin = constantaero.Tmaxmach[constantaero.CGREST];
   }

   elsif( cgpercent > constantaero.Tcgmax[constantaero.CGMAX] ) {
      me.find = constant.FALSE;
      me.machmin = constantaero.Tmaxmach[constantaero.CGMAX];
   }

   else {
      var j = 0;

      for( var i = 0; i < constantaero.CGMAX; i = i+1 ) {
           j = i+1;

           if( cgpercent > constantaero.Tcgmax[i] and cgpercent <= constantaero.Tcgmax[j] ) {
               me.cgmin = constantaero.Tcgmax[i];
               me.cgmax = constantaero.Tcgmax[j];
               me.corrmin = constantaero.Tmaxmach[i];
               me.corrmax = constantaero.Tmaxmach[j];

               break;
           }
      }
   }

   # Max performance Takeoff
   if( me.dependency["cg"].getChild("max-performance-to").getValue() ) {
       if( cgpercent <= constantaero.Tcgperf[constantaero.CGREST] ) {
           me.find = constant.FALSE;
           me.machmin = constantaero.Tperfmach[constantaero.CGREST];
       }

       else {
           var j = 0;

           for( var i = 0; i < constantaero.CGPERF; i = i+1 ) {
                j = i+1;

                if( cgpercent > constantaero.Tcgperf[i] and cgpercent <= constantaero.Tcgperf[j] ) {
                    me.find = constant.TRUE;
                    me.cgmin = constantaero.Tcgperf[i];
                    me.cgmax = constantaero.Tcgperf[j];
                    me.corrmin = constantaero.Tperfmach[i];
                    me.corrmax = constantaero.Tperfmach[j];

                    break;
                }
           }
       }
   }
}

# speed of sound
Machmeter.getsoundkt = func {
   var speedmach = 0.0;
   var soundkt = 0.0;
   var soundmps = 0.0;
   var Tdegc = 0.0;

   # simplification
   var speedkt = me.noinstrument["airspeed"].getValue();

   if( speedkt > me.GROUNDKT ) {
       speedmach = me.noinstrument["mach"].getValue();
       soundkt = speedkt / speedmach;
   }
   else {
       Tdegc = me.noinstrument["temperature"].getValue();
       soundmps = constant.newtonsoundmps( Tdegc );
       soundkt = soundmps * constant.MPSTOKT;
   }

   return soundkt;
}


# ===========
# TEMPERATURE
# ===========

Temperature = {};

Temperature.new = func {
   var obj = { parents : [Temperature,System]
         };

   obj.init();

   return obj;
};

Temperature.init = func {
   me.inherit_system("/instrumentation", "temperature");
}

# International Standard Atmosphere temperature
Temperature.isa = func {
   var altft = 0.0;
   var isadegc = 0.0;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
        altft = me.dependency["altimeter"][i].getChild("indicated-altitude-ft").getValue(); 

        isadegc = constantISA.temperature_degc( altft );

        me.itself["root"][i].getChild("isa-degc").setValue(isadegc);
   }
}

Temperature.schedule = func {
   if( me.dependency["electric"].getChild("specific").getValue() ) {
       me.isa();
   }
}


# =============
# MARKER BEACON
# =============

Markerbeacon = {};

Markerbeacon.new = func {
   var obj = { parents : [Markerbeacon],

           TESTSEC : 1.5
         };
   return obj;
};

# test of marker beacon lights
Markerbeacon.testexport = func {
   var outer = getprop("/instrumentation/marker-beacon/test-outer");
   var middle = getprop("/instrumentation/marker-beacon/test-middle");
   var inner = getprop("/instrumentation/marker-beacon/test-inner");

   # may press button during test
   if( !outer and !middle and !inner ) {
       me.testmarker();
   }
}

Markerbeacon.testmarker = func {
   var end = constant.FALSE;
   var outer = getprop("/instrumentation/marker-beacon/test-outer");
   var middle = getprop("/instrumentation/marker-beacon/test-middle");
   var inner = getprop("/instrumentation/marker-beacon/test-inner");

   if( !outer and !middle and !inner ) {
       setprop("/instrumentation/marker-beacon/test-outer",constant.TRUE);
       end = constant.FALSE;
   }
   elsif( outer ) {
       setprop("/instrumentation/marker-beacon/test-outer","");
       setprop("/instrumentation/marker-beacon/test-middle",constant.TRUE);
       end = constant.FALSE;
   }
   elsif( middle ) {
       setprop("/instrumentation/marker-beacon/test-middle","");
       setprop("/instrumentation/marker-beacon/test-inner",constant.TRUE);
       end = constant.FALSE;
   }
   else  {
       setprop("/instrumentation/marker-beacon/test-inner",constant.FALSE);
       end = constant.TRUE;
   }

   # re-schedule the next call
   if( !end ) {
       settimer(func { me.testmarker(); }, me.TESTSEC);
   }
}


# =======
# GENERIC
# =======

Generic = {};

Generic.new = func {
   var obj = { parents : [Generic],

           click : nil,

           generic : aircraft.light.new("/instrumentation/generic",[ 1.5,0.2 ])
         };

   obj.init();

   return obj;
};

Generic.init = func {
   me.click = props.globals.getNode("/instrumentation/generic/click");

   me.generic.toggle();
}

Generic.toggleclick = func {
   var sound = constant.TRUE;

   if( me.click.getValue() ) {
       sound = constant.FALSE;
   }

   me.click.setValue( sound );
}


# ===========
# TRANSPONDER
# ===========

Transponder = {};

Transponder.new = func {
   var obj = { parents : [Transponder],

           TESTSEC : 15
         };

   return obj;
};

Transponder.testexport = func {
   if( getprop("/instrumentation/transponder/serviceable") ) {
       if( !getprop("/controls/transponder/test") ) {
           setprop("/controls/transponder/test", constant.TRUE );
           settimer(func { me.test(); }, me.TESTSEC);
       }
   }
}

Transponder.test = func {
   if( getprop("/controls/transponder/test") ) {
       setprop("/controls/transponder/test", constant.FALSE );
   }
}


# ====
# TCAS
# ====

Traffic = {};

Traffic.new = func {
   var obj = { parents : [Traffic,System],

           aircrafts : nil,

           nbtraffics : 0,

           MAXTRAFFIC : 9,

           listindex : [ 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
           listnm : [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ],

           MINKT : 30,

           NOTRAFFIC : 9999
         };

   obj.init();

   return obj;
};

Traffic.init = func {
   me.inherit_system("/instrumentation/tcas");

   me.clear();
}

Traffic.clear = func {
   for( var i=me.nbtraffics; i < size(me.itself["traffic"]); i=i+1 ) {
        me.itself["traffic"][i].getNode("distance-nm").setValue(me.NOTRAFFIC);
   }
}

# tcas
Traffic.schedule = func {
   var altitudeft = 0.0;
   var rangenm = 0.0;
   var xshift = 0.0;
   var yshift = 0.0;
   var rotation = 0.0;
   var radar = nil;

   me.nbtraffics = 0;

   if( me.dependency["electric"].getChild("specific").getValue() ) {
       if( me.itself["root"].getChild("serviceable").getValue() ) {
           altitudeft = me.dependency["altimeter"].getChild("indicated-altitude-ft").getValue();
           if( altitudeft == nil ) {
               altitudeft = 0.0;
           }

           # missing nodes, if not refreshed
           me.aircrafts = me.dependency["ai"].getChildren("aircraft");

           # sort the nearest aircrafts
           for( var i=0; i < size(me.aircrafts); i=i+1 ) {
                # destroyed aircraft
                if( me.aircrafts[i] == nil ) {
                    continue;
                }

                radar = me.aircrafts[i].getNode("radar/in-range");
                if( radar == nil ) {
                    continue;
                }

                # aircraft on ground
                if( me.aircrafts[i].getNode("velocities/true-airspeed-kt").getValue() < me.MINKT ) {
                    continue;
                }

                if( radar.getValue() ) {
                    rangenm = me.aircrafts[i].getNode("radar/range-nm").getValue();
                    me.add( i, rangenm );
                }
           }

           # display the nearest aircrafts
           for( var i=0; i < me.nbtraffics; i=i+1 ) {
                j = me.listindex[i];

                rangenm = me.aircrafts[j].getNode("radar/range-nm").getValue();

                # relative altitude
                levelft = me.aircrafts[j].getNode("position/altitude-ft").getValue();
                levelft = levelft - altitudeft;

                xshift = me.aircrafts[j].getNode("radar/x-shift").getValue();
                yshift = me.aircrafts[j].getNode("radar/y-shift").getValue();
                rotation = me.aircrafts[j].getNode("radar/rotation").getValue();

                me.itself["traffic"][i].getNode("distance-nm").setValue(rangenm);
                me.itself["traffic"][i].getNode("level-ft",1).setValue(levelft);
                me.itself["traffic"][i].getNode("x-shift",1).setValue(xshift);
                me.itself["traffic"][i].getNode("y-shift",1).setValue(yshift);
                me.itself["traffic"][i].getNode("rotation",1).setValue(rotation);
                me.itself["traffic"][i].getNode("index",1).setValue(j);
           }
       }
   }

   # no traffic
   me.clear();
   me.itself["root"].getChild("nb-traffics").setValue(me.nbtraffics);
}

Traffic.add = func( index, distancenm ) {
   var j = 0;
   var insert = -1;

   for( var i=0; i < me.nbtraffics; i=i+1 ) {
        # lower
        if( me.listnm[ i ] <= distancenm ) {
            insert = i;
        }

        # higher
        else {
            break;
        }
   }

   # right shift to get an insertion slot.
   for( var i=me.nbtraffics-1; i > insert; i=i-1 ) {
        j = i+1;

        # except the last
        if( j < me.MAXTRAFFIC ) {
            me.listindex[ j ] = me.listindex[ i ];
            me.listnm[ j ] = me.listnm[ i ];
        }
   }

   # insertion
   if( insert < me.MAXTRAFFIC-1 ) {
       insert = insert + 1;
       me.listindex[ insert ] = index;
       me.listnm[ insert ] = distancenm;

       if( me.nbtraffics < me.MAXTRAFFIC ) {
           me.nbtraffics = me.nbtraffics + 1;
       }
   }
}


# ===========
# AUDIO PANEL
# ===========

AudioPanel = {};

AudioPanel.new = func {
   var obj = { parents : [AudioPanel],

           thecrew : nil
         };

   obj.init();

   return obj;
};

AudioPanel.init = func {
   me.thecrew = props.globals.getNode("/controls/audio/crew");
}

AudioPanel.headphones = func( marker, panel, seat ) {
   var audio = nil;

   # hears nothing outside
   var adf1 = 0.0;
   var adf2 = 0.0;
   var comm1 = 0.0;
   var comm2 = 0.0;
   var nav1 = 0.0;
   var nav2 = 0.0;

   # each crew member has an audio panel
   if( panel ) {
       audio = me.thecrew.getNode(seat);

       if( audio != nil ) {
           adf1  = audio.getNode("adf[0]/volume").getValue();
           adf2  = audio.getNode("adf[1]/volume").getValue();
           comm1 = audio.getNode("comm[0]/volume").getValue();
           comm2 = audio.getNode("comm[1]/volume").getValue();
           nav1  = audio.getNode("nav[0]/volume").getValue();
           nav2  = audio.getNode("nav[1]/volume").getValue();
       }
   }

   me.send( adf1, adf2, comm1, comm2, nav1, nav2, marker );
}

AudioPanel.send = func( adf1, adf2, comm1, comm2, nav1, nav2, marker ) {
   setprop("/instrumentation/adf[0]/volume-norm",adf1);
   setprop("/instrumentation/adf[1]/volume-norm",adf2);
   setprop("/instrumentation/comm[0]/volume",comm1);
   setprop("/instrumentation/comm[1]/volume",comm2);
   setprop("/instrumentation/nav[1]/volume",nav1);
   setprop("/instrumentation/nav[2]/volume",nav2);
   setprop("/instrumentation/marker-beacon/audio-btn",marker);
}


# =============
# SPEED UP TIME
# =============

Daytime = {};

Daytime.new = func {
   var obj = { parents : [Daytime,System],

               SPEEDUPSEC : 1.0,

               CLIMBFTPMIN : 3500,                                           # max climb rate
               MAXSTEPFT : 0.0,                                              # altitude change for step

               lastft : 0.0
         };

   obj.init();

   return obj;
}

Daytime.init = func {
    me.inherit_system("/instrumentation/clock");

    var climbftpsec = me.CLIMBFTPMIN / constant.MINUTETOSECOND;

    me.MAXSTEPFT = climbftpsec * me.SPEEDUPSEC;
}

Daytime.schedule = func {
   var altitudeft = me.noinstrument["altitude"].getValue();
   var speedup = me.noinstrument["speed-up"].getValue();

   if( speedup > 1 ) {
       var multiplier = 0.0;
       var offsetsec = 0.0;
       var warp = 0.0;
       var stepft = 0.0;
       var maxft = 0.0;
       var minft = 0.0;

       # accelerate day time
       multiplier = speedup - 1;
       offsetsec = me.SPEEDUPSEC * multiplier;
       warp = me.noinstrument["warp"].getValue() + offsetsec; 
       me.noinstrument["warp"].setValue(warp);

       # safety
       stepft = me.MAXSTEPFT * speedup;
       maxft = me.lastft + stepft;
       minft = me.lastft - stepft;

       # too fast
       if( altitudeft > maxft or altitudeft < minft ) {
           me.noinstrument["speed-up"].setValue(1);
       }
   }

   me.lastft = altitudeft;
}
