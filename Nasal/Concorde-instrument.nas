# Like the real Concorde : see http://www.concordesst.com.

# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# current nasal version doesn't accept :
# - more than multiplication on 1 line.
# - variable with hyphen or underscore.
# - boolean (can only test IF TRUE); replaced by strings.
# - object oriented classes.


# ==============
# AIRSPEED METER
# ==============

# ias light, when discrepancy with the autothrottle
iaslight = func {
   speedmode = getprop("/autopilot/locks/speed");
   if( speedmode == "speed-with-throttle" ) {
       speedkt = getprop("/autopilot/settings/target-speed-kt");
       # ias light within 10 kt
       minkt = speedkt - 10;
       setprop("/instrumentation/airspeed-indicator/light-min-kt",minkt);
       maxkt = speedkt + 10;
       setprop("/instrumentation/airspeed-indicator/light-max-kt",maxkt);
   }
}

# maximum operating speed (kt)
vmoktschedule = func {
   altitudeft = getprop("/instrumentation/altimeter/indicated-altitude-ft");
   if( altitudeft != nil ) {
       ratio = "true";
       # below 105 t
       if( getprop("/instrumentation/cg/below-105t") ) {
           # at startup, altitude may be negativ
           if( altitudeft <= 0 ) {
               ratio = "false";
               vmokt = 300;
           }
           # different
           elsif( altitudeft > 0 and altitudeft <= 4500 ) {
               vminkt = 300;
               vmaxkt = 385;
               altminft = 0;
               altmaxft = 4500;
           }
           elsif ( altitudeft > 4500 and altitudeft <= 6000 ) {
               vminkt = 385;
               vmaxkt = 390;
               altminft = 4500;
               altmaxft = 6000;
           }
           elsif ( altitudeft > 6000 and altitudeft <= 34500 ) {
               ratio = "false";
               vmokt = 390;
           }
           elsif ( altitudeft > 34500 and altitudeft <= 43000 ) {
               vminkt = 390;
               vmaxkt = 520;
               altminft = 34500;
               altmaxft = 43000;
           }
           # identical
           elsif ( altitudeft > 43000 and altitudeft <= 44000 ) {
               vminkt = 520;
               vmaxkt = 530;
               altminft = 43000;
               altmaxft = 44000;
           }
           elsif ( altitudeft > 44000 and altitudeft <= 51000 ) {
               ratio = "false";
               vmokt = 530;
           }
           elsif ( altitudeft > 51000 and altitudeft <= 60000 ) {
               vminkt = 530;
               vmaxkt = 430;
               altminft = 51000;
               altmaxft = 60000;
           }
           else {
               ratio = "false";
               vmokt = 430;
           }
       }
       # above 165 t
       else {
           # at startup, altitude may be negativ
           if( altitudeft <= 0 ) {
               ratio = "false";
               vmokt = 300;
           }
           elsif( altitudeft > 0 and altitudeft <= 4000 ) {
              vminkt = 300;
              vmaxkt = 395;
              altminft = 0;
              altmaxft = 4000;
           }
           elsif ( altitudeft > 4000 and altitudeft <= 6000 ) {
              vminkt = 395;
              vmaxkt = 400;
              altminft = 4000;
              altmaxft = 6000;
           }
           elsif ( altitudeft > 6000 and altitudeft <= 32000 ) {
              ratio = "false";
              vmokt = 400;
           }
           elsif ( altitudeft > 32000 and altitudeft <= 43000 ) {
              vminkt = 400;
              vmaxkt = 520;
              altminft = 32000;
              altmaxft = 43000;
           }
           elsif ( altitudeft > 43000 and altitudeft <= 44000 ) {
              vminkt = 520;
              vmaxkt = 530;
              altminft = 43000;
              altmaxft = 44000;
           }
           elsif ( altitudeft > 44000 and altitudeft <= 51000 ) {
              ratio = "false";
              vmokt = 530;
           }
           elsif ( altitudeft > 51000 and altitudeft <= 60000 ) {
              vminkt = 530;
              vmaxkt = 430;
              altminft = 51000;
              altmaxft = 60000;
           }
           else {
              ratio = "false";
              vmokt = 430;
           }
       }
       if( ratio == "true" ) {
           offsetkt = vmaxkt - vminkt;
           offsetft = altmaxft - altminft;
           stepft = altitudeft - altminft;
           ratio = stepft / offsetft;
           stepkt = offsetkt * ratio;
           vmokt = vminkt + stepkt;
       }
       speedkt = getprop("/velocities/airspeed-kt");
       # speed of sound
       if( speedkt > 50 ) {
           speedmach = getprop("/velocities/mach");
           soundkt = speedkt / speedmach;
       }
       else {
           # speed of sound : v^2 = dP/dRo = gamma x R x T, where
           # P = pressure
           # Ro = density
           # gamma = cp/cv, ratio of specific heats
           # R = absolute gas constant
           # T = temperature
           TK = getprop("/environment/temperature-degc") + CELSIUSTOK;
           dPdRoNewton = Rpm2ps2pK * TK;
           dPdRo = gammaairstp * dPdRoNewton;
           soundkt = math.sqrt(dPdRo) * MPSTOKT;
       }
       # mach number
       mmomach = vmokt / soundkt;
       # MMO Mach 2.04
       if( mmomach > 2.04 ) {
           mmomach = 2.04;
       }
       # always mach number (= makes the consumption constant)
       elsif( altitudeft >= 50190 ) {
           mmomach = 2.04;
           vmokt = mmomach * soundkt;
       }
       setprop("/instrumentation/airspeed-indicator[0]/vmo-kt", vmokt);
       setprop("/instrumentation/airspeed-indicator[1]/vmo-kt", vmokt);
       setprop("/instrumentation/mach-indicator/mmo-mach", mmomach);

       # overspeed
       maxkt = vmokt + 10;
       maxmach = mmomach + 0.04;
       setprop("/instrumentation/airspeed-indicator/overspeed-kt", maxkt);
       setprop("/instrumentation/mach-indicator/overspeed-mach", maxmach);
   }

   iaslight();
}  


