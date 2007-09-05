# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ======
# ENGINE
# ======

Engine = {};

Engine.new = func {
   obj = { parents : [Engine],

           airdoor : AirDoor.new(),
           bucket : Bucket.new(),
           intake : Intake.new(),
           rating : Rating.new(),

           engines : nil,
           engcontrols : nil,

           CUTOFFSEC : 1.0,

           OILPSI : 15.0
         };

   obj.init();

   return obj;
};

Engine.init = func {
   me.engines = props.globals.getNode("/engines").getChildren("engine");
   me.engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");
}

Engine.amber_intake = func( index ) {
    return me.intake.amber_intake( index );
}

Engine.set_rate = func( rates ) {
   me.bucket.set_rate( rates );
}

Engine.set_throttle = func( position ) {
   return me.rating.set_throttle( position );
}

Engine.laneexport = func {
    me.intake.laneexport();
}

Engine.schedule = func {
    me.bucket.schedule();
    me.airdoor.schedule();
    me.rating.schedule();
}

Engine.slowschedule = func {
    me.intake.schedule();
}

Engine.red_engine = func( index ) {
    if( me.engines[index].getChild("oil-pressure-psi").getValue() > me.OILPSI ) {
        result = constant.FALSE;
    }
    else {
        result = constant.TRUE;
    }

    return result;
}

Engine.cutoffcron = func {
   for( i=0; i<4; i=i+1 ) {
       # engine start by user
       if( me.engines[i].getChild("starter").getValue() ) {
           if( me.engcontrols[i].getChild("cutoff").getValue() ) {
               me.engcontrols[i].getChild("cutoff").setValue(constant.FALSE);
           }
       }
   }
}

# simplified engine start (2D panel)
Engine.cutoffexport = func {
   # delay for starter
   settimer(func { me.cutoffcron(); }, me.CUTOFFSEC);
}


# =========
# ENGINE N1
# =========

EngineN1 = {};

EngineN1.new = func {
   obj = { parents : [EngineN1,System],

           engcontrols : nil,
           engines : nil,
           theengines : nil,

           THROTTLEMAX : 1.0,
           THROTTLE88N1 : 0.806,                          # doesn't depend of temperature
           THROTTLEREHEAT : 0.10,

           N1REHEAT : 81,

           reheat : [ constant.FALSE, constant.FALSE, constant.FALSE, constant.FALSE ],

           texpath : "Textures",

           engine4limiter : constant.FALSE,

           ENGINE4KT : 60.0
         };

   obj.init();

   return obj;
};

EngineN1.init = func {
    me.init_ancestor("/systems/engines");

    me.engines = props.globals.getNode("/engines").getChildren("engine");
    me.engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");
    me.theengines = props.globals.getNode("/systems/engines").getChildren("engine");
}

EngineN1.get_throttle = func( position ) {
    if( me.engine4limiter ) {
        maxthrottle = me.THROTTLE88N1;
    }
    else {
        maxthrottle = me.THROTTLEMAX;
    }

    if( position > maxthrottle ) {
        position = maxthrottle;
    }

    return position;
}

EngineN1.schedule = func {
    me.engine4();
    me.reheatcontrol();
}

# Engine 4 N1 takeoff limiter
EngineN1.engine4 = func {
    speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();

    # avoids engine 4 vibration because of turbulences
    if( speedkt != nil ) {

        # only below 60 kt
        if( speedkt < me.ENGINE4KT ) {
            me.engine4limiter = me.engcontrols[3].getChild("n1-to-limiter").getValue();
        }

        # normal control
        else {
             if( me.engine4limiter ) {
                 me.engine4limiter = constant.FALSE;

                # align throttle
                throttle = me.engcontrols[2].getChild("throttle").getValue();
                me.engcontrols[3].getChild("throttle").setValue(throttle);
            }
        }
    }
}

