# Like the real Concorde : see http://www.concordesst.com.

# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer

# possible Nasal bug, see keyword BUG

# current nasal version doesn't accept :
# - more than multiplication on 1 line;
# - variable with hyphen or underscore.

# IMPORTANT : always uses /consumables/fuel/tank[0]/level-gal_us, because /level-lb seems not synchronized with
# level-gal_us, during the time of a procedure.

# conversion
# 1 US gallon = 6.6 pound
GALUSTOLB = 6.6;
LBTOKG = 0.453592;
CELSIUSTOK = 273.15;
MPSTOKT = 1.943844;
DEGTORAD = 0.0174532925199;
FPSTOKT = 0.592483801296;
NMTOFEET = 6076.11548556;
METERTOFEET = 3.28083989501;
MBARTOINHG = 0.029529987508;

# constants
# ratio of specific heats at STP
gammaairstp = 1.4;
# gas constant 286 /m2/s2/K for air
Rpm2ps2pK = 286;

# tanks content
CONTENT1LB  = 9255.01;
CONTENT2LB  = 10075.13;
CONTENT3LB  = 10075.13;
CONTENT4LB  = 9255.01;
# simplifies by removing dissymmetries
#CONTENT5LB  = 15873.28;
#CONTENT6LB  = 25544.96;
#CONTENT7LB  = 16325.23;
#CONTENT8LB  = 28302.95;
CONTENT5LB  = 16099.26;
CONTENT6LB  = 26923.95;
CONTENT7LB  = 16099.26;
CONTENT8LB  = 26923.95;
CONTENT9LB  = 24462.49;
CONTENT10LB = 26329.81;
CONTENT11LB = 22961.14;
CONTENT5ALB = 4905.29;
CONTENT7ALB = 4905.29;

# pump rate : 40 lb/s.
# at Mach 2, trim only feeds 2 supply tanks : 45200 lb/h, or 6.3 lb/s per tank.
PUMPLB = 600;
PUMPSEC = 15.0;
PUMPPMIN = 4;


# ==============
# AIRSPEED METER
# ==============

# maximum operating speed (kt)
calcvmoktcron = func {
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
       setprop("/instrumentation/airspeed-indicator/vmo-kt", vmokt);
       setprop("/instrumentation/mach-indicator/mmo-mach", mmomach);

       # overspeed
       maxkt = vmokt + 10;
       maxmach = mmomach + 0.04;
       setprop("/instrumentation/airspeed-indicator/overspeed-kt", maxkt);
       setprop("/instrumentation/mach-indicator/overspeed-mach", maxmach);
   }

   # re-schedule the next call
   settimer(calcvmoktcron, 5.0);
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


# ==========
# FUEL PUMPS
# ==========

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

# transfer between 2 tanks, arguments :
# - number of tank destination
# - content of tank destination (lb)
# - number of tank source
# - pumped volume (lb)
transfertanks = func {
   tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
   idest = arg[0];
   tankdestlb = tanks[idest].getChild("level-gal_us").getValue() * GALUSTOLB;
   contentdestlb = arg[1];
   maxdestlb = contentdestlb - tankdestlb;
   isour = arg[2];
   tanksourlb = tanks[isour].getChild("level-gal_us").getValue() * GALUSTOLB;
   maxsourlb = tanksourlb - 0;
   pumplb = arg[3];
   # can fill destination
   if( maxdestlb > 0 ) {
       # can with source
       if( maxsourlb > 0 ) {
           if( pumplb <= maxsourlb and pumplb <= maxdestlb ) {
               tanksourlb = tanksourlb - pumplb;
               tankdestlb = tankdestlb + pumplb;
           }
           # destination full
           elsif( pumplb <= maxsourlb and pumplb > maxdestlb ) {
               tanksourlb = tanksourlb - maxdestlb;
               tankdestlb = contentdestlb;
           }
           # source empty
           elsif( pumplb > maxsourlb and pumplb <= maxdestlb ) {
               tanksourlb = 0;
               tankdestlb = tankdestlb + maxsourlb;
           }
           # source empty and destination full
           elsif( pumplb > maxsourlb and pumplb > maxdestlb ) {
               # source empty
               if( maxdestlb > maxsourlb ) {
                   tanksourlb = 0;
                   tankdestlb = tankdestlb + maxsourlb;
               }
               # destination full
               elsif( maxdestlb < maxsourlb ) {
                   tanksourlb = tanksourlb - maxdestlb;
                   tankdestlb = contentdestlb;
               }
               # source empty and destination full
               else {
                  tanksourlb = 0;
                  tankdestlb = contentdestlb;
               }
           }
           # user sees emptying first
           # JBSim only sees US gallons
           tanksourgalus = tanksourlb / GALUSTOLB;
           tanks[isour].getChild("level-gal_us").setValue(tanksourgalus);
           tankdestgalus = tankdestlb / GALUSTOLB;
           tanks[idest].getChild("level-gal_us").setValue(tankdestgalus);
       }
   }
}

# pump forward
pumpforward = func {
       # from tank 11
       tank9lb = getprop("/consumables/fuel/tank[8]/level-gal_us") * GALUSTOLB;
       tank11lb = getprop("/consumables/fuel/tank[10]/level-gal_us") * GALUSTOLB;
       # towards tank 9 at first
       if( tank9lb < CONTENT9LB ) {
           # from rear tank 11
           if( tank11lb > 0 ) {
               transfertanks( 8, CONTENT9LB, 10, PUMPLB );
           }
       }
       # towards tank 10
       else {
           tank10lb = getprop("/consumables/fuel/tank[9]/level-gal_us") * GALUSTOLB ;
           if( tank10lb < CONTENT10LB ) {
               # from rear tank 11
               if( tank11lb > 0 ) {
                   transfertanks( 9, CONTENT10LB, 10, PUMPLB );
               }
           }
       }
}

# pump aft
pumpaft = func {
       tank11lb = getprop("/consumables/fuel/tank[10]/level-gal_us") * GALUSTOLB;
       # from tank 9 at first
       if( getprop("/consumables/fuel/tank[8]/level-gal_us") > 0 ) {
           # towards tank 11
           if( tank11lb < CONTENT11LB ) {
               transfertanks( 10, CONTENT11LB, 8, PUMPLB );
           }
       }
       # from tank 10
       elsif( getprop("/consumables/fuel/tank[9]/level-gal_us") > 0 ) {
           # towards tank 11
           if( tank11lb < CONTENT11LB ) {
                transfertanks( 10, CONTENT11LB, 9, PUMPLB );
           }
       }
}

