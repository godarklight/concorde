# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =================
# ELECTRICAL SYSTEM
# =================

Electrical = {};

Electrical.new = func {
   var obj = { parents : [Electrical,System],

           relight : EmergencyRelight.new(),
           parser : ElectricalXML.new(),
           csd : ConstantSpeedDrive.new(),

           ELECSEC : 1.0,                                 # refresh rate

           SERVICEVOLT : 600.0,
           GROUNDVOLT : 110.0,
           SPECIFICVOLT : 20.0,
           NOVOLT : 0.0,

           ac : nil,
           dc : nil,
           emergency : nil,
           engines : nil,
           generator : nil,
           ground : nil,
           outputs : nil,
           power : nil,
           probes : nil
         };

   obj.init();

   return obj;
};

Electrical.init = func {
   me.ac = props.globals.getNode("/controls/electric/ac");
   me.dc = props.globals.getNode("/controls/electric/dc");
   me.emergency = props.globals.getNode("/controls/electric/ac/emergency");
   me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
   me.generator = props.globals.getNode("/controls/electric/ac/emergency/generator");
   me.ground = props.globals.getNode("/systems/electrical/ground-service");
   me.outputs = props.globals.getNode("/systems/electrical/outputs");
   me.power = props.globals.getNode("/systems/electrical/power");
   me.probes = props.globals.getNode("/systems/electrical/outputs/probe");

   me.init_ancestor("/systems/electrical");

   me.csd.set_rate( me.ELECSEC );
}

Electrical.set_rate = func( rates ) {
   me.ELECSEC = rates;
   me.csd.set_rate( me.ELECSEC );
}