EngineN1.reheatcontrol = func {
   for( i = 0; i < 4; i = i+1 ) {
        if( me.engcontrols[i].getChild("reheat").getValue() and
            me.engcontrols[i].getChild("throttle").getValue() > me.THROTTLEREHEAT and
            me.engines[i].getChild("n1").getValue() > me.N1REHEAT ) {
            augmentation = constant.TRUE;
            factor = 1.0;
            texture = "concorde.rgb";
        }
        else {
            augmentation = constant.FALSE;
            factor = 0.0;
            texture = me.texpath ~ "/concorde-nozzle.rgb";
        }

        if( me.reheat[i] != augmentation ) {
            me.engcontrols[i].getChild("augmentation").setValue( augmentation );
            me.theengines[i].getChild("nozzle-factor").setValue(factor);
            me.theengines[i].getChild("nozzle-texture").setValue(texture);
            me.reheat[i] = augmentation;
        }
   }
}


# ======
# RATING
# ======

Rating = {};

Rating.new = func {
   obj = { parents : [Rating],

           enginen1 : EngineN1.new(),

           autothrottles : nil,
           engcontrols : nil,
           gears : nil,
           theengines : nil,

# contingency is not yet supported
           THROTTLETAKEOFF : 1.0,                         # N2 105.7 % (106.0 in Engines file)
           THROTTLECLIMB : 0.980,                         # N2 105.1 %
           THROTTLECRUISE : 0.967,                        # N2 104.5 % (guess)

           GEARLEFT : 1,
           GEARRIGHT : 3
         };

   obj.init();

   return obj;
};

Rating.init = func {
   me.autothrottles = props.globals.getNode("/autopilot/locks/autothrottle").getChildren("engine");
   me.engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");
   me.gears = props.globals.getNode("/gear").getChildren("gear");
   me.theengines = props.globals.getNode("/systems/engines").getChildren("engine");
}

Rating.set_throttle = func( position ) {
   # faster to process here
   for( i = 0; i < 4; i = i+1 ) {
        rating = me.engcontrols[i].getChild("rating").getValue();

        # autoland first
        if( rating == "takeoff" ) {
            maxthrottle = me.THROTTLETAKEOFF;
        }

        # flight
        else {
            rating = me.engcontrols[i].getChild("rating-flight").getValue();

            if( rating == "climb" ) {
                maxthrottle = me.THROTTLECLIMB;
            }

            # cruise
            else {
                maxthrottle = me.THROTTLECRUISE;
            }
        }

        if( position > maxthrottle ) {
            position = maxthrottle;
        }

        # engine N1 limiter
        if( i == 3 ) {
            position = me.enginen1.get_throttle( position );
        }

        # default, except autothrottle
        if( me.autothrottles[i].getValue() == "" ) {
            me.engcontrols[i].getChild("throttle").setValue( position );
        }

         # last human operation
        me.engcontrols[i].getChild("throttle-manual").setValue( position );
   }
}

Rating.schedule = func {
   me.enginen1.schedule();

   # arm takeoff rating
   for( i=0; i<4; i=i+1 ) {
        ratingnow = me.engcontrols[i].getChild("rating").getValue();
        if( ratingnow != "takeoff" ) {
            # engines 2 and 3 by right gear
            if( i > 0 and i < 3 ) {
                j = me.GEARRIGHT;
            }

            # engines 1 and 4 armed by left gear
            else {
                j = me.GEARLEFT;
            }

            if( me.gears[j].getChild("position-norm").getValue() == 1.0 ) {
                me.engcontrols[i].getChild("rating").setValue("takeoff");
            }
        }
   }

   monitor = getprop("/instrumentation/takeoff-monitor/armed");

   for( i=0; i<4; i=i+1 ) {
       rating = me.engcontrols[i].getChild("rating").getValue();
       reheat = me.engcontrols[i].getChild("reheat").getValue();

       if( reheat and rating == "takeoff" ) {
           # automatic contigency, if takeoff monitor
           if( monitor ) {
               me.engcontrols[i].getChild("contingency").setValue(constant.TRUE);
           }
       }
       elsif( !reheat and me.engcontrols[i].getChild("contingency").getValue() ) {
           me.engcontrols[i].getChild("contingency").setValue(constant.FALSE);
       }
   }

   # apply to engines
   for( i=0; i<4; i=i+1 ) {
        rating = me.engcontrols[i].getChild("rating").getValue();
        if( rating != "takeoff" ) {
            rating = me.engcontrols[i].getChild("rating-flight").getValue();
        }
        me.theengines[i].getChild("rating").setValue(rating);
   }
}


