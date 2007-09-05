# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence


# IMPORTANT : always uses /consumables/fuel/tank[0]/level-gal_us,
# because /level-lb seems not synchronized with level-gal_us, during the time of a procedure.



# ===============
# FUEL MANAGEMENT
# ===============

Fuel = {};

Fuel.new = func {
   obj = { parents : [Fuel,System], 

           tanksystem : Tanks.new(),
           totalfuelinstrument : TotalFuel.new(),
           fuelconsumedinstrument : FuelConsumed.new(),
           aircraftweightinstrument : AircraftWeight.new(),

           PUMPSEC : 1.0,

# at Mach 2, trim tank 10 only feeds 2 supply tanks 5 and 7 : 45200 lb/h, or 6.3 lb/s per tank.
           PUMPLBPSEC : 10,                                              # 10 lb/s for 1 pump.

           PUMPPMIN0 : 0.0,                                              # time step
           PUMPPMIN : 0.0,                                               # speed up

           PUMPLB0 : 0.0,                                                # rate for step
           PUMPLB : 0.0,                                                 # speed up

# auto trim limits
           FORWARDKG : 24000,
           AFTKG : 11000,
           EMPTYKG : 0,

           fuel : nil,
           pumps : nil
         };

    obj.init();

    return obj;
}

Fuel.init = func {
    me.PUMPPMIN0 = constant.MINUTETOSECOND / me.PUMPSEC;
    me.PUMPLB0 = me.PUMPLBPSEC * me.PUMPSEC;
    me.PUMPPMIN = me.PUMPPMIN0;
    me.PUMPLB = me.PUMPLB0;

    me.init_ancestor("/systems/fuel");

    me.fuel = props.globals.getNode("/systems/fuel");
    me.pumps = props.globals.getNode("/controls/fuel/pumps");

    me.tanksystem.initinstrument();
    me.tanksystem.presetfuel();
}

Fuel.amber_fuel = func {
   return me.tanksystem.amber_fuel();
}

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

   me.pumping();
}

Fuel.slowschedule = func {
   if( me.fuel.getChild("serviceable").getValue() ) {
       # mechanical valves are supposed
       me.inletvalve();
   }

   me.fuelconsumedinstrument.schedule();
   me.aircraftweightinstrument.schedule();
}

Fuel.menuexport = func {
   change = me.tanksystem.menu();

   me.fuel.getChild("reset").setValue( change );
}

Fuel.setweighthuman = func( totalkg ) {
   me.aircraftweightinstrument.setdatum( totalkg );
   me.fuelconsumedinstrument.reset();

   me.fuel.getChild("reset").setValue( constant.FALSE );
}

Fuel.inletvalve = func {
   # only 1 valve
   me.computeinletvalve( "5", 0 );
   me.computeinletvalve( "7", 0 );

   for( i = 0; i < 2; i = i+1 ) {
        me.computeinletvalve( "9", i );
        me.computeinletvalve( "11", i );
   }
}

Fuel.pumping = func {
   if( me.fuel.getChild("serviceable").getValue() ) {
       if( me.slave["electric"].getChild("specific").getValue() ) {
           # controlled only by inlet valves and fuel pumps :
           # tanks pumping each other is possible !
           me.autotrim();

           # feeds from trim tanks
           # balance the main tanks 5 and 7, closest to the collector tank
           me.pumptrim("5");
           me.pumptrim("7");

           # avoids running out of fuel
           me.pumpmain();

           me.pumpforward();
           me.pumpaft();

           me.fuelpiping();


           # avoid parallel updates
           dump = me.pumps.getChild("dump").getValue();
           dump2 = me.pumps.getChild("dump2").getValue();

           # avoid parallel events
           # 2 buttons for confirmation
           if( dump and dump2 ) {
               me.dumpreartanks();
           }

           me.connecttanks();
       }


       # for simplification, the diameter of inlet valves is enough for both the flow of
       # hydraulical and electrical pumps.
       me.hydraulicautotrim();
       me.hydraulicforward();
   }

   # to synchronized with pumping
   me.totalfuelinstrument.schedule();
}