# feed a left engine supply tank, with left main tanks
# - number of tank
# - content of tank (lb)
# - pumped volume (lb)
pumpleftmain = func {
   tank = arg[0];
   contentlb = arg[1];
   pumplb = arg[2] / 3;

   # balance the load on tanks 5, 6, and 5A
   # serve the forwards tanks at first, to shift the center of gravity aft
   transfertanks( tank, contentlb, 4, pumplb );
   transfertanks( tank, contentlb, 5, pumplb );
   transfertanks( tank, contentlb, 11, pumplb );
}

# feed a right engine supply tank, with right main tanks
# - number of tank
# - content of tank (lb)
# - pumped volume (lb)
pumprightmain = func {
   tank = arg[0];
   contentlb = arg[1];
   pumplb = arg[2] / 3;

   # balance the load on tanks 7, 8 and 7A
   # serve the forwards tanks at first, to shift the center of gravity aft
   transfertanks( tank, contentlb, 6, pumplb );
   transfertanks( tank, contentlb, 7, pumplb );
   transfertanks( tank, contentlb, 12, pumplb );
}

# feed engine supply tank, with trim tanks
# - number of tank
# - content of tank (lb)
# - pumped volume (lb)
# - aft
pumptrim = func {
   tank = arg[0];
   contentlb = arg[1];
   aft = arg[3];
   pumplb = arg[2];

   # front tanks 9 and 10 (center of gravity goes rear)
   if( aft ) {
       tank9 = getprop("/consumables/fuel/tank[8]/level-gal_us");
       if( tank9 > 0 ) {
           transfertanks( tank, contentlb, 8, pumplb );
       }
       # front tank 10 at last
       else {
           transfertanks( tank, contentlb, 9, pumplb );
       }
   }
   # rear tanks 11 (center of gravity goes forwards)
   else {
       tank11 = getprop("/consumables/fuel/tank[10]/level-gal_us");
       # from tank 11
       if( tank11 > 0 ) {
           transfertanks( tank, contentlb, 10, pumplb );
       }
   }
}

# dump a tank
# - number of tank
# - dumped volume (lb)
dumptank = func {
   tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
   itank = arg[0];
   tanklb = tanks[itank].getChild("level-gal_us").getValue() * GALUSTOLB;
   dumplb = arg[1];
   # can fill destination
   if( tanklb > 0 ) {
       if( tanklb > dumplb ) {
           tanklb = tanklb - dumplb;
       }
       # empty
       else {
           tanklb = 0;
       }
       # JBSim only sees US gallons
       tankgalus = tanklb / GALUSTOLB;
       tanks[itank].getChild("level-gal_us").setValue(tankgalus);
   }
}

# dump rear tanks
dumpreartanks = func {
   # tank 11 (tail)
   dumptank( 10, PUMPLB );
   # tanks 5A and 7A (rear outboord)
   dumptank( 11, PUMPLB );
   dumptank( 12, PUMPLB );
   # tanks 2 and 3 (rear inboord)
   dumptank( 1, PUMPLB );
   dumptank( 2, PUMPLB );
}

# balance 2 tanks
# - number of left tank
# - content of left tank
# - number of right tank
# - content of right tank
# - dumped volume (lb)
pumpcross = func {
   tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
   ileft = arg[0];
   tankleftlb = tanks[ileft].getChild("level-gal_us").getValue() * GALUSTOLB;
   contentleftlb = arg[1];
   iright = arg[2];
   tankrightlb = tanks[iright].getChild("level-gal_us").getValue() * GALUSTOLB;
   contentrightlb = arg[3];
   pumplb = arg[4];
   difflb = tankleftlb - tankrightlb;
   difflb = difflb / 2;

   # right too heavy
   if( difflb < 0 ) {
       difflb = - difflb;
       if( difflb > pumplb ) {
           difflb = pumplb;
       }
       transfertanks( ileft, contentleftlb, iright, difflb );
   }
   # left too heavy
   elsif( difflb > 0 )  {
       if( difflb > pumplb ) {
           difflb = pumplb;
       }
       transfertanks( iright, contentrightlb, ileft, difflb );
   }
}

# balance all tanks
crosstanks = func {
   # tanks 1 and 4
   pumpcross( 0, CONTENT1LB, 3, CONTENT4LB, PUMPLB );
   # tanks 5 and 7
   pumpcross( 4, CONTENT5LB, 6, CONTENT7LB, PUMPLB );
   # tanks 6 and 8
   pumpcross( 5, CONTENT6LB, 7, CONTENT8LB, PUMPLB );
   # tanks 2 and 3
   pumpcross( 1, CONTENT2LB, 2, CONTENT3LB, PUMPLB );
   # tanks 5A and 7A
   pumpcross( 11, CONTENT5ALB, 12, CONTENT7ALB, PUMPLB );
}

# feed engines
feedenginescron = func {
   # avoid parallel updates
   pump = props.globals.getNode("/systems/fuel-pump");
   engine = pump.getChild("engine").getValue();
   forward = pump.getChild("forward").getValue();
   aft = pump.getChild("aft").getValue();
   dump = pump.getChild("dump").getValue();
   dump2 = pump.getChild("dump2").getValue();
   cross = pump.getChild("cross").getValue();

   # feeds from trim tanks
   if( engine and ( forward or aft ) ) {
       # balance the main tanks, closest to the collector tank
       pumptrim( 4, CONTENT5LB, PUMPLB, aft );
       pumptrim( 6, CONTENT7LB, PUMPLB, aft );

       # avoids running out of fuel
       pumpleftmain( 0, CONTENT1LB, PUMPLB );
       pumpleftmain( 1, CONTENT2LB, PUMPLB );
       pumprightmain( 2, CONTENT3LB, PUMPLB );
       pumprightmain( 3, CONTENT4LB, PUMPLB );
   }
   # all tanks (balance)
   else {
       pumpleftmain( 0, CONTENT1LB, PUMPLB );
       pumpleftmain( 1, CONTENT2LB, PUMPLB );
       pumprightmain( 2, CONTENT3LB, PUMPLB );
       pumprightmain( 3, CONTENT4LB, PUMPLB );

       # a BUG somewhere (nasal ?) :
       # - the 1st time one sets aft, forward is set.
       # - one has to set forward 1 time, to make aft work.
       if( forward ) {
           pumpforward();
       }
       elsif( aft ) {
           pumpaft();
       }
   }
   # avoid parallel events
   # 2 buttons for confirmation
   if( dump and dump2 ) {
       dumpreartanks();
   }
   if( cross ) {
       crosstanks();
   }
   totalfuel();

   # synchronize with fuel gauges
   corridorcg();
   centergravity();
   corridormach();
   insfuel();
 
   # re-schedule the next call
   periodsec = PUMPSEC;
   speedup = getprop("/sim/speed-up");
   periodsec = periodsec / speedup;
   settimer(feedenginescron, periodsec);
}


