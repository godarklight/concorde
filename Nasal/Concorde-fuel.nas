# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# IMPORTANT : always uses /consumables/fuel/tank[0]/level-gal_us, because /level-lb seems not synchronized with
# level-gal_us, during the time of a procedure.



# ===============
# FUEL MANAGEMENT
# ===============

Fuel = {};

Fuel.new = func {
# tank contents, to be initialised from XML
   obj = { parents : [Fuel], 

           electricalsystem : nil,

           pumpsystem : Pump.new(),
           totalinstrument : Totalfuel.new(),

           CONTENTLB : [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0 ],

# aft trim at 40 %
           AFTTRIM1LB : 0.0,
           AFTTRIM4LB : 0.0,

# pump rate : 10 lb/s for 1 pump.
# at Mach 2, trim tank 10 only feeds 2 supply tanks 5 and 7 : 45200 lb/h, or 6.3 lb/s per tank.
           PUMPSEC : 1.0,
           PUMPLBPSEC : 10,
           PUMPPMIN0 : 0.0,
           PUMPLB0 : 0.0,

# troubles if doesn't create symbols !
           PUMPPMIN : 0.0,
           PUMPLB : 0.0,

           CLIMBFTPMIN : 3500,                                           # max climb rate
           CLIMBFTPSEC : 0.0,
           MAXSTEPFT : 0.0,

           tankcontrols : nil,
           tanks : nil,
           engines : nil
         };

    obj.init();

    return obj;
}

Fuel.init = func {
    me.PUMPPMIN0 = constant.MINUTETOSECOND / me.PUMPSEC;
    me.PUMPLB0 = me.PUMPLBPSEC * me.PUMPSEC;
    me.PUMPPMIN = me.PUMPPMIN0;
    me.PUMPLB = me.PUMPLB0;

    me.CLIMBFTPSEC = me.CLIMBFTPMIN / constant.MINUTETOSECOND;
    me.MAXSTEPFT = me.CLIMBFTPSEC * me.PUMPSEC;

    me.tankcontrols = props.globals.getNode("/controls/fuel").getChildren("tank");
    me.tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
    me.engines = props.globals.getNode("/engines/").getChildren("engine");

    me.initfuel();
    me.presetfuel();
}

Fuel.set_relation = func( electrical ) {
   me.electricalsystem = electrical;
}

# fuel configuration
Fuel.presetfuel = func {
   # default is 0
   fuel = getprop("/sim/presets/fuel");
   if( fuel == nil ) {
       fuel = 0;
   }
   fillings = props.globals.getNode("/sim/presets/tanks").getChildren("filling");
   if( fuel < 0 or fuel >= size(fillings) ) {
       fuel = 0;
   } 
   presets = fillings[fuel].getChildren("tank");
   for( i=0; i < size(presets); i=i+1 ) {
        child = presets[i].getChild("level-gal_us");
        if( child != nil ) {
            level = child.getValue();
            me.tanks[i].getChild("level-gal_us").setValue(level);
        }
   } 
}

# tank initialization
Fuel.inittank = func( no, contentlb, overfull, underfull, lowlevel ) {
   me.tanks[no].getChild("content-lb").setValue( contentlb );

   # optional :  must be created by instrument XML
   if( overfull == "true" ) {
       valuelb = contentlb * 0.97;
       me.tanks[no].getChild("over-full-lb").setValue( valuelb );
   }
   if( underfull == "true" ) {
       valuelb = contentlb * 0.80;
       me.tanks[no].getChild("under-full-lb").setValue( valuelb );
   }
   if( lowlevel == "true" ) {
       valuelb = contentlb * 0.20;
       me.tanks[no].getChild("low-level-lb").setValue( valuelb );
   }
}

# fuel initialization
Fuel.initfuel = func {
   for( i=0; i < size(me.tanks); i=i+1 ) {
        densityppg = me.tanks[0].getChild("density-ppg").getValue();
        me.CONTENTLB[i] = me.tanks[i].getChild("capacity-gal_us").getValue() * densityppg;

        overfull = "";
        underfull = "";
        lowlevel = "";

        if( ( i >= 0 and i <= 4 ) or i == 6 or i == 10 ) {
            overfull = "true";
        }
        if( i >= 0 and i <= 3 ) {
            underfull = "true";
        }
        if( i >= 0 and i <= 3 ) {
            lowlevel = "true";
        }

        me.inittank( i,  me.CONTENTLB[i],  overfull,  underfull,  lowlevel );
   }

   me.AFTTRIM1LB = me.CONTENTLB[0] * 0.4;
   me.AFTTRIM4LB = me.CONTENTLB[3] * 0.4;
}