Electrical.amber_electrical = func {
   var result = me.csd.amber_electrical();

   if( !result ) {
       for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
            if( !me.engines[i].getChild("master-alt").getValue() ) {
                result = constant.TRUE;
                break;
            }
       }
   }

   if( !result ) {
       if( me.probes.getChild( "ac-main", 0 ).getValue() <= me.SPECIFICVOLT or
           me.probes.getChild( "ac-main", 1 ).getValue() <= me.SPECIFICVOLT or
           me.probes.getChild( "ac-main", 2 ).getValue() <= me.SPECIFICVOLT or
           me.probes.getChild( "ac-main", 3 ).getValue() <= me.SPECIFICVOLT ) {
           result = constant.TRUE;
       }
       elsif( me.probes.getChild( "ac-essential", 0 ).getValue() <= me.SPECIFICVOLT or
              me.probes.getChild( "ac-essential", 1 ).getValue() <= me.SPECIFICVOLT or
              me.probes.getChild( "ac-essential", 2 ).getValue() <= me.SPECIFICVOLT or
              me.probes.getChild( "ac-essential", 3 ).getValue() <= me.SPECIFICVOLT ) {
           result = constant.TRUE;
       }
       elsif( !me.engines[0].getChild("master-bat").getValue() ) {
           result = constant.TRUE;
       }
       elsif( !me.dc.getChild("master-bat").getValue() ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Electrical.red_electrical = func {
   var result = constant.FALSE;

   if( me.probes.getChild("dc-main-a").getValue() <= me.SPECIFICVOLT or
       me.probes.getChild("dc-main-b").getValue() <= me.SPECIFICVOLT or
       me.probes.getChild("dc-essential-a").getValue() <= me.SPECIFICVOLT or
       me.probes.getChild("dc-essential-b").getValue() <= me.SPECIFICVOLT ) {
       result = constant.TRUE;
   }

   return result;
}

Electrical.red_doors = func {
    var result = constant.FALSE;

    if( me.ground.getChild("door").getValue() ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.emergencyrelightexport = func {
   me.relight.selectorexport();
}

Electrical.schedule = func {
    me.csd.schedule();
    me.parser.schedule();

    # no voltage at startup
    if( constant.system_ready() ) {
        me.emergency_generation();
    }

    # flags for other systems
    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         me.power.getChild("autopilot", i).setValue( me.has_autopilot(i) );
    }
    me.power.getChild("ground-service").setValue( me.has_ground_power() );
    me.power.getChild("specific").setValue( me.has_specific() );
}

Electrical.slowschedule = func {
    me.door();
    me.parser.slowschedule();
}

Electrical.groundserviceexport = func {
    var aglft = me.noinstrument["agl"].getValue();
    var speedkt = me.noinstrument["airspeed"].getValue();
    var powervolt = 0;

    if( aglft <  15 and speedkt < 15 ) {
        supply = me.ground.getChild("door").getValue();

        if( supply ) {
            powervolt = me.NOVOLT;
        }
        else {
            powervolt = me.SERVICEVOLT;
        }

        me.ground.getChild("door").setValue(!supply);
        me.ground.getChild("volts").setValue(powervolt);
    }
}

Electrical.emergency_generation = func {
    var engine12 = constant.TRUE;
    var auto = constant.FALSE;
    var bypass = constant.FALSE;
    var wow = constant.FALSE;
    var check = constant.FALSE;
    var status = constant.FALSE;

    # loss of green hydraulics for emergency generator
    if( !me.slave["engine"][0].getChild("running").getValue() and
        !me.slave["engine"][1].getChild("running").getValue() ) {
        engine12 = constant.FALSE;
    }

    # disconnect 17 X, because RAT can provide power only for 16 X
    me.emergency.getChild("asb").setValue( engine12 );


    # automatic start of emergency generator
    if( me.generator.getChild("arm").getValue() and
        !me.generator.getChild("selected").getValue() ) {

        auto = me.generator.getChild("auto").getValue();
        bypass = me.generator.getChild("ground-bypass").getValue();
        wow = me.slave["weight"].getChild("wow").getValue();

        # manual start
        if( !auto and !bypass ) {
            me.generator.getChild( "selected" ).setValue( constant.TRUE );
            check = constant.FALSE;
        }

        # automatic start on ground
        elsif( !auto and bypass ) {
            check = constant.TRUE;
        }

        # automatic start in flight
        elsif( auto and !wow ) {
            check = constant.TRUE;
        }

        # do nothing
        else {
            check = constant.FALSE;
        }


        # loss of engines 1 & 2
        if( check ) {
            if( !engine12 ) {
                me.generator.getChild( "selected" ).setValue( constant.TRUE );
                check = constant.FALSE;
            }
        }

        # fail of an AC Main busbar
        if( check ) {
            for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
                 if( me.probes.getChild( "ac-main", i ).getValue() <= me.SPECIFICVOLT ) {
                     me.generator.getChild( "selected" ).setValue( constant.TRUE );
                     break;
                 }
            }
        }
    }


    # automatic connection of a dead busbar
    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.probes.getChild( "ac-main", i ).getValue() > me.SPECIFICVOLT ) {
             status = constant.FALSE;
         }
         else {
             status = constant.TRUE;
         }

         me.emergency.getChild( "essential-auto", i ).setValue( status );
    }
}

# connection with delay by ground operator
Electrical.door = func {
    if( me.is_moving() ) {
        # door stays open, has forgotten to call for disconnection !
        me.ground.getChild("volts").setValue(me.NOVOLT);
    }
}

Electrical.has_specific = func {
    var result = constant.FALSE;
    var volts =  me.outputs.getChild("specific").getValue();

    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.SPECIFICVOLT ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.has_autopilot = func( index ) {
    var result = constant.FALSE;

    # autopilot[0] reserved for FG autopilot
    var index = index + 1;

    volts =  me.outputs.getChild("autopilot", index).getValue();
    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > 0 ) {
        result = constant.TRUE;
    }

    return result;
}

Electrical.has_ground_power = func {
    var result = constant.FALSE;
    var volts =  me.outputs.getNode("probe").getChild("ac-gpb").getValue();

    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.GROUNDVOLT ) {
        result = constant.TRUE;
    }

    return result;
}