# =======================
# SECONDARY NOZZLE BUCKET
# =======================

Bucket = {};

Bucket.new = func {
   obj = { parents : [Bucket,System],

           TRANSITSEC : 6.0,                                   # reverser transit in 6 s
           BUCKETSEC : 1.0,                                    # refresh rate
           RATEDEG : 0.0,                                      # maximum rotation speed
           REVERSERDEG : 73.0,
           TAKEOFFDEG : 21.0,
           SUPERSONICDEG : 0.0,
           SUBSONICMACH : 0.55,
           SUPERSONICMACH : 1.1,
           COEF : 0.0,

           propulsions : nil,
           engcontrols : nil,
           engines : nil
         };

   obj.init();

   return obj;
};

Bucket.set_rate = func( rates ) {
   me.BUCKETSEC = rates;

   offsetdeg = me.REVERSERDEG - me.TAKEOFFDEG;
   me.RATEDEG = offsetdeg * ( me.BUCKETSEC / me.TRANSITSEC );
}

Bucket.init = func {
   me.init_ancestor("/systems/engines");

   me.propulsions = props.globals.getNode("/fdm/jsbsim/propulsion").getChildren("engine");

   me.engines = props.globals.getNode("/systems/engines").getChildren("engine");
   me.engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");

   me.set_rate( me.BUCKETSEC );

   denom = me.SUPERSONICMACH - me.SUBSONICMACH;
   me.COEF = me.TAKEOFFDEG / denom;
}

Bucket.schedule = func {
    me.position();
}

Bucket.increase = func( angledeg, maxdeg ) {
    angledeg = angledeg + me.RATEDEG;
    if( angledeg > maxdeg ) {
        angledeg = maxdeg;
    }

    return angledeg;
}

Bucket.decrease = func( angledeg, mindeg ) {
    angledeg = angledeg - me.RATEDEG;
    if( angledeg < mindeg ) {
        angledeg = mindeg;
    }

    return angledeg;
}

Bucket.apply = func( property, angledeg, targetdeg ) {
   if( angledeg != targetdeg ) {
       offsetdeg = targetdeg - angledeg;
       if( offsetdeg > 0 ) {
           valuedeg = me.increase( angledeg, targetdeg );
       }
       else {
           valuedeg = me.decrease( angledeg, targetdeg );
       }
       interpolate( property, valuedeg, me.BUCKETSEC );
   }
}

# bucket position
Bucket.position = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();
   # takeoff : 21 deg
   if( speedmach < me.SUBSONICMACH ) {
       bucketdeg = me.TAKEOFFDEG;
   }
   # subsonic : 21 to 0 deg
   elsif( speedmach <= me.SUPERSONICMACH ) {
       step = speedmach - me.SUBSONICMACH;
       bucketdeg = me.TAKEOFFDEG - me.COEF * step;
   }
   # supersonic : 0 deg
   else {
       bucketdeg = me.SUPERSONICDEG;
   }

   for( i=0; i<4; i=i+1 ) {
       # CAUTION : use controls, because there is a delay by /engines/engine[0]/reversed !
       if( me.engcontrols[i].getChild("reverser").getValue() ) {
           # reversed : 73 deg
           angledeg = me.REVERSERDEG;
           valuedeg = angledeg;
       }
       else {
           angledeg = 0.0;
           valuedeg = bucketdeg;
       }

       result = me.engines[i].getChild("bucket-deg").getValue();
       me.apply( "/systems/engines/engine[" ~ i ~ "]/bucket-deg", result, valuedeg );
# reverser was implemented by 0.9.9
#       result = me.propulsions[i].getChild("reverser-angle").getValue();
#       me.apply( "/fdm/jsbsim/propulsion/engine[" ~ i ~ "]/reverser-angle", result, angledeg );
   }
}