# pump forward
Fuel.pumpforward = func {
       tank9lb = me.tanks[8].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
       # towards tank 9
       if( tank9lb < me.CONTENTLB[8] ) {
           tank11lb = me.tanks[10].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
           # from rear tank 11
           if( tank11lb > 0 ) {
               for( i=0; i < 2; i=i+1 ) {
                    if( me.tankcontrols[10].getChild("pump",i).getValue() ) {
                        me.pumpsystem.transfertanks( 8, me.CONTENTLB[8], 10, me.PUMPLB );
                    }
               }
           }
       }
}

# pump aft
Fuel.pumpaft = func {
       tank11lb = me.tanks[10].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
       # from tank 9 at first
       if( me.tanks[8].getChild("level-gal_us").getValue() > 0 and
           ( me.tankcontrols[8].getChild("pump",0).getValue() or
             me.tankcontrols[8].getChild("pump",1).getValue() ) ) {
           # towards tank 11
           if( tank11lb < me.CONTENTLB[10] ) {
               for( i=0; i < 2; i=i+1 ) {
                    if( me.tankcontrols[8].getChild("pump",i).getValue() ) {
                        me.pumpsystem.transfertanks( 10, me.CONTENTLB[10], 8, me.PUMPLB );
                    }
               }
           }
       }
       # from tank 10
       elsif( me.tanks[9].getChild("level-gal_us").getValue() > 0 and
              ( me.tankcontrols[9].getChild("pump",0).getValue() or
                me.tankcontrols[9].getChild("pump",1).getValue() ) ) {
           # towards tank 11
           if( tank11lb < me.CONTENTLB[10] ) {
               for( i=0; i < 2; i=i+1 ) {
                    if( me.tankcontrols[9].getChild("pump",i).getValue() ) { 
                        me.pumpsystem.transfertanks( 10, me.CONTENTLB[10], 9, me.PUMPLB );
                    }
               }
           }
       }
}

# feed a left engine supply tank, with left main tanks
# - number of tank
# - content of tank (lb)
# - pumped volume (lb)
Fuel.pumpleftmain = func {
   tank = arg[0];
   contentlb = arg[1];
   pumplb = arg[2];

   # tank 1 by left pump
   if( tank == 0 ) {
       if( me.tankcontrols[4].getChild("pump",0).getValue() ) {
           tank5 = "yes"; 
       }
       else {
           tank5 = "";
       }
       if( me.tankcontrols[5].getChild("pump",0).getValue() ) {
           tank6 = "yes"; 
       }
       else {
           tank6 = "";
       }
       if( me.tankcontrols[11].getChild("pump",0).getValue() ) {
           tank5a = "yes"; 
       }
       else {
           tank5a = "";
       }

       if( me.tankcontrols[0].getChild("aft-trim").getValue() ) {
           tank1lb = me.tanks[0].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
           if( tank1lb > me.AFTTRIM1LB ) {
               tank5 = ""; 
               tank6 = ""; 
           }
       }
   }

   # tank 2 by right pump
   else {
       if( me.tankcontrols[4].getChild("pump",1).getValue() ) {
           tank5 = "yes"; 
       }
       else {
           tank5 = "";
       }
       if( me.tankcontrols[5].getChild("pump",1).getValue() ) {
           tank6 = "yes"; 
       }
       else {
           tank6 = "";
       }
       if( me.tankcontrols[11].getChild("pump",1).getValue() ) {
           tank5a = "yes"; 
       }
       else {
           tank5a = "";
       }
   }

   # balance the load on tanks 5, 6, and 5A
   # serve the forwards tanks at first, to shift the center of gravity aft
   if( tank5 == "yes" ) {
       me.pumpsystem.transfertanks( tank, contentlb, 4, pumplb );
   }
   # 6 only when 5 empty
   if( tank6 == "yes" ) {
       if( me.tanks[4].getChild("level-gal_us").getValue() == 0 ) {
           me.pumpsystem.transfertanks( tank, contentlb, 5, pumplb );
       }
   }

   # engineer transfers tank 5A to tank 5
   if( tank5a == "yes" ) {
       if( me.tankcontrols[11].getChild("trans-valve").getValue() ) {
           me.pumpsystem.transfertanks( 4, me.CONTENTLB[4], 11, pumplb );
       }
   }
}