# ===================
# CSD OIL TEMPERATURE
# ===================

ConstantSpeedDrive = {};

ConstantSpeedDrive.new = func {
   var obj = { parents : [ConstantSpeedDrive,System],

           ELECSEC : 1.0,                                 # refresh rate

           LOWPSI : 30.0,

           engines : nil
         };

   obj.init();

   return obj;
};

ConstantSpeedDrive.init = func {
   me.init_ancestor("/systems/electrical");

   me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
}

ConstantSpeedDrive.set_rate = func( rates ) {
   me.ELECSEC = rates;
}

ConstantSpeedDrive.amber_electrical = func {
   var result = constant.FALSE;

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        if( me.slave["engine2"][i].getChild("csd-oil-psi").getValue() <= me.LOWPSI ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

# oil temperature
ConstantSpeedDrive.schedule = func {
   var csd = constant.FALSE;
   var csdpressurepsi = 0.0;
   var oatdegc = 0.0;
   var egtdegc = 0.0;
   var egtdegf = 0.0;
   var inletdegc = 0.0;
   var diffdegc = 0.0;

   for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
       csd = me.engines[i].getChild("csd").getValue();
       if( csd ) {
           csdpressurepsi = me.slave["engine"][i].getChild("oil-pressure-psi").getValue();
       }
       else {
           csdpressurepsi = 0.0;
       }

       # not real
       interpolate("/systems/engines/engine[" ~ i ~ "]/csd-oil-psi",csdpressurepsi,me.ELECSEC);

       oatdegc = me.noinstrument["temperature"].getValue();

       # connected
       if( csd ) {
           egtdegf = me.slave["engine"][i].getChild("egt_degf").getValue();
           egtdegc = constant.fahrenheit_to_celsius( egtdegf );
       }

       # not real
       inletdegc = me.slave["engine2"][i].getChild("csd-inlet-degc").getValue();
       if( csd ) {
           inletdegc = egtdegc / 3.3;
       }
       # scale until 0 deg C
       else {
           inletdegc = inletdegc * 0.95;
       }
       if( inletdegc < oatdegc ) {
           inletdegc = oatdegc;
       }
       interpolate("/systems/engines/engine[" ~ i ~ "]/csd-inlet-degc",inletdegc,me.ELECSEC);

       # not real
       diffdegc = me.slave["engine2"][i].getChild("csd-diff-degc").getValue();
       if( csd ) {
           diffdegc = egtdegc / 17.0;
       }
       # scale until 0 deg C
       else {
           diffdegc = diffdegc * 0.95;
       }
       interpolate("/systems/engines/engine[" ~ i ~ "]/csd-diff-degc",diffdegc,me.ELECSEC);
   }
}


# =================
# EMERGENCY RELIGHT
# =================

EmergencyRelight = {};

EmergencyRelight.new = func {
   var obj = { parents : [EmergencyRelight],

           switches : [ -1, 1, 3, 2, 0 ],                     # maps selector to relight (-1 is off)

           emergrelights : nil,
           relights : nil
         };

   obj.init();

   return obj;
};

EmergencyRelight.init = func {
   me.emergrelights = props.globals.getNode("controls/electric/ac/emergency").getChildren("relight");
   me.relights = props.globals.getNode("controls/electric/ac").getChildren("relight");
}

EmergencyRelight.selectorexport = func {
   var switch = 0;
   var selector = getprop("controls/electric/ac/emergency/relight-selector");

   for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
        switch = me.switches[selector];

        # only 1 emergency relight has voltage, if selector not at 0
        if( i == switch ) {
            me.relights[i].setValue( constant.FALSE );
            me.emergrelights[i].setValue( constant.TRUE );
        }

        # all 4 relights have voltage, if selector at 0
        else {
            me.emergrelights[i].setValue( constant.FALSE );
            me.relights[i].setValue( constant.TRUE );
        }
   }
}