# =================
# CENTER OF GRAVITY
# =================

# center of gravity
centergravity = func {
   # many jbsim, when relocation of aircraft !
   fdms = props.globals.getNode("/fdm").getChildren("jsbsim");
   last = size(fdms) - 1;
   # not feet, inches !
   cgxin = fdms[last].getNode("inertia/cg-x-ft").getValue();
   # % of aerodynamic chord C0 (18.7 m from nose).
   cgxin = cgxin - 736.22;
   setprop("/instrumentation/cg/cg-x-in", cgxin);
   # C0 = 90'9".
   cgfraction = cgxin / 1089;
   cgpercent = cgfraction * 100;
   setprop("/instrumentation/cg/percent", cgpercent);
}  

# corridor of center of gravity
corridorcg = func {
   speedmach = getprop("/velocities/mach");

   # corridor minimum
   # ================
   # normal corridor (there is also an extreme one)
   ratio = "true";
   # below 105 t
   if( getprop("/instrumentation/cg/below-105t") ) {
       # at startup, speed may be negativ
       if( speedmach <= 0 ) {
           ratio = "false";
           cgmin = 51.8;
       }
       elsif( speedmach > 0 and speedmach <= 0.82 ) {
           ratio = "false";
           cgmin = 51.8;
       }
       elsif ( speedmach > 0.82 and speedmach <= 0.92 ) {
           corrmin = 51.8;
           corrmax = 53.5;
           machmin = 0.82;
           machmax = 0.92;
       }
       elsif ( speedmach > 0.92 and speedmach <= 1.15 ) {
           corrmin = 53.5;
           corrmax = 55.0;
           machmin = 0.92;
           machmax = 1.15;
       }
       elsif ( speedmach > 1.15 and speedmach <= 1.5 ) {
          corrmin = 55.0;
          corrmax = 56.5;
          machmin = 1.15;
          machmax = 1.5;
       }
       elsif ( speedmach > 1.5 and speedmach <= 2.2 ) {
          corrmin = 56.5;
          corrmax = 57.25;
          machmin = 1.5;
          machmax = 2.2;
       }
       else {
          ratio = "false";
          cgmin = 57.25;
       }
   }
   # above 165 t
   else {
       # at startup, speed may be negativ
       if( speedmach <= 0 ) {
           ratio = "false";
           cgmin = 51.8;
       }
       elsif( speedmach > 0 and speedmach <= 0.8 ) {
           ratio = "false";
           cgmin = 51.8;
       }
       elsif ( speedmach > 0.8 and speedmach <= 0.92 ) {
           corrmin = 51.8;
           corrmax = 54.0;
           machmin = 0.8;
           machmax = 0.92;
       }
       elsif ( speedmach > 0.92 and speedmach <= 1.15 ) {
           corrmin = 54.0;
           corrmax = 55.5;
           machmin = 0.92;
           machmax = 1.15;
       }
       elsif ( speedmach > 1.15 and speedmach <= 1.5 ) {
          corrmin = 55.5;
          corrmax = 57.0;
          machmin = 1.15;
          machmax = 1.5;
       }
       elsif ( speedmach > 1.5 and speedmach <= 2.2 ) {
          corrmin = 57.0;
          corrmax = 57.7;
          machmin = 1.5;
          machmax = 2.2;
       }
       else {
          ratio = "false";
          cgmin = 57.7;
       }
   }
   if( ratio == "true" ) {
     offsetcg = corrmax - corrmin;
     offsetmach = machmax - machmin;
     stepmach = speedmach - machmin;
     ratio = stepmach / offsetmach;
     stepcg = offsetcg * ratio;
     cgmin = corrmin + stepcg;
   }

   # corridor maximum
   # ================
   ratio = "true";
   # at startup, speed may be negativ
   if( speedmach <= 0 ) {
     ratio = "false";
     cgmax = 53.8;
   }
   elsif( speedmach > 0 and speedmach <= 0.27 ) {
     ratio = "false";
     cgmax = 53.8;
   }
   elsif ( speedmach > 0.27 and speedmach <= 0.5 ) {
     corrmin = 53.8;
     corrmax = 54.0;
     machmin = 0.27;
     machmax = 0.5;
   }
   elsif ( speedmach > 0.5 and speedmach <= 0.94 ) {
     corrmin = 54.0;
     corrmax = 57.0;
     machmin = 0.5;
     machmax = 0.94;
   }
   elsif ( speedmach > 0.94 and speedmach <= 1.65 ) {
     corrmin = 57.0;
     corrmax = 59.3;
     machmin = 0.94;
     machmax = 1.65;
   }
   else {
     ratio = "false";
     cgmax = 59.3;
   }
   # Max performance Takeoff
   if( getprop("/instrumentation/cg/max-performance-to" ) ) {
       if( speedmach <= 0 ) {
           ratio = "false";
           cgmax = 54.2;
       }
       elsif( speedmach > 0 and speedmach <= 0.1 ) {
           ratio = "false";
           cgmax = 54.2;
       }
       elsif ( speedmach > 0.1 and speedmach <= 0.45 ) {
           ratio = "true";
           corrmin = 54.2;
           corrmax = 54.5;
           machmin = 0.1;
           machmax = 0.45;
       }
   }
   if( ratio == "true" ) {
     offsetcg = corrmax - corrmin;
     offsetmach = machmax - machmin;
     stepmach = speedmach - machmin;
     ratio = stepmach / offsetmach;
     stepcg = offsetcg * ratio;
     cgmax = corrmin + stepcg;
   }
   setprop("/instrumentation/cg/min-percent", cgmin);
   setprop("/instrumentation/cg/max-percent", cgmax);
}  


