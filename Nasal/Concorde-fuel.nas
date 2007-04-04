# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# IMPORTANT : always uses /consumables/fuel/tank[0]/level-gal_us, because /level-lb seems not synchronized
# with level-gal_us, during the time of a procedure.



# ===============
# FUEL MANAGEMENT
# ===============

Fuel = {};

Fuel.new = func {
   obj = { parents : [Fuel], 

           tanksystem : Tanks.new(),
           totalinstrument : Totalfuel.new(),

           PUMPSEC : 1.0,

# at Mach 2, trim tank 10 only feeds 2 supply tanks 5 and 7 : 45200 lb/h, or 6.3 lb/s per tank.
           PUMPLBPSEC : 10,                                              # 10 lb/s for 1 pump.
           PUMPPMIN0 : 0.0,
           PUMPLB0 : 0.0,

           PUMPPMIN : 0.0,
           PUMPLB : 0.0,

           CLIMBFTPMIN : 3500,                                           # max climb rate
           CLIMBFTPSEC : 0.0,
           MAXSTEPFT : 0.0,

           pumps : nil,

           noinstrument : { "altitude" : "" },
           slave : { "electric" : nil }
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

    me.noinstrument["altitude"] = getprop("/systems/fuel/noinstrument/altitude");

    propname = getprop("/systems/fuel/slave/electric");
    me.slave["electric"] = props.globals.getNode(propname);

    me.pumps = props.globals.getNode("/controls/fuel/pumps");

    me.tanksystem.initinstrument();
    me.tanksystem.presetfuel();
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


   serviceable = constant.FALSE;
   if( me.slave["electric"].getChild("specific").getValue() ) {
       if( getprop("/systems/fuel/serviceable") ) {
           serviceable = constant.TRUE;

           # avoid parallel updates
           engine = me.pumps.getChild("engine").getValue();
           forward = me.pumps.getChild("forward").getValue();
           aft = me.pumps.getChild("aft").getValue();
           dump = me.pumps.getChild("dump").getValue();
           dump2 = me.pumps.getChild("dump2").getValue();
           cross = me.pumps.getChild("cross").getValue();

           # feeds from trim tanks
           if( engine and ( forward or aft ) ) {
               # balance the main tanks 5 and 7, closest to the collector tank
               me.pumptrim( "5", me.PUMPLB, aft );
               me.pumptrim( "7", me.PUMPLB, aft );

               # avoids running out of fuel
               me.pumpmain( me.PUMPLB );
           }
           # all tanks (balance)
           else {
               me.pumpmain( me.PUMPLB );

               if( forward ) {
                   me.pumpforward();
               }
               elsif( aft ) {
                   me.pumpaft();
               }
           }

           me.pressurizeaccumulators();

           # avoid parallel events
           # 2 buttons for confirmation
           if( dump and dump2 ) {
               me.dumpreartanks();
           }
           if( cross ) {
               me.crosstanks();
           }
       }
   }


   me.speedupfuel( speedup );

   # the last
   me.totalinstrument.schedule( me.PUMPPMIN );
}

Fuel.menuexport = func {
   me.tanksystem.menu();
}

Fuel.full = func( tank ) {
   return me.tanksystem.full( tank );
}

Fuel.empty = func( tank ) {
   return me.tanksystem.empty( tank );
}

Fuel.lowlevel = func {
   return me.tanksystem.lowlevel();
}

Fuel.togglepump = func( tank, set ) {
   for( i=0; i < 2; i=i+1 ) {
        me.tanksystem.controls(tank).getChild("pump",i).setValue( set );
   }
}

Fuel.toggletransvalve = func( tank, set ) {
   me.tanksystem.controls(tank).getChild("trans-valve").setValue( set );
}

Fuel.toggleafttrim = func( set ) {
   me.tanksystem.controls("1").getChild("aft-trim").setValue( set );
   me.tanksystem.controls("4").getChild("aft-trim").setValue( set );
}

Fuel.toggleforward = func( set ) {
   if( !set ) {
       me.pumps.getChild("forward").setValue(constant.FALSE);
   }
   else {
       me.pumps.getChild("forward").setValue(constant.TRUE);
   }

   me.pumps.getChild("aft").setValue(constant.FALSE);
}

Fuel.toggleaft = func( set ) {
   if( !set ) {
       me.pumps.getChild("aft").setValue(constant.FALSE);
   }
   else {
       me.pumps.getChild("aft").setValue(constant.TRUE);
   }

   me.pumps.getChild("forward").setValue(constant.FALSE);
}

Fuel.toggleengine = func( set ) {
   if( !set ) {
       me.pumps.getChild("engine").setValue(constant.FALSE);
   }
   else {
       me.pumps.getChild("engine").setValue(constant.TRUE);
   }

   me.pumps.getChild("aft").setValue(constant.FALSE);
   me.pumps.getChild("forward").setValue(constant.FALSE);
}

Fuel.forwardexport = func {
   set = me.pumps.getChild("forward").getValue();
   me.toggleforward( !set );
}

Fuel.aftexport = func {
   set = me.pumps.getChild("aft").getValue();
   me.toggleaft( !set );
}

Fuel.engineexport = func {
   set = me.pumps.getChild("engine").getValue();
   me.toggleengine( !set );
}

# pump forward
Fuel.pumpforward = func {
   # towards tank 9
   if( !me.full("9") ) {
       # from rear tank 11
       if( !me.empty("11") ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("11").getChild("pump",i).getValue() ) {
                    me.tanksystem.transfertanks( "9", "11", me.PUMPLB );
                }
           }
       }
   }
}

