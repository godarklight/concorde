# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ================
# HYDRAULIC SYSTEM
# ================

Hydraulic = {};

Hydraulic.new = func {
   obj = { parents : [Hydraulic], 

           engines : HydEngines.new(),
           ground : HydGround.new(),
           rat : Rat.new(),
           brakes : Brakes.new(),

           HYDNORMALPSI : 4000.0,                         # normal hydraulic
           HYDNOPSI : 0.0,
           HYDSEC : 1.0,                                  # refresh rate
           circuits : nil,
           reservoirgalus : 0.0
         };

    obj.init();

    return obj;
}

Hydraulic.init = func() {
    me.circuits = props.globals.getNode("/systems/hydraulic/circuits/").getChildren("circuit");

    me.brakes.set_rate( me.HYDSEC );
}

Hydraulic.set_rate = func( rates ) {
    me.HYDSEC = rates;
    me.brakes.set_rate( me.HYDSEC );
}

Hydraulic.set_relation = func( electrical ) {
   me.ground.set_relation( electrical );
}

Hydraulic.reservoir = func( index, pressurepsi ) {
    me.reservoirgalus = me.circuits[index].getChild("content-gal_us").getValue();
    if( pressurepsi >= me.HYDNORMALPSI ) {
        pressurepsi = me.HYDNORMALPSI;

        # at full load, reservoir decreases
        me.reservoirgalus = me.reservoirgalus * 0.8;
    }

    return pressurepsi;
}

Hydraulic.applypressure = func( index, pressurepsi ) {
   result = me.circuits[index].getChild("pressure-psi").getValue();
   if( result != pressurepsi ) {
       interpolate("/systems/hydraulic/circuits/circuit[" ~ index ~ "]/pressure-psi",pressurepsi,me.HYDSEC);
   }
   result = me.circuits[index].getChild("reservoir-gal_us").getValue();
   if( result != me.reservoirgalus ) {
       interpolate("/systems/hydraulic/circuits/circuit[" ~ index ~ "]/reservoir-gal_us",me.reservoirgalus,me.HYDSEC);
   }
}

Hydraulic.failure = func {
    for( i=0; i <= 2; i=i+1 ) {
         me.circuits[i].getChild("pressure-psi").setValue(me.HYDNOPSI);
    }

    me.brakes.failure();
}

# hydraulic system
Hydraulic.schedule = func {
   if( getprop("/systems/hydraulic/serviceable") ) { 

       # ground power
       me.ground.supply();

       # RAT
       me.rat.supply();

       # engine provides hydraulical pressure
       me.engines.oil();


       # =============================
       # green : engines 1 & 2 and RAT
       # =============================
       pressurepsi = me.engines.apply( 0, 0, 1 );
       pressurepsi = me.rat.green( pressurepsi );
       pressurepsi = me.ground.green( pressurepsi );
       pressurepsi = me.reservoir( 0, pressurepsi );
       me.brakes.normal( pressurepsi );
       me.applypressure( 0, pressurepsi );


       # ==============================
       # yellow : engines 2 & 4 and RAT
       # ==============================
       pressurepsi = me.engines.apply( 1, 1, 3 );
       pressurepsi = me.rat.yellow( pressurepsi );
       pressurepsi = me.ground.yellow( pressurepsi );
       pressurepsi = me.reservoir( 1, pressurepsi );
       me.brakes.emergency( pressurepsi );
       me.applypressure( 1, pressurepsi );


       # ====================
       # blue : engines 3 & 4
       # ====================
       pressurepsi = me.engines.apply( 2, 2, 3 );
       pressurepsi = me.ground.blue( pressurepsi );
       pressurepsi = me.reservoir( 2, pressurepsi );
       me.applypressure( 2, pressurepsi );
   }


   # failure
   else {
       me.failure();
   }


   # ======
   # brakes
   # ======
   me.brakes.schedule();
}


# =============
# GROUND SUPPLY
# =============
HydGround = {};

HydGround.new = func {
   obj = { parents : [HydGround], 

           electricalsystem : nil,

           HYDELECTRICALPSI : 3500.0,                     # electrical pump hydraulic
           hydpumps : nil,
           groundvolts : constant.FALSE,                  # electrical ground power
           hydcheckout : 0                                # selector
         };

    obj.init();

    return obj;
}