# ===================
# SECONDARY AIR DOORS
# ===================

AirDoor = {};

AirDoor.new = func {
   obj = { parents : [AirDoor,System],

           ENGINESMACH : 0.26,
           ENGINE4KT : 220.0,

           engines : nil,
           engcontrols : nil
         };

   obj.init();

   return obj;
};

AirDoor.init = func {
   me.engines = props.globals.getNode("/systems/engines").getChildren("engine");
   me.engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");

   me.init_ancestor("/systems/engines");
}

# air door position
AirDoor.schedule = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();
   speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();

   touchdown = getprop("/instrumentation/weight-switch/wow");

   # engines 1 to 3 :
   for( i=0; i<3; i=i+1 ) {
       if( me.engcontrols[i].getChild("secondary-air-door").getValue() ) {
           value = me.engines[i].getChild("secondary-air-door").getValue();
           # opens above Mach 0.26
           if( !value ) {
               if( speedmach > me.ENGINESMACH ) {
                   value = constant.TRUE;
               }
           }
           # shuts below Mach 0.26, if touch down
           elsif( speedmach < me.ENGINESMACH and touchdown ) {
               value = constant.FALSE;
           }
           me.engines[i].getChild("secondary-air-door").setValue(value);
       }
   }

   # engine 4
   if( me.engcontrols[3].getChild("secondary-air-door").getValue() ) {
       gearpos = getprop("/gear/gear[1]/position-norm");

       value = me.engines[3].getChild("secondary-air-door").getValue();
       # opens above 220 kt
       if( !value ) {
           if( speedkt > me.ENGINE4KT ) {
               value = constant.TRUE;
           }
       } 
       # shuts below Mach 0.26, gear down
       elsif( speedmach < me.ENGINESMACH and gearpos == 1.0 ) {
           value = constant.FALSE;
       }
       me.engines[3].getChild("secondary-air-door").setValue(value);
   }
}


# ===========
# INTAKE RAMP
# ===========

Intake = {};

Intake.new = func {
   obj = { parents : [Intake,System],

           MAXRAMP : 50.0,
           MINRAMP : 0.0,
           MAXMACH : 2.02,
           MINMACH : 1.3,
           INLETMACH : 0.75,
           OFFSETMACH : 0.0,

           LANEA : 2,
           LANEAUTOA : 0,

           POSSUBSONIC : 1.0,
           POSSUPERSONIC : 0.0,

           enginecontrol : nil,
           enginesystem : nil,
           engines : nil,

           hydmain : [ "green", "green", "blue", "blue" ],

           lane : [ constant.TRUE, constant.FALSE ]
         };

   obj.init();

   return obj;
};

Intake.init = func {
   me.init_ancestor("/systems/engines");

   me.enginecontrol = props.globals.getNode("/controls/engines").getChildren("engine");
   me.enginesystem = props.globals.getNode("/systems/engines");
   me.engines = props.globals.getNode("/systems/engines").getChildren("engine");

   me.OFFSETMACH = me.MAXMACH - me.MINMACH;
}

# main system failure
Intake.amber_intake = func( index ) {
    # auto or green / blue selected
    if( !me.slave["hydraulic"].getChild(me.hydmain[index]).getValue() and
        me.engines[index].getChild("intake-main").getValue() ) {
        result = constant.TRUE;
    }

    # yellow selected
    elsif( !me.slave["hydraulic"].getChild("yellow").getValue() and
           me.engines[index].getChild("intake-standby").getValue() ) {
        result = constant.TRUE;
    }

    else {
        result = constant.FALSE;
    }

    return result;
}

Intake.laneexport = func {
   for( i=0; i<4; i=i+1 ) {
        selector = me.enginecontrol[i].getChild("intake-selector").getValue();

        if( selector == me.LANEAUTOA or selector == me.LANEA ) {
            me.lane[0] = constant.TRUE;
            me.lane[1] = constant.FALSE;
        }
        else {
            me.lane[0] = constant.FALSE;
            me.lane[1] = constant.TRUE;
        }

        for( j=0; j<2; j=j+1 ) {
             me.engines[i].getChild("intake-lane", j).setValue(me.lane[j]);
        }
   }
}