# pump aft
Fuel.pumpaft = func {
   # from tank 9 at first
   if( !me.empty("9") and
       ( me.tanksystem.controls("9").getChild("pump",0).getValue() or
         me.tanksystem.controls("9").getChild("pump",1).getValue() ) ) {
       # towards tank 11
       if( !me.full("11") ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("9").getChild("pump",i).getValue() ) {
                    me.tanksystem.transfertanks( "11", "9", me.PUMPLB );
                }
           }
       }
   }
   # from tank 10
   elsif( !me.empty("10") and
          ( me.tanksystem.controls("10").getChild("pump",0).getValue() or
            me.tanksystem.controls("10").getChild("pump",1).getValue() ) ) {
       # towards tank 11
       if( !me.full("11") ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("10").getChild("pump",i).getValue() ) { 
                    me.tanksystem.transfertanks( "11", "10", me.PUMPLB );
                }
           }
       }
   }
}

# feed a left engine supply tank, with left main tanks
Fuel.pumpleftmain = func( tank, pumplb ) {
   # tank 1 by left pump
   if( tank == "1" ) {
       if( me.tanksystem.controls("5").getChild("pump",0).getValue() ) {
           tank5 = constant.TRUE; 
       }
       else {
           tank5 = constant.FALSE;
       }
       if( me.tanksystem.controls("6").getChild("pump",0).getValue() ) {
           tank6 = constant.TRUE; 
       }
       else {
           tank6 = constant.FALSE;
       }
       if( me.tanksystem.controls("5A").getChild("pump",0).getValue() ) {
           tank5a = constant.TRUE; 
       }
       else {
           tank5a = constant.FALSE;
       }

       if( me.tanksystem.controls("1").getChild("aft-trim").getValue() ) {
           tank1lb = me.tanksystem.getlevellb("1");
           if( tank1lb > me.tanksystem.getafttrimlb("1") ) {
               tank5 = constant.FALSE; 
               tank6 = constant.FALSE; 
           }
       }
   }

   # tank 2 by right pump
   else {
       if( me.tanksystem.controls("5").getChild("pump",1).getValue() ) {
           tank5 = constant.TRUE; 
       }
       else {
           tank5 = constant.FALSE;
       }
       if( me.tanksystem.controls("6").getChild("pump",1).getValue() ) {
           tank6 = constant.TRUE; 
       }
       else {
           tank6 = constant.FALSE;
       }
       if( me.tanksystem.controls("5A").getChild("pump",1).getValue() ) {
           tank5a = constant.TRUE; 
       }
       else {
           tank5a = constant.FALSE;
       }
   }

   # balance the load on tanks 5, 6, and 5A
   # serve the forwards tanks at first, to shift the center of gravity aft
   if( tank5 ) {
       me.tanksystem.transfertanks( tank, "5", pumplb );
   }
   # 6 only when 5 empty
   if( tank6 ) {
       if( me.empty("5") ) {
           me.tanksystem.transfertanks( tank, "6", pumplb );
       }
   }

   # engineer transfers tank 5A to tank 5
   if( tank5a ) {
       if( me.tanksystem.controls("5A").getChild("trans-valve").getValue() ) {
           me.tanksystem.transfertanks( "5", "5A", pumplb );
       }
   }
}