# feed a right engine supply tank, with right main tanks
# - number of tank
# - content of tank (lb)
# - pumped volume (lb)
Fuel.pumprightmain = func {
   tank = arg[0];
   contentlb = arg[1];
   pumplb = arg[2];

   # tank 3 by left pump
   if( tank == 2 ) {
       if( me.tankcontrols[6].getChild("pump",0).getValue() ) {
           tank7 = "yes"; 
       }
       else {
           tank7 = "";
       }
       if( me.tankcontrols[7].getChild("pump",0).getValue() ) {
           tank8 = "yes"; 
       }
       else {
           tank8 = "";
       }
       if( me.tankcontrols[12].getChild("pump",0).getValue() ) {
           tank7a = "yes"; 
       }
       else {
           tank7a = "";
       }
   }

   # tank 4 by right pump
   else {
       if( me.tankcontrols[6].getChild("pump",1).getValue() ) {
           tank7 = "yes"; 
       }
       else {
           tank7 = "";
       }
       if( me.tankcontrols[7].getChild("pump",1).getValue() ) {
           tank8 = "yes"; 
       }
       else {
           tank8 = "";
       }
       if( me.tankcontrols[12].getChild("pump",1).getValue() ) {
           tank7a = "yes"; 
       }
       else {
           tank7a = "";
       }

       if( me.tankcontrols[3].getChild("aft-trim").getValue() ) {
           tank4lb = me.tanks[3].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
           if( tank4lb > me.AFTTRIM4LB ) {
               tank7 = ""; 
               tank8 = ""; 
           }
       }
   }

   # balance the load on tanks 7, 8 and 7A
   # serve the forwards tanks at first, to shift the center of gravity aft
   if( tank7 == "yes" ) {
       me.pumpsystem.transfertanks( tank, contentlb, 6, pumplb );
   }
   # 8 only when 7 empty
   if( tank8 == "yes" ) {
       if( me.tanks[6].getChild("level-gal_us").getValue() == 0 ) {
           me.pumpsystem.transfertanks( tank, contentlb, 7, pumplb );
       }
   }

   # engineer transfers tank 7A to tank 7
   if( tank7a == "yes" ) {
       if( me.tankcontrols[12].getChild("trans-valve").getValue() ) {
           me.pumpsystem.transfertanks( 6, me.CONTENTLB[6], 12, pumplb );
       }
   }
}

# feed engine supply tank, with trim tanks
# - number of tank
# - content of tank (lb)
# - pumped volume (lb)
# - aft
Fuel.pumptrim = func {
   tank = arg[0];
   contentlb = arg[1];
   aft = arg[3];
   pumplb = arg[2];

   # front tanks 9 and 10 (center of gravity goes rear)
   if( aft == "on" ) {
       tank9 = me.tanks[8].getChild("level-gal_us").getValue();
       if( tank9 > 0 and
           ( me.tankcontrols[8].getChild("pump",0).getValue() or
             me.tankcontrols[8].getChild("pump",1).getValue() ) ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tankcontrols[8].getChild("pump",i).getValue() ) {
                    me.pumpsystem.transfertanks( tank, contentlb, 8, pumplb );
                }
           }
       }
       # front tank 10 at last
       else {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tankcontrols[9].getChild("pump",i).getValue() ) {
                    me.pumpsystem.transfertanks( tank, contentlb, 9, pumplb );
                }
           }
       }
   }

   # rear tanks 11 (center of gravity goes forwards)
   else {
       tank11 = me.tanks[10].getChild("level-gal_us").getValue();
       # from tank 11
       if( tank11 > 0 ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tankcontrols[10].getChild("pump",i).getValue() ) {
                    me.pumpsystem.transfertanks( tank, contentlb, 10, pumplb );
                }
           }
       }
   }
}