HydGround.init = func() {
    me.hydpumps = props.globals.getNode("/controls/hydraulic/ground/").getChildren("pump");
}

HydGround.set_relation = func( electrical ) {
   me.electricalsystem = electrical;
}

HydGround.supply = func {
   me.groundvolts = me.electricalsystem.has_ground_power();
   if( me.groundvolts ) {
       me.hydcheckout = getprop("/controls/hydraulic/ground/selector");
   }

   # magnetic release of the switch
   else {
       if( me.hydpumps[0].getChild("switch").getValue() ) {
           me.hydpumps[0].getChild("switch").setValue(constant.FALSE);
       }
       if( me.hydpumps[1].getChild("switch").getValue() ) {
           me.hydpumps[1].getChild("switch").setValue(constant.FALSE);
       }
   }
}

HydGround.apply = func( index, pressurepsi ) {
   if( me.hydpumps[index].getChild("switch").getValue() ) {
       pressurepsi = pressurepsi + me.HYDELECTRICALPSI;
   }

   return pressurepsi;
}


HydGround.green = func ( pressurepsi ) {
   if( me.groundvolts ) {
       # green-blue or green-yellow
       if( me.hydcheckout == 1 or me.hydcheckout == 4 ) {
           pressurepsi = me.apply( 0, pressurepsi );
       }
   }

   return pressurepsi;
}

HydGround.yellow = func ( pressurepsi ) {
   if( me.groundvolts ) {
       # yellow-yellow
       if( me.hydcheckout == 0 or me.hydcheckout == 3 or me.hydcheckout == 5 ) {
           pressurepsi = me.apply( 0, pressurepsi );
       }
       # yellow-yellow, blue-yellow or green-yellow
       if( me.hydcheckout == 0 or me.hydcheckout == 2 or me.hydcheckout == 3 or me.hydcheckout == 4 or me.hydcheckout == 5 ) {
           pressurepsi = me.apply( 1, pressurepsi );
       }
   }

   return pressurepsi;
}

HydGround.blue = func ( pressurepsi ) {
   # green-blue or blue-yellow
   if( me.groundvolts ) {
       if( me.hydcheckout == 1 ) {
           pressurepsi = me.apply( 1, pressurepsi );
       }
       if( me.hydcheckout == 2 ) {
           pressurepsi = me.apply( 0, pressurepsi );
       }
   }

   return pressurepsi;
}


# =======
# ENGINES
# =======
HydEngines = {};

HydEngines.new = func {
   obj = { parents : [HydEngines], 
           HYDENGINEPSI : 34.0,                           # engine oil pressure to get hydraulic pressure
           HYDFAILUREPSI : 3400.0,                        # abnormal hydraulic
           HYDNOPSI : 0.0,
           HYDCOEF : 0.0,
           engines : nil,
           oilpsi : [ 0.0,0.0,0.0,0.0 ],
           hydcontrols : nil
         };

    obj.init();

    return obj;
}

HydEngines.init = func() {
    me.engines = props.globals.getNode("/engines/").getChildren("engine");

    # not named controls, otherwise lost controls.setFlaps() !!
    me.hydcontrols = props.globals.getNode("/controls/hydraulic/circuits/").getChildren("circuit");

    me.HYDCOEF = me.HYDFAILUREPSI / me.HYDENGINEPSI;
}

# engine provides hydraulical pressure
HydEngines.oil = func {
    for( i=0; i < 4; i=i+1 ) {
         me.oilpsi[i] = me.HYDNOPSI;
         if( me.engines[i].getChild("running").getValue() or
             me.engines[i].getChild("starter").getValue() ) {
             me.oilpsi[i] = me.engines[i].getChild("oil-pressure-psi").getValue();
             if( me.oilpsi[i] == nil ) {
                 me.oilpsi[i] = me.HYDNOPSI;
             }
         }
    }
}

