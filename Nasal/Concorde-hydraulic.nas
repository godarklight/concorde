# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ================
# HYDRAULIC SYSTEM
# ================

Hydraulic = {};

Hydraulic.new = func {
   var obj = { parents : [Hydraulic,System], 

           parser : HydraulicXML.new(),
           ground : HydGround.new(),
           rat : Rat.new(),
           brakes : Brakes.new(),

           sensors : nil,
           power : nil,

           HYDSEC : 1.0,                                  # refresh rate

           HYDFAILUREPSI : 3400.0,

           color : { "green" : 0, "yellow" : 1, "blue" : 2 }
         };

    obj.init();

    return obj;
}

Hydraulic.init = func() {
    me.init_ancestor("/systems/hydraulic");

    me.sensors = props.globals.getNode("/systems/hydraulic/sensors");
    me.power = props.globals.getNode("/systems/hydraulic/power");

    me.brakes.set_rate( me.HYDSEC );
}

Hydraulic.set_rate = func( rates ) {
    me.HYDSEC = rates;

    me.parser.set_rate( me.HYDSEC );
    me.brakes.set_rate( me.HYDSEC );
}

Hydraulic.groundexport = func {
    me.ground.selectorexport();
}

Hydraulic.brakesparkingexport = func {
    me.brakes.parkingexport();
}

Hydraulic.brakesemergencyexport = func {
    me.brakes.emergencyexport();
}

Hydraulic.amber_hydraulics = func {
    var result = constant.FALSE;

    if( me.sensors.getChild("green-left").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("green-right").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("yellow-left").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("yellow-right").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("blue-left").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("blue-right").getValue() < me.HYDFAILUREPSI ) {
        result = constant.TRUE;
    }

    return result;
}

Hydraulic.red_intake = func( index ) {
    var result = constant.FALSE;

    if( me.sensors.getChild("intake", index).getValue() < me.HYDFAILUREPSI ) {
        result = constant.TRUE;
    }

    return result;
}

Hydraulic.red_feel = func {
    var result = constant.TRUE;

    if( me.has_green() or me.has_blue() ) {
        result = constant.FALSE;
    }

    return result;
}