# =====================
# CABINE PRESSURIZATION
# =====================

# human physiology tolerates 18 mbar per minute until 8000 ft.
PRESSURIZEMBARPM = 18.0;
# 18 mbar/minute = 0.53 inhg/minute
PRESSURIZEINHGPM = PRESSURIZEMBARPM * MBARTOINHG;
# sampling
PRESSURIZESEC = 15.0;
PRESSURIZEMBAR = PRESSURIZEMBARPM / ( 60 / PRESSURIZESEC );
PRESSURIZEINHG = PRESSURIZEMBAR * MBARTOINHG;
# max descent speed around 6000 feet/minute.
PRESSURIZEFTPM = 7000.0 / ( 60 / PRESSURIZESEC );
# 8000 ft (standard atmosphere)
PRESSURIZEMININHG = 22.25;
PRESSURIZEMAXFT = 8000.0;

# cabine altitude in feet, arguments
# - cabine pressure in inhg
# - "true" if below 8000 ft
cabinealtitude = func {
   cabineinhg = arg[0];
   interpolate = arg[1];

   # one supposes instrument calibrated by standard atmosphere
if( interpolate == "true" ) {
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
else {
   cabineinhg = PRESSURIZEMININHG;
   cabinealtft = PRESSURIZEMAXFT;
}

   setprop("/instrumentation/cabine-altitude/cabine-inhg",cabineinhg);
   setprop("/instrumentation/cabine-altitude/indicated-altitude-ft",cabinealtft);
}

# cabine altitude meter (pressurization)
calccabineftcron = func {
   lastaltft = getprop("/systems/pressurization/altitude-sea-ft");
   aglft = getprop("/position/altitude-agl-ft");
   altseaft = getprop("/position/altitude-ft");
   seainhg = getprop("/environment/pressure-sea-level-inhg");
   pressureinhg = getprop("/environment/pressure-inhg");
   cabineinhg = getprop("/instrumentation/cabine-altitude/cabine-inhg");

   # filters startup
   if( aglft == nil or altseaft == nil or seainhg == nil or pressureinhg == nil ) {
       aglft = 0.0;
       altseaft = 0.0;
       seainhg = 29.92;
       pressureinhg = 29.92;

       targetinhg = 29.92;
       outflowinhg = 0.0;

       startup = "true";
   }

   # pressurization curve has a lower slope than aircraft descent/climb profile
   else {
       # 11 ft AGL on ground (Z height of center of gravity minus Z height of main landing gear)
       aglft = aglft - 11.0;

       if( aglft > 2500.0 ) {
           # average vertical speed of 2000 feet/minute
           minutes = altseaft / 2000.0;
           targetinhg = seainhg - minutes * PRESSURIZEINHGPM;
           if( targetinhg < PRESSURIZEMININHG ) {
               targetinhg = PRESSURIZEMININHG;
           }
       }

       # radio altimeter works below 2500 feet
       else {
           # average landing speed of 1500 feet/minute
           minutes = ( altseaft - aglft ) / 1500.0;
           targetinhg = seainhg - minutes * PRESSURIZEINHGPM;
           if( targetinhg < PRESSURIZEMININHG ) {
               targetinhg = PRESSURIZEMININHG;
           }
       }

       startup = "false";
   }

   # ==========
   # real modes
   # ==========
   if( startup != "true" ) {
       outflowinhg = targetinhg - cabineinhg;
       if( cabineinhg < targetinhg ) {
           if( outflowinhg > PRESSURIZEINHG ) {
               outflowinhg = PRESSURIZEINHG;
           }
           cabineinhg = cabineinhg + outflowinhg;
       }
       elsif( cabineinhg > targetinhg ) {
           if( outflowinhg < -PRESSURIZEINHG ) {
               outflowinhg = -PRESSURIZEINHG;
           }
           cabineinhg = cabineinhg + outflowinhg;
       }
       # balance
       else {
           outflowinhg = 0;
           cabineinhg = targetinhg;
       }
   }

   # one supposes instrument calibrated by standard atmosphere
   if( outflowinhg != 0 or cabineinhg > PRESSURIZEMININHG ) {
       interpolate = "true";
   }

   # above 8000 ft
   else {
       interpolate = "false";
   }

   # ================
   # artificial modes
   # ================
   # relocation in flight
   if( startup != "true" ) {
       variationftpm = lastaltft - altseaft;
       if( variationftpm < -PRESSURIZEFTPM or variationftpm > PRESSURIZEFTPM ) {
           outflowinhg = 0.0;
           cabineinhg = targetinhg;
           interpolate = "true";        
       }
       # relocation on ground (change of airport)
       elsif( aglft < 1.0 ) {
           outflowinhg = 0.0;
           targetinhg = pressureinhg;
           cabineinhg = targetinhg;
           interpolate = "true";
       }
   }

   setprop("/systems/pressurization/atmosphere-inhg",pressureinhg);
   setprop("/systems/pressurization/target-inhg",targetinhg);
   setprop("/systems/pressurization/outflow-inhg",outflowinhg);
   setprop("/systems/pressurization/altitude-sea-ft",altseaft);
   cabinealtitude( cabineinhg, interpolate );        

   # re-schedule the next call
   settimer(calccabineftcron, PRESSURIZESEC);
}


# ==========================
# INERTIAL NAVIGATION SYSTEM
# ==========================

# ins fuel
insfuel = func {
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


# ==============
# TRUE AIR SPEED
# ==============

# true air speed
calctascron = func {
   ubodyfps = getprop("/velocities/uBody-fps");
   vbodyfps = getprop("/velocities/vBody-fps");
   speedfps2 = ubodyfps*ubodyfps + vbodyfps*vbodyfps;
   taskt = math.sqrt(speedfps2) * FPSTOKT;
   setprop("/instrumentation/tas-indicator/indicated-tas-kt",taskt);

   # re-schedule the next call
   settimer(calctascron, 3.0);
}


# ===========
# TEMPERATURE
# ===========

# maximum total temperature
calctmodegccron = func {
   speedmach = getprop("/velocities/mach");
   if( speedmach >= 1.0 ) {
       oatdegc=getprop("/environment/temperature-degc");

       # TMO 127C at Mach 2.02 :
       # - cold atmosphere : static temperature < -55C.
       # - hot atmosphere : static temperature > -51C (Max Cruise mode).
       #
       # linear is supposed
       stepmach = 2.02 - speedmach;
       deltamach = 2.02 - 1.0;
       deltadegc = 127 - ( - 53 );
       tmodegc = oatdegc + deltadegc * ( 1 - stepmach / deltamach );

       setprop("/instrumentation/temperature/indicated-tmo-degc",tmodegc);
   }

   # re-schedule the next call
   settimer(calctmodegccron, 15.0);
}


# ============================
# INSTANTANEOUS VERTICAL SPEED
# ============================

INSTRUMENTSEC = 0.10;
FILTERSEC = 0.10;
FILTERW = INSTRUMENTSEC / FILTERSEC;
FILTERCOEF1 = 1.0 / ( FILTERW + 1.0 );
FILTERCOEF2 = FILTERW / ( FILTERW + 1.0 );

# specific VSI
calcverticalfpscron = func {
   # not filtered
   pressureinhg = getprop("/environment/pressure-inhg");
   altimeterinhg = getprop("/instrumentation/altimeter/setting-inhg");
   if( altimeterinhg != nil and pressureinhg != nil ) {
       # reduces oscillations
       lastsec = getprop("/instrumentation/instantaneous-vertical-speed-indicator/elapsed-sec");
       nowsec = getprop("/sim/time/elapsed-sec");
       if( lastsec == nil or nowsec == nil ) {
           stepsec = INSTRUMENTSEC;
           nowsec = 0.0;
       }
       else {
           stepsec = nowsec - lastsec;
       }

       # pressure rate of change
       lastinhg = getprop("/instrumentation/instantaneous-vertical-speed-indicator/pressure-inhg");
       if( lastinhg == nil ) {
           rateinhgps = 0.0;
       }
       else {
           rateinhgps = ( pressureinhg - lastinhg ) / stepsec;
       }

       setprop("/instrumentation/instantaneous-vertical-speed-indicator/elapsed-sec",nowsec);
       setprop("/instrumentation/instantaneous-vertical-speed-indicator/pressure-inhg",pressureinhg);
       setprop("/instrumentation/instantaneous-vertical-speed-indicator/rate-inhg-per-s",rateinhgps);

       deltainhg = altimeterinhg - pressureinhg;
       setprop("/instrumentation/instantaneous-vertical-speed-indicator/delta-inhg",deltainhg);

       # standard atmosphere (pressure difference from sea level) : search for the current altitude
       slopeft = 2952.75591;
       # guess below - 2700 m
       if( deltainhg < -8.41 ) {
           slopeinhg = 7.65;
           slopeft = 8858.26772;
       }
       # - 2700 m
       elsif( deltainhg >= -8.41 and deltainhg < 0 ) {
           slopeinhg = 0 + 8.41;
           slopeft = 8858.26772;
       }
       # 0 m
       elsif( deltainhg >= 0 and deltainhg < 3.05 ) {
           slopeinhg = 3.05 - 0;
       }
       # 900 m
       elsif( deltainhg >= 3.05 and deltainhg < 5.86 ) {
           slopeinhg = 5.86 - 3.05;
       }
       # 1800 m
       elsif( deltainhg >= 5.86 and deltainhg < 8.41 ) {
           slopeinhg = 8.41 - 5.86;
       }
       # 2700 m
       elsif( deltainhg >= 8.41 and deltainhg < 10.74 ) {
           slopeinhg = 10.74 - 8.41;
       }
       # 3600 m
       elsif( deltainhg >= 10.74 and deltainhg < 12.87 ) {
           slopeinhg = 12.87 - 10.74;
       }
       # 4500 m
       elsif( deltainhg >= 12.87 and deltainhg < 14.78 ) {
           slopeinhg = 14.78 - 12.87;
       }
       # 5400 m
       elsif( deltainhg >= 14.78 and deltainhg < 16.55 ) {
           slopeinhg = 16.55 - 14.78;
       }
       # 6300 m
       elsif( deltainhg >= 16.55 and deltainhg < 18.13 ) {
           slopeinhg = 18.13 - 16.55;
       }
       # 7200 m
       elsif( deltainhg >= 18.13 and deltainhg < 19.62 ) {
           slopeinhg = 19.62 - 18.13;
       }
       # 8100 m
       elsif( deltainhg >= 19.62 and deltainhg < 20.82 ) {
           slopeinhg = 20.82 - 19.62;
       }
       # 9000 m
       elsif( deltainhg >= 20.82 and deltainhg < 21.96 ) {
           slopeinhg = 21.96 - 20.82;
       }
       # 9900 m
       elsif( deltainhg >= 21.96 and deltainhg < 23.01 ) {
           slopeinhg = 23.01 - 21.96;
       }
       # 10800 m
       elsif( deltainhg >= 23.01 and deltainhg < 23.91 ) {
           slopeinhg = 23.91 - 23.01;
       }
       # 11700 m
       elsif( deltainhg >= 23.91 and deltainhg < 24.71 ) {
           slopeinhg = 24.71 - 23.91;
       }
       # 12600 m
       elsif( deltainhg >= 24.71 and deltainhg < 25.40 ) {
           slopeinhg = 25.40 - 24.71;
       }
       # 13500 m
       elsif( deltainhg >= 25.40 and deltainhg < 26.00 ) {
           slopeinhg = 26.00 - 25.40;
       }
       # 14400 m
       elsif( deltainhg >= 26.00 and deltainhg < 26.51 ) {
           slopeinhg = 26.51 - 26.00;
       }
       # 15300 m
       elsif( deltainhg >= 26.51 and deltainhg < 27.35 ) {
           slopeinhg = 27.35 - 26.51;
       }
       # 16200 m
       elsif( deltainhg >= 27.35 and deltainhg < 27.68 ) {
           slopeinhg = 27.68 - 27.35;
       }
       # 17100 m
       elsif( deltainhg >= 27.68 and deltainhg < 27.98 ) {
           slopeinhg = 27.98 - 27.68;
       }
       # guess above 18900 m
       else {
           slopeinhg = 0.27;
       }
   
       setprop("/instrumentation/instantaneous-vertical-speed-indicator/slope-inhg",slopeinhg);
       speedfps = - rateinhgps * slopeft / slopeinhg;

       # low pass filter
#       lastfps = getprop("/instrumentation/instantaneous-vertical-speed-indicator/indicated-speed-fps");
#       if( lastfps != nil ) {
#           speedfps = FILTERCOEF1 * lastfps + FILTERCOEF2 * speedfps;
#       }

       setprop("/instrumentation/instantaneous-vertical-speed-indicator/indicated-speed-fps",speedfps);
   }

   # re-schedule the next call
   settimer(calcverticalfpscron, INSTRUMENTSEC);
}


# ===============
# AUTOPILOT MODES
# ===============

# disconnect autopilot
apdiscexport = func {
   apdischeadingexport();
   apdiscverticalexport();
   apdischorizontalexport();
   apdiscaltitudeexport();
   apdiscaltitude2export();
}

# activate autopilot
apexport = func {
   ap = props.globals.getNode("/autopilot").getChildren("locks");
   altitude = ap[0].getChild("altitude").getValue();
   altitude2 = ap[0].getChild("altitude2").getValue();
   heading = ap[0].getChild("heading").getValue();
   vertical = ap[0].getChild("vertical").getValue();
   horizontal = ap[0].getChild("horizontal").getValue();

   # pitch hold and heading hold is default on activation
   if( altitude == "" and altitude2 == "" and heading == "" and vertical == "" and horizontal == "" ) {
       appitchexport();
       apheadingholdexport();
   }
   else {
       apdiscexport();
   }
}

# -------------
# VERTICAL MODE
# -------------

# disconnect vertical mode
apdiscverticalexport = func {
   setprop("/autopilot/locks/vertical","");
}

# disconnect altitude 2 mode
apdiscaltitude2export = func {
   setprop("/autopilot/locks/altitude2","");
}

# go around mode
goaround = func {
   verticalmode = getprop("/autopilot/locks/vertical");
   # 2 throttles full foward during an autoland or glide slope
   if( getprop("/autopilot/locks/altitude") == "gs1-hold" or verticalmode == "autoland" ) {
       engine = props.globals.getNode("/controls/engines").getChildren("engine");
       count = 0;
       for(i=0; i<size(engine); i=i+1) {
           if( engine[i].getChild("throttle").getValue() == 1 ) {
               count = count + 1;
           }
       }
       if( count >= 2 ) {
           # pitch at 15 deg and hold the wing level, until the next command of crew
           setprop("/autopilot/settings/target-pitch-deg",15);
           setprop("/autopilot/locks/altitude","pitch-hold");
           setprop("/autopilot/locks/heading","wing-leveler");
           # disable other vertical modes
           apdiscaltitude2export();
           # crew control
           atdiscspeedexport();
           # light on
           setprop("/autopilot/locks/vertical","goaround");
       }
   }
   # light off
   if( verticalmode == "goaround" ) {
       if( getprop("/autopilot/settings/target-pitch-deg") != 15 or
           getprop("/autopilot/locks/altitude") != "pitch-hold" or
           getprop("/autopilot/locks/heading") != "wing-leveler" ) {
           apdiscverticalexport();
       }
   }
}

# adjust target speed with wind
# - target speed (kt)
targetwind = func {
   # VREF 152-162 kt
   tankskg = getprop("/instrumentation/fuel/total-kg");
   if( tankskg > 19000 )
   {
       targetkt = 162;
   }
   else
   {
       targetkt = 152 + 10 * ( 19000 - tankskg ) / 19000;
   }

   # wind increases lift
   windkt = getprop("/environment/wind-speed-kt");
   if( windkt > 0 ) {
       winddeg = getprop("/environment/wind-from-heading-deg");
       vordeg = getprop("/radios/nav/radials/target-radial-deg");
       offsetdeg = vordeg - winddeg;
       # north crossing
       if( offsetdeg > 180 ) {
           offsetdeg = offsetdeg - 360;
       }
       elsif( offsetdeg < -180 ) {
              offsetdeg = offsetdeg + 360;
       }
       # add head wind component;
       # except tail wind (too much glide)
       if( offsetdeg > -90 and offsetdeg < 90 ) {
           offsetrad = offsetdeg * DEGTORAD;
           offsetkt = windkt * math.cos( offsetrad );
           targetkt = targetkt + offsetkt;
       }
   }
   # avoid infinite gliding (too much ground effect ?)
   setprop("/autopilot/settings/target-speed-kt",targetkt);
}

# autoland mode
# (tested at 245000 lb)
autolandcron = func {
   verticalmode2 = "";      
   verticalmode = getprop("/autopilot/locks/vertical") ;
   if( verticalmode == "autoland" or verticalmode == "autoland-armed" ) {
       verticalmode2 = "goaround-armed";
       aglft = getprop("/position/altitude-agl-ft") ;
       # armed
       if( verticalmode == "autoland-armed" ) {
           if( aglft <= 1500 ) {
               verticalmode = "autoland";
               setprop("/autopilot/locks/vertical",verticalmode);
           }
           else {
               rates = 1.0;
           }
       }
       # engaged
       if( verticalmode == "autoland" ) {
           # touch down
           # JBSim indicates :
           # - 11 ft AGL on ground (Z height of center of gravity minus Z height of main landing gear)
           # - 13 ft when main wing gear touches the ground
           if( aglft < 14 ) {
               # gently reduce pitch
               if( getprop("/orientation/pitch-deg") > 1.0 ) {
                   rates = 0.2;
                   # 1 deg / s
                   pitchdeg = getprop("/autopilot/settings/target-pitch-deg");
                   pitchdeg = pitchdeg - 0.2;
                   setprop("/autopilot/settings/target-pitch-deg",pitchdeg);
                   apdiscaltitudeexport();
                   setprop("/autopilot/locks/altitude","pitch-hold");
                   apdiscaltitude2export();
               }
               # safe on ground
               else {
                   rates = 1.0;
                   # disable autopilot
                   apdiscaltitudeexport();
                   apdischeadingexport();
                   apdischorizontalexport();
			 apdiscverticalexport();
                   verticalmode2 = "";
                   # reset trims
                   setprop("/controls/flight/elevator-trim",0.0);
                   setprop("/controls/flight/rudder-trim",0.0);
                   setprop("/controls/flight/aileron-trim",0.0);
               }
               # engine idles
               engine = props.globals.getNode("/controls/engines").getChildren("engine");
               if( engine[0].getChild("throttle").getValue != 0 ) {
                   for(i=0; i<size(engine); i=i+1) {
                       engine[i].getChild("throttle").setValue(0);
                   }
               }
           }
           # triggers below 1500 ft
           elsif( aglft > 1500 ) {
               rates = 1.0;
               verticalmode = "autoland-armed";
               setprop("/autopilot/locks/vertical",verticalmode);
           }
           else {
               # landing pitch
               if( aglft < 175 ) {
                   rates = 0.1;
                   apdiscaltitudeexport();
                   setprop("/autopilot/settings/target-pitch-deg",10);
                   setprop("/autopilot/locks/altitude","pitch-hold");
                   setprop("/autopilot/settings/vertical-speed-fpm",-750);
                   setprop("/autopilot/locks/altitude2","vertical-speed-with-throttle");
                   atdiscspeedexport();
               }
               # glide slope
               else {
                   rates = 0.1;
                   apdiscaltitudeexport();
                   setprop("/autopilot/locks/altitude","gs1-hold");
                   # near VREF (no wind)
                   targetwind();
                   setprop("/autopilot/locks/speed","speed-with-throttle");
               }
               setprop("/autopilot/locks/heading","nav1-hold");
               apdischorizontalexport();
           }
       }
   }
   else {
       rates = 1.0;
       if( getprop("/autopilot/locks/altitude") == "gs1-hold" ) {
           verticalmode2 = "goaround-armed";      
       }
   }

   # 0.1 s improves the catch of throttle maximum, when autoland
   setprop("/autopilot/locks/vertical2",verticalmode2);
   goaround();

   # re-schedule the next call
   if( verticalmode2 == "goaround-armed" or getprop("/autopilot/locks/vertical") == "goaround" ) {
      settimer(autolandcron, rates);
   }
}

# autopilot autoland
aplandexport = func {
   verticalmode = getprop("/autopilot/locks/vertical");
   if( verticalmode != "autoland" and verticalmode != "autoland-armed" ) {
       setprop("/autopilot/locks/vertical","autoland-armed");
       if( getprop("/autopilot/locks/vertical2") != "goaround-armed" ) {
           autolandcron();
       }
   }
   else {
       apdiscverticalexport();
   }
}

# autopilot turbulence mode
apturbulenceexport = func {
   verticalmode = getprop("/autopilot/locks/vertical");
   if( verticalmode != "turbulence" ) {
       apdiscaltitudeexport();
       setprop("/autopilot/locks/vertical","turbulence");
       pitchdeg = getprop("/orientation/pitch-deg");
       setprop("/autopilot/settings/target-pitch-deg",pitchdeg);
       setprop("/autopilot/locks/altitude","pitch-hold");
       headingdeg = getprop("/orientation/heading-deg");
       setprop("/autopilot/settings/true-heading-deg",headingdeg);
       setprop("/autopilot/locks/heading","true-heading-hold");
       apdischorizontalexport();
   }
   else {
       apdiscverticalexport();
	 apdiscaltitudeexport();
       apdischeadingexport(); 
   }
}

# -------------
# ALTITUDE MODE
# -------------

# disconnect autopilot altitude
apdiscaltitudeexport = func {
   setprop("/autopilot/locks/altitude","");
}

# altitude button lights, when the dialed altitude is reached.
# altimeter light, when the dialed altitude is reached.
altitudelightcron = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode == "altitude-hold" ) {
       altft = getprop("/autopilot/settings/target-altitude-ft");
       # altimeter light within 1000 ft
       minft = altft - 1000;
       setprop("/instrumentation/altimeter/target-min-ft",minft);
       maxft = altft + 1000;
       setprop("/instrumentation/altimeter/target-max-ft",maxft);
       # no altimeter light within 50 ft
       minft = altft - 50;
       setprop("/instrumentation/altimeter/light-min-ft",minft);
       maxft = altft + 50;
       setprop("/instrumentation/altimeter/light-max-ft",maxft);

       # re-schedule the next call
       settimer(altitudelightcron, 15.0);
   }
}