# ==========
# MACH METER
# ==========

# Mach corridor
corridormach = func {
   cgpercent = getprop("/instrumentation/cg/percent");

   # corridor maximum
   # ================
   # normal corridor (there is also an extreme one)
   ratio = "true";
   # below 105 t
   if( getprop("/instrumentation/cg/below-105t") ) {
       if( cgpercent <= 51.8 ) {
           ratio = "false";
           machmax = 0.82;
       }
       elsif ( cgpercent > 51.8 and cgpercent <= 53.5 ) {
           cgmin = 51.8;
           cgmax = 53.5;
           corrmin = 0.82;
           corrmax = 0.92;
       }
       elsif ( cgpercent > 53.5 and cgpercent <= 55.0 ) {
           cgmin = 53.5;
           cgmax = 55.0;
           corrmin = 0.92;
           corrmax = 1.15;
       }
       elsif ( cgpercent > 55.0 and cgpercent <= 56.5 ) {
          cgmin = 55.0;
          cgmax = 56.5;
          corrmin = 1.15;
          corrmax = 1.5;
       }
       elsif ( cgpercent > 56.5 and cgpercent <= 57.25 ) {
          cgmin = 56.5;
          cgmax = 57.25;
          corrmin = 1.5;
          corrmax = 2.2;
       }
       else {
          ratio = "false";
          machmax = 2.2;
       }
   }
   # above 165 t
   else {
       if( cgpercent <= 51.8 ) {
           ratio = "false";
           machmax = 0.8;
       }
       elsif ( cgpercent > 51.8 and cgpercent <= 54.0 ) {
           cgmin = 51.8;
           cgmax = 54.0;
           corrmin = 0.8;
           corrmax = 0.92;
       }
       elsif ( cgpercent > 54.0 and cgpercent <= 55.5 ) {
           cgmin = 54.0;
           cgmax = 55.5;
           corrmin = 0.92;
           corrmax = 1.15;
       }
       elsif ( cgpercent > 55.5 and cgpercent <= 57.0 ) {
          cgmin = 55.5;
          cgmax = 57.0;
          corrmin = 1.15;
          corrmax = 1.5;
       }
       elsif ( cgpercent > 57.0 and cgpercent <= 57.7 ) {
          cgmin = 57.0;
          cgmax = 57.7;
          corrmin = 1.5;
          corrmax = 2.2;
       }
       else {
          ratio = "false";
          machmax = 2.2;
       }
   }
   if( ratio == "true" ) {
     offsetmach = corrmax - corrmin;
     offsetcg = cgmax - cgmin;
     stepcg = cgpercent - cgmin;
     ratio = stepcg / offsetcg;
     stepmach = offsetmach * ratio;
     machmax = corrmin + stepmach;
   }

   # corridor minimum
   # ================
   ratio = "true";
   # at startup, speed may be negativ
   if( cgpercent <= 53.8 ) {
     ratio = "false";
     machmin = 0.0;
   }
   elsif ( cgpercent > 53.8 and cgpercent <= 54.0 ) {
     cgmin = 53.8;
     cgmax = 54.0;
     corrmin = 0.27;
     corrmax = 0.5;
   }
   elsif ( cgpercent > 54.0 and cgpercent <= 57.0 ) {
     cgmin = 54.0;
     cgmax = 57.0;
     corrmin = 0.5;
     corrmax = 0.94;
   }
   elsif ( cgpercent > 57.0 and cgpercent <= 59.3 ) {
     cgmin = 57.0;
     cgmax = 59.3;
     corrmin = 0.94;
     corrmax = 1.65;
   }
   else {
     ratio = "false";
     machmin = 1.65;
   }
   # Max performance Takeoff
   if( getprop("/instrumentation/cg/max-performance-to" ) ) {
       if( cgpercent <= 54.2 ) {
           ratio = "false";
           machmin = 0.0;
       }
       elsif ( cgpercent > 54.2 and cgpercent <= 54.5 ) {
           ratio = "true";
           cgmin = 54.2;
           cgmax = 54.5;
           corrmin = 0.1;
           corrmax = 0.45;
       }
   }
   if( ratio == "true" ) {
     offsetmach = corrmax - corrmin;
     offsetcg = cgmax - cgmin;
     stepcg = cgpercent - cgmin;
     ratio = stepcg / offsetcg;
     stepmach = offsetmach * ratio;
     machmin = corrmin + stepmach;
   }
   setprop("/instrumentation/mach-indicator/min", machmin);
   setprop("/instrumentation/mach-indicator/max", machmax);
}