HydEngines.apply = func( index, engine1, engine2 ) {
   pressurepsi = me.HYDNOPSI;
   if( me.hydcontrols[index].getChild("onloada").getValue() ) {
       pressurepsi = pressurepsi + me.HYDCOEF * me.oilpsi[engine1];
   }
   if( me.hydcontrols[index].getChild("onloadb").getValue() ) {
       pressurepsi = pressurepsi + me.HYDCOEF * me.oilpsi[engine2];
   }

   return pressurepsi;
}


# ======
# BRAKES
# ======
Brakes = {};

Brakes.new = func {
   obj = { parents : [Brakes], 
           BRAKEACCUPSI : 3000.0,                         # yellow emergency/parking brakes accumulator
           BRAKEMAXPSI : 1200.0,                          # max brake pressure
           BRAKEYELLOWPSI : 900.0,                        # max abnormal pressure (yellow)
           BRAKEGREENPSI : 400.0,                         # max normal pressure (green)
           BRAKERESIDUALPSI : 15.0,                       # residual pressure of emergency brakes (1 atmosphere)
           BRAKEPSIPSEC : 400.0,                          # reaction time, when one applies brakes
           HYDNOPSI : 0.0,
           BRAKERATEPSI : 0.0,
           HYDSEC : 1.0,                                  # refresh rate
           brakes : nil,
           gearcontrols : nil,
           normalaccupsi : 0.0,
           leftbrakepsi : 0.0,
           rightbrakepsi : 0.0,
           emergaccupsi : 0.0,
           leftemergpsi : 0.0,
           rightemergpsi : 0.0
         };

   obj.init();

   return obj;
}

Brakes.init = func {
    me.brakes = props.globals.getNode("/systems/hydraulic/brakes");
    me.gearcontrols = props.globals.getNode("/controls/gear");

    me.set_rate( me.HYDSEC );
}

Brakes.set_rate = func( rates ) {
    me.HYDSEC = rates;
    me.BRAKERATEPSI = me.BRAKEPSIPSEC * me.HYDSEC;
}

Brakes.increase = func( pressurepsi, maxpsi ) {
    resultpsi = pressurepsi + me.BRAKERATEPSI;
    if( resultpsi > maxpsi ) {
        resultpsi = maxpsi;
    }

    return resultpsi;
}

Brakes.decrease = func( pressurepsi, minpsi ) {
    resultpsi = pressurepsi - me.BRAKERATEPSI;
    if( resultpsi < minpsi ) {
        resultpsi = minpsi;
    }

    return resultpsi;
}

Brakes.truncate = func( pressurepsi, maxpsi ) {
    if( pressurepsi > maxpsi ) {
        resultpsi = maxpsi;
    }
    else {
        resultpsi = pressurepsi;
    }

    return resultpsi;
}

Brakes.schedule = func {
   result = me.brakes.getChild("green-accu-psi").getValue();
   if( result != me.normalaccupsi ) {
       interpolate("/systems/hydraulic/brakes/green-accu-psi",me.normalaccupsi,me.HYDSEC);
   }
   result = me.brakes.getChild("left-psi").getValue();
   if( result != me.leftbrakepsi ) {
       interpolate("/systems/hydraulic/brakes/left-psi",me.leftbrakepsi,me.HYDSEC);
   }
   result = me.brakes.getChild("right-psi").getValue();
   if( result != me.rightbrakepsi ) {
       interpolate("/systems/hydraulic/brakes/right-psi",me.rightbrakepsi,me.HYDSEC);
   }

   # automatic, until there is a brake lever
   if( !me.gearcontrols.getChild("brake-emergency").getValue() ) {
       if( me.normalaccupsi < me.BRAKEACCUPSI ) {
           me.gearcontrols.getChild("brake-emergency").setValue(constant.TRUE);
       }
   }
   else {
       if( me.normalaccupsi >= me.BRAKEACCUPSI ) {
           me.gearcontrols.getChild("brake-emergency").setValue(constant.FALSE);
       }
   }

   result = me.brakes.getChild("yellow-accu-psi").getValue();
   if( result != me.emergaccupsi ) {
       interpolate("/systems/hydraulic/brakes/yellow-accu-psi",me.emergaccupsi,me.HYDSEC);
   }
   result = me.brakes.getChild("emerg-left-psi").getValue();
   if( result != me.leftemergpsi ) {
       interpolate("/systems/hydraulic/brakes/emerg-left-psi",me.leftemergpsi,me.HYDSEC);
   }
   result = me.brakes.getChild("emerg-right-psi").getValue();
   if( result != me.rightemergpsi ) {
       interpolate("/systems/hydraulic/brakes/emerg-right-psi",me.rightemergpsi,me.HYDSEC);
   }
}