# dump tanks
Fuel.dumpreartanks = func {
   # trim tanks :
   # - 9 and 10 (front)
   # - 11 (tail)
   for( i=8; i < 11; i=i+1 ) {
        for( j=0; j < 2; j=j+1 ) {
             if( me.tankcontrols[i].getChild("pump",j).getValue() ) {
                 me.pumpsystem.dumptank( i, me.PUMPLB );
             }
        }
   }

   # collector tanks 1, and 3 (not the left pump reserved for engine)
   for( i=0; i < 4; i=i+2 ) {
        for( j=1; j < 3; j=j+1 ) {
             if( me.tankcontrols[i].getChild("pump",j).getValue() ) {
                 me.pumpsystem.dumptank( i, me.PUMPLB );
             }
        }
   }

   # collector tanks 2 and 4 (not the right pump reserved for engine)
   for( i=1; i < 5; i=i+2 ) {
        for( j=0; j < 2; j=j+1 ) {
             if( me.tankcontrols[i].getChild("pump",j).getValue() ) {
                 me.pumpsystem.dumptank( i, me.PUMPLB );
             }
        }
   }
}

# balance all tanks (no pump)
Fuel.crosstanks = func {
   # engine cross feed (to be implemented)
   # tanks 1 and 4
   me.pumpsystem.pumpcross( 0, me.CONTENTLB[0], 3, me.CONTENTLB[3], me.PUMPLB );
   # tanks 2 and 3
   me.pumpsystem.pumpcross( 1, me.CONTENTLB[1], 2, me.CONTENTLB[2], me.PUMPLB );

   # interconnect (by gravity)
   # tanks 5 and 7
   me.pumpsystem.pumpcross( 4, me.CONTENTLB[4], 6, me.CONTENTLB[6], me.PUMPLB );
   # tanks 6 and 8
   me.pumpsystem.pumpcross( 5, me.CONTENTLB[5], 7, me.CONTENTLB[7], me.PUMPLB );
}

# pressurize the accumulators
Fuel.pressaccumulators = func {
   for( i=0; i < 4; i=i+1 ) {
        if( !me.tankcontrols[i].getChild("pump",0).getValue() and
            !me.tankcontrols[i].getChild("pump",1).getValue() and
            !me.tankcontrols[i].getChild("pump",2).getValue() ) {

            # engine stops when no fuel pressure
            setprop("/controls/engines/engine[" ~ i ~ "]/cutoff",constant.TRUE);
        }
   }
}

# feed collector tanks :
# - pumped volume (lb)
Fuel.pumpmain = func {
   pumplb = arg[0];

   for( i=0; i < 2; i=i+1 ) {
        me.pumpleftmain( i, me.CONTENTLB[i], pumplb );
   }
   for( i=2; i < 4; i=i+1 ) {
        me.pumprightmain( i, me.CONTENTLB[i], pumplb );
   }
}

# speed up engine, arguments :
# - engine tank
# - fuel flow of engine (lb per hour)
# - speed up
Fuel.speedupengine = func {
   enginetank = arg[0];
   flowlbph = arg[1];
   multiplier = arg[2];

   if( flowlbph == nil ) {
       flowlbph = 0;
   }
   flowgph = flowlbph * constant.LBTOGALUS;

   # fuel consumed during the time step
   if( flowgph > 0 ) {
       multiplier = multiplier - 1;
       enginegal = flowgph * multiplier;
       enginegal = enginegal / constant.HOURTOSECOND;
       enginegal = enginegal * me.PUMPSEC;

       tankgal = me.tanks[enginetank].getValue("level-gal_us");

       # collector tank
       if( enginegal > 0 ) {
           tankgal = me.tanks[enginetank].getValue("level-gal_us");
           if( tankgal > 0 ) {
               if( tankgal > enginegal ) {
                   tankgal = tankgal - enginegal;
                   enginegal = 0;
               }
               else {
                   enginegal = enginegal - tankgal;
                   tankgal = 0;
               }
               me.tanks[enginetank].getChild("level-gal_us").setValue(tankgal);
           }
       } 
   }
}

