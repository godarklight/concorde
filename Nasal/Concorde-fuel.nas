# Like the real Concorde : see http://www.concordesst.com.

# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# current nasal version doesn't accept :
# - more than multiplication on 1 line.
# - variable with hyphen or underscore.
# - boolean (can only test IF TRUE); replaced by strings.
# - object oriented classes.

# IMPORTANT : always uses /consumables/fuel/tank[0]/level-gal_us, because /level-lb seems not synchronized with
# level-gal_us, during the time of a procedure.


# =============
# TANKS CONTENT
# =============

# tank contents, to be initialised from XML
CONTENT1LB = 0.0;
CONTENT2LB = 0.0;
CONTENT3LB = 0.0;
CONTENT4LB = 0.0;
CONTENT5LB = 0.0;
CONTENT6LB = 0.0;
CONTENT7LB = 0.0;
CONTENT8LB = 0.0;
CONTENT9LB = 0.0;
CONTENT10LB = 0.0;
CONTENT11LB = 0.0;
CONTENT5ALB = 0.0;
CONTENT7ALB = 0.0;

# aft trim at 40 %
AFTTRIM1LB = 0.0;
AFTTRIM4LB = 0.0;


# tank initialization, arguments :
# - tank no
# - tank label
# - tank content lb
# - over full, if true
# - under full, if true
# - low levell, if true
inittank = func {
   no = arg[0];
   label = arg[1];
   contentlb = arg[2];
   overfull = arg[3];
   underfull = arg[4];
   lowlevel = arg[5];

   tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
   tanks[no].getChild("tank-num").setValue( label );
   tanks[no].getChild("content-lb").setValue( contentlb );

   # optional :  must be created by instrument XML
   if( overfull == "true" ) {
       valuelb = contentlb * 0.97;
       tanks[no].getChild("over-full-lb").setValue( valuelb );
   }
   if( underfull == "true" ) {
       valuelb = contentlb * 0.80;
       tanks[no].getChild("under-full-lb").setValue( valuelb );
   }
   if( lowlevel == "true" ) {
       valuelb = contentlb * 0.20;
       tanks[no].getChild("low-level-lb").setValue( valuelb );
   }
}

# fuel initialization
initfuel = func {
   densityppg = getprop("/consumables/fuel/tank[0]/density-ppg");
   CONTENT1LB = getprop("/consumables/fuel/tank[0]/capacity-gal_us") * densityppg;
   inittank( 0,  "1",  CONTENT1LB,  "true",  "true",  "true" );
   densityppg = getprop("/consumables/fuel/tank[1]/density-ppg");
   CONTENT2LB = getprop("/consumables/fuel/tank[1]/capacity-gal_us") * densityppg;
   inittank( 1,  "2",  CONTENT2LB,  "true",  "true",  "true" );
   densityppg = getprop("/consumables/fuel/tank[2]/density-ppg");
   CONTENT3LB = getprop("/consumables/fuel/tank[2]/capacity-gal_us") * densityppg;
   inittank( 2,  "3",  CONTENT3LB,  "true",  "true",  "true" );
   densityppg = getprop("/consumables/fuel/tank[3]/density-ppg");
   CONTENT4LB = getprop("/consumables/fuel/tank[3]/capacity-gal_us") * densityppg;
   inittank( 3,  "4",  CONTENT4LB,  "true",  "true",  "true" );
   densityppg = getprop("/consumables/fuel/tank[4]/density-ppg");
   CONTENT5LB = getprop("/consumables/fuel/tank[4]/capacity-gal_us") * densityppg;
   inittank( 4,  "5",  CONTENT5LB,  "true",  "false", "false" );
   densityppg = getprop("/consumables/fuel/tank[5]/density-ppg");
   CONTENT6LB = getprop("/consumables/fuel/tank[5]/capacity-gal_us") * densityppg;
   inittank( 5,  "6",  CONTENT6LB,  "false", "false", "false" );
   densityppg = getprop("/consumables/fuel/tank[6]/density-ppg");
   CONTENT7LB = getprop("/consumables/fuel/tank[6]/capacity-gal_us") * densityppg;
   inittank( 6,  "7",  CONTENT7LB,  "true",  "false", "false" );
   densityppg = getprop("/consumables/fuel/tank[7]/density-ppg");
   CONTENT8LB = getprop("/consumables/fuel/tank[7]/capacity-gal_us") * densityppg;
   inittank( 7,  "8",  CONTENT8LB,  "false", "false", "false" );
   densityppg = getprop("/consumables/fuel/tank[8]/density-ppg");
   CONTENT9LB = getprop("/consumables/fuel/tank[8]/capacity-gal_us") * densityppg;
   inittank( 8,  "9",  CONTENT9LB,  "false", "false", "false" );
   densityppg = getprop("/consumables/fuel/tank[9]/density-ppg");
   CONTENT10LB = getprop("/consumables/fuel/tank[9]/capacity-gal_us") * densityppg;
   inittank( 9,  "10", CONTENT10LB, "false", "false", "false" );
   densityppg = getprop("/consumables/fuel/tank[10]/density-ppg");
   CONTENT11LB = getprop("/consumables/fuel/tank[10]/capacity-gal_us") * densityppg;
   inittank( 10, "11", CONTENT11LB, "true",  "false", "false" );
   densityppg = getprop("/consumables/fuel/tank[11]/density-ppg");
   CONTENT5ALB = getprop("/consumables/fuel/tank[11]/capacity-gal_us") * densityppg;
   inittank( 11, "5A", CONTENT5ALB, "false", "false", "false" );
   densityppg = getprop("/consumables/fuel/tank[12]/density-ppg");
   CONTENT7ALB = getprop("/consumables/fuel/tank[12]/capacity-gal_us") * densityppg;
   inittank( 12, "7A", CONTENT7ALB, "false", "false", "false" );


   AFTTRIM1LB = CONTENT1LB * 0.4;
   AFTTRIM4LB = CONTENT4LB * 0.4;
}