# feed a right engine supply tank, with right main tanks
Fuel.pumprightmain = func( tank, pumplb ) {
   # tank 3 by left pump
   if( tank == "3" ) {
       if( me.tanksystem.controls("7").getChild("pump",0).getValue() ) {
           tank7 = constant.TRUE; 
       }
       else {
           tank7 = constant.FALSE;
       }
       if( me.tanksystem.controls("8").getChild("pump",0).getValue() ) {
           tank8 = constant.TRUE; 
       }
       else {
           tank8 = constant.FALSE;
       }
       if( me.tanksystem.controls("7A").getChild("pump",0).getValue() ) {
           tank7a = constant.TRUE; 
       }
       else {
           tank7a = constant.FALSE;
       }
   }

   # tank 4 by right pump
   else {
       if( me.tanksystem.controls("7").getChild("pump",1).getValue() ) {
           tank7 = constant.TRUE; 
       }
       else {
           tank7 = constant.FALSE;
       }
       if( me.tanksystem.controls("8").getChild("pump",1).getValue() ) {
           tank8 = constant.TRUE; 
       }
       else {
           tank8 = constant.FALSE;
       }
       if( me.tanksystem.controls("7A").getChild("pump",1).getValue() ) {
           tank7a = constant.TRUE; 
       }
       else {
           tank7a = constant.FALSE;
       }

       if( me.tanksystem.controls("4").getChild("aft-trim").getValue() ) {
           tank4lb = me.tanksystem.getlevellb("4");
           if( tank4lb > me.tanksystem.getafttrimlb("4") ) {
               tank7 = constant.FALSE; 
               tank8 = constant.FALSE; 
           }
       }
   }

   # balance the load on tanks 7, 8 and 7A
   # serve the forwards tanks at first, to shift the center of gravity aft
   if( tank7 ) {
       me.tanksystem.transfertanks( tank, "7", pumplb );
   }
   # 8 only when 7 empty
   if( tank8 ) {
       if( me.empty("7") ) {
           me.tanksystem.transfertanks( tank, "8", pumplb );
       }
   }

   # engineer transfers tank 7A to tank 7
   if( tank7a ) {
       if( me.tanksystem.controls("7A").getChild("trans-valve").getValue() ) {
           me.tanksystem.transfertanks( "7", "7A", pumplb );
       }
   }
}