# =====
# WIPER
# =====

Wiper = {};

Wiper.new = func {
   var obj = { parents : [Wiper, System],

               noseinstrument : nil,

               wiper : nil,
               motors : nil,

               RAINSEC : 1.0,

               MOVEMENTSEC : [ 1.8, 0.8 ],

               ratesec : [ 0.0, 0.0 ],

               WIPERUP : 1.0,
               WIPERDELTA : 0.1,                            # interpolate may not completely reach its target
               WIPERDOWN : 0.0,

               WIPEROFF : 0
         };

   obj.init();

   return obj;
};

Wiper.init = func {
   me.init_ancestor("/instrumentation/wiper");

   me.wiper = props.globals.getNode("instrumentation/wiper");
   me.motors = props.globals.getNode("controls/wiper").getChildren("motor");
}

Wiper.set_relation = func( nose ) {
   me.noseinstrument = nose;
}

Wiper.schedule = func {
   if( me.slave["electric"].getChild("specific").getValue() ) {
       # disables wiper with visor up, since one cannot raise the visor with the wiper running.
       if( me.noseinstrument.is_visor_down() ) {
           me.motor();
       }
   }
}

Wiper.motor = func {
   var power = constant.FALSE;
   var stopped = constant.TRUE;
   var selector = 0;
   var pos = 0.0;

   for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
        selector =  me.motors[i].getChild("selector").getValue();

        if( selector > me.WIPEROFF ) {
            stopped = constant.FALSE;
            power = constant.TRUE;

            # returns to rest at the same speed.
            me.ratesec[i] = me.MOVEMENTSEC[selector-1]; 
        }
        else {
            stopped = constant.TRUE;
        }

        pos = me.motors[i].getChild("position-norm").getValue();

        # starts a new sweep.
        if( pos <= ( me.WIPERDOWN + me.WIPERDELTA ) ) {
            if( !stopped ) {
               interpolate("controls/wiper/motor[" ~ i ~ "]/position-norm",me.WIPERUP,me.ratesec[i]);
            }
        }

        # ends its sweep, even if off.
        elsif( pos >= ( me.WIPERUP - me.WIPERDELTA ) ) {
            power = constant.TRUE;
            interpolate("controls/wiper/motor[" ~ i ~ "]/position-norm",me.WIPERDOWN,me.ratesec[i]);
        }
   }

   me.wiper.getChild("power").setValue( power );
}


# ========
# LIGHTING
# ========

Lighting = {};

Lighting.new = func {
   var obj = { parents : [Lighting],

           compass : CompassLight.new(),
           internal : LightLevel.new(),
           landing : LandingLight.new()
         };

   obj.init();

   return obj;
};

Lighting.init = func {
   var strobe_switch = props.globals.getNode("controls/lighting/strobe", constant.FALSE);
   aircraft.light.new("controls/lighting/external/strobe", [ 0.03, 1.20 ], strobe_switch);
}

Lighting.schedule = func {
   me.compass.schedule();
   me.landing.schedule();
   me.internal.schedule();
}

Lighting.compassexport = func( level ) {
   me.compass.illuminateexport( level );
}

Lighting.extendexport = func {
   me.landing.extendexport();
}

Lighting.floodexport = func {
   me.internal.floodexport();
}

Lighting.roofexport = func {
   me.internal.roofexport();
}


# =====================
# STANDBY COMPASS LIGHT
# =====================

CompassLight = {};

CompassLight.new = func {
   var obj = { parents : [CompassLight, System],

           overhead : nil,

           BRIGHTNORM : 1.0,
           DIMNORM : 0.5,
           OFFNORM : 0.0,

           norm : 0.0
         };

   obj.init();

   return obj;
}

CompassLight.init = func {
   me.init_ancestor("/systems/lighting");

   me.overhead = props.globals.getNode("/controls/lighting/crew/overhead");

   me.norm = me.overhead.getChild("compass-norm").getValue();
}