# ==========
# FUEL PUMPS
# ==========

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


# ===============
# FUEL MANAGEMENT
# ===============

# pump rate : 10 lb/s for 1 pump.
# at Mach 2, trim tank 10 only feeds 2 supply tanks 5 and 7 : 45200 lb/h, or 6.3 lb/s per tank.
PUMPSEC = 1.0;
PUMPLBPSEC = 10;
PUMPPMIN0 = 60.0 / PUMPSEC;
PUMPLB0 = PUMPLBPSEC * PUMPSEC;

# troubles if doesn't create symbols !
PUMPPMIN = PUMPPMIN0;
PUMPLB = PUMPLB0;

# pump forward
pumpforward = func {
       tank9lb = getprop("/consumables/fuel/tank[8]/level-gal_us") * GALUSTOLB;
       # towards tank 9
       if( tank9lb < CONTENT9LB ) {
           tank11lb = getprop("/consumables/fuel/tank[10]/level-gal_us") * GALUSTOLB;
           # from rear tank 11
           if( tank11lb > 0 ) {
               if( getprop("/controls/fuel/tank[10]/pump[0]") ) {
                   transfertanks( 8, CONTENT9LB, 10, PUMPLB );
               }
               if( getprop("/controls/fuel/tank[10]/pump[1]") ) {
                   transfertanks( 8, CONTENT9LB, 10, PUMPLB );
               }
           }
       }
}