# feed engine supply tank, with trim tanks
Fuel.pumptrim = func( tank, pumplb, aft ) {
   # front tanks 9 and 10 (center of gravity goes rear)
   if( aft ) {
       if( !me.empty("9") and
           ( me.tanksystem.controls("9").getChild("pump",0).getValue() or
             me.tanksystem.controls("9").getChild("pump",1).getValue() ) ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("9").getChild("pump",i).getValue() ) {
                    me.tanksystem.transfertanks( tank, "9", pumplb );
                }
           }
       }
       # front tank 10 at last
       else {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("10").getChild("pump",i).getValue() ) {
                    me.tanksystem.transfertanks( tank, "10", pumplb );
                }
           }
       }
   }

   # rear tanks 11 (center of gravity goes forwards)
   else {
       if( !me.empty("11") ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("11").getChild("pump",i).getValue() ) {
                    me.tanksystem.transfertanks( tank, "11", pumplb );
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
   for( j=0; j < 2; j=j+1 ) {
        if( me.tanksystem.controls("9").getChild("pump",j).getValue() ) {
            me.tanksystem.dumptank( "9", me.PUMPLB );
        }
        if( me.tanksystem.controls("10").getChild("pump",j).getValue() ) {
            me.tanksystem.dumptank( "10", me.PUMPLB );
        }
        if( me.tanksystem.controls("11").getChild("pump",j).getValue() ) {
            me.tanksystem.dumptank( "11", me.PUMPLB );
        }
   }

   # collector tanks 1, and 3 (not the left pump reserved for engine)
   for( j=1; j < 3; j=j+1 ) {
        if( me.tanksystem.controls("1").getChild("pump",j).getValue() ) {
            me.tanksystem.dumptank( "1", me.PUMPLB );
        }
        if( me.tanksystem.controls("3").getChild("pump",j).getValue() ) {
            me.tanksystem.dumptank( "3", me.PUMPLB );
        }
   }

   # collector tanks 2 and 4 (not the right pump reserved for engine)
   for( j=0; j < 2; j=j+1 ) {
        if( me.tanksystem.controls("2").getChild("pump",j).getValue() ) {
            me.tanksystem.dumptank( "2", me.PUMPLB );
        }
        if( me.tanksystem.controls("4").getChild("pump",j).getValue() ) {
            me.tanksystem.dumptank( "4", me.PUMPLB );
        }
   }
}

# balance all tanks (no pump)
Fuel.crosstanks = func {
   # engine cross feed (to be implemented)
   # tanks 1 and 4
   me.tanksystem.pumpcross( "1", "4", me.PUMPLB );
   # tanks 2 and 3
   me.tanksystem.pumpcross( "2", "3", me.PUMPLB );

   # interconnect (by gravity)
   # tanks 5 and 7
   me.tanksystem.pumpcross( "5", "7", me.PUMPLB );
   # tanks 6 and 8
   me.tanksystem.pumpcross( "6", "8", me.PUMPLB );
}

Fuel.accumulator = func( tank ) {
   thetank = me.tanksystem.controls(tank);
   if( !thetank.getChild("pump",0).getValue() and
       !thetank.getChild("pump",1).getValue() and
       !thetank.getChild("pump",2).getValue() ) {

       # engine stops when no fuel pressure
       me.tanksystem.getenginecontrols(tank).getChild("cutoff").setValue(constant.TRUE);
   }
}

# pressurize the accumulators
Fuel.pressurizeaccumulators = func {
   me.accumulator("1");
   me.accumulator("2");
   me.accumulator("3");
   me.accumulator("4");
}

# feed collector tanks :
Fuel.pumpmain = func( pumplb ) {
   me.pumpleftmain( "1", pumplb );
   me.pumpleftmain( "2", pumplb );

   me.pumprightmain( "3", pumplb );
   me.pumprightmain( "4", pumplb );
}

# speed up engine, arguments :
Fuel.speedupengine = func( enginetank, multiplier ) {
   flowlbph = me.tanksystem.getengines(enginetank).getChild("fuel-flow_pph").getValue();
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

       # collector tank
       me.tanksystem.reduce( enginetank, enginegal );
   }
}