CompassLight.schedule = func {
   var level = me.norm;

   if( !me.slave["electric"].getChild("specific").getValue() ) {
       level = me.OFFNORM;
   }

   me.overhead.getChild("compass-light").setValue( level );
}

CompassLight.illuminateexport = func( level ) {
   if( level == me.norm ) {
       me.norm = me.OFFNORM;
   }
   else {
       me.norm = level;
   }

   me.overhead.getChild("compass-norm").setValue( me.norm );

   me.schedule();
}


# =============
# LANDING LIGHT
# =============

LandingLight = {};

LandingLight.new = func {
   var obj = { parents : [LandingLight,System],

           lightsystem : nil,
           mainlanding : nil,
           landingtaxi : nil,

           EXTENDSEC : 8.0,                                # time to extend a landing light
           ROTATIONSEC : 2.0,                              # time to rotate a landing light

           ROTATIONNORM : 1.2,
           EXTENDNORM : 1.0,
           ERRORNORM : 0.1,                                # Nasal interpolate may not reach 1.0
           RETRACTNORM : 0.0,

           MAXKT : 365.0                                   # speed of automatic blowback
         };

   obj.init();

   return obj;
};

LandingLight.init = func {
   me.init_ancestor("/systems/lighting");

   me.lightsystem = props.globals.getNode("/systems/lighting");
   me.mainlanding = props.globals.getNode("/controls/lighting/external").getChildren("main-landing");
   me.landingtaxi = props.globals.getNode("/controls/lighting/external").getChildren("landing-taxi");
}

LandingLight.schedule = func {
   if( me.lightsystem.getChild("serviceable").getValue() ) {
       if( me.landingextended() ) {
           me.extendexport();
       }
   }
}

LandingLight.landingextended = func {
   var extension = constant.FALSE;

   # because of motor failure, may be extended with switch off, or switch on and not yet extended
   for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1) {
        if( me.mainlanding[i].getChild("norm").getValue() > 0 or
            me.mainlanding[i].getChild("extend").getValue() ) {
            extension = constant.TRUE;
            break;
        }
        if( me.landingtaxi[i].getChild("norm").getValue() > 0 or
            me.landingtaxi[i].getChild("extend").getValue() ) {
            extension = constant.TRUE;
            break;
        }
   }

   return extension;
}

# automatic blowback
LandingLight.landingblowback = func {
   if( me.slave["asi"].getChild("indicated-speed-kt").getValue() > me.MAXKT ) {
       for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1) {
            if( me.mainlanding[i].getChild("extend").getValue() ) {
                me.mainlanding[i].getChild("extend").setValue(constant.FALSE);
            }
            if( me.landingtaxi[i].getChild("extend").getValue() ) {
                me.landingtaxi[i].getChild("extend").setValue(constant.FALSE);
            }
       }
   }
}

# compensate approach attitude
LandingLight.landingrotate = func {
   # ground taxi
   var target = me.EXTENDNORM;

   # pitch at approach
   if( me.slave["radio-altimeter"].getChild("indicated-altitude-ft").getValue() > constantaero.AGLTOUCHFT ) {
       target = me.ROTATIONNORM;
   }

   return target;
}