# pump aft
pumpaft = func {
       tank11lb = getprop("/consumables/fuel/tank[10]/level-gal_us") * GALUSTOLB;
       # from tank 9 at first
       if( getprop("/consumables/fuel/tank[8]/level-gal_us") > 0 and
           ( getprop("/controls/fuel/tank[8]/pump[0]") or
             getprop("/controls/fuel/tank[8]/pump[1]") ) ) {
           # towards tank 11
           if( tank11lb < CONTENT11LB ) {
               if( getprop("/controls/fuel/tank[8]/pump[0]") ) {
                   transfertanks( 10, CONTENT11LB, 8, PUMPLB );
               }
               if( getprop("/controls/fuel/tank[8]/pump[1]") ) {
                   transfertanks( 10, CONTENT11LB, 8, PUMPLB );
               }
           }
       }
       # from tank 10
       elsif( getprop("/consumables/fuel/tank[9]/level-gal_us") > 0 and
              ( getprop("/controls/fuel/tank[9]/pump[0]") or
                getprop("/controls/fuel/tank[9]/pump[1]") ) ) {
           # towards tank 11
           if( tank11lb < CONTENT11LB ) {
               if( getprop("/controls/fuel/tank[9]/pump[0]") ) { 
                   transfertanks( 10, CONTENT11LB, 9, PUMPLB );
               }
               if( getprop("/controls/fuel/tank[9]/pump[1]") ) { 
                   transfertanks( 10, CONTENT11LB, 9, PUMPLB );
               }
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
   pumplb = arg[2];

   # tank 1 by left pump
   if( tank == 0 ) {
       if( getprop("/controls/fuel/tank[4]/pump[0]") ) {
           tank5 = "yes"; 
       }
       else {
           tank5 = "";
       }
       if( getprop("/controls/fuel/tank[5]/pump[0]") ) {
           tank6 = "yes"; 
       }
       else {
           tank6 = "";
       }
       if( getprop("/controls/fuel/tank[11]/pump[0]") ) {
           tank5a = "yes"; 
       }
       else {
           tank5a = "";
       }

       if( getprop("/controls/fuel/tank[0]/aft-trim") ) {
           tank1lb = getprop("/consumables/fuel/tank[0]/level-gal_us") * GALUSTOLB;
           if( tank1lb > AFTTRIM1LB ) {
               tank5 = ""; 
               tank6 = ""; 
           }
       }
   }

   # tank 2 by right pump
   else {
       if( getprop("/controls/fuel/tank[4]/pump[1]") ) {
           tank5 = "yes"; 
       }
       else {
           tank5 = "";
       }
       if( getprop("/controls/fuel/tank[5]/pump[1]") ) {
           tank6 = "yes"; 
       }
       else {
           tank6 = "";
       }
       if( getprop("/controls/fuel/tank[11]/pump[1]") ) {
           tank5a = "yes"; 
       }
       else {
           tank5a = "";
       }
   }

   # engineer transfers tank 5A to tank 5
   if( tank5a == "yes" ) {
       if( getprop("/controls/fuel/tank[11]/trans-valve") ) {
           transfertanks( 4, CONTENT5LB, 11, pumplb );
       }
   }

   # balance the load on tanks 5, 6, and 5A
   # serve the forwards tanks at first, to shift the center of gravity aft
   if( tank5 == "yes" ) {
       transfertanks( tank, contentlb, 4, pumplb );
   }
   # 6 only when 5 empty
   if( tank6 == "yes" ) {
       if( getprop("/consumables/fuel/tank[4]/level-gal_us") == 0 ) {
           transfertanks( tank, contentlb, 5, pumplb );
       }
   }
}

# feed a right engine supply tank, with right main tanks
# - number of tank
# - content of tank (lb)
# - pumped volume (lb)
pumprightmain = func {
   tank = arg[0];
   contentlb = arg[1];
   pumplb = arg[2];

   # tank 3 by left pump
   if( tank == 2 ) {
       if( getprop("/controls/fuel/tank[6]/pump[0]") ) {
           tank7 = "yes"; 
       }
       else {
           tank7 = "";
       }
       if( getprop("/controls/fuel/tank[7]/pump[0]") ) {
           tank8 = "yes"; 
       }
       else {
           tank8 = "";
       }
       if( getprop("/controls/fuel/tank[12]/pump[0]") ) {
           tank7a = "yes"; 
       }
       else {
           tank7a = "";
       }
   }

   # tank 4 by right pump
   else {
       if( getprop("/controls/fuel/tank[6]/pump[1]") ) {
           tank7 = "yes"; 
       }
       else {
           tank7 = "";
       }
       if( getprop("/controls/fuel/tank[7]/pump[1]") ) {
           tank8 = "yes"; 
       }
       else {
           tank8 = "";
       }
       if( getprop("/controls/fuel/tank[12]/pump[1]") ) {
           tank7a = "yes"; 
       }
       else {
           tank7a = "";
       }

       if( getprop("/controls/fuel/tank[3]/aft-trim") ) {
           tank4lb = getprop("/consumables/fuel/tank[3]/level-gal_us") * GALUSTOLB;
           if( tank4lb > AFTTRIM4LB ) {
               tank7 = ""; 
               tank8 = ""; 
           }
       }
   }

   # engineer transfers tank 7A to tank 7
   if( tank7a == "yes" ) {
       if( getprop("/controls/fuel/tank[12]/trans-valve") ) {
           transfertanks( 6, CONTENT6LB, 12, pumplb );
       }
   }

   # balance the load on tanks 7, 8 and 7A
   # serve the forwards tanks at first, to shift the center of gravity aft
   if( tank7 == "yes" ) {
       transfertanks( tank, contentlb, 6, pumplb );
   }
   # 8 only when 7 empty
   if( tank8 == "yes" ) {
       if( getprop("/consumables/fuel/tank[6]/level-gal_us") == 0 ) {
           transfertanks( tank, contentlb, 7, pumplb );
       }
   }
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
   if( aft == "on" ) {
       tank9 = getprop("/consumables/fuel/tank[8]/level-gal_us");
       if( tank9 > 0 and
           ( getprop("/controls/fuel/tank[8]/pump[0]") or
             getprop("/controls/fuel/tank[8]/pump[1]") ) ) {
           if( getprop("/controls/fuel/tank[8]/pump[0]") ) {
             transfertanks( tank, contentlb, 8, pumplb );
           }
           if( getprop("/controls/fuel/tank[8]/pump[1]") ) {
             transfertanks( tank, contentlb, 8, pumplb );
           }
       }
       # front tank 10 at last
       else {
           if( getprop("/controls/fuel/tank[9]/pump[0]") ) {
               transfertanks( tank, contentlb, 9, pumplb );
           }
           if( getprop("/controls/fuel/tank[9]/pump[1]") ) {
               transfertanks( tank, contentlb, 9, pumplb );
           }
       }
   }

   # rear tanks 11 (center of gravity goes forwards)
   else {
       tank11 = getprop("/consumables/fuel/tank[10]/level-gal_us");
       # from tank 11
       if( tank11 > 0 ) {
           if( getprop("/controls/fuel/tank[10]/pump[0]") ) {
               transfertanks( tank, contentlb, 10, pumplb );
           }
           if( getprop("/controls/fuel/tank[10]/pump[1]") ) {
               transfertanks( tank, contentlb, 10, pumplb );
           }
       }
   }
}

# dump tanks
dumpreartanks = func {
   # trim tanks 9 and 10 (front)
   if( getprop("/controls/fuel/tank[8]/pump[0]") ) {
       dumptank( 8, PUMPLB );
   }
   if( getprop("/controls/fuel/tank[8]/pump[1]") ) {
       dumptank( 8, PUMPLB );
   }

   if( getprop("/controls/fuel/tank[9]/pump[0]") ) {
       dumptank( 9, PUMPLB );
   }
   if( getprop("/controls/fuel/tank[9]/pump[1]") ) {
       dumptank( 9, PUMPLB );
   }

   # trim tank 11 (tail)
   if( getprop("/controls/fuel/tank[10]/pump[0]") ) {
       dumptank( 10, PUMPLB );
   }
   if( getprop("/controls/fuel/tank[10]/pump[1]") ) {
       dumptank( 10, PUMPLB );
   }

   # collector tanks 1, 2, 3 and 4
   if( getprop("/controls/fuel/tank[0]/pump[1]") ) {
       dumptank( 0, PUMPLB );
   }
   if( getprop("/controls/fuel/tank[0]/pump[2]") ) {
       dumptank( 0, PUMPLB );
   }

   if( getprop("/controls/fuel/tank[1]/pump[0]") ) {
       dumptank( 1, PUMPLB );
   }
   if( getprop("/controls/fuel/tank[1]/pump[1]") ) {
       dumptank( 1, PUMPLB );
   }

   if( getprop("/controls/fuel/tank[2]/pump[1]") ) {
       dumptank( 2, PUMPLB );
   }
   if( getprop("/controls/fuel/tank[2]/pump[2]") ) {
       dumptank( 2, PUMPLB );
   }

   if( getprop("/controls/fuel/tank[3]/pump[0]") ) {
       dumptank( 3, PUMPLB );
   }
   if( getprop("/controls/fuel/tank[3]/pump[1]") ) {
       dumptank( 3, PUMPLB );
   }
}

# balance all tanks (no pump)
crosstanks = func {
   # engine cross feed (to be implemented)
   # tanks 1 and 4
   pumpcross( 0, CONTENT1LB, 3, CONTENT4LB, PUMPLB );
   # tanks 2 and 3
   pumpcross( 1, CONTENT2LB, 2, CONTENT3LB, PUMPLB );

   # interconnect (by gravity)
   # tanks 5 and 7
   pumpcross( 4, CONTENT5LB, 6, CONTENT7LB, PUMPLB );
   # tanks 6 and 8
   pumpcross( 5, CONTENT6LB, 7, CONTENT8LB, PUMPLB );
}

# pressurize the accumulators
pressaccumulators = func {
   # engine stops when no fuel pressure
   if( !getprop("/controls/fuel/tank[0]/pump[0]") and
       !getprop("/controls/fuel/tank[0]/pump[1]") and
       !getprop("/controls/fuel/tank[0]/pump[2]") ) {
       setprop("/controls/engines/engine[0]/cutoff",1);
   }

   if( !getprop("/controls/fuel/tank[1]/pump[0]") and
       !getprop("/controls/fuel/tank[1]/pump[1]") and
       !getprop("/controls/fuel/tank[1]/pump[2]") ) {
       setprop("/controls/engines/engine[1]/cutoff",1);
   }

   if( !getprop("/controls/fuel/tank[2]/pump[0]") and
       !getprop("/controls/fuel/tank[2]/pump[1]") and
       !getprop("/controls/fuel/tank[2]/pump[2]") ) {
       setprop("/controls/engines/engine[2]/cutoff",1);
   }

   if( !getprop("/controls/fuel/tank[3]/pump[0]") and
       !getprop("/controls/fuel/tank[3]/pump[1]") and
       !getprop("/controls/fuel/tank[3]/pump[2]") ) {
       setprop("/controls/engines/engine[3]/cutoff",1);
   }
}

# feed collector tanks :
# - pumped volume (lb)
pumpmain = func {
   pumplb = arg[0];

   pumpleftmain( 0, CONTENT1LB, pumplb );
   pumpleftmain( 1, CONTENT2LB, pumplb );
   pumprightmain( 2, CONTENT3LB, pumplb );
   pumprightmain( 3, CONTENT4LB, pumplb );
}

# feed engines
feedengineschedule = func {
   speedup = getprop("/sim/speed-up");
   if( speedup > 1 ) {
       PUMPPMIN = PUMPPMIN0 / speedup;
       PUMPLB = PUMPLB0 * speedup;
   }
   else {
       PUMPPMIN = PUMPPMIN0;
       PUMPLB = PUMPLB0;
   }

   outputvolt =  getprop("/systems/electrical/outputs/specific");
   if( outputvolt != nil ) {
       if( getprop("/systems/fuel/serviceable") and outputvolt > 20 ) {
           # avoid parallel updates
           pump = props.globals.getNode("/systems/fuel/pump");
           engine = pump.getChild("engine").getValue();
           forward = pump.getChild("forward").getValue();
           aft = pump.getChild("aft").getValue();
           dump = pump.getChild("dump").getValue();
           dump2 = pump.getChild("dump2").getValue();
           cross = pump.getChild("cross").getValue();

           # feeds from trim tanks
           if( engine == "on" and ( forward == "on" or aft == "on" ) ) {
               # balance the main tanks 5 and 7, closest to the collector tank
               pumptrim( 4, CONTENT5LB, PUMPLB, aft );
               pumptrim( 6, CONTENT7LB, PUMPLB, aft );

               # avoids running out of fuel
               pumpmain( PUMPLB );
           }
           # all tanks (balance)
           else {
               pumpmain( PUMPLB );

               if( forward == "on" ) {
                   pumpforward();
               }
               elsif( aft == "on" ) {
                   pumpaft();
               }
           }

           pressaccumulators();

           # avoid parallel events
           # 2 buttons for confirmation
           if( dump == "on" and dump2 == "on" ) {
               dumpreartanks();
           }
           if( cross == "on" ) {
               crosstanks();
           }
           totalfuel();

           # synchronize with fuel gauges
           corridorcg();
           centergravity();
           corridormach();
       }
   }

   speedupfuel();
}

# feed engines (CPP)
feedengineschedulecpp = func {
   speedup = getprop("/sim/speed-up");
   if( speedup > 1 ) {
       PUMPPMIN = PUMPPMIN0 / speedup;
       PUMPLB = PUMPLB0 * speedup;
   }
   else {
       PUMPPMIN = PUMPPMIN0;
       PUMPLB = PUMPLB0;
   }

   outputvolt =  getprop("/systems/electrical/outputs/specific");
   if( outputvolt != nil ) {
       if( getprop("/systems/fuel/serviceable") and outputvolt > 20 ) {
           # avoid parallel updates
           pump = props.globals.getNode("/systems/fuel/pump");
           engine = pump.getChild("engine").getValue();
           forward = pump.getChild("forward").getValue();
           aft = pump.getChild("aft").getValue();
           dump = pump.getChild("dump").getValue();
           dump2 = pump.getChild("dump2").getValue();
           cross = pump.getChild("cross").getValue();

           # feeds from trim tanks
           if( engine == "on" and ( forward == "on" or aft == "on" ) ) {
               setprop("/systems/fuel/pumps/on[12]",0);
               setprop("/systems/fuel/pumps/on[13]",0);

               # balance the main tanks, closest to the collector tank
               if( forward == "on" ) {
                   setprop("/systems/fuel/pumps/on[8]",0);
                   setprop("/systems/fuel/pumps/on[9]",1);
               }
               elsif( aft == "on" ) {
                   setprop("/systems/fuel/pumps/on[8]",1);
                   setprop("/systems/fuel/pumps/on[9]",0);
               }
               else {
                   setprop("/systems/fuel/pumps/on[8]",0);
                   setprop("/systems/fuel/pumps/on[9]",0);
               }
           }
           # all tanks (balance)
           else {
               setprop("/systems/fuel/pumps/on[8]",0);
               setprop("/systems/fuel/pumps/on[9]",0);

               if( forward == "on" ) {
                   setprop("/systems/fuel/pumps/on[12]",0);
                   setprop("/systems/fuel/pumps/on[13]",1);
               }
               elsif( aft == "on" ) {
                   setprop("/systems/fuel/pumps/on[12]",1);
                   setprop("/systems/fuel/pumps/on[13]",0);
               }
               else {
                   setprop("/systems/fuel/pumps/on[12]",0);
                   setprop("/systems/fuel/pumps/on[13]",0);
               }
           }
           # avoid parallel events
           # 2 buttons for confirmation
           if( dump == "on" and dump2 == "on" ) {
               setprop("/systems/fuel/pumps/on[5]",1);
               setprop("/systems/fuel/pumps/on[6]",1);
               setprop("/systems/fuel/pumps/on[7]",1);
           }
           else {
               setprop("/systems/fuel/pumps/on[5]",0);
               setprop("/systems/fuel/pumps/on[6]",0);
               setprop("/systems/fuel/pumps/on[7]",0);
           }
           if( cross == "on" ) {
               setprop("/systems/fuel/pumps/on[0]",1);
               setprop("/systems/fuel/pumps/on[1]",1);
               setprop("/systems/fuel/pumps/on[2]",1);
               setprop("/systems/fuel/pumps/on[3]",1);
               setprop("/systems/fuel/pumps/on[4]",1);
           }
           else {
               setprop("/systems/fuel/pumps/on[0]",0);
               setprop("/systems/fuel/pumps/on[1]",0);
               setprop("/systems/fuel/pumps/on[2]",0);
               setprop("/systems/fuel/pumps/on[3]",0);
               setprop("/systems/fuel/pumps/on[4]",0);
           }
           totalfuel();

           # synchronize with fuel gauges
           corridorcg();
           centergravity();
           corridormach();
       }
   }

   speedupfuel();
}


# ===========================
# CONSUMPTION DURING SPEED-UP
# ===========================

CLIMBFTPMIN = 3500;                                           # max climb rate
CLIMBFTPSEC = CLIMBFTPMIN / 60;
MAXSTEPFT = CLIMBFTPSEC * PUMPSEC;

# speed up engine, arguments :
# - engine tank
# - fuel flow of engine (lb per hour)
# - speed up
speedupengine = func {
   enginetank = arg[0];
   flowlbph = arg[1];
   multiplier = arg[2];

   if( flowlbph == nil ) {
       flowlbph = 0;
   }
   flowgph = flowlbph * LBTOGALUS;

   # fuel consumed during the time step
   if( flowgph > 0 ) {
       multiplier = multiplier - 1;
       enginegal = flowgph * multiplier;
       enginegal = enginegal / 3600;
       enginegal = enginegal * PUMPSEC;

       tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");

       tankgal = tanks[enginetank].getValue("level-gal_us");

       # collector tank
       if( enginegal > 0 ) {
           tankgal = tanks[enginetank].getValue("level-gal_us");
           if( tankgal > 0 ) {
               if( tankgal > enginegal ) {
                   tankgal = tankgal - enginegal;
                   enginegal = 0;
               }
               else {
                   enginegal = enginegal - tankgal;
                   tankgal = 0;
               }
               tanks[enginetank].getChild("level-gal_us").setValue(tankgal);
           }
       } 
   }
}

# speed up consumption
speedupfuel = func {
   altitudeft = getprop("/position/altitude-ft");
   speedup = getprop("/sim/speed-up");
   if( speedup > 1 ) {
       engines = props.globals.getNode("/engines/").getChildren("engine");
       lbphour = engines[0].getValue("fuel-flow_pph");
       speedupengine( 0, lbphour, speedup );
       lbphour = engines[1].getValue("fuel-flow_pph");
       speedupengine( 1, lbphour, speedup );
       lbphour = engines[2].getValue("fuel-flow_pph");
       speedupengine( 2, lbphour, speedup );
       lbphour = engines[3].getValue("fuel-flow_pph");
       speedupengine( 3, lbphour, speedup );

       # accelerate day time
       node = props.globals.getNode("/sim/time/warp");
       multiplier = speedup - 1;
       offsetsec = PUMPSEC * multiplier;
       warp = node.getValue() + offsetsec; 
       node.setValue(warp);

       # safety
       lastft = getprop("/systems/fuel/pump/speed-up-ft");
       if( lastft != nil ) {
           stepft = MAXSTEPFT * speedup;
           maxft = lastft + stepft;
           minft = lastft - stepft;

           # too fast
           if( altitudeft > maxft or altitudeft < minft ) {
               setprop("/sim/speed-up",1);
           }
       }
   }

   setprop("/systems/fuel/pump/speed-up-ft",altitudeft);
}


# ===================
# TANK PRESSURIZATION
# ===================

# tank pressure leak
tankpressureleak = func {
    atmosinhg = getprop("/environment/pressure-inhg");
    tankinhg = getprop("/systems/tank-pressure/pressure-inhg");

    # the leak is ignored !
    diffpsi = ( tankinhg - atmosinhg ) * INHGTOPSI; 

    setprop("/instrumentation/tank-pressure/differential-psi",diffpsi);
}

# tank pressurization
tankpressureschedule = func {
    outputvolt =  getprop("/systems/electrical/outputs/specific");
    if( outputvolt != nil ) {
        if( getprop("/systems/tank-pressure/serviceable") and outputvolt > 20 and
            getprop("/systems/air-bleed/pressure-psi") >= 35 ) { 

            atmosinhg = getprop("/environment/pressure-inhg");

            # pressurize above 28000 ft (this is a guess)
            if( atmosinhg < 24.0 ) {
                pressurepsi = 1.5;
            }  
            else {
                pressurepsi = 0.0;
            }

            tankinhg = atmosinhg + pressurepsi * PSITOINHG;

            setprop("/instrumentation/tank-pressure/differential-psi",pressurepsi);
            setprop("/systems/tank-pressure/pressure-inhg",atmosinhg);
        }

        # leak
        else{
            tankpressureleak();
        }
    }
}
