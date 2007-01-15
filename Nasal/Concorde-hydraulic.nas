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

           HYDSEC : 1.0,                                  # refresh rate

           HYDNORMALPSI : 4000.0,                         # normal hydraulic
           HYDFAILUREPSI : 3400.0,                        # abnormal hydraulic
           HYDNOPSI : 0.0,

           RESERVOIRCOEF : 0.8,

           GEARFT : 20.0,

           color : { "green" : 0, "yellow" : 1, "blue" : 2 },
           circuits : nil,
           reservoirgalus : 0.0,

           noinstrument : { "agl" : "" },
           slave : { "electric" : nil }
         };

    obj.init();

    return obj;
}

Hydraulic.init = func() {
    me.noinstrument["agl"] = getprop("/systems/hydraulic/noinstrument/agl");

    propname = getprop("/systems/hydraulic/slave/electric");
    me.slave["electric"] = props.globals.getNode(propname);

    me.circuits = props.globals.getNode("/systems/hydraulic/circuits/").getChildren("circuit");

    me.brakes.set_rate( me.HYDSEC );
}

Hydraulic.set_rate = func( rates ) {
    me.HYDSEC = rates;

    me.brakes.set_rate( me.HYDSEC );
}

Hydraulic.has = func( index ) {
   if( me.circuits[index].getChild("pressure-psi").getValue() >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Hydraulic.has_green = func {
   return me.has( me.color["green"] );
}

Hydraulic.has_yellow = func {
   return me.has( me.color["yellow"] );
}

Hydraulic.has_blue = func {
   return me.has( me.color["blue"] );
}

Hydraulic.gear_up = func {
   result = constant.FALSE;

   if( me.slave["electric"].getChild("specific").getValue() ) {
       if( me.has_green() ) {
           if( getprop(me.noinstrument["agl"]) > me.GEARFT ) {
               if( !getprop("/controls/gear/neutral") and
                   getprop("/controls/gear/gear-down" ) ) {
                   result = constant.TRUE;
               }
           }
       }
   }

   return result;
}

Hydraulic.gear_down = func {
   result = constant.FALSE;

   if( me.slave["electric"].getChild("specific").getValue() ) {
       if( me.has_green() or me.has_yellow() ) {
           if( !getprop("/controls/gear/neutral") and
               !getprop("/controls/gear/gear-down" ) ) {
               result = constant.TRUE;
           }
       }
   }

   return result;
}

Hydraulic.nose_up = func {
   result = constant.FALSE;

   if( me.slave["electric"].getChild("specific").getValue() ) {
       if( me.has_green() ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Hydraulic.nose_down = func {
   result = constant.FALSE;

   if( me.slave["electric"].getChild("specific").getValue() ) {
       if( me.has_green() or me.has_yellow() ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Hydraulic.has_brakes = func {
   return me.brakes.has();
}

Hydraulic.has_parking_brake = func {
   return me.brakes.has_emergency();
}

Hydraulic.reservoir = func( index, pressurepsi ) {
    me.reservoirgalus = me.circuits[index].getChild("content-gal_us").getValue();
    if( pressurepsi >= me.HYDNORMALPSI ) {
        pressurepsi = me.HYDNORMALPSI;

        # at full load, reservoir decreases
        me.reservoirgalus = me.reservoirgalus * me.RESERVOIRCOEF;
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
       pressurepsi = me.engines.apply( me.color["green"], 0, 1 );
       pressurepsi = me.rat.green( pressurepsi );
       pressurepsi = me.ground.green( pressurepsi );
       pressurepsi = me.reservoir( me.color["green"], pressurepsi );
       me.brakes.normal( pressurepsi );
       me.applypressure( me.color["green"], pressurepsi );


       # ==============================
       # yellow : engines 2 & 4 and RAT
       # ==============================
       pressurepsi = me.engines.apply( me.color["yellow"], 1, 3 );
       pressurepsi = me.rat.yellow( pressurepsi );
       pressurepsi = me.ground.yellow( pressurepsi );
       pressurepsi = me.reservoir( me.color["yellow"], pressurepsi );
       me.brakes.emergency( pressurepsi );
       me.applypressure( me.color["yellow"], pressurepsi );


       # ====================
       # blue : engines 3 & 4
       # ====================
       pressurepsi = me.engines.apply( me.color["blue"], 2, 3 );
       pressurepsi = me.ground.blue( pressurepsi );
       pressurepsi = me.reservoir( me.color["blue"], pressurepsi );
       me.applypressure( me.color["blue"], pressurepsi );
   }


   # failure
   else {
       me.failure();
   }


   me.brakes.schedule();
}


# =============
# GROUND SUPPLY
# =============
HydGround = {};

HydGround.new = func {
   obj = { parents : [HydGround], 

           hydpumps : nil,

           HYDELECTRICALPSI : 3500.0,                     # electrical pump hydraulic
           groundvolts : constant.FALSE,                  # electrical ground power
           hydcheckout : 0,                               # selector

           slave : { "electric" : nil }
         };

    obj.init();

    return obj;
}

HydGround.init = func() {
    propname = getprop("/systems/hydraulic/slave/electric");
    me.slave["electric"] = props.globals.getNode(propname);

    me.hydpumps = props.globals.getNode("/controls/hydraulic/ground/").getChildren("pump");
}

HydGround.supply = func {
   me.groundvolts = me.slave["electric"].getChild("ground-service").getValue();
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

           oilpsi : [ 0.0,0.0,0.0,0.0 ],
           hydcontrols : nil,

           slave : { "engine" : nil }
         };

    obj.init();

    return obj;
}

HydEngines.init = func() {
    propname = getprop("/systems/hydraulic/slave/engine");
    me.slave["engine"] = props.globals.getNode(propname).getChildren("engine");

    # not named controls, otherwise lost controls.setFlaps() !!
    me.hydcontrols = props.globals.getNode("/controls/hydraulic/circuits/").getChildren("circuit");

    me.HYDCOEF = me.HYDFAILUREPSI / me.HYDENGINEPSI;
}

# engine provides hydraulical pressure
HydEngines.oil = func {
    for( i=0; i < 4; i=i+1 ) {
         me.oilpsi[i] = me.HYDNOPSI;
         if( me.slave["engine"][i].getChild("running").getValue() or
             me.slave["engine"][i].getChild("starter").getValue() ) {
             me.oilpsi[i] = me.slave["engine"][i].getChild("oil-pressure-psi").getValue();
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

           brakes : nil,
           gearcontrols : nil,

           HYDSEC : 1.0,                                  # refresh rate

           BRAKEACCUPSI : 3000.0,                         # yellow emergency/parking brakes accumulator
           BRAKEMAXPSI : 1200.0,                          # max brake pressure
           BRAKEYELLOWPSI : 900.0,                        # max abnormal pressure (yellow)
           BRAKEGREENPSI : 400.0,                         # max normal pressure (green)
           BRAKERESIDUALPSI : 15.0,                       # residual pressure of emergency brakes (1 atmosphere)
           HYDNOPSI : 0.0,

           BRAKEPSIPSEC : 400.0,                          # reaction time, when one applies brakes
           BRAKERATEPSI : 0.0,

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

Brakes.has_emergency = func {
    # TO DO : failure only on left or right
    if( getprop("/systems/hydraulic/brakes/yellow-accu-psi") < me.BRAKEACCUPSI ) {
        result = constant.FALSE;
    }
    else {
        result = constant.TRUE;
    }

    return result;
}

Brakes.has = func {
    # TO DO : failure only on left or right
    if( getprop("/systems/hydraulic/brakes/green-accu-psi") < me.BRAKEACCUPSI and
        !me.has_emergency() ) {
        result = constant.FALSE;
    }
    else {
        result = constant.TRUE;
    }

    return result;
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
           # disable normal brake (joystick)
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
   if( me.gearcontrols.getChild("brake-parking-lever").getValue() ) {
       # stays in the green area
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEGREENPSI );
       if( me.emergfailure( targetbrakepsi ) ) {
           # disable brake parking (keyboard)
           me.gearcontrols.getChild("brake-parking").setValue(0.0);
       }

       # visualize apply of parking brake
       else {
           me.gearcontrols.getChild("brake-parking").setValue(1.0);

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
           # disable emergency brake (joystick)
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
       # disable
       me.gearcontrols.getChild("brake-parking").setValue(0.0);

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

           deployed : constant.FALSE,
           speedkt : 0.0,

           noinstrument : { "airspeed" : "" }
         };

   obj.init();

   return obj;
}

Rat.init = func {
   me.noinstrument["airspeed"] = getprop("/systems/hydraulic/noinstrument/airspeed");
}

Rat.supply = func {
   me.deployed = getprop("/systems/hydraulic/rat/deployed");
   if( me.deployed ) {
       me.speedkt = getprop(me.noinstrument["airspeed"]);
   }
}

Rat.green = func( pressurepsi ) {
   if( me.deployed ) {
       if( me.speedkt != nil ) {
           if( me.speedkt > me.HYDRATKT ) {
               pressurepsi = pressurepsi + me.HYDRATGREENPSI;
           }
       }
   }

   return pressurepsi;
}

Rat.yellow = func( pressurepsi ) {
   if( me.deployed ) {
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
    if( getprop("/systems/hydraulic/rat/test") ) {
        setprop("/systems/hydraulic/rat/selector[0]/test",constant.FALSE);
        setprop("/systems/hydraulic/rat/selector[1]/test",constant.FALSE);
        setprop("/systems/hydraulic/rat/test","");
    }
    elsif( getprop("/systems/hydraulic/rat/selector[0]/test") or
           getprop("/systems/hydraulic/rat/selector[1]/test") ) {
        setprop("/systems/hydraulic/rat/test",constant.TRUE);

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
    if( getprop("/systems/hydraulic/rat/deploying") ) {
        setprop("/systems/hydraulic/rat/deploying",constant.FALSE);
        setprop("/systems/hydraulic/rat/deployed",constant.TRUE);
    }
    elsif( getprop("/systems/hydraulic/rat/selector[0]/on") or 
           getprop("/systems/hydraulic/rat/selector[1]/on") ) {

        if( !getprop("/systems/hydraulic/rat/deployed") and
            !getprop("/systems/hydraulic/rat/deploying") ) {
            setprop("/systems/hydraulic/rat/deploying",constant.TRUE);

            # delay of deployment
            settimer(ratdeploy, 1.5);
        }
    }
}


# ===========
# GEAR SYSTEM
# ===========

Gear = {};

Gear.new = func {
   obj = { parents : [Gear],

           damper : PitchDamper.new()
         };

   obj.init();

   return obj;
}

Gear.init = func {
    settimer( gearcron, 5.0 );
}

gearcron = func {
    gearsystem.schedule();
}

Gear.schedule = func {
    rates = me.damper.schedule();

    settimer( gearcron, rates );
}


# ============
# PITCH DAMPER
# ============

PitchDamper = {};

PitchDamper.new = func {
   obj = { parents : [PitchDamper],

           wow : WeightSwitch.new(),

           thegear : nil,

           DAMPERSEC : 1.0,
           TOUCHSEC : 0.2,                                      # to detect touch down

           rates : 0.0,

           TOUCHDEG : 5.0,

           rebound : constant.FALSE,

           DAMPERDEGPS : 1.0,

           field : { "left" : "bogie-left-deg", "right" : "bogie-right-deg" },
           gearpath : "/systems/gear/",

           noinstrument : { "pitch" : "" }
         };

   obj.init();

   return obj;
}

PitchDamper.init = func {
    me.thegear = props.globals.getNode("/systems/gear");

    me.noinstrument["pitch"] = getprop("/systems/gear/noinstrument/pitch");
}

PitchDamper.schedule = func {
    me.rates = me.wow.schedule();

    me.damper( "left" );
    me.damper( "right" );

    return me.rates;
}

PitchDamper.set_rate = func( rates ) {
    if( rates < me.rates ) {
        me.rates = rates;
    }
}

PitchDamper.damper = func( name ) {
    result = me.thegear.getChild(me.field[name]).getValue();

    # shock at touch down
    if( me.wow.bogie(name) ) {
        target = getprop(me.noinstrument["pitch"]);

        # aft tyre rebounds over runway
        if( result == 0.0 ) {
            target = target + me.TOUCHDEG;
            me.thegear.getChild(me.field[name]).setValue(target);
            me.rebound = constant.TRUE;
            me.set_rate( me.TOUCHSEC );
        }

        # end of rebound
        elsif( me.rebound ) {
            me.thegear.getChild(me.field[name]).setValue(target);
            me.rebound = constant.FALSE;
            me.set_rate( me.TOUCHSEC );
        }

        # rolling
        else {
            path = me.gearpath ~ me.field[name];
            me.rebound = constant.FALSE;
            me.set_rate( me.DAMPERSEC );
            interpolate(path,target,me.rates);
        }
    }

    # pitch damper
    elsif( result != 0.0 ) {
        target = result - me.DAMPERDEGPS * me.rates;
        if( target < 0.0 ) {
            target = 0.0;
        }

        path = me.gearpath ~ me.field[name];
        interpolate(path,target,me.rates);
        me.rebound = constant.FALSE;
    }
}


# =============
# WEIGHT SWITCH
# =============

WeightSwitch = {};

WeightSwitch.new = func {
   obj = { parents : [WeightSwitch],

           gears : nil,
           switch : nil,

           AIRSEC : 15.0,
           TOUCHSEC : 0.2,                                      # to detect touch down

           rates : 0.0,

           LANDFT : 500.0,
           AIRFT : 50.0,

           tyre : { "left" : 2, "right" : 4 },
           ground : { "left" : constant.TRUE, "right" : constant.TRUE },

           noinstrument : { "agl" : "" }
         };

   obj.init();

   return obj;
}

WeightSwitch.init = func {
    me.gears = props.globals.getNode("/gear").getChildren("gear");
    me.switch = props.globals.getNode("/instrumentation/weight-switch");

    me.noinstrument["agl"] = getprop("/instrumentation/weight-switch/noinstrument/agl");
}

WeightSwitch.schedule = func {
    me.rates = me.AIRSEC;

    aglft = getprop(me.noinstrument["agl"]);

    me.gear( "left", aglft );
    me.gear( "right", aglft );

    if( me.ground["left"] or me.ground["right"] ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    me.switch.getChild("wow").setValue(result);

    return me.rates;
}

WeightSwitch.gear = func( name, aglft ) {
    # touch down
    if( me.gears[me.tyre[name]].getChild("wow").getValue() ) {
        if( aglft < me.AIRFT ) {
            me.ground[name] = constant.TRUE;
        }

        # wow not reset in air (bug)
        else {
            if( aglft < me.LANDFT ) {
                me.rates = me.TOUCHSEC;
            }

            me.ground[name] = constant.FALSE;
        }
    }

    # lift off
    else {
        if( aglft < me.LANDFT ) {
            me.rates = me.TOUCHSEC;
        }

        me.ground[name] = constant.FALSE;
    }
}

WeightSwitch.bogie = func( name ) {
    return me.ground[name];
}
