# Like the real Concorde : see http://www.concordesst.com.

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

# constants
# ratio of specific heats at STP
gammaairstp = 1.4;
# gas constant 286 /m2/s2/°K for air
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
       setprop("/instrumentation/fuel/fuel-flow-kg_ph", fuelkgph);
   }
}

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

# maximum operating speed (kt)
calcvmokt = func {
   altitudeft = getprop("/position/altitude-ft");
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
   setprop("/instrumentation/airspeed-indicator/vmo-kt", vmokt);
   setprop("/instrumentation/mach-indicator/mmo-mach", mmomach);
   # re-schedule the next call
   settimer(calcvmokt, 5.0);
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
           # from rear tank 11 at first
           if( tank11lb > 0 ) {
               transfertanks( 8, CONTENT9LB, 10, PUMPLB );
           }
           else {
               # both tanks (balance)
               transfertanks( 8, CONTENT9LB, 11, PUMPLB );
               transfertanks( 8, CONTENT9LB, 12, PUMPLB );
           }
       }
       # towards tank 10
       else {
           tank10lb = getprop("/consumables/fuel/tank[9]/level-gal_us") * GALUSTOLB ;
           if( tank10lb < CONTENT10LB ) {
               # from rear tank 11 at first
               if( tank11lb > 0 ) {
                   transfertanks( 9, CONTENT10LB, 10, PUMPLB );
               }
               else {
                   # both tanks (balance)
                   transfertanks( 9, CONTENT10LB, 11, PUMPLB );
                   transfertanks( 9, CONTENT10LB, 12, PUMPLB );
               }
           }
       }
}

# pump aft
pumpaft = func {
       tank11lb = getprop("/consumables/fuel/tank[10]/level-gal_us") * GALUSTOLB;
       # from tank 9 at first
       if( getprop("/consumables/fuel/tank[8]/level-gal_us") > 0 ) {
           # toward tank 11 at first
           if( tank11lb < CONTENT11LB ) {
               transfertanks( 10, CONTENT11LB, 8, PUMPLB );
           }
           else {
               # both tanks (balance)
               transfertanks( 11, CONTENT5ALB, 8, PUMPLB );
               transfertanks( 12, CONTENT7ALB, 8, PUMPLB );
           }
       }
       # from tank 10
       elsif( getprop("/consumables/fuel/tank[9]/level-gal_us") > 0 ) {
           # toward tank 11 at first
           if( tank11lb < CONTENT11LB ) {
                transfertanks( 10, CONTENT11LB, 9, PUMPLB );
           }
           else {
                # both tanks (balance)
                transfertanks( 11, CONTENT5ALB, 9, PUMPLB );
                transfertanks( 12, CONTENT7ALB, 9, PUMPLB );
           }
       }
}