LandingLight.landingmotor = func( light, present, target ) {
   var durationsec = 0.0;

   if( present < me.RETRACTNORM + me.ERRORNORM ) {
       if( target == me.EXTENDNORM ) {
           durationsec = me.EXTENDSEC;
       }
       elsif( target == me.ROTATIONNORM ) {
           durationsec = me.EXTENDSEC + me.ROTATIONSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   elsif( present > me.EXTENDNORM - me.ERRORNORM and present < me.EXTENDNORM + me.ERRORNORM ) {
       if( target == me.RETRACTNORM ) {
           durationsec = me.EXTENDSEC;
       }
       elsif( target == me.ROTATIONNORM ) {
           durationsec = me.ROTATIONSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   elsif( present > me.ROTATIONNORM - me.ERRORNORM ) {
       if( target == me.RETRACTNORM ) {
           durationsec = me.ROTATIONSEC + me.EXTENDSEC;
       }
       elsif( target == me.EXTENDNORM ) {
           durationsec = me.EXTENDSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   # motor in movement
   else {
       durationsec = 0.0;
   }

   if( durationsec > 0.0 ) {
       interpolate(light,target,durationsec);
   }
}

LandingLight.extendexport = func {
   var target = 0.0;
   var value = 0.0;
   var result = 0.0;
   var light = "";

   if( me.slave["electric"].getChild("specific").getValue() ) {

       # automatic blowback
       me.landingblowback();

       # activate electric motors
       target = me.landingrotate();

       for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
            if( me.mainlanding[i].getChild("extend").getValue() ) {
                value = target;
            }
            else {
                value = me.RETRACTNORM;
            }

            result = me.mainlanding[i].getChild("norm").getValue();
            if( result != value ) {
                light = "/controls/lighting/external/main-landing[" ~ i ~ "]/norm";
                me.landingmotor( light, result, value );
            }

            if( me.landingtaxi[i].getChild("extend").getValue() ) {
                value = target;
            }
            else {
                value = me.RETRACTNORM;
            }
 
            result = me.landingtaxi[i].getChild("norm").getValue();
            if( result != value ) {
                light = "/controls/lighting/external/landing-taxi[" ~ i ~ "]/norm";
                me.landingmotor( light, result, value );
            }
       }
   }
}


# ===========
# LIGHT LEVEL
# ===========

# the material animation is for instruments :
# - no blend of fluorescent and flood.
# - all object is illuminated, instead of only a surface.
LightLevel = {};

LightLevel.new = func {
   var obj = { parents : [LightLevel,System],

           lightcontrol : nil,
           lightsystem : nil,

# internal lights
           LIGHTFULL : 1.0,
           LIGHTINVISIBLE : 0.00001,                      # invisible offset
           LIGHTNO : 0.0,

           invisible : constant.TRUE,                     # force a change on 1st recover, then alternate

           fluorescent : "",
           fluorescentnorm : "",
           floods : [ "", "", "", "", "", "" ],
           floodnorms : [ "", "", "", "", "", "" ],
           nbfloods : 5,
           powerfailure : constant.FALSE
         };

   obj.init();

   return obj;
};

LightLevel.init = func {
   me.init_ancestor("/systems/lighting");

   me.lightcontrol = props.globals.getNode("/controls/lighting/crew");
   me.lightsystem = props.globals.getNode("/systems/lighting");

   # norm is user setting, light is animation
   me.fluorescent = "roof-light";
   me.fluorescentnorm = "roof-norm";

   me.floods[0] = "captain/flood-light";
   me.floods[1] = "copilot/flood-light";
   me.floods[2] = "center/flood-light";
   me.floods[3] = "engineer/flood-light";
   me.floods[4] = "engineer/spot-light";

   me.floodnorms[0] = "captain/flood-norm";
   me.floodnorms[1] = "copilot/flood-norm";
   me.floodnorms[2] = "center/flood-norm";
   me.floodnorms[3] = "engineer/flood-norm";
   me.floodnorms[4] = "engineer/spot-norm";
}

LightLevel.schedule = func {
   # clear all lights
   if( !me.slave["electric"].getChild("specific").getValue() or
       !me.lightsystem.getChild("serviceable").getValue() ) {
       me.powerfailure = constant.TRUE;
       me.failure();
   }

   # recover from failure
   elsif( me.powerfailure ) {
       me.powerfailure = constant.FALSE;
       me.recover();
   }
}

LightLevel.failure = func {
   me.fluofailure();
   me.floodfailure();
}

LightLevel.fluofailure = func {
   me.lightcontrol.getNode(me.fluorescent).setValue(me.LIGHTNO);
}

LightLevel.floodfailure = func {
   for( var i=0; i < me.nbfloods; i=i+1 ) {
        me.lightcontrol.getNode(me.floods[i]).setValue(me.LIGHTNO);
   }
}

LightLevel.recover = func {
   me.fluorecover();
   me.floodrecover();
}

LightLevel.fluorecover = func {
   if( !me.powerfailure ) {
       me.failurerecover(me.fluorescentnorm,me.fluorescent,constant.FALSE);
   }
}

LightLevel.floodrecover = func {
   if( !me.lightcontrol.getChild("roof").getValue() and !me.powerfailure ) {
       for( var i=0; i < me.nbfloods; i=i+1 ) {
            # may change a flood light, during a fluo lighting
            me.failurerecover(me.floodnorms[i],me.floods[i],me.invisible);
       }
   }
}

# was no light, because of failure, or the knob has changed
LightLevel.failurerecover = func( propnorm, proplight, offset ) {
   var norm = me.lightcontrol.getNode(propnorm).getValue();

   if( norm != me.lightcontrol.getNode(proplight).getValue() ) {

       # flood cannot recover from fluorescent light without a change
       if( offset ) {
           if( norm > me.LIGHTNO and me.invisible ) {
               norm = norm - me.LIGHTINVISIBLE;
           }
       }

       me.lightcontrol.getNode(proplight).setValue(norm);
   }
}

LightLevel.floodexport = func {
   me.floodrecover();
}

LightLevel.roofexport = func {
   var value = 0.0;

   if( me.lightcontrol.getChild("roof").getValue() ) {
       value = me.LIGHTFULL;

       # no blend with flood
       me.floodfailure();
   }
   else {
       value = me.LIGHTNO;

       me.invisible = !me.invisible;

       me.floodrecover();
   }

   me.lightcontrol.getNode(me.fluorescentnorm).setValue(value);
   me.fluorecover();
}


# ==========
# ANTI-ICING
# ==========

# reference :
# ---------
#  - http://fr.wikipedia.org/wiki/Concorde :
#  electric anti-icing (no air piping).

Antiicing = {};

Antiicing.new = func {
   var obj = { parents : [Antiicing,System],

           detector : Icedetection.new(),

           engines : nil,
           icingsystem : nil,
           outputs : nil,
           wings : nil
         };

   obj.init();

   return obj;
};

Antiicing.init = func {
    me.init_ancestor("/systems/anti-icing");

    me.engines = props.globals.getNode("/controls/anti-ice").getChildren("engine");
    me.icingsystem = props.globals.getNode("/systems/anti-icing");
    me.outputs = props.globals.getNode("/systems/anti-icing/power");
    me.wing = props.globals.getNode("/controls/anti-ice/wing");
}

Antiicing.red_ice = func {
    var result = constant.FALSE;

    if( me.icingsystem.getChild("warning").getValue() ) {
        if( !me.outputs.getChild("wing").getValue() ) {
            result = constant.TRUE;
        }
       
        else {
            for( i = 0; i < constantaero.NBENGINES; i=i+1 ) {
                 if( !me.outputs.getChild("engine",i).getValue() ) {
                     result = constant.TRUE;
                     break;
                 }
            }
        }
    }

    return result;
}

Antiicing.schedule = func {
    var serviceable = me.icingsystem.getChild("serviceable").getValue();
    var power = me.slave["electric"].getChild("specific").getValue();
    var value = constant.FALSE;

    if( ( me.wing.getChild("main-selector").getValue() > 0 or
          me.wing.getChild("alternate-selector").getValue() > 0 ) and
          power and serviceable ) {
        value = constant.TRUE;
    }

    me.outputs.getChild("wing").setValue( value );

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.engines[i].getChild("inlet-vane").getValue() and
             power and serviceable ) {
             value = constant.TRUE;
         }
         else {
             value = constant.FALSE;
         }

         me.outputs.getChild("engine", i).setValue( value );
    }
}

Antiicing.slowschedule = func {
    me.detector.schedule();
}