# datum adjust of pitch
datumpitchexport = func {
   sign=arg[0];

   # plus/minus 11 deg
   datumdeg = getprop("/autopilot/datum/pitch-deg");
   step = 1.0 * sign;
   if( datumdeg == nil ) {
       datumdeg = step;
   }
   else {
       datumdeg = datumdeg + step;
   }
   if( datumdeg >= -22.0 and datumdeg <= 22.0 ) {
       degrange = "true";
       setprop("/autopilot/datum/pitch-deg",datumdeg);
   }
   else {
       degrange = "false";
   }

   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode == "pitch-hold" ) {
       if( degrange == "true" ) {
           targetdeg = getprop("/autopilot/settings/target-pitch-deg");
           step = 0.5 * sign;
           targetdeg = targetdeg + step;
           setprop("/autopilot/settings/target-pitch-deg",targetdeg);
       }
   }
}

# autopilot altitude hold
apaltitudeexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "altitude-hold" ) {
       setprop("/autopilot/locks/altitude","altitude-hold");
       apdiscverticalexport();
       altitudelightcron();
   }
   else {
       apdiscaltitudeexport();
   }
}

# autopilot glide slope
apglideexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "gs1-hold" ) {
       apdiscaltitudeexport();
       setprop("/autopilot/locks/altitude","gs1-hold");
       setprop("/autopilot/locks/heading","nav1-hold");
       apdischorizontalexport();
       apdiscverticalexport();
       if( getprop("/autopilot/locks/vertical2") != "goaround-armed" ) {
           autolandcron();
       }
   }
   else {
       apdiscaltitudeexport();
   }
}