# speed up consumption
Fuel.speedupfuel = func( speedup ) {
   altitudeft = getprop(me.noinstrument["altitude"]);
   if( speedup > 1 ) {
       # disabled : JSBSim now supports time acceleration
#       me.speedupengine( "1", speedup );
#       me.speedupengine( "2", speedup );
#       me.speedupengine( "3", speedup );
#       me.speedupengine( "4", speedup );

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


# =====
# TANKS
# =====

# adds an indirection to convert the tank name into an array index.

Tanks = {};

Tanks.new = func {
# tank contents, to be initialised from XML
   obj = { parents : [Tanks], 

           pumpsystem : Pump.new(),

           CONTENTLB : { "1" : 0.0, "2" : 0.0, "3" : 0.0, "4" : 0.0, "5" : 0.0, "6" : 0.0, "7" : 0.0,
                         "8" : 0.0, "9" : 0.0, "10" : 0.0, "11" : 0.0, "5A" : 0.0, "7A" : 0.0 },
           TANKINDEX : { "1" : 0, "2" : 1, "3" : 2, "4" : 3, "5" : 4, "6" : 5, "7" : 6,
                         "8" : 7, "9" : 8, "10" : 9, "11" : 10, "5A" : 11, "7A" : 12 },
           TANKNAME : [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "5A", "7A" ],
           nb_tanks : 0,
           OVERFULL : 0.97,
           OVERFULL : 0.97,
           UNDERFULL : 0.8,
           LOWLEVELLB : [ 0.0, 0.0, 0.0, 0.0 ],
           LOWLEVEL : 0.2,

           AFTTRIMLB : { "1" : 0.0, "4" : 0.0 },
           AFTTRIM : 0.4,                                                # aft trim at 40 %

           enginecontrols : nil,
           engines : nil,
           fillings : nil,
           pumps : nil,
           tankcontrols : nil,
           tanks : nil
         };

    obj.init();

    return obj;
}

Tanks.init = func {
    me.tankcontrols = props.globals.getNode("/controls/fuel").getChildren("tank");
    me.tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
    me.enginecontrols = props.globals.getNode("/controls/engines").getChildren("engine");
    me.engines = props.globals.getNode("/engines/").getChildren("engine");
    me.fillings = props.globals.getNode("/sim/presets/tanks").getChildren("filling");
    me.pumps = props.globals.getNode("/controls/fuel/pumps");

    me.nb_tanks = size(me.tanks);

    me.initcontent();
}

# fuel initialization
Tanks.initcontent = func {
   for( i=0; i < me.nb_tanks; i=i+1 ) {
        densityppg = me.tanks[i].getChild("density-ppg").getValue();
        me.CONTENTLB[me.TANKNAME[i]] = me.tanks[i].getChild("capacity-gal_us").getValue() * densityppg;
   }

   me.AFTTRIMLB["1"] = me.CONTENTLB["1"] * me.AFTTRIM;
   me.AFTTRIMLB["4"] = me.CONTENTLB["4"] * me.AFTTRIM;

   for( i=0; i < 4; i=i+1 ) {
       me.LOWLEVELLB[i] = me.CONTENTLB[me.TANKNAME[i]] * me.LOWLEVEL;
   }
}

# change by dialog
Tanks.menu = func {
   value = getprop("/sim/presets/tanks/dialog");
   for( i=0; i < size(me.fillings); i=i+1 ) {
        if( me.fillings[i].getChild("comment").getValue() == value ) {
            me.load( i );
            # for aircraft-data
            setprop("/sim/presets/fuel",i);
            break;
        }
   }
}

# fuel configuration
Tanks.presetfuel = func {
   # default is 0
   fuel = getprop("/sim/presets/fuel");
   if( fuel == nil ) {
       fuel = 0;
   }

   if( fuel < 0 or fuel >= size(me.fillings) ) {
       fuel = 0;
   } 

   # copy to dialog
   dialog = getprop("/sim/presets/tanks/dialog");
   if( dialog == "" or dialog == nil ) {
       value = me.fillings[fuel].getChild("comment").getValue();
       setprop("/sim/presets/tanks/dialog", value);
   }

   me.load( fuel );
}

Tanks.load = func( fuel ) {
   presets = me.fillings[fuel].getChildren("tank");
   for( i=0; i < size(presets); i=i+1 ) {
        child = presets[i].getChild("level-gal_us");
        if( child != nil ) {
            level = child.getValue();
        }

        # new load through dialog
        else {
            level = me.CONTENTLB[me.TANKNAME[i]] * constant.LBTOGALUS;
        } 
        me.pumpsystem.setlevel(i, level);
   } 
}

# tank initialization
Tanks.inittank = func( no, contentlb, overfull, underfull, lowlevel ) {
   me.tanks[no].getChild("content-lb").setValue( contentlb );

   # optional :  must be created by XML
   if( overfull ) {
       valuelb = contentlb * me.OVERFULL;
       me.tanks[no].getChild("over-full-lb").setValue( valuelb );
   }
   if( underfull ) {
       valuelb = contentlb * me.UNDERFULL;
       me.tanks[no].getChild("under-full-lb").setValue( valuelb );
   }
   if( lowlevel ) {
       me.tanks[no].getChild("low-level-lb").setValue( me.LOWLEVELLB[no] );
   }
}

Tanks.initinstrument = func {
   for( i=0; i < me.nb_tanks; i=i+1 ) {
        overfull = constant.FALSE;
        underfull = constant.FALSE;
        lowlevel = constant.FALSE;

        if( ( i >= me.TANKINDEX["1"] and i <= me.TANKINDEX["4"] ) or
            i == me.TANKINDEX["5"] or i == me.TANKINDEX["7"] or i == me.TANKINDEX["11"] ) {
            overfull = constant.TRUE;
        }
        if( i >= me.TANKINDEX["1"] and i <= me.TANKINDEX["4"] ) {
            underfull = constant.TRUE;
        }
        if( i >= me.TANKINDEX["1"] and i <= me.TANKINDEX["4"] ) {
            lowlevel = constant.TRUE;
        }

        me.inittank( i,  me.CONTENTLB[me.TANKNAME[i]],  overfull,  underfull,  lowlevel );
   }
}

Tanks.controls = func( name ) {
   return me.tankcontrols[me.TANKINDEX[name]];
}

Tanks.getenginecontrols = func( name ) {
   return me.enginecontrols[me.TANKINDEX[name]];
}

Tanks.getengines = func( name ) {
   return me.engines[me.TANKINDEX[name]];
}

Tanks.getafttrimlb = func( name ) {
   return me.AFTTRIMLB[name];
}

Tanks.getlevellb = func( name ) {
   return me.pumpsystem.getlevellb( me.TANKINDEX[name] );
}

Tanks.lowlevel = func {
   result = constant.FALSE;

   for( i=0; i < 4; i=i+1 ) {
      levellb = me.pumpsystem.getlevellb( i ); 
      if( levellb < me.LOWLEVELLB[i] ) {
          result = constant.TRUE;
          break;
      }
   }

   return result;
}

Tanks.empty = func( name ) {
   return me.pumpsystem.empty( me.TANKINDEX[name] );
}

Tanks.full = func( name ) {
   return me.pumpsystem.full( me.TANKINDEX[name], me.CONTENTLB[name] );
}

Tanks.reduce = func( name, enginegal ) {
   me.pumpsystem.reduce( me.TANKINDEX[name], enginegal );
}

Tanks.dumptank = func( name, pumplb ) {
   me.pumpsystem.dumptank( me.TANKINDEX[name], pumplb );
}

Tanks.pumpcross = func( left, right, pumplb ) {
   me.pumpsystem.pumpcross( me.TANKINDEX[left], me.CONTENTLB[left],
                            me.TANKINDEX[right], me.CONTENTLB[right], pumplb );
}

Tanks.transfertanks = func( dest, sour, pumplb ) {
   me.pumpsystem.transfertanks( me.TANKINDEX[dest], me.CONTENTLB[dest], me.TANKINDEX[sour], pumplb );
}


# ==========
# FUEL PUMPS
# ==========

# does the transfers between the tanks

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

Pump.getlevel = func( index ) {
   tankgalus = me.tanks[index].getChild("level-gal_us").getValue();

   return tankgalus;
}

Pump.getlevellb = func( index ) {
   tanklb = me.getlevel(index) * constant.GALUSTOLB;

   return tanklb;
}

Pump.empty = func( index ) {
   tankgal = me.getlevel(index);

   if( tankgal == 0.0 ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Pump.full = func( index, contentlb ) {
   tanklb = me.getlevellb(index);

   if( tanklb < contentlb ) {
       result = constant.FALSE;
   }
   else {
       result = constant.TRUE;
   }

   return result;
}

Pump.setlevel = func( index, levelgalus ) {
   me.tanks[index].getChild("level-gal_us").setValue(levelgalus);
}

Pump.setlevellb = func( index, levellb ) {
   levelgalus = levellb / constant.GALUSTOLB;

   me.setlevel( index, levelgalus );
}

Pump.reduce = func( enginetank, enginegal ) {
   if( enginegal > 0 ) {
       tankgal = me.getlevel(enginetank);
       if( tankgal > 0 ) {
           if( tankgal > enginegal ) {
               tankgal = tankgal - enginegal;
               enginegal = 0;
           }
           else {
               enginegal = enginegal - tankgal;
               tankgal = 0;
           }
           me.setlevel(enginetank,tankgal);
       }
   }
}


# balance 2 tanks
# - number of left tank
# - content of left tank
# - number of right tank
# - content of right tank
# - dumped volume (lb)
Pump.pumpcross = func {
   ileft = arg[0];
   tankleftlb = me.getlevellb(ileft);
   contentleftlb = arg[1];
   iright = arg[2];
   tankrightlb = me.getlevellb(iright);
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
   tanklb = me.getlevellb(itank);
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
       me.setlevellb(itank,tanklb);
   }
}

# transfer between 2 tanks, arguments :
# - number of tank destination
# - content of tank destination (lb)
# - number of tank source
# - pumped volume (lb)
Pump.transfertanks = func {
   idest = arg[0];
   tankdestlb = me.getlevellb(idest);
   contentdestlb = arg[1];
   maxdestlb = contentdestlb - tankdestlb;
   isour = arg[2];
   tanksourlb = me.getlevellb(isour);
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
           me.setlevellb(isour,tanksourlb);
           me.setlevellb(idest,tankdestlb);
       }
   }
}


# ===================
# TANK PRESSURIZATION
# ===================

PressurizeTank = {};

PressurizeTank.new = func {
   obj = { parents : [PressurizeTank],

           diffpressure : TankPressure.new(),

           TANKSEC : 30.0,                          # refresh rate
           PRESSURIZEINHG : 9.73,                   # 28000 ft
           MAXPSI : 1.5,
           MINPSI : 0.0,

           staticport : "",
           slave : { "air" : nil, "electric" : nil }
         };

   obj.init();

   return obj;
};

PressurizeTank.init = func {
    me.staticport = getprop("/systems/tank/static-port");
    me.staticport = me.staticport ~ "/pressure-inhg";

    propname = getprop("/systems/tank/slave/air");
    me.slave["air"] = props.globals.getNode(propname);
    propname = getprop("/systems/tank/slave/electric");
    me.slave["electric"] = props.globals.getNode(propname);

    me.diffpressure.set_rate( me.TANKSEC );
}

# tank pressurization
PressurizeTank.schedule = func {
    if( me.slave["electric"].getChild("specific").getValue() ) {
        if( getprop("/systems/tank/serviceable") and
            me.slave["air"].getChild("pressurization").getValue() ) {
            atmosinhg = getprop(me.staticport);

            # pressurize above 28000 ft (this is a guess)
            if( atmosinhg < me.PRESSURIZEINHG ) {
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
   # last total
   tanksgalus = getprop("/instrumentation/fuel/total-gal_us");
   tankskg = tanksgalus * constant.GALUSTOKG;


   fuelgalus = 0;
   for(i=0; i<me.nb_tanks; i=i+1) {
       fuelgalus = fuelgalus + me.tanks[i].getChild("level-gal_us").getValue();
   }
   # not real
   setprop("/instrumentation/fuel/total-gal_us", fuelgalus);


   # real
   fuelkg = fuelgalus * constant.GALUSTOKG;
   setprop("/instrumentation/fuel/total-kg", fuelkg);


   # ==========================================================
   # - MUST BE CONSTANT with speed up : pumping is accelerated.
   # - not real, used to check errors in pumping.
   # ==========================================================
   stepkg = tankskg - fuelkg;
   fuelkgpmin = stepkg * pumppmin;
   fuelkgph = fuelkgpmin * constant.HOURTOMINUTE;

   setprop("/instrumentation/fuel/fuel-flow-kg_ph", fuelkgph);
}