Fuel.autotrim = func {
   forwardoverride = me.pumps.getChild("forward-override").getValue();

   if( !me.pumps.getChild("auto-off").getValue() or forwardoverride ) {
       tank9kg = me.tanksystem.getlevelkg("9");
       tank10kg = me.tanksystem.getlevelkg("10");
       level910kg = tank9kg + tank10kg;
       level11kg = me.tanksystem.getlevelkg("11");

       # forward or emergency override (which ignores the load limits)
       if( me.pumps.getChild("auto-forward").getValue() or forwardoverride ) {
           if( me.tanksystem.controls( "11", "pump-auto", 0 ).getValue() and
               me.tanksystem.controls( "11", "pump-auto", 1 ).getValue() ) {

               empty11 = me.empty( "11" );

               # stop everything
               if( empty11 or
                   ( level11kg <= me.tanksystem.controls( "11", "limit-kg" ).getValue() and
                     !forwardoverride ) ) {
                   me.stopautopumps();
                   me.enginehuman( constant.FALSE );
               }

               # 11 to 5 and 7, until limit of 11
               elsif( me.full( "9" ) or
                      ( level910kg >= me.tanksystem.controls( "9", "limit-kg" ).getValue() and
                        !forwardoverride ) ) {
                   if ( me.tanksystem.controls( "5", "inlet-auto" ).getValue() and
                        me.tanksystem.controls( "7", "inlet-auto" ).getValue() ) {
                        me.forwardautopumps( constant.FALSE, constant.FALSE );
                        me.enginehuman( constant.TRUE );
                        me.forwardhuman( constant.TRUE );
                   }
               }

               # 11 to 9 until limit of 9 + 10
               elsif ( me.tanksystem.controls( "9", "inlet-auto", 0 ).getValue() and
                       me.tanksystem.controls( "9", "inlet-auto", 1 ).getValue() ) {
                   me.forwardautopumps( constant.FALSE, constant.FALSE );
                   me.enginehuman( constant.FALSE );
                   me.forwardhuman( constant.TRUE );
               }

               # stop
               else {
                   me.stopautopumps();
                   me.enginehuman( constant.FALSE );
               }
           }
       }

       # rearward
       else {
           if( me.tanksystem.controls( "9", "pump-auto", 0 ).getValue() and
               me.tanksystem.controls( "9", "pump-auto", 1 ).getValue() and
               me.tanksystem.controls( "10", "pump-auto", 0 ).getValue() and
               me.tanksystem.controls( "10", "pump-auto", 1 ).getValue() ) {

               empty9 = me.empty( "9" );

               # stop everything
               if( ( empty9 and me.empty( "10" ) ) or
                   level910kg <= me.tanksystem.controls( "9", "limit-kg" ).getValue() ) {
                   me.stopautopumps();
                   me.enginehuman( constant.FALSE );
               }

               # 9 + 10 to 5 and 7, until limit of 9 + 10 
               elsif( me.full( "11" ) or
                      level11kg >= me.tanksystem.controls( "11", "limit-kg" ).getValue() ) {
                   if ( me.tanksystem.controls( "5", "inlet-auto" ).getValue() and
                        me.tanksystem.controls( "7", "inlet-auto" ).getValue() ) {
                        me.forwardautopumps( constant.TRUE, empty9 );
                        me.enginehuman( constant.TRUE );
                        me.afthuman( constant.TRUE );
                   }
               }

               # 9 + 10 to 11 until limit of 11
               elsif ( me.tanksystem.controls( "11", "inlet-auto", 0 ).getValue() and
                       me.tanksystem.controls( "11", "inlet-auto", 1 ).getValue() ) {
                   me.forwardautopumps( constant.TRUE, empty9 );
                   me.enginehuman( constant.FALSE );
                   me.afthuman( constant.TRUE );
               }

               # stop
               else {
                   me.stopautopumps();
                   me.enginehuman( constant.FALSE );
               }
           }
       }
   }


   # not driven by auto
   else {
       me.stopautopumps();
   }
}

Fuel.stopautopumps = func {
   # driven by switch
   for( i = 0; i < 2; i = i+1 ) {
        status = me.tanksystem.controls( "9", "pump-on", i ).getValue();
        me.tanksystem.controls( "9", "pump", i ).setValue( status );
        status = me.tanksystem.controls( "10", "pump-on", i ).getValue();
        me.tanksystem.controls( "10", "pump", i ).setValue( status );
        status = me.tanksystem.controls( "11", "pump-on", i ).getValue();
        me.tanksystem.controls( "11", "pump", i ).setValue( status );
   }
}

Fuel.forwardautopumps = func( forward, empty9 ) {
   if( forward ) {
       for( i = 0; i < 2; i = i+1 ) {
            me.tanksystem.controls( "9", "pump", i ).setValue( !empty9 );
            me.tanksystem.controls( "10", "pump", i ).setValue( empty9 );
            me.tanksystem.controls( "11", "pump", i ).setValue( constant.FALSE );
       }
   }
   else {
       for( i = 0; i < 2; i = i+1 ) {
            me.tanksystem.controls( "9", "pump", i ).setValue( constant.FALSE );
            me.tanksystem.controls( "10", "pump", i ).setValue( constant.FALSE );
            me.tanksystem.controls( "11", "pump", i ).setValue( constant.TRUE );
       }
   }
}

Fuel.hydraulicautotrim = func {
   forwardoverride = me.pumps.getChild("forward-override").getValue();

   if( !me.pumps.getChild("auto-off").getValue() or forwardoverride ) {
       tank9kg = me.tanksystem.getlevelkg("9");
       tank10kg = me.tanksystem.getlevelkg("10");
       level910kg = tank9kg + tank10kg;
       level11kg = me.tanksystem.getlevelkg("11");

       # forward or emergency override (which ignores the load limits)
       if( me.pumps.getChild("auto-forward").getValue() or forwardoverride ) {
           if( me.tanksystem.controls( "11", "pump-blue-auto" ).getValue() and
               me.tanksystem.controls( "11", "pump-green-auto" ).getValue() ) {

               # stop everything
               if( me.empty( "11" ) or
                   ( level11kg <= me.tanksystem.controls( "11", "limit-kg" ).getValue() and
                     !forwardoverride ) ) {
                   me.stophydraulicpumps();
                   me.enginehuman( constant.FALSE );
               }

               # 11 to 5 and 7, until limit of 11
               elsif( me.full( "9" ) or
                      ( level910kg >= me.tanksystem.controls( "9", "limit-kg" ).getValue() and
                        !forwardoverride ) ) {
                   if ( me.tanksystem.controls( "5", "inlet-auto" ).getValue() and
                        me.tanksystem.controls( "7", "inlet-auto" ).getValue() ) {
                        me.starthydraulicpumps();
                        me.enginehuman( constant.TRUE );
                        me.forwardhuman( constant.TRUE );
                   }
               }

               # 11 to 9 until limit of 9 + 10
               elsif ( me.tanksystem.controls( "9", "inlet-auto", 0 ).getValue() and
                       me.tanksystem.controls( "9", "inlet-auto", 1 ).getValue() ) {
                   me.starthydraulicpumps();
                   me.enginehuman( constant.FALSE );
                   me.forwardhuman( constant.TRUE );
               }

               # stop
               else {
                   me.stophydraulicpumps();
                   me.enginehuman( constant.FALSE );
               }
           }
       }
   }


   # not driven by auto
   else {
        me.stophydraulicpumps();
   }
}