Hydraulic.has_green = func {
   var result = constant.FALSE;

   if( me.sensors.getChild("green").getValue() >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.has_yellow = func {
   var result = constant.FALSE;

   if( me.sensors.getChild("yellow").getValue() >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.has_blue = func {
   var result = constant.FALSE;

   if( me.sensors.getChild("blue").getValue() >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.has_gear = func {
   var result = constant.FALSE;

   if( me.sensors.getChild("gear").getValue() >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }

   return result;
}

Hydraulic.brakes_pedals = func( pressure ) {
   return me.brakes.pedals( pressure );
}

Hydraulic.schedule = func {
   me.ground.schedule();
   me.parser.schedule();

   var greenpsi = me.sensors.getChild("green").getValue();
   var yellowpsi = me.sensors.getChild("yellow").getValue();

   me.brakes.schedule( greenpsi, yellowpsi );

   me.power.getChild("blue").setValue( me.has_blue() );
   me.power.getChild("green").setValue( me.has_green() );
   me.power.getChild("yellow").setValue( me.has_yellow() );

   me.power.getChild("gear").setValue( me.has_gear() );
}


# =============
# GROUND SUPPLY
# =============
HydGround = {};

HydGround.new = func {
   var obj = { parents : [HydGround,System], 

           circuits : nil,
           ground : nil,
           hydpumps : nil,

           pumps : [ [ constant.FALSE, constant.TRUE , constant.TRUE , constant.FALSE ],     # Y-Y
                     [ constant.TRUE , constant.FALSE, constant.FALSE, constant.TRUE  ],     # G-B
                     [ constant.FALSE, constant.TRUE , constant.FALSE, constant.TRUE  ],     # B-Y
                     [ constant.FALSE, constant.TRUE , constant.TRUE , constant.FALSE ],     # Y-Y
                     [ constant.TRUE , constant.FALSE, constant.TRUE , constant.FALSE ],     # G-Y
                     [ constant.FALSE, constant.TRUE , constant.TRUE , constant.FALSE ] ]    # Y-Y
         };

    obj.init();

    return obj;
}

HydGround.init = func() {
    me.init_ancestor("/systems/hydraulic");

    me.circuits = props.globals.getNode("/controls/hydraulic").getChildren("circuit");
    me.ground = props.globals.getNode("/controls/hydraulic/ground");
    me.hydpumps = props.globals.getNode("/controls/hydraulic/ground/").getChildren("pump");
}

HydGround.schedule = func {
   var selector = me.ground.getChild("selector").getValue();

   # magnetic release of the switch
   if( !me.slave["electric"].getChild("ground-service").getValue() ) {
       for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
            me.hydpumps[i].getChild("switch").setValue(constant.FALSE);
       }

       me.circuits[0].getChild("ground").setValue( constant.FALSE );
       me.circuits[1].getChild("ground", 0).setValue( constant.FALSE );
       me.circuits[1].getChild("ground", 1).setValue( constant.FALSE );
       me.circuits[2].getChild("ground").setValue( constant.FALSE );
   }

   if( me.hydpumps[0].getChild("switch").getValue() ) {
       me.circuits[0].getChild("ground").setValue( me.pumps[selector][0] );
       me.circuits[1].getChild("ground", 0).setValue( me.pumps[selector][1] );
   }
   else {
       me.circuits[0].getChild("ground").setValue( constant.FALSE );
       me.circuits[1].getChild("ground", 0).setValue( constant.FALSE );
   }

   if( me.hydpumps[1].getChild("switch").getValue() ) {
       me.circuits[1].getChild("ground", 1).setValue( me.pumps[selector][2] );
       me.circuits[2].getChild("ground").setValue( me.pumps[selector][3] );
   }
   else {
       me.circuits[1].getChild("ground", 1).setValue( constant.FALSE );
       me.circuits[2].getChild("ground").setValue( constant.FALSE );
   }
}


# ======
# BRAKES
# ======

Brakes = {};

Brakes.new = func {
   var obj = { parents : [Brakes,System], 

           brakes : nil,

           heat : BrakesHeat.new(),

           HYDSEC : 1.0,                               # refresh rate

           BRAKEACCUPSI : 3000.0,                      # yellow emergency/parking brakes accumulator
           BRAKEMAXPSI : 1200.0,                       # max brake pressure
           BRAKEYELLOWPSI : 900.0,                     # max abnormal pressure (yellow)
           BRAKEGREENPSI : 400.0,                      # max normal pressure (green)
           BRAKERESIDUALPSI : 15.0,                    # residual pressure of emergency brakes (1 atmosphere)
           HYDNOPSI : 0.0,

           BRAKEPSIPSEC : 400.0,                       # reaction time, when one applies brakes

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

    me.init_ancestor("/systems/hydraulic");

    me.set_rate( me.HYDSEC );

    # sets 3D lever from brake-parking-lever flag in Concorde-set.xml file
    me.lever();
}

Brakes.set_rate = func( rates ) {
    me.HYDSEC = rates;
    me.BRAKERATEPSI = me.BRAKEPSIPSEC * me.HYDSEC;

    me.heat.set_rate( rates );
}

Brakes.lever = func {
    # normal
    var pos = constantaero.BRAKENORMAL;

    # parking brake
    if( me.slave["gear"].getChild("brake-parking-lever").getValue() ) {
        pos = constantaero.BRAKEPARKING;
    }

    # emergency (must be set by Captain)
    elsif( me.slave["gear"].getChild("brake-emergency").getValue() ) {
        pos = constantaero.BRAKEEMERGENCY;
    }

    # for 3D lever
    me.slave["gear"].getChild("brake-pos-norm").setValue(pos);
}

Brakes.emergencyexport = func {
    var value = constant.TRUE;
    var value2 = constant.FALSE;

    if( me.slave["gear"].getChild("brake-emergency").getValue() ) {
        value = constant.FALSE;
        value2 = constant.TRUE;
    }

    # toggles between parking and emergency
    me.slave["gear"].getChild("brake-emergency").setValue(value);
    me.slave["gear"].getChild("brake-parking-lever").setValue(value2);

    me.lever();
}

Brakes.parkingexport = func {
    var value = constant.TRUE;

    if( me.slave["gear"].getChild("brake-parking-lever").getValue() ) {
        value = constant.FALSE;
    }

    # toggles between parking and normal
    me.slave["gear"].getChild("brake-emergency").setValue(constant.FALSE);
    me.slave["gear"].getChild("brake-parking-lever").setValue(value);

    me.lever();
}

Brakes.pedals = func( pressure ) {
    var action = constant.TRUE;
    var depress = me.has();

    # releases the pedals
    if( pressure == 0 ) {
        action = constant.FALSE;
    }

    me.brakes.getChild("pedals").setValue(action);

    return depress;
}

Brakes.has_emergency = func {
    var result = constant.TRUE;

    # TO DO : failure only on left or right
    if( me.brakes.getChild("yellow-accu-psi").getValue() < me.BRAKEACCUPSI ) {
        result = constant.FALSE;
    }

    return result;
}

Brakes.has_normal = func {
    var result = constant.TRUE;

    # TO DO : failure only on left or right
    if( me.brakes.getChild("green-accu-psi").getValue() < me.BRAKEACCUPSI ) {
        result = constant.FALSE;
    }

    return result;
}

Brakes.has = func {
    var result = constant.TRUE;
    var emergency = me.slave["gear"].getChild("brake-emergency").getValue();

    # TO DO : failure only on left or right
    if( ( !me.has_normal() and !emergency ) or
        ( !me.has_emergency() and emergency ) ) {
        result = constant.FALSE;
    }

    return result;
}

Brakes.schedule = func( greenpsi, yellowpsi ) {
   me.normal( greenpsi, yellowpsi );
   me.emergency( yellowpsi );
   me.accumulator();

   me.heat.schedule();
}

Brakes.accumulator = func {
   interpolate("/systems/hydraulic/brakes/green-accu-psi",me.normalaccupsi,me.HYDSEC);
   interpolate("/systems/hydraulic/brakes/left-psi",me.leftbrakepsi,me.HYDSEC);
   interpolate("/systems/hydraulic/brakes/right-psi",me.rightbrakepsi,me.HYDSEC);

   interpolate("/systems/hydraulic/brakes/yellow-accu-psi",me.emergaccupsi,me.HYDSEC);
   interpolate("/systems/hydraulic/brakes/emerg-left-psi",me.leftemergpsi,me.HYDSEC);
   interpolate("/systems/hydraulic/brakes/emerg-right-psi",me.rightemergpsi,me.HYDSEC);
}

Brakes.normal = func( greenpsi, yellowpsi ) {
   var targetbrakepsi = 0.0;

   # brake failure
   if( !me.slave["gear"].getChild("brake-emergency").getValue() ) {
       targetbrakepsi = me.normalpsi( greenpsi );

       # disable normal brake (joystick)
       if( me.normalfailure( targetbrakepsi ) ) {
       }

       # visualize apply of brake
       else {
           me.brakeapply( me.leftbrakepsi, me.rightbrakepsi, targetbrakepsi );
       }
   }

   # ermergency brake failure
   else {
       targetbrakepsi = me.emergencypsi( yellowpsi );

       # above the yellow area exceptionally allowed
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEMAXPSI );

       if( me.emergfailure( targetbrakepsi ) ) {
           # disable emergency brake (joystick)
       }

       # visualize apply of emergency brake
       else {
           me.brakeapply( me.leftemergpsi, me.rightemergpsi, targetbrakepsi );
       }
   }
}

Brakes.emergency = func( yellowpsi ) {
   var targetbrakepsi = me.emergencypsi( yellowpsi );

   # brake parking failure
   if( me.slave["gear"].getChild("brake-parking-lever").getValue() ) {
       # stays in the green area
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEGREENPSI );
       if( me.emergfailure( targetbrakepsi ) ) {
           # disable brake parking (keyboard)
           me.slave["gear"].getChild("brake-parking").setValue(constantaero.BRAKENORMAL);
       }

       # visualize apply of parking brake
       else {
           me.slave["gear"].getChild("brake-parking").setValue(constantaero.BRAKEPARKING);

           me.parkingapply( targetbrakepsi );
       }
   }

   # unused emergency/parking brakes have a weaker pressure
   else {
       me.slave["gear"].getChild("brake-parking").setValue(constantaero.BRAKENORMAL);

       if( me.normalaccupsi >= me.BRAKEACCUPSI ) {
           targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEMAXPSI );

           # yellow failure
           if( me.emergfailure( targetbrakepsi ) ) {
           }
           else {
               me.parkingapply( targetbrakepsi );
           }
       }
   }
}

Brakes.normalpsi = func( pressurepsi ) {
   # normal brakes are on green circuit
   me.normalaccupsi = me.truncate( pressurepsi, me.BRAKEACCUPSI );

   # divide by 2 : left and right
   var targetbrakepsi = me.normalaccupsi / 2.0;

   # green has same action than yellow
   var targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEGREENPSI );

   me.leftbrakepsi = me.brakes.getChild("left-psi").getValue();
   me.rightbrakepsi = me.brakes.getChild("right-psi").getValue();

   return targetbrakepsi;
}

Brakes.emergencypsi = func( pressurepsi ) {
   # emergency brakes accumulator
   me.emergaccupsi = me.truncate( pressurepsi, me.BRAKEACCUPSI );

   # divide by 2 : left and right
   var targetbrakepsi = me.emergaccupsi / 2.0;

   me.leftemergpsi = me.brakes.getChild("emerg-left-psi").getValue();
   me.rightemergpsi = me.brakes.getChild("emerg-right-psi").getValue();

   return targetbrakepsi;
}

Brakes.brakeapply = func( leftnormalpsi, rightnormalpsi, targetbrakepsi ) {
   var leftpsi = me.apply( "/controls/gear/brake-left", leftnormalpsi, targetbrakepsi );
   var rightpsi = me.apply( "/controls/gear/brake-right", rightnormalpsi, targetbrakepsi );

   me.leftbrakepsi = leftpsi;       # BUG ?
   me.rightbrakepsi = rightpsi;       # BUG ?
}

Brakes.parkingapply = func( targetbrakepsi ) {
   var leftpsi = me.apply( "/controls/gear/brake-parking", me.leftemergpsi, targetbrakepsi );
   var rightpsi = me.apply( "/controls/gear/brake-parking", me.rightemergpsi, targetbrakepsi );

   me.leftemergpsi = leftpsi;       # BUG ?
   me.rightemergpsi = rightpsi;       # BUG ?
}

Brakes.apply = func( pedal, brakepsi, targetpsi ) {
   var maxpsi = 0.0;
   var pedalpsi = 0.0;
   var pedalpos = getprop(pedal);

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

Brakes.normalfailure = func( targetbrakepsi ) {
   var leftpsi = 0.0;
   var rightpsi = 0.0;
   var result = constant.FALSE;

   if( targetbrakepsi < me.BRAKEGREENPSI ) {
       leftpsi = me.decrease( me.leftbrakepsi, targetbrakepsi );
       rightpsi = me.decrease( me.rightbrakepsi, targetbrakepsi );

       me.leftbrakepsi = leftpsi;       # BUG ?
       me.rightbrakepsi = rightpsi;       # BUG ?

       result = constant.TRUE;
   }

   return result;
}

Brakes.emergfailure = func( targetbrakepsi ) {
   var leftpsi = 0.0;
   var rightpsi = 0.0;
   var result = constant.FALSE;

   if( targetbrakepsi < me.BRAKEGREENPSI ) {
       leftpsi = me.decrease( me.leftemergpsi, targetbrakepsi );
       rightpsi = me.decrease( me.rightemergpsi, targetbrakepsi );

       me.leftemergpsi = leftpsi;       # BUG ?
       me.rightemergpsi = rightpsi;       # BUG ?

       result = constant.TRUE;
   }

   return result;
}

Brakes.increase = func( pressurepsi, maxpsi ) {
    var resultpsi = pressurepsi + me.BRAKERATEPSI;

    if( resultpsi > maxpsi ) {
        resultpsi = maxpsi;
    }

    return resultpsi;
}

Brakes.decrease = func( pressurepsi, minpsi ) {
    var resultpsi = pressurepsi - me.BRAKERATEPSI;

    if( resultpsi < minpsi ) {
        resultpsi = minpsi;
    }

    return resultpsi;
}

Brakes.truncate = func( pressurepsi, maxpsi ) {
    var resultpsi = pressurepsi;

    if( pressurepsi > maxpsi ) {
        resultpsi = maxpsi;
    }

    return resultpsi;
}


# ===========
# BRAKES HEAT
# ===========

# reference :
# ---------
#  - http://en.wikipedia.org/wiki/Concorde :
#  several hours of cooling (300-500 degC) after an aborted takeoff (before V1).
#  - http://en.wikipedia.org/wiki/Heat_conduction :
#  Newton's law of cooling, T = Tenv + ( To - Tenv ) exp( - t / t0 ).

BrakesHeat = {};

BrakesHeat.new = func {
   var obj = { parents : [BrakesHeat,System], 

           COOLSEC : 1000,                             # ( 500 - 15 ) degc / 2 hours
           HYDSEC : 1.0,

           timesec : 0.0,

           brakes : nil,
           gear : nil,

           WARMKT2TODEGCPSEC : 0.0184,                 # (500 - 15 ) degc / ( 160 kt x 160 kt )

           lastspeedkt : 0.0,

           ABRUPTDEGC : 1.0,

           lastoatdegc : 0.0,
           tempdegc : 0.0,
           tempmaxdegc : 0.0,
           temppeakdegc : 0.0
         };

   obj.init();

   return obj;
}

BrakesHeat.init = func {
    me.brakes = props.globals.getNode("/systems/hydraulic/brakes");
    me.gear = props.globals.getNode("/controls/gear");

    me.init_ancestor("/systems/hydraulic");

    me.set_rate( me.HYDSEC );

    me.tempdegc = me.brakes.getChild("temperature-degc").getValue();
    me.tempmaxdegc = me.brakes.getChild("temp-max-degc").getValue();
    me.lastoatdegc = me.tempdegc;
    me.peak();
}

BrakesHeat.set_rate = func( rates ) {
    me.HYDSEC = rates;

    me.set_rate_ancestor( me.HYDSEC );

    me.WARMKT2TODEGCPSEC = me.WARMKT2TODEGCPSEC * me.HYDSEC;
}

BrakesHeat.schedule = func {
   if( !me.warming() ) {
       me.cooling();
   }

   me.brakes.getChild("temperature-degc").setValue(me.tempdegc);

   if( me.tempdegc > me.tempmaxdegc ) {
       me.tempmaxdegc = me.tempdegc;
       me.brakes.getChild("temp-max-degc").setValue(me.tempmaxdegc);

       # gauge
       if( !me.brakes.getChild("test").getValue() ) {
           me.brakes.getChild("test-degc").setValue(me.tempmaxdegc);
       }
   }
}

BrakesHeat.warming = func {
   var result = constant.FALSE;
   var speedkt = me.noinstrument["airspeed"].getValue();

   if( me.noinstrument["agl"].getValue() < constantaero.AGLTOUCHFT ) {
       if( me.noinstrument["gear"].getValue() ) {
           var left = 0.0;
           var right = 0.0;
           var allbrakes = 0.0;
           var stepkt2 = 0.0;
           var stepdegc = 0.0;

           left = me.gear.getChild("brake-left").getValue();
           right = me.gear.getChild("brake-right").getValue();
           allbrakes = left + right;

           if( allbrakes > 0.0 ) {
               # aborted takeoff at V1 (160 kt) heats until 300-500 degc
               if( speedkt < me.lastspeedkt ) {
                   # conversion of kinetic energy to heat
                   stepkt2 = ( me.lastspeedkt * me.lastspeedkt - speedkt * speedkt );
                   stepdegc = stepkt2 * me.WARMKT2TODEGCPSEC;
                   stepdegc = allbrakes * stepdegc;

                   result = constant.TRUE;

                   me.tempdegc = me.tempdegc + stepdegc;
                   me.peak();
               }
           }
       }
   }

   me.lastspeedkt = speedkt;

   return result;
}

BrakesHeat.cooling = func {
   var ratio = 0.0;
   var diffdegc = 0.0;
   var oatdegc = me.noinstrument["temperature"].getValue();

   me.curvestep( oatdegc );

   # exponential cooling
   if( !me.is_relocating() ) {
       ratio = - me.timesec / me.COOLSEC;
       diffdegc = ( me.temppeakdegc - oatdegc ) * math.exp( ratio );
       me.tempdegc = oatdegc + diffdegc;
   }

   me.lastoatdegc = oatdegc;
}

BrakesHeat.peak = func {
   me.temppeakdegc = me.tempdegc;

   me.curvereset();
}

BrakesHeat.curvestep = func( oatdegc ) {
   # cooling curve is supposed applicable within a stable environment;
   if( constant.within( oatdegc, me.lastoatdegc, me.ABRUPTDEGC ) ) {  
       me.timesec = me.timesec + constant.times( me.HYDSEC );
   }

   # otherwise, one starts a new cooling curve, with the new boundary conditions.
   else {
       me.curvereset();
   }
}

BrakesHeat.curvereset = func {
   me.timesec = 0.0;
}


# ===============
# RAM AIR TURBINE
# ===============
Rat = {};

Rat.new = func {
   var obj = { parents : [Rat],

           TESTSEC : 2.5,
           DEPLOYSEC : 1.5
         };

   return obj;
}

Rat.testexport = func {
   me.test();
}

Rat.test = func {
    if( getprop("/systems/hydraulic/rat/test") ) {
        setprop("/systems/hydraulic/rat/selector[0]/test",constant.FALSE);
        setprop("/systems/hydraulic/rat/selector[1]/test",constant.FALSE);
        setprop("/systems/hydraulic/rat/test","");
    }
    elsif( getprop("/systems/hydraulic/rat/selector[0]/test") or
           getprop("/systems/hydraulic/rat/selector[1]/test") ) {
        setprop("/systems/hydraulic/rat/test",constant.TRUE);

        # shows the light
        settimer(func { me.test(); }, me.TESTSEC);
    }
}

Rat.deployexport = func {
    me.deploy();
}

Rat.deploy = func {
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
            settimer(func { me.deploy(); }, me.DEPLOYSEC);
        }
    }
}


# ===========
# GEAR SYSTEM
# ===========

Gear = {};

Gear.new = func {
   var obj = { parents : [Gear, System],

           damper : PitchDamper.new(),

           GEARSEC : 5.0,

           thegear : nil
         };

   obj.init();

   return obj;
}

Gear.init = func {
    me.init_ancestor("/systems/gear");

    me.thegear = props.globals.getNode("/controls/gear");

    settimer( func { me.schedule(); }, me.GEARSEC );
}

Gear.schedule = func {
    var rates = me.damper.schedule();

    settimer( func { me.schedule(); }, rates );
}

Gear.can_up = func {
   var result = constant.FALSE;

   if( me.slave["electric"].getValue() ) {
       if( me.slave["hydraulic"].getChild("gear").getValue() ) {
           # prevents retract on ground
           if( me.noinstrument["agl"].getValue() > constantaero.GEARFT ) {
               if( me.thegear.getChild("gear-down").getValue() ) {
                   result = constant.TRUE;
               }
           }
       }
   }

   return result;
}

Gear.can_down = func {
   var result = constant.FALSE;

   if( me.slave["electric"].getValue() ) {
       if( me.slave["hydraulic"].getChild("gear").getValue() ) {
           if( !me.thegear.getChild("gear-down").getValue() ) {
               result = constant.TRUE;
           }
       }
   }

   return result;
}

Gear.can_standby = func {
   var result = constant.FALSE;

   if( me.slave["electric"].getValue() ) {
       if( me.slave["hydraulic"].getChild("yellow").getValue() ) {
           if( !me.thegear.getChild("gear-down").getValue() ) {
               result = constant.TRUE;
           }
       }
   }

   return result;
}

Gear.standbyexport = func {
   if( me.can_standby() ) {
       if( !me.thegear.getChild("gear-down").getValue() ) {
           me.thegear.getChild("gear-down").setValue( constant.TRUE );
       }
   }
}


# ============
# PITCH DAMPER
# ============

PitchDamper = {};

PitchDamper.new = func {
   var obj = { parents : [PitchDamper,System],

           wow : WeightSwitch.new(),

           thegear : nil,

           DAMPERSEC : 1.0,
           TOUCHSEC : 0.2,                                      # to detect touch down

           rates : 0.0,

           TOUCHDEG : 5.0,

           rebound : constant.FALSE,

           DAMPERDEGPS : 1.0,

           field : { "left" : "bogie-left-deg", "right" : "bogie-right-deg" },
           gearpath : "/systems/gear/"
         };

   obj.init();

   return obj;
}

PitchDamper.init = func {
    me.thegear = props.globals.getNode(me.gearpath);

    me.init_ancestor(me.gearpath);
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
    var target = 0.0;
    var path = "";
    var result = me.thegear.getChild(me.field[name]).getValue();

    # shock at touch down
    if( me.wow.bogie(name) ) {
        target = me.noinstrument["pitch"].getValue();

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
  var  obj = { parents : [WeightSwitch,System],

           switch : nil,

           AIRSEC : 15.0,
           TOUCHSEC : 0.2,                                      # to detect touch down

           rates : 0.0,

           LANDFT : 500.0,
           AIRFT : 50.0,

           tyre : { "left" : 2, "right" : 4 },
           ground : { "left" : constant.TRUE, "right" : constant.TRUE }
         };

   obj.init();

   return obj;
}

WeightSwitch.init = func {
    me.switch = props.globals.getNode("/instrumentation/weight-switch");

    me.init_ancestor("/instrumentation/weight-switch");
}

WeightSwitch.schedule = func {
    var result = constant.FALSE;
    var aglft = me.noinstrument["agl"].getValue();

    me.rates = me.AIRSEC;

    me.gear( "left", aglft );
    me.gear( "right", aglft );

    if( me.ground["left"] or me.ground["right"] ) {
        result = constant.TRUE;
    }

    me.switch.getChild("wow").setValue(result);

    return me.rates;
}

WeightSwitch.gear = func( name, aglft ) {
    # touch down
    if( me.slave["gear"][me.tyre[name]].getChild("wow").getValue() ) {
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


# ==========
# NOSE VISOR
# ==========

NoseVisor = {};

NoseVisor.new = func {
   var obj = { parents : [NoseVisor, System],

               nose : nil,
               nosectrl : nil,

               VISORDOWN : 0.0
         };

   obj.init();

   return obj;
};

NoseVisor.init = func() {
    me.init_ancestor("/instrumentation/nose-visor");

    me.nose = props.globals.getNode("/instrumentation/nose-visor");
    me.nosectrl = props.globals.getNode("/controls/nose-visor");

    me.VISORDOWN = getprop("/sim/flaps/setting[1]");
}

NoseVisor.has_nose_down = func {
   var result = constant.FALSE;

   if( me.nosectrl.getChild("pos-norm").getValue() > me.VISORDOWN ) {
       result = constant.TRUE;
   }

   return result;
}

NoseVisor.is_visor_down = func {
   var result = constant.FALSE;

   if( me.nose.getChild("pos-norm").getValue() >= me.VISORDOWN ) {
       result = constant.TRUE;
   }

   return result;
}

NoseVisor.can_up = func {
   var result = constant.FALSE;

   if( me.slave["hydraulic"].getChild("green").getValue() ) {
       # raising of visor is not allowed, if wiper is not parked
       if( me.slave["wiper"].getValue() ) {
           if( me.has_nose_down() ) {
               result = constant.TRUE;
           }
           elsif( me.nosectrl.getChild("wiper-override").getValue() ) {
               result = constant.TRUE;
           }
       }
       else {
           result = constant.TRUE;
       }
   }

   return result;
}

NoseVisor.can_down = func {
   var result = constant.FALSE;

   if( me.slave["hydraulic"].getChild("green").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

NoseVisor.can_standby = func {
   var result = constant.FALSE;

   if( me.slave["hydraulic"].getChild("yellow").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

NoseVisor.standbyexport = func {
   if( me.can_standby() ) {
       override_flapsDown(1);
   }
}



# ======================
# FLIGHT CONTROLS SYSTEM
# ======================

Flight = {};

Flight.new = func {
   var obj = { parents : [Flight,System], 

           FLIGHTSEC : 3.0,                               # refresh rate

           channels : nil
         };

    obj.init();

    return obj;
}

Flight.init = func() {
    me.channels = props.globals.getNode("/controls/flight/channel");

    me.init_ancestor("/systems/flight");
}

Flight.resetexport = func {
   var green = constant.FALSE;

   if( !me.slave["hydraulic"].getChild("blue").getValue() ) {
       green = me.slave["hydraulic"].getChild("green").getValue();

       if( !me.channels.getChild("inner-mechanical").getValue() ) {
           if( !green ) {
               me.channels.getChild("inner-mechanical").setValue( constant.TRUE );
           }
           elsif( me.channels.getChild("inner-blue").getValue() ) {
               me.channels.getChild("inner-blue").setValue( constant.FALSE );
           }
       }

       if( !me.channels.getChild("outer-mechanical").getValue() ) {
           if( !green ) {
               me.channels.getChild("outer-mechanical").setValue( constant.TRUE );
           }
           elsif( me.channels.getChild("outer-blue").getValue() ) {
               me.channels.getChild("outer-blue").setValue( constant.FALSE );
           }
       }

       if( !me.channels.getChild("rudder-mechanical").getValue() ) {
           if( !green ) {
               me.channels.getChild("rudder-mechanical").setValue( constant.TRUE );
           }
           elsif( me.channels.getChild("rudder-blue").getValue() ) {
               me.channels.getChild("rudder-blue").setValue( constant.FALSE );
           }
       }
   } 
}

Flight.red_pfc = func {
   var result = constant.FALSE;

   if( !me.channels.getChild("inner-blue").getValue() or
       me.channels.getChild("inner-mechanical").getValue() or
       !me.channels.getChild("outer-blue").getValue() or
       me.channels.getChild("outer-mechanical").getValue() or
       !me.channels.getChild("rudder-blue").getValue() or
       me.channels.getChild("rudder-mechanical").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Flight.schedule = func {
   # avoid reset by FDM or system initialization
   if( constant.system_ready() ) {
       me.resetexport();
   }
}