# feed an engine supply tank, with main tanks
# - number of tank
# - content of tank (lb)
# - pumped volume (lb)
pumpmain = func {
   tank = arg[0];
   contentlb = arg[1];
   pumplb = arg[2] / 4;

   # balance the load on tanks 5, 6, 7 and 8
   # serve the heaviest tanks at first, to shift the center of gravity aft
   transfertanks( tank, contentlb, 5, pumplb );
   transfertanks( tank, contentlb, 7, pumplb );
   transfertanks( tank, contentlb, 4, pumplb );
   transfertanks( tank, contentlb, 6, pumplb );
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
   # rear tanks 11, 5A and 7A (center of gravity goes forwards)
   else {
       tank11 = getprop("/consumables/fuel/tank[10]/level-gal_us");
       # from tank 11 at first
       if( tank11 > 0 ) {
           transfertanks( tank, contentlb, 10, pumplb );
       }
       else {
           # keep balance
           pumplb = pumplb / 2;
           transfertanks( tank, contentlb, 11, pumplb );
           transfertanks( tank, contentlb, 12, pumplb );
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
feedengines = func {
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
       # feeds all supply tanks, because of JBSim
       pumptrim( 0, CONTENT1LB, PUMPLB, aft );
       pumptrim( 1, CONTENT2LB, PUMPLB, aft );
       pumptrim( 2, CONTENT3LB, PUMPLB, aft );
       pumptrim( 3, CONTENT4LB, PUMPLB, aft );
       # x-feed will balance
       pumptrim( 4, CONTENT5LB, PUMPLB, aft );
       pumptrim( 5, CONTENT6LB, PUMPLB, aft );
   }
   # all tanks (balance)
   else {
       pumpmain( 0, CONTENT1LB, PUMPLB );
       pumpmain( 1, CONTENT2LB, PUMPLB );
       pumpmain( 2, CONTENT3LB, PUMPLB );
       pumpmain( 3, CONTENT4LB, PUMPLB );

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
 
   # re-schedule the next call
   settimer(feedengines, PUMPSEC);
}

# max climb mode
maxclimb = func {
   verticalmode = getprop("/autopilot/locks/vertical");
   if( verticalmode == "maxclimb" ) {
       vmokt = getprop("/instrumentation/airspeed-indicator/vmo-kt");
       minkt = vmokt - 1;
       maxkt = vmokt + 1;
       # may be out of order
       speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
       # catches the VMO with autothrottle
       if( speedkt < minkt or speedkt > maxkt ) {
           setprop("/autopilot/settings/target-speed-kt",vmokt);
           setprop("/autopilot/locks/speed","speed-with-throttle");
       }
       # then holds the VMO with pitch
       else {
           setprop("/autopilot/settings/target-speed-kt",vmokt);
           setprop("/autopilot/locks/speed","speed-with-pitch");
       }
   }
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
           # disable other vertical modes
           setprop("/autopilot/locks/altitude2","");
           # crew control
           setprop("/autopilot/locks/speed","");
           # light on
           setprop("/autopilot/locks/vertical","goaround");
       }
   }
   # light off
   if( verticalmode == "goaround" ) {
       if( getprop("/autopilot/settings/target-pitch-deg") != 15 or
           getprop("/autopilot/locks/altitude") != "pitch-hold" ) {
           setprop("/autopilot/locks/vertical","");
       }
   }
}

# adjust target speed with wind
# - target speed (kt)
targetwind = func {
   targetkt = arg[0];
   # wind increases lift
   windkt = getprop("/environment/wind-speed-kt");
   if( windkt > 0 ) {
       winddeg = getprop("/environment/wind-from-heading-deg");
       vordeg = getprop("/radios/nav/radials/selected-deg");
       offsetdeg = vordeg - winddeg;
       # north crossing
       if( offsetdeg > 180 ) {
           offsetdeg = offsetdeg - 360;
       }
       elsif( offsetdeg < -180 ) {
              offsetdeg = offsetdeg + 360;
       }
       # substract head wind component;
       # except tail wind (too much glide)
       if( offsetdeg > -90 and offsetdeg < 90 ) {
           offsetrad = offsetdeg * DEGTORAD;
           offsetkt = windkt * math.cos( offsetrad );
           targetkt = targetkt - offsetkt;
       }
   }
   # avoid infinite gliding (too much ground effect ?)
   setprop("/autopilot/settings/target-speed-kt",targetkt);
}

# autoland mode
# (tested at 245000 lb)
autoland = func {
   verticalmode = getprop("/autopilot/locks/vertical") ;
   if( verticalmode == "autoland" or verticalmode == "autoland-armed" ) {
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
                   setprop("/autopilot/locks/altitude","pitch-hold");
                   setprop("/autopilot/locks/altitude2","");
               }
               # safe on ground
               else {
                   rates = 1.0;
                   # disable autopilot
                   setprop("/autopilot/locks/altitude","");
                   setprop("/autopilot/locks/heading","");
                   setprop("/autopilot/locks/vertical","");
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
                   setprop("/autopilot/settings/target-pitch-deg",10);
                   setprop("/autopilot/locks/altitude","pitch-hold");
                   setprop("/autopilot/settings/vertical-speed-fpm",-750);
                   setprop("/autopilot/locks/altitude2","vertical-speed-with-throttle");
                   setprop("/autopilot/locks/speed","");
               }
               # glide slope
               else {
                   rates = 0.1;
                   setprop("/autopilot/locks/altitude","gs1-hold");
                   # near VREF (no wind)
                   targetwind( 163 );
                   setprop("/autopilot/locks/speed","speed-with-throttle");
               }
               setprop("/autopilot/locks/heading","nav1-hold");
           }
       }
   }
   else {
       rates = 1.0;
   }

   # 0.1 s improves the catch of throttle maximum, when autoland
   goaround();
   maxclimb();

   # re-schedule the next call
   settimer(autoland, rates);
}

# mach speed modes (temporary)
automach = func {
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
   }

   # re-schedule the next call
   settimer(automach, 1.0);
}

# altitude button lights when the dialed altitude is reached
altitudelight = func {
   altitudemode = getprop("/autopilot/locks/altitude");
   if( altitudemode == "altitude-hold" ) {
       altft = getprop("/autopilot/settings/target-altitude-ft");
       # within 100 ft
       minft = altft - 100;
       setprop("/instrumentation/altimeter/target-min-ft",minft);
       maxft = altft + 100;
       setprop("/instrumentation/altimeter/target-max-ft",maxft);
   }

   # re-schedule the next call
   settimer(altitudelight, 15.0);
}

# initialization
init = func {
   # schedule the 1st call
   settimer(calcvmokt, 0);
   settimer(feedengines, 0);
   settimer(autoland, 0);
   settimer(automach, 0);
   settimer(altitudelight,0);
}

init();