# autopilot pitch hold
appitchexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "pitch-hold" ) {
       apdiscaltitudeexport();
       pitchdeg = getprop("/orientation/pitch-deg");
       setprop("/autopilot/settings/target-pitch-deg",pitchdeg);
       setprop("/autopilot/locks/altitude","pitch-hold");
       apdiscverticalexport();
   }
   else {
       apdiscaltitudeexport();
   }
}

# autopilot vertical speed hold
apverticalexport = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode != "vertical-speed-hold" ) {
       setprop("/autopilot/locks/altitude","vertical-speed-hold");
       apdiscverticalexport();
   }
   else {
       apdiscaltitudeexport();
   }
}

# ---------------
# HORIZONTAL MODE
# ---------------

# disconnect horizontal mode
apdischorizontalexport = func {
   setprop("/autopilot/locks/horizontal","");
}

# ins light
inslightcron = func {
   insmode = "false";
   # new waypoint
   if( getprop("/autopilot/locks/horizontal") != "ins" ) {
       if( getprop("/autopilot/locks/heading") == "true-heading-hold" ) {
           waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
           distance = waypoints[0].getChild("dist").getValue();
           if( distance != nil and distance != 0.0 ) {
               insmode = "true";
               setprop("/autopilot/locks/horizontal","ins");
           }
       }
   }
   # no more waypoint
   else {
       waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
       if( waypoints[0].getChild("dist").getValue() == 0.0 ) {
           apdischorizontalexport();
       }
       else {
           insmode = "true";
       }
   }

   # ground speed from waypoint
   if( insmode == "true" )
   {
       waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
       distnm = waypoints[0].getChild("dist").getValue();
       timesec = getprop("/sim/time/elapsed-sec");
       # no waypoint
       if( distnm == nil or distnm == 0.0 ) {
           groundkt = 9999;
      }
       else {
           lastdistnm = getprop("/instrumentation/ins/last-wp-nm");
           lasttimesec = getprop("/instrumentation/ins/last-time-s");
           if( lastdistnm != nil and lasttimesec != nil ) {
               deltanm = lastdistnm - distnm;
               deltafeet = deltanm * NMTOFEET;
               deltasec = timesec - lasttimesec;
               groundfps = deltafeet / deltasec;
               groundkt = groundfps * FPSTOKT;
               # speed up
               speedup = getprop("/sim/speed-up");
               groundkt = groundkt / speedup;
               if( groundkt < 0 ) {
                   groundkt = - groundkt;
               }
           }
           else {
               groundkt = 9999;
           }
       }
       setprop("/instrumentation/ins/last-wp-nm",distnm);
       setprop("/instrumentation/ins/last-time-s",timesec);
       setprop("/instrumentation/ins/ground-speed-kt",groundkt);
   }

   # re-schedule the next call
   settimer(inslightcron, 5.0);
}