Brakes.failure = func {
   me.normalaccupsi = me.HYDNOPSI;
   me.leftbrakepsi = me.HYDNOPSI;
   me.rightbrakepsi = me.HYDNOPSI;
   me.emergaccupsi = me.HYDNOPSI;
   me.leftemergpsi = me.HYDNOPSI;
   me.rightemergpsi = me.HYDNOPSI;
}

Brakes.apply = func ( pedal, brakepsi, targetpsi ) {
   pedalpos = getprop(pedal);
   # target is not greatest than the yellow pressure
   if( pedalpos > 0.0 ) {
       maxpsi = me.BRAKERESIDUALPSI + ( targetpsi - me.BRAKERESIDUALPSI ) * pedalpos; 
       pedalpsi = me.increase( brakepsi, maxpsi );
   }
   # visualize release of brake
   else {
       pedalpsi = me.decrease( brakepsi, me.BRAKERESIDUALPSI );
   }

   return pedalpsi;
}

Brakes.emergfailure = func( targetbrakepsi ) {
   if( targetbrakepsi < me.BRAKEGREENPSI ) {
       leftpsi = me.decrease( me.leftemergpsi, targetbrakepsi );
       rightpsi = me.decrease( me.rightemergpsi, targetbrakepsi );

       me.leftemergpsi = leftpsi;       # BUG ?
       me.rightemergpsi = rightpsi;       # BUG ?

       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Brakes.normal = func( pressurepsi ) {
   # normal brakes are on green circuit
   me.normalaccupsi = me.truncate( pressurepsi, me.BRAKEACCUPSI );

   # divide by 2 : left and right
   targetbrakepsi = me.normalaccupsi / 2.0;

   # green has same action than yellow
   targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEGREENPSI );
   me.leftbrakepsi = me.brakes.getChild("left-psi").getValue();
   me.rightbrakepsi = me.brakes.getChild("right-psi").getValue();

   # brake failure
   if( !me.gearcontrols.getChild("brake-emergency").getValue() ) {
       if( targetbrakepsi < me.BRAKEGREENPSI ) {
           leftpsi = me.decrease( me.leftbrakepsi, targetbrakepsi );
           rightpsi = me.decrease( me.rightbrakepsi, targetbrakepsi );
           # TO DO : disable normal brake (joystick)
       }

       # visualize apply of brake
       else {
           leftpsi = me.apply( "/controls/gear/brake-left", me.leftbrakepsi, targetbrakepsi );
           rightpsi = me.apply( "/controls/gear/brake-right", me.rightbrakepsi, targetbrakepsi );
       }
       me.leftbrakepsi = leftpsi;       # BUG ?
       me.rightbrakepsi = rightpsi;       # BUG ?
   }
}

Brakes.emergency = func( pressurepsi ) {
   # ermgency brakes accumulator
   me.emergaccupsi = me.truncate( pressurepsi, me.BRAKEACCUPSI );

   # divide by 2 : left and right
   targetbrakepsi = me.emergaccupsi / 2.0;

   me.leftemergpsi = me.brakes.getChild("emerg-left-psi").getValue();
   me.rightemergpsi = me.brakes.getChild("emerg-right-psi").getValue();

   # brake parking failure
   if( me.gearcontrols.getChild("brake-parking").getValue() == 1.0 ) {
       # stays in the green area
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEGREENPSI );
       if( me.emergfailure( targetbrakepsi ) ) {
           # TO DO : disable brake parking (keyboard)
       }

       # visualize apply of parking brake
       else {
           leftpsi = me.apply( "/controls/gear/brake-parking", me.leftemergpsi, targetbrakepsi );
           rightpsi = me.apply( "/controls/gear/brake-parking", me.rightemergpsi, targetbrakepsi );

           me.leftemergpsi = leftpsi;      # BUG ?
           me.rightemergpsi = rightpsi;      # BUG ?
       }
   }

   # ermergency brake failure
   elsif( me.gearcontrols.getChild("brake-emergency").getValue() ) {
       # above the yellow area exceptionally allowed
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEMAXPSI );
       if( me.emergfailure( targetbrakepsi ) ) {
           # TO DO : disable emergency brake (joystick)
       }

       # visualize apply of emergency brake
       else {
           leftpsi = me.apply( "/controls/gear/brake-left", me.leftemergpsi, targetbrakepsi );
           rightpsi = me.apply( "/controls/gear/brake-right", me.rightemergpsi, targetbrakepsi );

           me.leftemergpsi = leftpsi;       # BUG ?
           me.rightemergpsi = rightpsi;       # BUG ?
       }
   }

   # unused emergency/parking brakes have a weaker pressure
   elsif( me.normalaccupsi >= me.BRAKEACCUPSI ) {
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEMAXPSI );
       # yellow failure
       if( me.emergfailure( targetbrakepsi ) ) {
       }
       else {
           leftpsi = me.apply( "/controls/gear/brake-parking", me.leftemergpsi, targetbrakepsi );
           rightpsi = me.apply( "/controls/gear/brake-parking", me.rightemergpsi, targetbrakepsi );

           me.leftemergpsi = leftpsi;       # BUG ?
           me.rightemergpsi = rightpsi;       # BUG ?
       }
   }
}