# speed up consumption
Fuel.speedupfuel = func {
   altitudeft = noinstrument.get_altitude_ft();
   speedup = getprop("/sim/speed-up");
   if( speedup > 1 ) {
       for( i=0; i < 4; i=i+1 ) {
            lbphour = me.engines[i].getValue("fuel-flow_pph");
            me.speedupengine( i, lbphour, speedup );
       }

       # accelerate day time
       node = props.globals.getNode("/sim/time/warp");
       multiplier = speedup - 1;
       offsetsec = me.PUMPSEC * multiplier;
       warp = node.getValue() + offsetsec; 
       node.setValue(warp);

       # safety
       lastft = getprop("/systems/fuel/pump/speed-up-ft");
       if( lastft != nil ) {
           stepft = me.MAXSTEPFT * speedup;
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

# feed engines
Fuel.schedule = func {
   speedup = getprop("/sim/speed-up");
   if( speedup > 1 ) {
       me.PUMPPMIN = me.PUMPPMIN0 / speedup;
       me.PUMPLB = me.PUMPLB0 * speedup;
   }
   else {
       me.PUMPPMIN = me.PUMPPMIN0;
       me.PUMPLB = me.PUMPLB0;
   }

   if( me.electricalsystem.has_specific() ) {
       if( getprop("/systems/fuel/serviceable") ) {
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
               me.pumptrim( 4, me.CONTENTLB[4], me.PUMPLB, aft );
               me.pumptrim( 6, me.CONTENTLB[6], me.PUMPLB, aft );

               # avoids running out of fuel
               me.pumpmain( me.PUMPLB );
           }
           # all tanks (balance)
           else {
               me.pumpmain( me.PUMPLB );

               if( forward == "on" ) {
                   me.pumpforward();
               }
               elsif( aft == "on" ) {
                   me.pumpaft();
               }
           }

           me.pressaccumulators();

           # avoid parallel events
           # 2 buttons for confirmation
           if( dump == "on" and dump2 == "on" ) {
               me.dumpreartanks();
           }
           if( cross == "on" ) {
               me.crosstanks();
           }
           me.totalinstrument.schedule( me.PUMPPMIN );
       }
   }

   me.speedupfuel();
}

# feed engines (CPP)
Fuel.schedulecpp = func {
   speedup = getprop("/sim/speed-up");
   if( speedup > 1 ) {
       me.PUMPPMIN = me.PUMPPMIN0 / speedup;
       me.PUMPLB = me.PUMPLB0 * speedup;
   }
   else {
       me.PUMPPMIN = me.PUMPPMIN0;
       me.PUMPLB = me.PUMPLB0;
   }

   if( me.electricalsystem.has_specific() ) {
       if( getprop("/systems/fuel/serviceable") ) {
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
           me.totalinstrument.schedule( me.PUMPPMIN );
       }
   }

   me.speedupfuel();
}


# ==========
# FUEL PUMPS
# ==========

Pump = {};

Pump.new = func {
   obj = { parents : [Pump],
           tanks : nil 
         };

   obj.init();

   return obj;
}

Pump.init = func {
   me.tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
}

# balance 2 tanks
# - number of left tank
# - content of left tank
# - number of right tank
# - content of right tank
# - dumped volume (lb)
Pump.pumpcross = func {
   ileft = arg[0];
   tankleftlb = me.tanks[ileft].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
   contentleftlb = arg[1];
   iright = arg[2];
   tankrightlb = me.tanks[iright].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
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
       me.transfertanks( ileft, contentleftlb, iright, difflb );
   }
   # left too heavy
   elsif( difflb > 0 )  {
       if( difflb > pumplb ) {
           difflb = pumplb;
       }
       me.transfertanks( iright, contentrightlb, ileft, difflb );
   }
}

# dump a tank
# - number of tank
# - dumped volume (lb)
Pump.dumptank = func {
   itank = arg[0];
   tanklb = me.tanks[itank].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
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
       tankgalus = tanklb / constant.GALUSTOLB;
       me.tanks[itank].getChild("level-gal_us").setValue(tankgalus);
   }
}

# transfer between 2 tanks, arguments :
# - number of tank destination
# - content of tank destination (lb)
# - number of tank source
# - pumped volume (lb)
Pump.transfertanks = func {
   idest = arg[0];
   tankdestlb = me.tanks[idest].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
   contentdestlb = arg[1];
   maxdestlb = contentdestlb - tankdestlb;
   isour = arg[2];
   tanksourlb = me.tanks[isour].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
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
           tanksourgalus = tanksourlb / constant.GALUSTOLB;
           me.tanks[isour].getChild("level-gal_us").setValue(tanksourgalus);
           tankdestgalus = tankdestlb / constant.GALUSTOLB;
           me.tanks[idest].getChild("level-gal_us").setValue(tankdestgalus);
       }
   }
}