# ins mode
apinsexport = func {
   horizontalmode = getprop("/autopilot/locks/horizontal");

   if( horizontalmode != "ins" ) {
       waypoint = getprop("/autopilot/route-manager/wp[0]/id");
       if( waypoint != "" ) {
           setprop("/autopilot/locks/heading","true-heading-hold");
           setprop("/autopilot/locks/horizontal","ins");
       }
   }
   else {
       apdischeadingexport(); 
       apdischorizontalexport();
   }
}

# ------------
# HEADING MODE
# ------------

# disconnect heading mode
apdischeadingexport = func {
   setprop("/autopilot/locks/heading","");
}

# autopilot magnetic heading
apmagheadingexport = func {
   headingmode = getprop("/autopilot/locks/heading");
   if( headingmode != "dg-heading-hold" ) {
       setprop("/autopilot/locks/heading","dg-heading-hold");
       apdischorizontalexport();
   }
   else {
       apdischeadingexport(); 
   }
}

# heading hold
apheadingholdexport = func {
   headingdeg = getprop("/orientation/heading-magnetic-deg");
   setprop("/autopilot/settings/heading-bug-deg",headingdeg);
   apmagheadingexport();
}

# autopilot heading
apheadingexport = func {
   headingmode = getprop("/autopilot/locks/heading");
   if( headingmode != "dg-heading-hold" and headingmode != "true-heading-hold" ) {
       trackpush = getprop("/autopilot/settings/track-push");
       if( trackpush == nil or !trackpush ) {
           apmagheadingexport();
       }
       else {
           setprop("/autopilot/locks/heading","true-heading-hold");
           apdischorizontalexport();
       }
   }
   elsif( headingmode == "dg-heading-hold" ) {
       apmagheadingexport();
   }
   else {
       apdischeadingexport(); 
       apdischorizontalexport();
   }
}