# ===============
# RAM AIR TURBINE
# ===============
Rat = {};

Rat.new = func {
   obj = { parents : [Rat], 
           HYDRATGREENPSI : 3850.0,                       # RAT green hydraulic
           HYDRATYELLOWPSI : 3500.0,                      # RAT yellow hydraulic
           HYDRATKT : 150,                                # speed to get hydraulic pressure by RAT (can land)
           deployed : "",
           speedkt : 0.0
         };
   return obj;
}

Rat.supply = func {
   me.deployed = getprop("/systems/hydraulic/rat/deployed");
   if( me.deployed == "on" ) {
       me.speedkt = noinstrument.get_speed_kt();
   }
}

Rat.green = func( pressurepsi ) {
   if( me.deployed == "on" ) {
       if( me.speedkt != nil ) {
           if( me.speedkt > me.HYDRATKT ) {
               pressurepsi = pressurepsi + me.HYDRATGREENPSI;
           }
       }
   }

   return pressurepsi;
}

Rat.yellow = func( pressurepsi ) {
   if( me.deployed == "on" ) {
       if( me.speedkt != nil ) {
           if( me.speedkt > me.HYDRATKT ) {
               pressurepsi = pressurepsi + me.HYDRATYELLOWPSI;
           }
       }
   }

   return pressurepsi;
}

# cannot make a settimer on a class member
Rat.testexport = func {
   rattest();
}

# test RAT
rattest = func {
    if( getprop("/systems/hydraulic/rat/test") == "on" ) {
        setprop("/systems/hydraulic/rat/selector[0]/test","");
        setprop("/systems/hydraulic/rat/selector[1]/test","");
        setprop("/systems/hydraulic/rat/test","");
    }
    elsif( getprop("/systems/hydraulic/rat/selector[0]/test") == "on" or
           getprop("/systems/hydraulic/rat/selector[1]/test") == "on" ) {
        setprop("/systems/hydraulic/rat/test","on");

        # shows the light
        settimer(rattest, 2.5);
    }
}

# cannot make a settimer on a class member
Rat.deployexport = func {
   ratdeploy();
}

# deploy RAT 
ratdeploy = func {
    if( getprop("/systems/hydraulic/rat/deploying") == "on" ) {
        setprop("/systems/hydraulic/rat/deploying","");
        setprop("/systems/hydraulic/rat/deployed","on");
    }
    elsif( getprop("/systems/hydraulic/rat/selector[0]/on") or 
           getprop("/systems/hydraulic/rat/selector[1]/on") ) {

        if( getprop("/systems/hydraulic/rat/deployed") != "on" and
            getprop("/systems/hydraulic/rat/deploying") != "on" ) {
            setprop("/systems/hydraulic/rat/deploying","on");

            # delay of deployment
            settimer(ratdeploy, 1.5);
        }
    }
}