Fuel.stophydraulicpumps = func {
   # driven by switch
   for( i = 0; i < 2; i = i+1 ) {
        status = me.tanksystem.controls( "11", "pump-green-on" ).getValue();
        me.tanksystem.controls( "11", "pump-green" ).setValue( status );
        status = me.tanksystem.controls( "11", "pump-blue-on" ).getValue();
        me.tanksystem.controls( "11", "pump-green" ).setValue( status );
   }
}

Fuel.starthydraulicpumps = func {
   for( i = 0; i < 2; i = i+1 ) {
        me.tanksystem.controls( "11", "pump-green" ).setValue( constant.TRUE );
        me.tanksystem.controls( "11", "pump-blue" ).setValue( constant.TRUE );
   }
}

Fuel.forwardautohuman = func( forward ) {
   if( forward ) {
       me.tanksystem.controls( "9", "limit-kg" ).setValue( me.FORWARDKG );
       me.tanksystem.controls( "11", "limit-kg" ).setValue( me.EMPTYKG );
   }
   else {
       me.tanksystem.controls( "9", "limit-kg" ).setValue( me.EMPTYKG );
       me.tanksystem.controls( "11", "limit-kg" ).setValue( me.AFTKG );
   }

   me.pumps.getChild("auto-forward").setValue( forward );
   me.pumps.getChild("auto-off").setValue( constant.FALSE );
   me.pumps.getChild("auto-guard").setValue( constant.FALSE );

   me.engineautotrim( constant.TRUE );

   for( i = 0; i < 2; i = i+1 ) {
        me.tanksystem.controls( "9", "inlet-auto", i ).setValue( forward );
        me.tanksystem.controls( "11", "inlet-auto", i ).setValue( !forward );
        me.tanksystem.controls( "9", "pump-auto", i ).setValue( !forward );
        me.tanksystem.controls( "10", "pump-auto", i ).setValue( !forward );
        me.tanksystem.controls( "11", "pump-auto", i ).setValue( forward );
   }

   me.offhydraulicautotrim();
}

Fuel.engineautotrim = func( set ) {
   # only 1 valve
   me.tanksystem.controls( "5", "inlet-auto" ).setValue( set );
   me.tanksystem.controls( "7", "inlet-auto" ).setValue( set );
}

Fuel.offautohuman = func {
   me.pumps.getChild("auto-off").setValue( constant.TRUE );
   me.pumps.getChild("auto-guard").setValue( constant.TRUE );

   me.engineautotrim( constant.FALSE );

   for( i = 0; i < 2; i = i+1 ) {
        me.tanksystem.controls( "9", "inlet-auto", i ).setValue( constant.FALSE );
        me.tanksystem.controls( "11", "inlet-auto", i ).setValue( constant.FALSE );
        me.tanksystem.controls( "9", "pump-auto", i ).setValue( constant.FALSE );
        me.tanksystem.controls( "10", "pump-auto", i ).setValue( constant.FALSE );
        me.tanksystem.controls( "11", "pump-auto", i ).setValue( constant.FALSE );
   }

   me.offhydraulicautotrim();
}

Fuel.offhydraulicautotrim = func {
   me.tanksystem.controls( "11", "pump-blue-auto" ).setValue( constant.FALSE );
   me.tanksystem.controls( "11", "pump-green-auto" ).setValue( constant.FALSE );
}