# autopilot vor localizer
apvorlocexport = func {
   headingmode = getprop("/autopilot/locks/heading");
   if( headingmode != "nav1-hold" ) {
       setprop("/autopilot/locks/heading","nav1-hold");
       apdischorizontalexport();
   }
   else {
       apdischeadingexport(); 
   }
}

# ----------
# SPEED MODE
# ----------

# disconnect speed 2 mode
atdiscspeed2export = func {
   setprop("/autopilot/locks/speed2","");
}

# max climb mode (includes max cruise mode)
maxclimbcron = func {
   speedmode = getprop("/autopilot/locks/speed2");
   if( speedmode == "maxclimb" or speedmode == "maxcruise" ) {          
       speedmach = getprop("/velocities/mach");
       if( speedmach < 1.7 ) {
           vmokt = getprop("/instrumentation/airspeed-indicator/vmo-kt");
           maxkt = getprop("/instrumentation/airspeed-indicator/overspeed-kt");
           # may be out of order
           speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
           # catches the VMO with autothrottle
           if( speedkt < maxkt ) {
               setprop("/autopilot/settings/target-speed-kt",vmokt);
               setprop("/autopilot/locks/speed","speed-with-throttle");
           }
           # then holds the VMO with pitch
           else {
              setprop("/autopilot/settings/target-speed-kt",vmokt);
              setprop("/autopilot/locks/speed","speed-with-pitch");
           }

           if( speedmode == "maxcruise" ) {
               setprop("/autopilot/locks/speed2","maxclimb");
           }
       }
       else {
           mmomach = getprop("/instrumentation/mach-indicator/mmo-mach");
           # cruise at Mach 2.0-2.02 (reduce fuel consumption)          
           if( mmomach > 2.02 ) {
               mmomach = 2.02;
           }
           # TO DO : control TMO over 128C
           # catches the MMO with autothrottle
           setprop("/autopilot/settings/target-mach",mmomach);
           setprop("/autopilot/locks/speed","mach-with-throttle");

           altft = getprop("/instrumentation/altimeter/indicated-altitude-ft");
           if( speedmach > 2 or altft > 50190 ) {
               setprop("/autopilot/locks/speed2","maxcruise");
           }
           else {
               setprop("/autopilot/locks/speed2","maxclimb");
           }

           if( getprop("/autopilot/internal/automach") != "true" ) {
               automachcron();
           }          
       }

       # re-schedule the next call (1st is CL)
       settimer(maxclimbcron, 1.0);
   }
}

# max climb mode
apmaxclimbexport = func {
   speedmode = getprop("/autopilot/locks/speed2");
   if( speedmode == "maxclimb" or speedmode == "maxcruise" ) {
       atdiscspeed2export();
   }
   else {
       setprop("/autopilot/locks/speed2","maxclimb");
       maxclimbcron();
   }          
}

# -----------------
# AUTOTHROTTLE MODE
# -----------------

# disconnect speed mode
atdiscspeedexport = func {
   setprop("/autopilot/locks/speed","");
}

# disconnect autothrottle
atdiscthrottleexport = func {
   atdiscspeedexport();
   atdiscspeed2export();
}

# activate autothrottle
atexport = func {
   ap = props.globals.getNode("/autopilot").getChildren("locks");
   speed = ap[0].getChild("speed").getValue();
   speed2 = ap[0].getChild("speed2").getValue();

   # IAS hold is default on activation
   if( speed == "" and speed2 == "" ) {
       speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
       setprop("/autopilot/settings/target-speed-kt",speedkt);
       ap[0].getChild("speed").setValue("speed-with-throttle");
   }
   else {
       atdiscthrottleexport();
   }
}

# autothrottle
atspeedexport = func {
   speedmode = getprop("/autopilot/locks/speed");
   if( speedmode != "speed-with-throttle" ) {
       setprop("/autopilot/locks/speed","speed-with-throttle");
       atdiscspeed2export();
   }
   else{
       atdiscthrottleexport();
   }
}