# ===================
# TANK PRESSURIZATION
# ===================

Tank = {};

Tank.new = func {
   obj = { parents : [Tank],

           electricalsystem : nil,
           airbleedsystem : nil,

           diffpressure : TankPressure.new(),

           TANKSEC : 30.0,                          # refresh rate
           MAXPSI : 1.5,
           MINPSI : 0.0,
           staticport : ""
         };

   obj.init();

   return obj;
};

Tank.init = func {
    me.staticport = getprop("/systems/tank/static-port");
    me.staticport = me.staticport ~ "/pressure-inhg";

    me.diffpressure.set_rate( me.TANKSEC );
}

Tank.set_relation = func( airbleed, electrical ) {
   me.airbleedsystem = airbleed;
   me.electricalsystem = electrical;
}

# tank pressurization
Tank.schedule = func {
    if( me.electricalsystem.has_specific() ) {
        if( getprop("/systems/tank/serviceable") and me.airbleedsystem.has_pressure() ) { 

            atmosinhg = getprop(me.staticport);

            # pressurize above 28000 ft (this is a guess)
            if( atmosinhg < 9.73 ) {
                pressurepsi = me.MAXPSI;
            }  
            else {
                pressurepsi = me.MINPSI;
            }

            tankinhg = atmosinhg + pressurepsi * constant.PSITOINHG;

            setprop("/systems/tank/pressure-inhg",tankinhg);
        }
    }

    me.diffpressure.schedule();
}


# ==========================
# TANK DIFFERENTIAL PRESSURE
# ==========================

TankPressure = {};

TankPressure.new = func {
   obj = { parents : [TankPressure],
           TANKSEC : 30.0,                         # refresh rate
           staticport : ""                         # energy provided by differential pressure
         };

   obj.init();

   return obj;
};

TankPressure.init = func {
    me.staticport = getprop("/instrumentation/tank-pressure/static-port");
    me.staticport = me.staticport ~ "/pressure-inhg";
}

TankPressure.set_rate = func( rates ) {
    me.TANKSEC = rates;
}

TankPressure.schedule = func {
    atmosinhg = getprop(me.staticport);
    tankinhg = getprop("/systems/tank/pressure-inhg");

    diffpsi = ( tankinhg - atmosinhg ) * constant.INHGTOPSI; 

    if( diffpsi > 0.0 ) {
        raising = constant.TRUE;
        falling = constant.FALSE;
    }
    elsif( diffpsi < 0.0 ) {
        falling = constant.TRUE;
        raising = constant.FALSE;
    }
    else {
        raising = constant.FALSE;
        falling = constant.FALSE;
    }

    setprop("/instrumentation/tank-pressure/raising",raising);
    setprop("/instrumentation/tank-pressure/falling",falling);

    interpolate("/instrumentation/tank-pressure/differential-psi",diffpsi,me.TANKSEC);
}


# ==========
# TOTAL FUEL
# ==========
Totalfuel = {};

Totalfuel.new = func {
   obj = { parents : [Totalfuel],
           tanks : nil,
           nb_tanks : 0
         };

   obj.init();

   return obj;
};

Totalfuel.init = func {
   me.tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
   me.nb_tanks = size(me.tanks);
}

# total of fuel in kg
Totalfuel.schedule = func( pumppmin ) {
   tankskg = getprop("/instrumentation/fuel/total-kg");
   fuelgalus = 0;

   for(i=0; i<me.nb_tanks; i=i+1) {
   fuelgalus = fuelgalus + me.tanks[i].getChild("level-gal_us").getValue();
   }
   setprop("/instrumentation/fuel/total-gal_us", fuelgalus);

   # parser wants 1 line per multiplication !
   fuellb = fuelgalus * constant.GALUSTOLB;
   fuelkg = fuellb * constant.LBTOKG;
   setprop("/instrumentation/fuel/total-kg", fuelkg);

   # to check errors in pumping
   if( tankskg != nil ) {
       stepkg = tankskg - fuelkg;
       fuelkgpmin = stepkg * pumppmin;
       fuelkgph = fuelkgpmin * constant.HOURTOMINUTE;

       # no speed up : pumping is accelerated
       setprop("/instrumentation/fuel/fuel-flow-kg_ph", fuelkgph);
   }
}