Fuel.shutstandbyhuman = func {
   me.tanksystem.controls( "1", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "2", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "3", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "4", "inlet-standby" ).setValue( constant.FALSE );

   me.tanksystem.controls( "5", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "6", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "7", "inlet-standby" ).setValue( constant.FALSE );
   me.tanksystem.controls( "8", "inlet-standby" ).setValue( constant.FALSE );

   me.tanksystem.controls( "10", "inlet-standby" ).setValue( constant.FALSE );
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

# set manually the switch
Fuel.pumphuman = func( tank, set ) {
   # for trim tank, auto may also drive the pump
   if( tank == "9" or tank == "10" or tank == "11" ) {
       for( i=0; i < 2; i=i+1 ) {
             me.tanksystem.controls(tank, "pump-on", i).setValue( set );
       }
   }

   else {
       for( i=0; i < 2; i=i+1 ) {
             me.tanksystem.controls(tank, "pump", i).setValue( set );
       }
   }
}

Fuel.transvalvehuman = func( tank, set ) {
   me.tanksystem.controls(tank, "trans-valve").setValue( set );
}

Fuel.toggleinterconnectvalve = func( tank, set ) {
   me.tanksystem.controls(tank, "interconnect-valve").setValue( set );
}

Fuel.togglecrossfeedvalve = func( tank, set ) {
   me.tanksystem.controls(tank, "cross-feed-valve").setValue( set );
}

Fuel.afttrimhuman = func( set ) {
   me.tanksystem.controls("1", "aft-trim").setValue( set );
   me.tanksystem.controls("4", "aft-trim").setValue( set );
}

Fuel.valveforward = func( set, toengine ) {
   me.pumps.getChild("forward").setValue( set );
   if( !toengine ) {
       for( i = 0; i < 2; i = i+1 ) {
            me.toggleinletvalve( "9", i, set );
       }
   }
}

Fuel.valveaft = func( set, toengine ) {
   me.pumps.getChild("aft").setValue( set);
   if( !toengine ) {
       for( i = 0; i < 2; i = i+1 ) {
            me.toggleinletvalve( "11", i, set );
       }
   }
}

Fuel.togglecross = func( set ) {
   me.pumps.getChild("cross").setValue( set );

   me.toggleinterconnectvalve( "6", set );
   me.toggleinterconnectvalve( "8", set );

   me.togglecrossfeedvalve( "1", set );
   me.togglecrossfeedvalve( "2", set );
   me.togglecrossfeedvalve( "3", set );
   me.togglecrossfeedvalve( "4", set );
}

Fuel.forwardhuman = func( set ) {
   toengine = me.pumps.getChild("engine").getValue();

   me.valveforward( set, toengine );
   me.valveaft( constant.FALSE, toengine );
}

Fuel.afthuman = func( set ) {
   toengine = me.pumps.getChild("engine").getValue();

   me.valveaft( set, toengine );
   me.valveforward( constant.FALSE, toengine );
}

Fuel.enginehuman = func( set ) {
   me.pumps.getChild("engine").setValue( set );

   # only 1 valve
   me.toggleinletvalve( "5", 0, set );
   me.toggleinletvalve( "7", 0, set );

   me.aft2Dhuman( constant.FALSE );

   me.valveaft( constant.FALSE, constant.FALSE );
   me.valveforward( constant.FALSE, constant.FALSE );
}

Fuel.aft2Dhuman = func( set ) {
   me.pumps.getChild("aft-2D").setValue( set );
}

Fuel.toggleinletvalve = func( tank, valve, state ) {
   # - with main selector only
   # - auto is unchanged
   me.tanksystem.controls(tank, "inlet-off", valve).setValue( constant.TRUE );
   me.tanksystem.controls(tank, "inlet-main", valve).setValue( state );
   me.computeinletvalve(tank, valve);
}

# computes the inlet valve from the main and override switches
Fuel.computeinletvalve = func( tank, valve ) {
   if( me.tanksystem.controls( tank, "inlet-off", valve ).getValue() ) {
       # gets the switch as set either by :
       # - engineer.
       # - or 2D panel.
       # - or auto trim.
       state = me.tanksystem.controls( tank, "inlet-main", valve ).getValue();

       if( !me.tanksystem.controls( tank, "inlet-auto", valve ).getValue() ) {
           me.tanksystem.controls( tank, "inlet-valve", valve ).setValue( state );
       }

       # auto trim opens and closes itself the valve
       elsif( !me.pumps.getChild("auto-off").getValue() ) {
           me.tanksystem.controls( tank, "inlet-valve", valve ).setValue( state );
       }
   }
   else {
       state = me.tanksystem.controls( tank, "inlet-override", valve ).getValue();
       me.tanksystem.controls( tank, "inlet-valve", valve ).setValue( state );
   }

   # also sets to false, when engineer toggles a switch (valve transit)
   voltage = me.slave["electric"].getChild("specific").getValue();
   me.tanksystem.controls( tank, "inlet-static", valve ).setValue( voltage );
}

Fuel.crossexport = func {
   set = me.pumps.getChild("cross").getValue();
   me.togglecross( !set );
}

Fuel.forwardexport = func {
   set = me.pumps.getChild("forward").getValue();

   me.shutstandbyhuman();
   me.offautohuman();

   me.pumphuman( "9", constant.FALSE );
   me.pumphuman( "10", constant.FALSE );
   me.pumphuman( "11", !set );

   me.aft2Dhuman( constant.FALSE );

   me.forwardhuman( !set );
}

Fuel.aftexport = func {
   set = me.pumps.getChild("aft").getValue();

   me.shutstandbyhuman();
   me.offautohuman();

   empty9 = me.empty("9");

   me.pumphuman( "9", !empty9 );
   me.pumphuman( "10", empty9 );
   me.pumphuman( "11", constant.FALSE );

   # will switch to tank 10
   me.aft2Dhuman( !set );

   me.afthuman( !set );
}

Fuel.engineexport = func {
   set = me.pumps.getChild("engine").getValue();

   me.enginehuman( !set );
}

Fuel.hydraulicforward = func {
   # towards tank 9, from rear tank 11
   if( me.slave["hydraulic"].getChild("green").getValue() ) {
       if( me.tanksystem.controls("11", "pump-green").getValue() and
           me.tanksystem.controls("9", "inlet-valve", 0).getValue() ) {
           me.tanksystem.transfertanks( "9", "11", me.PUMPLB );
       }
   }
   if( me.slave["hydraulic"].getChild("blue").getValue() ) {
       if( me.tanksystem.controls("11", "pump-blue").getValue() and
           me.tanksystem.controls("9", "inlet-valve", 1).getValue() ) {
           me.tanksystem.transfertanks( "9", "11", me.PUMPLB );
       }
   }


   # standby inlet valves left
   if( me.tanksystem.controls("11", "pump-green").getValue() and
       me.slave["hydraulic"].getChild("green").getValue() ) {
       if( me.tanksystem.controls("1", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "1", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("2", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "2", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("5", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "5", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("6", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "6", "11", me.PUMPLB );
       }
   }


   # standby inlet valves blue
   if( me.tanksystem.controls("11", "pump-blue").getValue() and
       me.slave["hydraulic"].getChild("blue").getValue() ) {
       if( me.tanksystem.controls("3", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "3", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("4", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "4", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("7", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "7", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("8", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "8", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("10", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "10", "11", me.PUMPLB );
       }
   }
}

Fuel.pumpforward = func {
   # towards tank 9
   if( !me.full("9") ) {
       # from rear tank 11
       if( !me.empty("11") ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("11", "pump", i).getValue() and
                    me.tanksystem.controls("9", "inlet-valve", i).getValue() ) {
                    me.tanksystem.transfertanks( "9", "11", me.PUMPLB );
                }
           }
       }
   }


   # standby inlet valves left
   if( me.tanksystem.controls("11", "pump", 0).getValue() ) {
       if( me.tanksystem.controls("1", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "1", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("2", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "2", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("5", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "5", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("6", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "6", "11", me.PUMPLB );
       }
   }


   # standby inlet valves right
   if( me.tanksystem.controls("11", "pump", 1).getValue() ) {
       if( me.tanksystem.controls("3", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "3", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("4", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "4", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("7", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "7", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("8", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "8", "11", me.PUMPLB );
       }

       if( me.tanksystem.controls("10", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "10", "11", me.PUMPLB );
       }
   }
}

Fuel.pumpaft = func {
   # towards tank 11
   if( !me.full("11") ) {
       # from tank 9
       if( !me.empty("9") ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("9", "pump", i).getValue() and
                    me.tanksystem.controls("11", "inlet-valve", i).getValue() ) {
                    me.tanksystem.transfertanks( "11", "9", me.PUMPLB );
                }
           }
       }

       # for 2D panel, switch from tank 9 to tank 10
       elsif( me.pumps.getChild("aft-2D").getValue() ) {
           me.pumphuman( "9", constant.FALSE );
           me.pumphuman( "10", constant.TRUE );
       }

       # from tank 10
       if( !me.empty("10") ) {
           for( i=0; i < 2; i=i+1 ) {
                if( me.tanksystem.controls("10", "pump", i).getValue() and
                    me.tanksystem.controls("11", "inlet-valve", i).getValue() ) {
                    me.tanksystem.transfertanks( "11", "10", me.PUMPLB );
                }
           }
       }
   }


   # standby inlet valves left
   if( me.tanksystem.controls("9", "pump", 0).getValue() ) {
       if( me.tanksystem.controls("1", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "1", "9", me.PUMPLB );
       }

       if( me.tanksystem.controls("2", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "2", "9", me.PUMPLB );
       }

       if( me.tanksystem.controls("5", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "5", "9", me.PUMPLB );
       }

       if( me.tanksystem.controls("6", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "6", "9", me.PUMPLB );
       }
   }

   if( me.tanksystem.controls("10", "pump", 0).getValue() ) {
       if( me.tanksystem.controls("1", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "1", "10", me.PUMPLB );
       }

       if( me.tanksystem.controls("2", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "2", "10", me.PUMPLB );
       }

       if( me.tanksystem.controls("5", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "5", "10", me.PUMPLB );
       }

       if( me.tanksystem.controls("6", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "6", "10", me.PUMPLB );
       }
   }


   # standby inlet valves right (should never happen)
   if( me.tanksystem.controls("9", "pump", 1).getValue() ) {
       if( me.tanksystem.controls("3", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "3", "9", me.PUMPLB );
       }

       if( me.tanksystem.controls("4", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "4", "9", me.PUMPLB );
       }

       if( me.tanksystem.controls("7", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "7", "9", me.PUMPLB );
       }

       if( me.tanksystem.controls("8", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "8", "9", me.PUMPLB );
       }

       if( me.tanksystem.controls("10", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "10", "9", me.PUMPLB );
       }
   }

   if( me.tanksystem.controls("10", "pump", 1).getValue() ) {
       if( me.tanksystem.controls("3", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "3", "10", me.PUMPLB );
       }

       if( me.tanksystem.controls("4", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "4", "10", me.PUMPLB );
       }

       if( me.tanksystem.controls("7", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "7", "10", me.PUMPLB );
       }

       if( me.tanksystem.controls("8", "inlet-standby").getValue() ) {
           me.tanksystem.transfertanks( "8", "10", me.PUMPLB );
       }

       # from tank 10, do nothing !
   }
}

# feed a left engine supply tank, with left main tanks
Fuel.pumpleftmain = func( tank ) {
   # tank 1 by left pump
   if( tank == "1" ) {
       tank5 = me.tanksystem.controls("5", "pump", 0).getValue();
       tank6 = me.tanksystem.controls("6", "pump", 0).getValue();
       tank5a = me.tanksystem.controls("5A", "pump", 0).getValue();

       if( me.tanksystem.controls("1", "aft-trim").getValue() ) {
           tank1lb = me.tanksystem.getlevellb("1");
           if( tank1lb > me.tanksystem.getafttrimlb("1") ) {
               tank5 = constant.FALSE; 
               tank6 = constant.FALSE; 
           }
       }
   }

   # tank 2 by right pump
   else {
       tank5 = me.tanksystem.controls("5", "pump", 1).getValue();
       tank6 = me.tanksystem.controls("6", "pump", 1).getValue();
       tank5a = me.tanksystem.controls("5A", "pump", 1).getValue();
   }

   # balance the load on tanks 5, 6, and 5A
   # serve the forwards tanks at first, to shift the center of gravity aft
   if( tank5 ) {
       me.tanksystem.transfertanks( tank, "5", me.PUMPLB );
   }
   # engineer shuts the pump 6, to optimize the shift of center of gravity
   # (done automatically by autotrim)
   if( tank6 ) {
       me.tanksystem.transfertanks( tank, "6", me.PUMPLB );
   }

   # engineer transfers tank 5A to tank 5
   if( tank5a ) {
       if( me.tanksystem.controls("5A", "trans-valve").getValue() ) {
           me.tanksystem.transfertanks( "5", "5A", me.PUMPLB );
       }
   }
}

# feed a right engine supply tank, with right main tanks
Fuel.pumprightmain = func( tank ) {
   # tank 3 by left pump
   if( tank == "3" ) {
       tank7 = me.tanksystem.controls("7", "pump", 0).getValue();
       tank8 = me.tanksystem.controls("8", "pump", 0).getValue();
       tank7a = me.tanksystem.controls("7A", "pump", 0).getValue();
   }

   # tank 4 by right pump
   else {
       tank7 = me.tanksystem.controls("7", "pump", 1).getValue();
       tank8 = me.tanksystem.controls("8", "pump", 1).getValue();
       tank7a = me.tanksystem.controls("7A", "pump", 1).getValue();

       if( me.tanksystem.controls("4", "aft-trim").getValue() ) {
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
       me.tanksystem.transfertanks( tank, "7", me.PUMPLB );
   }

   # engineer shuts the pump 8, to optimize the shift of center of gravity
   # (done automatically by autotrim)
   if( tank8 ) {
       me.tanksystem.transfertanks( tank, "8", me.PUMPLB );
   }

   # engineer transfers tank 7A to tank 7
   if( tank7a ) {
       if( me.tanksystem.controls("7A", "trans-valve").getValue() ) {
           me.tanksystem.transfertanks( "7", "7A", me.PUMPLB );
       }
   }
}

# feed engine supply tank, with trim tanks
Fuel.pumptrim = func( tank ) {
   # front tanks 9 and 10 (center of gravity goes rear)
   if( !me.empty("9") ) {
       for( i=0; i < 2; i=i+1 ) {
            if( me.tanksystem.controls("9", "pump", i).getValue() and
                me.tanksystem.controls(tank, "inlet-valve").getValue() ) {
                me.tanksystem.transfertanks( tank, "9", me.PUMPLB );
            }
       }
   }

   # front tank 10 at last
   if( !me.empty("10") ) {
       for( i=0; i < 2; i=i+1 ) {
            if( me.tanksystem.controls("10", "pump", i).getValue() and
                me.tanksystem.controls(tank, "inlet-valve").getValue() ) {
                me.tanksystem.transfertanks( tank, "10", me.PUMPLB );
            }
       }
   }

   # rear tanks 11 (center of gravity goes forwards)
   if( !me.empty("11") ) {
       for( i=0; i < 2; i=i+1 ) {
            if( me.tanksystem.controls("11", "pump", i).getValue() and
                me.tanksystem.controls(tank, "inlet-valve").getValue() ) {
                me.tanksystem.transfertanks( tank, "11", me.PUMPLB );
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
        if( me.tanksystem.controls("9", "pump", j).getValue() ) {
            me.tanksystem.dumptank( "9", me.PUMPLB );
        }
        if( me.tanksystem.controls("10", "pump", j).getValue() ) {
            me.tanksystem.dumptank( "10", me.PUMPLB );
        }
        if( me.tanksystem.controls("11", "pump", j).getValue() ) {
            me.tanksystem.dumptank( "11", me.PUMPLB );
        }
   }

   # collector tanks 1, and 3 (not the left pump reserved for engine)
   for( j=1; j < 3; j=j+1 ) {
        if( me.tanksystem.controls("1", "pump", j).getValue() ) {
            me.tanksystem.dumptank( "1", me.PUMPLB );
        }
        if( me.tanksystem.controls("3", "pump", j).getValue() ) {
            me.tanksystem.dumptank( "3", me.PUMPLB );
        }
   }

   # collector tanks 2 and 4 (not the right pump reserved for engine)
   for( j=0; j < 2; j=j+1 ) {
        if( me.tanksystem.controls("2", "pump", j).getValue() ) {
            me.tanksystem.dumptank( "2", me.PUMPLB );
        }
        if( me.tanksystem.controls("4", "pump", j).getValue() ) {
            me.tanksystem.dumptank( "4", me.PUMPLB );
        }
   }
}

# balance all tanks (no pump)
Fuel.connecttanks = func {
   # interconnect (by gravity)
   # tanks 5 and 7
   if( me.tanksystem.controls( "5", "interconnect-valve" ).getValue() ) {
       me.tanksystem.pumpcross( "5", "8", me.PUMPLB );
   }

   # tanks 6 and 8
   if( me.tanksystem.controls( "6", "interconnect-valve" ).getValue() ) {
       me.tanksystem.pumpcross( "6", "7", me.PUMPLB );
   }
}

# feed collector tanks :
Fuel.pumpmain = func {
   me.pumpleftmain( "1" );
   me.pumpleftmain( "2" );

   me.pumprightmain( "3" );
   me.pumprightmain( "4" );
}

Fuel.crossfeed = func( dest, sour ) {
   if( me.tanksystem.controls(sour, "cross-feed-valve").getValue() ) {
       for( i = 1; i <= 4; i = i+1 ) {
            tank = "" ~ i ~ "";

            if( dest != tank ) {
                if( me.tanksystem.controls(tank, "cross-feed-valve").getValue() ) {
                    me.feedengine( dest, tank );
 
                    if( me.tanksystem.full( dest ) ) {
                        break;
                    }
                }
            }
       }
   }
}

Fuel.feedengine = func( dest, sour ) {
   full = constant.FALSE;

   for( i = 0; i <= 2; i = i+1 ) {
        # 1 pump over 3 is enough
        if( me.tanksystem.controls(sour, "pump", i).getValue() ) {
            me.tanksystem.filltank( dest, sour );

            if( me.tanksystem.full( dest ) ) {
                full = constant.TRUE;
                break;
            }
        }
   }

   return full;
}

Fuel.hpvalve = func( dest, sour ) {
   # HP valve shut stops the engine
   if( me.tanksystem.controls(sour, "lp-valve").getValue() ) {
       if( !me.feedengine( dest, sour ) ) {

           # engine cross feed
           me.crossfeed( dest, sour );
       }
   }
}

Fuel.fuelpiping = func {
   me.hpvalve( "LP1", "1" );
   me.hpvalve( "LP2", "2" );
   me.hpvalve( "LP3", "3" );
   me.hpvalve( "LP4", "4" );
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
                         "8" : 0.0, "9" : 0.0, "10" : 0.0, "11" : 0.0, "5A" : 0.0, "7A" : 0.0,
                         "LP1" : 0.0, "LP2" : 0.0, "LP3" : 0.0, "LP4" : 0.0 },
           TANKINDEX : { "1" : 0, "2" : 1, "3" : 2, "4" : 3, "5" : 4, "6" : 5, "7" : 6,
                         "8" : 7, "9" : 8, "10" : 9, "11" : 10, "5A" : 11, "7A" : 12,
                         "LP1" : 13, "LP2" : 14, "LP3" : 15, "LP4" : 16 },
           TANKNAME : [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "5A", "7A",
                        "LP1", "LP2", "LP3", "LP4" ],

           nb_tanks : 0,

           OVERFULL : 0.97,
           OVERFULL : 0.97,
           UNDERFULL : 0.8,
           LOWLEVELLB : [ 0.0, 0.0, 0.0, 0.0 ],
           LOWLEVEL : 0.2,

           AFTTRIMLB : { "1" : 0.0, "4" : 0.0 },
           AFTTRIM : 0.4,                                                # aft trim at 40 %

           HPVALVELB : 30.0,                                             # fuel low pressure

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
    me.fillings = props.globals.getNode("/systems/fuel/tanks").getChildren("filling");
    me.pumps = props.globals.getNode("/controls/fuel/pumps");

    me.nb_tanks = size(me.tanks);

    me.initcontent();
}

Tanks.amber_fuel = func {
   result = constant.FALSE;

   for( i = 0; i < 4; i = i+1 ) {
        if( me.tanks[i].getChild("level-lb").getValue() <= me.LOWLEVELLB[i] ) {
            result = constant.TRUE;
            break;
        }
   }

   if( !result ) {
       # LP valve
       for( i = 13; i <= 16; i = i+1 ) {
            if( me.tanks[i].getChild("level-lb").getValue() <= me.HPVALVELB ) {
                result = constant.TRUE;
                break;
            }
       }
   }

   return result;
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
   change = constant.FALSE;
   last = getprop("/sim/presets/fuel");

   comment = getprop("/systems/fuel/tanks/dialog");

   for( i=0; i < size(me.fillings); i=i+1 ) {
        if( me.fillings[i].getChild("comment").getValue() == comment ) {
            me.load( i );

            # for aircraft-data
            setprop("/sim/presets/fuel",i);
            if( i != last ) {
                change = constant.TRUE;
            }

            break;
        }
   }

   return change;
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

   # to detect change
   setprop("/sim/presets/fuel",fuel);

   # copy to dialog
   dialog = getprop("/systems/fuel/tanks/dialog");
   if( dialog == "" or dialog == nil ) {
       value = me.fillings[fuel].getChild("comment").getValue();
       setprop("/systems/fuel/tanks/dialog", value);
   }

   me.load( fuel );
}

Tanks.load = func( fuel ) {
   presets = me.fillings[fuel].getChildren("tank");
   for( i=0; i < size(presets); i=i+1 ) {
        child = presets[i].getChild("level-gal_us");
        if( child != nil ) {
            levelgalus = child.getValue();
        }

        # new load through dialog
        else {
            levelgalus = me.CONTENTLB[me.TANKNAME[i]] * constant.LBTOGALUS;
        } 

        me.pumpsystem.setlevel(i, levelgalus);
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
            i == me.TANKINDEX["5"] or i == me.TANKINDEX["7"] or
            i == me.TANKINDEX["9"] or i == me.TANKINDEX["11"] ) {
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

Tanks.controls = func( name, switch, index = 0 ) {
   return me.tankcontrols[me.TANKINDEX[name]].getChild( switch, index );
}

Tanks.getafttrimlb = func( name ) {
   return me.AFTTRIMLB[name];
}

Tanks.getlevellb = func( name ) {
   return me.pumpsystem.getlevellb( me.TANKINDEX[name] );
}

Tanks.getlevelkg = func( name ) {
   return me.pumpsystem.getlevelkg( me.TANKINDEX[name] );
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

# fills completely a tank
Tanks.filltank = func( dest, sour ) {
   pumplb = me.CONTENTLB[dest] - me.getlevellb( dest );
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

Pump.getlevelkg = func( index ) {
   tankkg = me.getlevel(index) * constant.GALUSTOKG;

   return tankkg;
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

Pressurizetank = {};

Pressurizetank.new = func {
   obj = { parents : [Pressurizetank,System],

           diffpressure : TankPressure.new(),

           TANKSEC : 30.0,                          # refresh rate
           PRESSURIZEINHG : 9.73,                   # 28000 ft
           MAXPSI : 1.5,
           MINPSI : 0.0,

           staticport : ""
         };

   obj.init();

   return obj;
};

Pressurizetank.init = func {
    me.staticport = getprop("/systems/tank/static-port");
    me.staticport = me.staticport ~ "/pressure-inhg";

    me.init_ancestor("/systems/tank");

    me.diffpressure.set_rate( me.TANKSEC );
}

Pressurizetank.amber_fuel = func {
    return me.diffpressure.amber_fuel();
}

# tank pressurization
Pressurizetank.schedule = func {
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

           instrument : nil,

           TANKSEC : 30.0,                         # refresh rate

           HIGHPSI : 4.0,
           RAISINGPSI : 1.5,
           FALLINGPSI : -0.8,
           LOWPSI : -1.75,

           staticport : ""                         # energy provided by differential pressure
         };

   obj.init();

   return obj;
};

TankPressure.init = func {
    me.instrument = props.globals.getNode("/instrumentation/tank-pressure");

    me.staticport = getprop("/instrumentation/tank-pressure/static-port");
    me.staticport = me.staticport ~ "/pressure-inhg";
}

TankPressure.set_rate = func( rates ) {
    me.TANKSEC = rates;
}

TankPressure.amber_fuel = func {
    diffpsi = me.instrument.getChild("differential-psi").getValue();
    falling = me.instrument.getChild("falling").getValue();
    raising = me.instrument.getChild("raising").getValue();

    if( diffpsi < me.LOWPSI or diffpsi > me.HIGHPSI or
        ( diffpsi < me.FALLINGPSI and falling ) or
        ( diffpsi > me.RAISINGPSI and raising ) ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
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

    me.instrument.getChild("raising").setValue(raising);
    me.instrument.getChild("falling").setValue(falling);

    interpolate("/instrumentation/tank-pressure/differential-psi",diffpsi,me.TANKSEC);
}


# ==========
# TOTAL FUEL
# ==========
TotalFuel = {};

TotalFuel.new = func {
   obj = { parents : [TotalFuel],

           STEPSEC : 1.0,                     # 3 s would be enough, but needs 1 s for kg/h

           fuel : nil,
           tanks : nil,

           nb_tanks : 0
         };

   obj.init();

   return obj;
};

TotalFuel.init = func {
   me.fuel = props.globals.getNode("/instrumentation/fuel");
   me.tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");

   me.nb_tanks = size(me.tanks);
}

# total of fuel in kg
TotalFuel.schedule = func {
   speedup = getprop("/sim/speed-up");

   # last total
   tanksgalus = me.fuel.getChild("total-gal_us").getValue();
   tankskg = tanksgalus * constant.GALUSTOKG;


   fuelgalus = 0;
   for(i=0; i<me.nb_tanks; i=i+1) {
       fuelgalus = fuelgalus + me.tanks[i].getChild("level-gal_us").getValue();
   }
   # not real
   me.fuel.getChild("total-gal_us").setValue(fuelgalus);


   # real
   fuelkg = fuelgalus * constant.GALUSTOKG;
   me.fuel.getChild("total-kg").setValue(fuelkg);


   # ==========================================================
   # - MUST BE CONSTANT with speed up : pumping is accelerated.
   # - not real, used to check errors in pumping.
   # ==========================================================
   stepkg = tankskg - fuelkg;
   fuelkgpmin = stepkg * constant.MINUTETOSECOND / ( me.STEPSEC * speedup );
   fuelkgph = fuelkgpmin * constant.HOURTOMINUTE;

   # not real
   me.fuel.getChild("fuel-flow-kg_ph").setValue(fuelkgph);
}


# =============
# FUEL CONSUMED
# =============
FuelConsumed = {};

FuelConsumed.new = func {
   obj = { parents : [FuelConsumed,System],

           STEPSEC : 3.0,

           fuel : nil,

           RESETKG : 0
         };

   obj.init();

   return obj;
};

FuelConsumed.init = func {
   me.fuel = props.globals.getNode("/instrumentation").getChildren("fuel-consumed");

   me.init_ancestor("/instrumentation/fuel-consumed");
}

FuelConsumed.schedule = func {
   speedup = getprop("/sim/speed-up");

   for( i = 0; i <= 3; i = i+1 ) {
        totalkg = me.fuel[i].getChild("total-kg").getValue();

        # flow meter inside engine
        flowlbph = me.slave["engine"][i].getChild("fuel-flow_pph").getValue();
        flowkgps = flowlbph * constant.LBTOKG / constant.HOURTOSECOND;
        stepkg = flowkgps * me.STEPSEC * speedup;

        totalkg = totalkg + stepkg;
        me.fuel[i].getChild("total-kg").setValue( totalkg );
   }
}

FuelConsumed.reset = func {
   for( i = 0; i <= 3; i = i+1 ) {
        me.fuel[i].getChild("total-kg").setValue( me.RESETKG );
        me.fuel[i].getChild("reset").setValue( constant.FALSE );
   }
}


# ===============
# AIRCRAFT WEIGHT
# ===============
AircraftWeight = {};

AircraftWeight.new = func {
   obj = { parents : [AircraftWeight,System],

           acweight : nil,

           clear : constant.TRUE,

           weightdatumlb : 0.0,

           NOFUELKG : -9999,

           fueldatumkg : 0.0
         };

   obj.init();

   return obj;
};

AircraftWeight.init = func {
   me.acweight = props.globals.getNode("/instrumentation/ac-weight");

   me.init_ancestor("/instrumentation/ac-weight");
}

AircraftWeight.schedule = func {
   # set manually by engineer
   me.fueldatumkg = me.acweight.getChild("fuel-datum-kg").getValue();
   me.weightdatumlb = me.acweight.getChild("weight-datum-lb").getValue();

   # substract fuel flow consumed from the manually set datum,
   # to cross check with fuel gauge reading (leaks)
   consumedkg = 0;
   for( i = 0; i <= 3; i = i+1 ) {
        consumedkg = consumedkg + me.slave["fuel-consumed"][i].getChild("total-kg").getValue();
   }

   fuelkg = me.fueldatumkg - consumedkg;
   me.acweight.getChild("fuel-remaining-kg").setValue( fuelkg );

   # add the remaining fuel to the manually set datum
   me.setweightdatum();
   if( !me.clear ) {
       weightlb = me.weightdatumlb + ( fuelkg * constant.KGTOLB );
       me.acweight.getChild("weight-lb").setValue( weightlb );
   }
}

AircraftWeight.setdatum = func( fuelkg ) {
   me.fueldatumkg = fuelkg;
   me.acweight.getChild("fuel-datum-kg").setValue( me.fueldatumkg );

   # compute weight datum at the next iteration, once FDM is refreshed with the fuel
   me.clear = constant.TRUE;

   # feedback for display
   me.acweight.getChild("fuel-remaining-kg").setValue( me.NOFUELKG );
}

# TODO : replace by manual input (engineer)
AircraftWeight.setweightdatum = func {
   if( me.clear ) {
       me.weightdatumlb = me.acweight.getChild("weight-real-lb").getValue();
       
       # substract fuel datum
       if( me.weightdatumlb != nil ) {
           if( me.weightdatumlb > 0.0 ) {
               me.weightdatumlb = me.weightdatumlb - ( me.fueldatumkg * constant.KGTOLB );
               me.acweight.getChild("weight-datum-lb").setValue( me.weightdatumlb );
               me.clear = constant.FALSE;
           }
       }
   }
}