# mach hold
atmachexport = func {
   speedmode = getprop("/autopilot/locks/speed");
   if( speedmode != "mach-with-throttle" ) {
       speedmach = getprop("/velocities/mach");
       setprop("/autopilot/settings/target-mach",speedmach);
       setprop("/autopilot/locks/speed","mach-with-throttle");
       atdiscspeed2export();
       automachcron();
   }
   else{
       atdiscthrottleexport();
   }
}

# speed with pitch
atspeedpitchexport = func {
   speedmode = getprop("/autopilot/locks/speed");
   if( speedmode != "speed-with-pitch" ) {
       speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
       setprop("/autopilot/settings/target-speed-kt",speedkt);
       setprop("/autopilot/locks/speed","speed-with-pitch");
       atdiscspeed2export();
   }
   else{
       atdiscthrottleexport();
   }
}

# mach with pitch
atmachpitchexport = func {
   speedmode = getprop("/autopilot/locks/speed");
   speedmode2 = getprop("/autopilot/locks/speed2");

   # only if no autothrottle
   if( speedmode == "" and speedmode2 == "" ) {
       speedmach = getprop("/velocities/mach");
       setprop("/autopilot/settings/target-mach",speedmach);
       setprop("/autopilot/locks/speed","mach-with-pitch");
       atdiscspeed2export();
       automachcron();
   }

   # default to pitch hold if autothrottle
   elsif( speedmode != "mach-with-pitch" and ( speedmode != "" or speedmode2 != "" ) ) {
       appitchexport();
   }

   else{
       atdiscthrottleexport();
   }
}

# mach speed modes (temporary)
automachcron = func {
   speedmode = getprop("/autopilot/locks/speed");
   if( speedmode == "mach-with-throttle" or speedmode == "mach-with-pitch" ) {
       speedkt = getprop("/velocities/airspeed-kt");
       # speed of sound
       if( speedkt > 50 ) {
           speedmach = getprop("/velocities/mach");
           soundkt = speedkt / speedmach;
           aheadkt = getprop("/autopilot/internal/lookahead-5-sec-airspeed-kt");
           aheadmach = aheadkt / soundkt;
           setprop("/autopilot/internal/lookahead-5-sec-mach",aheadmach);
       }
       status = "true";

       # re-schedule the next call (1st by MP or MH)
       settimer(automachcron, 1.0);
   }
   else {
       status = "false";
   }

   setprop("/autopilot/internal/automach",status);
}

# datum adjust of autothrottle
datumthrottleexport = func {
   sign=arg[0];

   # plus/minus 22 kt or 0.06 Mach (real)
   datumkt = getprop("/autopilot/datum/speed-kt");
   step = 1.0 * sign;
   if( datumkt == nil ) {
       datumkt = step;
   }
   else {
       datumkt = datumkt + step;
   }
   if( datumkt >= -22.0 and datumkt <= 22.0 ) {
       ktrange = "true";
       setprop("/autopilot/datum/speed-kt",datumkt);
   }
   else {
       ktrange = "false";
   }

   speedmode = getprop("/autopilot/locks/speed");
   if( speedmode == "mach-with-throttle" or speedmode == "mach-with-pitch" ) {
       if( ktrange == "true" ) {
           targetmach = getprop("/autopilot/settings/target-mach");
           step = 0.002727 * sign;
           targetmach = targetmach + step;
           setprop("/autopilot/settings/target-mach",targetmach);
       }
   }
   elsif( speedmode == "speed-with-throttle" or speedmode == "speed-with-pitch" ) {
       if( ktrange == "true" ) {
           targetkt = getprop("/autopilot/settings/target-speed-kt");
           step = 1.0 * sign;
           targetkt = targetkt + step;
           setprop("/autopilot/settings/target-speed-kt",targetkt);
       }
   }
}

# ==============
# INITIALIZATION
# ==============
init = func {
   # tank content
   tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
   tanks[0].getChild("content-lb").setValue( CONTENT1LB );
   tanks[1].getChild("content-lb").setValue( CONTENT2LB );
   tanks[2].getChild("content-lb").setValue( CONTENT3LB );
   tanks[3].getChild("content-lb").setValue( CONTENT4LB );
   tanks[4].getChild("content-lb").setValue( CONTENT5LB );
   tanks[5].getChild("content-lb").setValue( CONTENT6LB );
   tanks[6].getChild("content-lb").setValue( CONTENT7LB );
   tanks[7].getChild("content-lb").setValue( CONTENT8LB );
   tanks[8].getChild("content-lb").setValue( CONTENT9LB );
   tanks[9].getChild("content-lb").setValue( CONTENT10LB );
   tanks[10].getChild("content-lb").setValue( CONTENT11LB );
   tanks[11].getChild("content-lb").setValue( CONTENT5ALB );
   tanks[12].getChild("content-lb").setValue( CONTENT7ALB );

   # tank number
   tanks[0].getChild("tank-num").setValue( "1" );
   tanks[1].getChild("tank-num").setValue( "2" );
   tanks[2].getChild("tank-num").setValue( "3" );
   tanks[3].getChild("tank-num").setValue( "4" );
   tanks[4].getChild("tank-num").setValue( "5" );
   tanks[5].getChild("tank-num").setValue( "6" );
   tanks[6].getChild("tank-num").setValue( "7" );
   tanks[7].getChild("tank-num").setValue( "8" );
   tanks[8].getChild("tank-num").setValue( "9" );
   tanks[9].getChild("tank-num").setValue( "10" );
   tanks[10].getChild("tank-num").setValue( "11" );
   tanks[11].getChild("tank-num").setValue( "5A" );
   tanks[12].getChild("tank-num").setValue( "7A" );

   # engine number
   engines = props.globals.getNode("/engines/").getChildren("engine");
   engines[0].getChild("engine-num").setValue( 1 );
   engines[1].getChild("engine-num").setValue( 2 );
   engines[2].getChild("engine-num").setValue( 3 );
   engines[3].getChild("engine-num").setValue( 4 );

   # cabine altitude (standard sea level)
   setprop("/instrumentation/cabine-altitude/cabine-inhg",29.92);
   setprop("/instrumentation/cabine-altitude/indicated-altitude-ft",0.0);
   setprop("/systems/pressurization/altitude-sea-ft",0.0);

   # schedule the 1st call
#   settimer(calcverticalfpscron,0);
   settimer(calctascron,0);
   settimer(calcvmoktcron, 0);
   settimer(feedenginescron, 0);
   settimer(inslightcron,0);
   settimer(calccabineftcron,0);
   settimer(calctmodegccron,0);
}

init();