# ==========================
# INERTIAL NAVIGATION SYSTEM
# ==========================

# ins fuel
insfuelschedule = func {
   outputvolt = getprop("/systems/electrical/outputs/specific");
   if( outputvolt != nil ) {
       if( outputvolt > 20 ) {
           taskt = getprop("/instrumentation/tas-indicator/indicated-tas-kt");
           if( taskt != nil ) {
               # subsonic average
               if( taskt < 100 ) {
                   taskt = 480;
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
                   ratio = distnm / taskt;
                   fuelkg = kgph * ratio;
                   fuelkg = totalkg - fuelkg;
                   if( fuelkg < 0 ) {
                       fuelkg = 0;
                   }
                   waypoints[0].getChild("fuel-kg").setValue(fuelkg);
                   # next
                   distnm = waypoints[1].getChild("dist").getValue();
                   if( distnm != nil ) {
                       ratio = distnm / taskt;
                       fuelkg = kgph * ratio;
                       fuelkg = totalkg - fuelkg;
                       if( fuelkg < 0 ) {
                           fuelkg = 0;
                       }
                       waypoints[1].getChild("fuel-kg").setValue(fuelkg);
                       # last
                       distnm = getprop("/autopilot/route-manager/wp-last/dist"); 
	               if( distnm != nil ) {
                           ratio = distnm / taskt;
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
   }
}


# ==============
# TRUE AIR SPEED
# ==============

# true air speed
tasschedule = func {
   ubodyfps = getprop("/velocities/uBody-fps");
   vbodyfps = getprop("/velocities/vBody-fps");
   speedfps2 = ubodyfps*ubodyfps + vbodyfps*vbodyfps;
   taskt = math.sqrt(speedfps2) * FPSTOKT;
   setprop("/instrumentation/tas-indicator/indicated-tas-kt",taskt);
}


# ===========
# TEMPERATURE
# ===========

# International Standard Atmosphere temperature
isatemperature = func {
   altft = getprop("/instrumentation/altimeter/indicated-altitude-ft"); 
   altmeter = altft * FEETTOMETER;

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
       isadegk = 288.15 * factor;
       isadegc = isadegk - 273.15;
   }

   setprop("/instrumentation/temperature/isa-degc",isadegc);
}


# maximum total temperature
tmodegcschedule = func {
   outputvolt = getprop("/systems/electrical/outputs/specific");
   if( outputvolt != nil ) {
       if( outputvolt > 20 ) {
           oatdegc=getprop("/environment/temperature-degc");
           setprop("/instrumentation/temperature/indicated-static-degc",oatdegc);

           # TMO 127C at Mach 2.02 :
           # - cold atmosphere : static temperature < -55C.
           # - hot atmosphere : static temperature > -51C (Max Cruise mode).
           #
           # linear is supposed
           speedmach = getprop("/velocities/mach");
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

           isatemperature();
       }
    }
}


# ==============
# GROUND SERVICE
# ==============

# connection with delay by ground operator
groundserviceschedule = func {
    aglft = getprop("/position/altitude-agl-ft");
    speedkt = getprop("/velocities/airspeed-kt");
    if( aglft <  15 and speedkt < 15 ) {
        powervolt = 600.0;
        pressurepsi = 35.0;
    }
    else {
        powervolt = 0.0;
        pressurepsi = 0.0;
    }

   setprop("/systems/electrical/suppliers/ground-service",powervolt);
   setprop("/systems/air-bleed/ground-service-psi",pressurepsi);
}


# =======================
# SECONDARY NOZZLE BUCKET
# =======================

# bucket position
bucketdegschedule = func {
   speedmach = getprop("/velocities/mach");
   # takeoff : 21 deg
   if( speedmach < 0.55 ) {
       bucketdeg = 21;
   }
   # subsonic : 21 to 0 deg
   elsif( speedmach <= 1.1 ) {
       step = speedmach - 0.55;
       denom = 1.1 - 0.55;
       coef = 21 / denom;
       bucketdeg = 21 - coef * step;
   }
   # supersonic : 0 deg
   else {
       bucketdeg = 0;
   }

   engines = props.globals.getNode("/engines").getChildren("engine");
   for( i=0; i<4; i=i+1 ) {
       # reversed : 36.5 deg
       if( engines[i].getChild("reversed").getValue() ) {
           valuedeg = 35;
       }
       else {
           valuedeg = bucketdeg;
       }
       engines[i].getChild("bucket-deg").setValue(valuedeg);
   }
}


# ============================
# INSTANTANEOUS VERTICAL SPEED
# ============================

INSTRUMENTSEC = 0.05;
MAX_INHG_PER_S = 0.0002;
RESPONSIVENESS = 5.0;           # A higher number means more responsive.

# A real IVSI is operated by static pressure changes.
# It operates like a conventional VSI, except that an internal sensor detects load factors,
# to momentarily alters the static pressure (with lag).
# It appears lag free at subsonic speed; at high altitude indication may be less than 1/3 of
# actual conditions.
calcverticalfpscron = func {
   if( getprop("/instrumentation/inst-vertical-speed-indicator/serviceable") ) {

       # pressure not filtered
       pressureinhg = getprop("/environment/pressure-inhg");
       seainhg= getprop("/environment/pressure-sea-level-inhg");

       # elapsed time
       lastsec = getprop("/instrumentation/inst-vertical-speed-indicator/elapsed-sec");
       nowsec = getprop("/sim/time/elapsed-sec");
       if( lastsec == nil or nowsec == nil ) {
           stepsec = INSTRUMENTSEC;
           nowsec = 0.0;
       }
       else {
           stepsec = nowsec - lastsec;
       }

       # speed up
       speedup = getprop("/sim/speed-up");
       if( speedup > 1 ) {
           stepsec = stepsec * speedup;
       }

       # limit effect of external environment
       lastseainhg = getprop("/instrumentation/inst-vertical-speed-indicator/sea-inhg");
       if( lastseainhg == nil ) {
           rateseainhgps = 0.0;
       }
       else {
           rateseainhgps = ( seainhg - lastseainhg ) / stepsec;
       }
 
       # pressure rate of change
       if( rateseainhgps > - MAX_INHG_PER_S and rateseainhgps < MAX_INHG_PER_S ) {
           lastinhg = getprop("/instrumentation/inst-vertical-speed-indicator/pressure-inhg");
           if( lastinhg == nil ) {
               rateinhgps = 0.0;
           }
           else {
               rateinhgps = ( pressureinhg - lastinhg ) / stepsec;
           }

           #setprop("/instrumentation/inst-vertical-speed-indicator/rate-inhg-per-s",rateinhgps);

           deltainhg = P0_inhg - pressureinhg;
           #setprop("/instrumentation/inst-vertical-speed-indicator/delta-inhg",deltainhg);

           # standard atmosphere (pressure difference from sea level) : search for the current altitude
           #
	   # IVSI determines alone the current altitude, without altimeter setting.
	   # Altimeter setting is 29.92 above 10000 or 18000 ft.
	   # Below this level, the slope is slightly wrong.
           slopeft = 2952.75591;
           # guess at 0 m
           if( deltainhg < 0 ) {
               slopeinhg = 3.33;
           }
           # 900 m
           elsif( deltainhg >= 0 and deltainhg < 3.05 ) {
               slopeinhg = 3.05 - 0;
           }
           # 1800 m
           elsif( deltainhg >= 3.05 and deltainhg < 5.86 ) {
               slopeinhg = 5.86 - 3.05;
           }
           # 2700 m
           elsif( deltainhg >= 5.86 and deltainhg < 8.41 ) {
               slopeinhg = 8.41 - 5.86;
           }
           # 3600 m
           elsif( deltainhg >= 8.41 and deltainhg < 10.74 ) {
               slopeinhg = 10.74 - 8.41;
           }
           # 4200 m
           elsif( deltainhg >= 10.74 and deltainhg < 12.87 ) {
               slopeinhg = 12.87 - 10.74;
           }
           # 5400 m
           elsif( deltainhg >= 12.87 and deltainhg < 14.78 ) {
               slopeinhg = 14.78 - 12.87;
           }
           # 6300 m
           elsif( deltainhg >= 14.78 and deltainhg < 16.55 ) {
               slopeinhg = 16.55 - 14.78;
           }
           # 7200 m
           elsif( deltainhg >= 16.55 and deltainhg < 18.13 ) {
               slopeinhg = 18.13 - 16.55;
           }
           # 8100 m
           elsif( deltainhg >= 18.13 and deltainhg < 19.62 ) {
               slopeinhg = 19.62 - 18.13;
           }
           # 9000 m
           elsif( deltainhg >= 19.62 and deltainhg < 20.82 ) {
               slopeinhg = 20.82 - 19.62;
           }
           # 9900 m
           elsif( deltainhg >= 20.82 and deltainhg < 21.96 ) {
               slopeinhg = 21.96 - 20.82;
           }
           # 10800 m
           elsif( deltainhg >= 21.96 and deltainhg < 23.01 ) {
               slopeinhg = 23.01 - 21.96;
           }
           # 11700 m
           elsif( deltainhg >= 23.01 and deltainhg < 23.91 ) {
               slopeinhg = 23.91 - 23.01;
           }
           # 12600 m
           elsif( deltainhg >= 23.91 and deltainhg < 24.71 ) {
               slopeinhg = 24.71 - 23.91;
           }
           # 13500 m
           elsif( deltainhg >= 24.71 and deltainhg < 25.40 ) {
               slopeinhg = 25.40 - 24.71;
           }
           # 14400 m
           elsif( deltainhg >= 25.40 and deltainhg < 26.00 ) {
               slopeinhg = 26.00 - 25.40;
           }
           # 15300 m
           elsif( deltainhg >= 26.00 and deltainhg < 26.51 ) {
               slopeinhg = 26.51 - 26.00;
           }
           # 16200 m
           elsif( deltainhg >= 26.51 and deltainhg < 26.96 ) {
               slopeinhg = 26.96 - 26.51;
           }
           # 17100 m
           elsif( deltainhg >= 26.96 and deltainhg < 27.35 ) {
               slopeinhg = 27.35 - 26.96;
           }
           # 18000 m
           elsif( deltainhg >= 27.35 and deltainhg < 27.68 ) {
               slopeinhg = 27.68 - 27.35;
           }
           # 18900 m
           elsif( deltainhg >= 27.68 and deltainhg < 27.98 ) {
               slopeinhg = 27.98 - 27.68;
           }
           # overflow above 18900 m
           else {
               slopeinhg = 27.98 - 27.68;
           }
   
           #setprop("/instrumentation/inst-vertical-speed-indicator/slope-inhg",slopeinhg);
           speedfps = - rateinhgps * slopeft / slopeinhg;

           # Alex Perry's low pass filter
           lastfps = getprop("/instrumentation/inst-vertical-speed-indicator/indicated-speed-fps");
           if( lastfps != nil ) {
               timeratio = stepsec * RESPONSIVENESS;
               if( timeratio < 0.0 ) {
                    # time went backwards; kill the filter
                    if( timeratio < -1.0 ) {
                        speedfps = speedfps;
                    }
                    # ignore mildly negative time
                    else {
                        speedfps = lastfps;
                    }
               }
               # Normal mode of operation; fast approximation to exp(-timeratio)
               elsif( timeratio < 0.2 ) {
                    A = lastfps * (1.0 - timeratio);
                    B = speedfps * timeratio;
                    speedfps = A + B;
               }
               # Huge time step; assume filter has settled
               elsif ( timeratio > 5.0 ) {
                    speedfps = speedfps;
               }
               # Moderate time step; non linear response
               else {
                    keep = math.exp(-timeratio);
                    A = lastfps * keep;
                    B = speedfps * (1.0 - keep);
                    speedfps = A + B;
               }
           }

           setprop("/instrumentation/inst-vertical-speed-indicator/indicated-speed-fps",speedfps);
       }
       else {
           overflow = getprop("/sim/time/gmt");
           setprop("/instrumentation/inst-vertical-speed-indicator/overflow",overflow);
       }

       setprop("/instrumentation/inst-vertical-speed-indicator/elapsed-sec",nowsec);
       setprop("/instrumentation/inst-vertical-speed-indicator/step-sec",stepsec);
       setprop("/instrumentation/inst-vertical-speed-indicator/pressure-inhg",pressureinhg);
       setprop("/instrumentation/inst-vertical-speed-indicator/sea-inhg",seainhg);
   }

   # re-schedule the next call
   settimer(calcverticalfpscron, INSTRUMENTSEC);
}


# ==============
# TEST OF LIGHTS
# ==============

# test of marker beacon lights
testmarkerexport = func {
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
       settimer(testmarkerexport, 1.5);
   }
}

# flashing light
flashinglightcron = func {
   light = getprop("/instrumentation/generic/flashing-light");
   if( light == nil or light != "on") {
       light = "on";
       lightsec = 7.0;
   }
   else {
       light = "";
       lightsec = 0.2;
   }
   setprop("/instrumentation/generic/flashing-light",light);

   # re-schedule the next call
   settimer(flashinglightcron, lightsec);
}


# ====
# TCAS
# ====

# tcas
tcasschedule = func {
   traffics = props.globals.getNode("/instrumentation/tcas/traffics").getChildren("traffic");
   nbtraffics = 0;

   outputvolt = getprop("/systems/electrical/outputs/specific");
   if( outputvolt != nil ) {
       if( getprop("/instrumentation/tcas/serviceable") and outputvolt > 20 ) {
           altitudeft = getprop("/position/altitude-ft");
           if( altitudeft == nil ) {
               altitudeft = 0.0;
           }

           aircrafts = props.globals.getNode("/ai/models").getChildren("aircraft");
           for( i=0; i < size(aircrafts); i=i+1 ) {
                # instrument limitation
                if( nbtraffics < size(traffics) ) {
                    # destroyed aircraft
                    if( aircrafts[i] != nil ) {
                        radarinrange = aircrafts[i].getNode("radar/in-range",1).getValue();
                        if( radarinrange ) {
                            rangenm = aircrafts[i].getNode("radar/range-nm").getValue();
                            traffics[nbtraffics].getNode("distance-nm").setValue(rangenm);
                            # relative altitude
                            levelft = aircrafts[i].getNode("position/altitude-ft").getValue();
                            levelft = levelft - altitudeft;
                            traffics[nbtraffics].getNode("level-ft",1).setValue(levelft);
                            xshift = aircrafts[i].getNode("radar/x-shift").getValue();
                            traffics[nbtraffics].getNode("x-shift",1).setValue(xshift);
                            yshift = aircrafts[i].getNode("radar/y-shift").getValue();
                            traffics[nbtraffics].getNode("y-shift",1).setValue(yshift);
                            rotation = aircrafts[i].getNode("radar/rotation").getValue();
                            traffics[nbtraffics].getNode("rotation",1).setValue(rotation);
                            traffics[nbtraffics].getNode("index",1).setValue(i);
                            nbtraffics = nbtraffics + 1;
                        }
                    }
               }
           }
       }
   }

   # no traffic
   for( i=nbtraffics; i < size(traffics); i=i+1 ) {
        traffics[i].getNode("distance-nm").setValue(9999);
   }
   setprop("/instrumentation/tcas/nb-traffics",nbtraffics);
}


# ==============
# PRESSURIZATION
# ==============

# cabine altitude in feet, arguments
# - cabine pressure in inhg
cabinealtitude = func {
   cabineinhg = arg[0];


   # optimization (cruise)
   if( cabineinhg == PRESSURIZEMININHG ) {
       cabinealtft = PRESSURIZEMAXFT;
   }

   # one supposes instrument calibrated by standard atmosphere
   else {
       ratio = cabineinhg / 29.92;

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
           cabinealtm = altminm + deltam * coeff;
           cabinealtft = cabinealtm * METERTOFEET;
       }
       # out of range
       else {
           cabineinhg = 29.92;
           cabinealtft = 0;
       }
   }

   setprop("/instrumentation/cabine-altitude/cabine-inhg",cabineinhg);
   setprop("/instrumentation/cabine-altitude/indicated-altitude-ft",cabinealtft);
}

# differential pressure
diffpressure = func {
   cabineinhg = getprop("/instrumentation/cabine-altitude/cabine-inhg");
   pressureinhg = getprop("/environment/pressure-inhg");
   diffinhg = cabineinhg - pressureinhg;
   setprop("/instrumentation/differential-pressure/differential-inhg",diffinhg);
}


# ====
# FUEL
# ====

# total of fuel in kg
totalfuel = func {
   tankskg = getprop("/instrumentation/fuel/total-kg");
   fuelgalus = 0;
   tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");

   for(i=0; i<size(tanks); i=i+1) {
   fuelgalus = fuelgalus + tanks[i].getChild("level-gal_us").getValue();
   }
   setprop("/instrumentation/fuel/total-gal_us", fuelgalus);

   # parser wants 1 line per multiplication !
   fuellb = fuelgalus * GALUSTOLB;
   fuelkg = fuellb * LBTOKG;
   setprop("/instrumentation/fuel/total-kg", fuelkg);

   # to check errors in pumping
   if( tankskg != nil ) {
       stepkg = tankskg - fuelkg;
       fuelkgpmin = stepkg * PUMPPMIN;
       fuelkgph = fuelkgpmin * 60;

       # no speed up : pumping is accelerated
       setprop("/instrumentation/fuel/fuel-flow-kg_ph", fuelkgph);
   }
}