Intake.schedule = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();

   me.auxilliaryinlet( speedmach );
   me.ramphydraulic();
   me.rampposition( speedmach );
}

Intake.auxilliaryinlet = func( speedmach ) {
   if( speedmach < me.INLETMACH ) {
       pos = constant.TRUE;
   }
   else {
       pos = constant.FALSE;
   }

   for( i=0; i<4; i=i+1 ) {
        me.engines[i].getChild("intake-aux-inlet").setValue(pos);
   }
}

Intake.ramphydraulic = func {
   for( i=0; i<4; i=i+1 ) {
        if( me.enginecontrol[i].getChild("intake-auto").getValue() ) {
            main = constant.TRUE;
            standby = !me.slave["hydraulic"].getChild(me.hydmain[i]).getValue();
        }
        else {
            main = me.enginecontrol[i].getChild("intake-main").getValue();
            standby = !main;
        }

        me.engines[i].getChild("intake-main").setValue(main);
        me.engines[i].getChild("intake-standby").setValue(standby);
   }
}

Intake.rampposition = func( speedmach ) {
   if( speedmach <= me.MINMACH ) {
       ramppercent = me.MINRAMP;
       rampsubsonic = me.POSSUBSONIC;
   }
   elsif( speedmach > me.MINMACH and speedmach < me.MAXMACH ) {
       stepmach = speedmach - me.MINMACH;
       coef = stepmach / me.OFFSETMACH;
       ramppercent = me.MAXRAMP * coef;
       rampsubsonic = me.POSSUPERSONIC;
   }
   else {
       ramppercent = me.MAXRAMP;
       rampsubsonic = me.POSSUPERSONIC;
   }

   hydfailure = constant.FALSE;
   for( i=0; i<4; i=i+1 ) {
        if( me.amber_intake(i) ) {
            hydfailure = constant.TRUE;
            break;
        }
   }

   # TO DO : effect of throttle on intake pressure ratio error

   # engineer moves ramp manually
   if( hydfailure ) {
       for( i=0; i<4; i=i+1 ) {
            pospercent = me.engines[i].getChild("ramp-percent").getValue();

            # to the left (negativ), if throttle lever must be retarded
            ratio = ( ramppercent - pospercent ) / me.MAXRAMP;

            ratiopercent = ratio * 100;
            me.engines[i].getChild("intake-ratio-error").setValue(ratiopercent);
       }

       # ramp is too much closed (supercritical)
       if( ratio < 0.0 ) {
           if( rampsubsonic == me.POSSUBSONIC ) {
               rampsubsonic = me.superramp( ratio, me.POSSUPERSONIC, rampsubsonic );
           }
           else {
               rampsubsonic = me.superramp( ratio, me.POSSUBSONIC, rampsubsonic );
           }
       }

       # ramp is too much opened (subcritical)
       elsif( ratio > 0.0 ) {
           if( rampsubsonic == me.POSSUPERSONIC ) {
               rampsubsonic = me.subramp( ratio, me.POSSUBSONIC, rampsubsonic );
           }
           else {
               rampsubsonic = me.subramp( ratio, me.POSSUPERSONIC, rampsubsonic );
           }
       }
   }

   # hydraulics moves intake ramp
   else {
       for( i=0; i<4; i=i+1 ) {
            me.engines[i].getChild("ramp-percent").setValue(ramppercent);
            me.engines[i].getChild("intake-ratio-error").setValue(0.0);
       }
   }

   # JSBSim can disable only 4 intakes at once
   me.enginesystem.getChild("intake-subsonic").setValue(rampsubsonic);
}

Intake.superramp = func( ratio, target, present ) {
   result = present - ( target - present ) * ratio;

   return result;
}

Intake.subramp = func( ratio, target, present ) {
   result = present + ( target - present ) * ratio;

   return result;
}
