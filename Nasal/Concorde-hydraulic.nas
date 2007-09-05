# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ================
# HYDRAULIC SYSTEM
# ================

Hydraulic = {};

Hydraulic.new = func {
   obj = { parents : [Hydraulic,System], 

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

Hydraulic.amber_hydraulics = func {
    if( me.sensors.getChild("green-left").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("green-right").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("yellow-left").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("yellow-right").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("blue-left").getValue() < me.HYDFAILUREPSI or
        me.sensors.getChild("blue-right").getValue() < me.HYDFAILUREPSI ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Hydraulic.red_intake = func( index ) {
    if( me.sensors.getChild("intake", index).getValue() < me.HYDFAILUREPSI ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Hydraulic.red_feel = func {
    if( me.has_green() or me.has_blue() ) {
        result = constant.FALSE;
    }
    else {
        result = constant.TRUE;
    }

    return result;
}

Hydraulic.has_green = func {
   if( me.sensors.getChild("green").getValue() >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Hydraulic.has_yellow = func {
   if( me.sensors.getChild("yellow").getValue() >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Hydraulic.has_blue = func {
   if( me.sensors.getChild("blue").getValue() >= me.HYDFAILUREPSI ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# TO DO : disconnect hydraulics if gear neutral
Hydraulic.gear_up = func {
   result = constant.FALSE;

   if( me.slave["electric"].getChild("specific").getValue() ) {
       if( me.has_green() ) {
           if( me.noinstrument["agl"].getValue() > constantaero.GEARFT ) {
               if( !me.slave["gear"].getChild("neutral").getValue() and
                   me.slave["gear"].getChild("gear-down" ).getValue() ) {
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
           if( !me.slave["gear"].getChild("neutral").getValue() and
               !me.slave["gear"].getChild("gear-down" ).getValue() ) {
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

Hydraulic.schedule = func {
   me.ground.schedule();
   me.parser.schedule();

   greenpsi = me.sensors.getChild("green").getValue();
   yellowpsi = me.sensors.getChild("yellow").getValue();
   me.brakes.schedule( greenpsi, yellowpsi );

   me.power.getChild("blue").setValue( me.has_blue() );
   me.power.getChild("green").setValue( me.has_green() );
   me.power.getChild("yellow").setValue( me.has_yellow() );
}


# =============
# GROUND SUPPLY
# =============
HydGround = {};

HydGround.new = func {
   obj = { parents : [HydGround,System], 

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
   # magnetic release of the switch
   if( !me.slave["electric"].getChild("ground-service").getValue() ) {
       for( i = 0; i < 2; i = i+1 ) {
            me.hydpumps[i].getChild("switch").setValue(constant.FALSE);
       }

       me.circuits[0].getChild("ground").setValue( constant.FALSE );
       me.circuits[1].getChild("ground", 0).setValue( constant.FALSE );
       me.circuits[1].getChild("ground", 1).setValue( constant.FALSE );
       me.circuits[2].getChild("ground").setValue( constant.FALSE );
   }

   selector = me.ground.getChild("selector").getValue();

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
   obj = { parents : [Brakes,System], 

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
}

Brakes.set_rate = func( rates ) {
    me.HYDSEC = rates;
    me.BRAKERATEPSI = me.BRAKEPSIPSEC * me.HYDSEC;

    me.heat.set_rate( rates );
}

Brakes.has_emergency = func {
    # TO DO : failure only on left or right
    if( me.brakes.getChild("yellow-accu-psi").getValue() < me.BRAKEACCUPSI ) {
        result = constant.FALSE;
    }
    else {
        result = constant.TRUE;
    }

    return result;
}

Brakes.has = func {
    # TO DO : failure only on left or right
    if( me.brakes.getChild("green-accu-psi").getValue() < me.BRAKEACCUPSI and
        !me.has_emergency() ) {
        result = constant.FALSE;
    }
    else {
        result = constant.TRUE;
    }

    return result;
}

Brakes.schedule = func( greenpsi, yellowpsi ) {
   me.normal( greenpsi );
   me.emergency( yellowpsi );
   me.accumulator();

   me.heat.schedule();
}

Brakes.accumulator = func {
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

   # TO DO : automatic, until there is a brake lever
   if( !me.slave["gear"].getChild("brake-emergency").getValue() ) {
       if( me.normalaccupsi < me.BRAKEACCUPSI ) {
           me.slave["gear"].getChild("brake-emergency").setValue(constant.TRUE);
       }
   }
   else {
       if( me.normalaccupsi >= me.BRAKEACCUPSI ) {
           me.slave["gear"].getChild("brake-emergency").setValue(constant.FALSE);
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
   if( !me.slave["gear"].getChild("brake-emergency").getValue() ) {
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
   if( me.slave["gear"].getChild("brake-parking-lever").getValue() ) {
       # stays in the green area
       targetbrakepsi = me.truncate( targetbrakepsi, me.BRAKEGREENPSI );
       if( me.emergfailure( targetbrakepsi ) ) {
           # disable brake parking (keyboard)
           me.slave["gear"].getChild("brake-parking").setValue(0.0);
       }

       # visualize apply of parking brake
       else {
           me.slave["gear"].getChild("brake-parking").setValue(1.0);

           leftpsi = me.apply( "/controls/gear/brake-parking", me.leftemergpsi, targetbrakepsi );
           rightpsi = me.apply( "/controls/gear/brake-parking", me.rightemergpsi, targetbrakepsi );

           me.leftemergpsi = leftpsi;      # BUG ?
           me.rightemergpsi = rightpsi;      # BUG ?
       }
   }

   # ermergency brake failure
   elsif( me.slave["gear"].getChild("brake-emergency").getValue() ) {
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
       me.slave["gear"].getChild("brake-parking").setValue(0.0);

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


# ===========
# BRAKES HEAT
# ===========

# reference :
# ---------
#  - http://en.wikipedia.org/wiki/Concorde :
#  several hours of cooling (300-500 degC) after an aborted takeoff (before V1).

BrakesHeat = {};

BrakesHeat.new = func {
   obj = { parents : [BrakesHeat,System], 

           HYDSEC : 1.0,

           brakes : nil,
           gear : nil,

           WARMKT2TODEGCPSEC : 0.0184,                 # (500 - 15 ) degc / ( 160 kt x 160 kt )

           lastspeedkt : 0.0,

           COOLDEGCPSEC : - 0.067,                     # ( 500 - 15 ) degc / 2 hours

           tempdegc : 0.0,
           tempmaxdegc : 0.0,
           stepdegc : 0.0
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
}

BrakesHeat.set_rate = func( rates ) {
    me.HYDSEC = rates;

    me.set_rate_ancestor( me.HYDSEC );

    me.COOLDEGCPSEC = me.COOLDEGCPSEC * me.HYDSEC;
    me.WARMKT2TODEGCPSEC = me.WARMKT2TODEGCPSEC * me.HYDSEC;
}

BrakesHeat.schedule = func {
   if( !me.warming() ) {
       me.cooling();
   }

   me.tempdegc = me.tempdegc + me.stepdegc;
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
   result = constant.FALSE;

   speedkt = me.noinstrument["airspeed"].getValue();

   if( me.noinstrument["agl"].getValue() < constantaero.AGLTOUCHFT ) {
       if( me.noinstrument["gear"].getValue() ) {
           left = me.gear.getChild("brake-left").getValue();
           right = me.gear.getChild("brake-right").getValue();
           allbrakes = left + right;

           if( allbrakes > 0.0 ) {
               # aborted takeoff at V1 (160 kt) heats until 300-500 degc
               if( speedkt < me.lastspeedkt ) {
                   # conversion of kinetic energy to heat
                   stepkt2 = ( me.lastspeedkt * me.lastspeedkt - speedkt * speedkt );
                   me.stepdegc = stepkt2 * me.WARMKT2TODEGCPSEC;
                   me.stepdegc = allbrakes * me.stepdegc;

                   result = constant.TRUE;
               }
           }
       }
   }

   me.lastspeedkt = speedkt;

   return result;
}

BrakesHeat.cooling = func {
   oatdegc = me.noinstrument["temperature"].getValue();
   me.stepdegc = oatdegc - me.tempdegc;

   # linear cooling
   if( !me.is_relocating() ) {
       me.stepdegc = constant.clip( me.COOLDEGCPSEC, - me.COOLDEGCPSEC, me.stepdegc );
   }
}


# ===============
# RAM AIR TURBINE
# ===============
Rat = {};

Rat.new = func {
   obj = { parents : [Rat],

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
   obj = { parents : [Gear],

           damper : PitchDamper.new()
         };

   obj.init();

   return obj;
}

Gear.init = func {
    settimer( func { me.schedule(); }, 5.0 );
}

Gear.schedule = func {
    rates = me.damper.schedule();

    settimer( func { me.schedule(); }, rates );
}


# ============
# PITCH DAMPER
# ============

PitchDamper = {};

PitchDamper.new = func {
   obj = { parents : [PitchDamper,System],

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
    result = me.thegear.getChild(me.field[name]).getValue();

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
   obj = { parents : [WeightSwitch,System],

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
    me.rates = me.AIRSEC;

    aglft = me.noinstrument["agl"].getValue();

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


# ======================
# FLIGHT CONTROLS SYSTEM
# ======================

Flight = {};

Flight.new = func {
   obj = { parents : [Flight,System], 

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
   if( !me.channels.getChild("inner-blue").getValue() or
       me.channels.getChild("inner-mechanical").getValue() or
       !me.channels.getChild("outer-blue").getValue() or
       me.channels.getChild("outer-mechanical").getValue() or
       !me.channels.getChild("rudder-blue").getValue() or
       me.channels.getChild("rudder-mechanical").getValue() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Flight.schedule = func {
   # avoid reset by FDM or system initialization
   if( constant.system_ready() ) {
       me.resetexport();
   }
}
