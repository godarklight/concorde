# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ======
# ENGINE
# ======

Engine = {};

Engine.new = func {
   obj = { parents : [Engine],

           enginen1 : EngineN1.new(),
           airdoor : AirDoor.new(),
           bucket : Bucket.new(),
           intake : Intake.new(),
           rating : Rating.new(),

           CUTOFFSEC : 1.0,

           N2MIN : 60.0
         };

   obj.init();

   return obj;
};

Engine.init = func {
}

Engine.set_rate = func( rates ) {
   me.bucket.set_rate( rates );
}

# engine controls
Engine.schedule = func {
    me.bucket.schedule();
    me.airdoor.schedule();
    me.rating.schedule();
}

# engine slow controls
Engine.slowschedule = func {
    me.intake.schedule();
}

# delay for starter
cutoffcron = func {
   engines = props.globals.getNode("/engines").getChildren("engine");
   engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");

   for( i=0; i<4; i=i+1 ) {
       # engine start by user
       if( engines[i].getChild("starter").getValue() ) {
           if( engcontrols[i].getChild("cutoff").getValue() ) {
               engcontrols[i].getChild("cutoff").setValue(constant.FALSE);
           }
       }
   }
}

# simplified engine start (2D panel)
Engine.cutoffexport = func {
    settimer(cutoffcron, me.CUTOFFSEC);
}

Engine.takeofflimiter = func {
   me.enginen1.takeofflimiter();
}


# =========
# ENGINE N1
# =========

EngineN1 = {};

EngineN1.new = func {
   obj = { parents : [EngineN1],

           N1MAX : 88.0,                                  # maximum N1
           N1LIMITER : 0.0,                               # lowest N1 during the control
           ENGINE4KT : 60.0,
           LOOKAHEADSEC : 0.25,                           # oscillations if too high
           NON1 : -1.0,
           lastn1 : 0.0,
           engine4limiter : constant.FALSE,

           engcontrols : nil,
           engines : nil,

           slave : { "asi" : nil }
         };

   obj.init();

   return obj;
};

EngineN1.init = func {
    propname = getprop("/systems/engines/slave/asi");
    me.slave["asi"] = props.globals.getNode(propname);

    me.engines = props.globals.getNode("/engines").getChildren("engine");
    me.engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");

    me.N1LIMITER = me.N1MAX - 0.5;
    me.lastn1 = me.NON1;

    me.takeofflimiter();
}

# cannot call settimer on a class function
takeofflimitercron = func {
    enginesystem.takeofflimiter();
}

# Engine 4 N1 takeoff limiter
EngineN1.takeofflimiter = func {
    speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();
    rates = 5.0;
    saven1 = me.NON1;

    # avoids engine 4 vibration because of turbulences
    if( speedkt != nil ) {

        # only below 60 kt
        if( speedkt < me.ENGINE4KT ) {
            rates = 0.1;

            if( me.engcontrols[3].getChild("n1-to-limiter").getValue() ) {
                n1 = me.engines[3].getChild("n1").getValue();
                saven1 = n1;

                # idle
                if( n1 < 35.0 ) {
                    rates = 1.0;
                }

                # look ahead
                n1ahead = n1;
                if( me.lastn1 != me.NON1 ) {
                    slope = (n1 - me.lastn1) / rates;
                    if( slope > 0 ) {
                        n1ahead = n1 + slope * me.LOOKAHEADSEC;
                    }
                }

                # limiter stable
                if( n1 >= me.N1LIMITER and n1 <= me.N1MAX ) {
                }

                # above 88 %
                elsif( n1ahead > me.N1MAX ) {
                    me.engine4limiter = constant.TRUE;

                    throttle = me.engcontrols[3].getChild("throttle").getValue();
                    throttle = throttle * me.N1LIMITER / n1ahead;
                    me.engcontrols[3].getChild("throttle").setValue(throttle);
                }

                # below 88 
                elsif( n1 < me.N1LIMITER and me.engine4limiter ) {
                     throttle3 = me.engcontrols[2].getChild("throttle").getValue();
                     throttle = me.engcontrols[3].getChild("throttle").getValue();

                     if( throttle < throttle3 ) {
                         throttle = throttle * me.N1MAX / n1;
                         me.engcontrols[3].getChild("throttle").setValue(throttle);
                     }

                     # returns to idle
                     else {
                         me.engine4limiter = constant.FALSE;
                     }
                }
            }
        }

        # normal control
        else {
             if( me.engine4limiter ) {
                 me.engine4limiter = constant.FALSE;

                # align throttle
                throttle = me.engcontrols[2].getChild("throttle").getValue();
                me.engcontrols[3].getChild("throttle").setValue(throttle);
            }

            if( speedkt < 100 ) {
                rates = 0.1;
            }

        }
    }

    me.lastn1 = saven1;

    settimer(takeofflimitercron,rates);
}


# ======
# RATING
# ======

Rating = {};

Rating.new = func {
   obj = { parents : [Rating],

           engines : nil,
           gears : nil,

           GEARLEFT : 1,
           GEARRIGHT : 3
         };

   obj.init();

   return obj;
};

Rating.init = func {
   me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
   me.gears = props.globals.getNode("/gear").getChildren("gear");
}

Rating.schedule = func {
   # arm takeoff rating
   for( i=0; i<4; i=i+1 ) {
        ratingnow = me.engines[i].getChild("rating").getValue();
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
                me.engines[i].getChild("rating").setValue("takeoff");
            }
        }
   }

   monitor = getprop("/instrumentation/takeoff-monitor/armed");

   for( i=0; i<4; i=i+1 ) {
       rating = me.engines[i].getChild("rating").getValue();
       augmentation = me.engines[i].getChild("augmentation").getValue();

       if( augmentation and rating == "takeoff" ) {
           # automatic contigency, if takeoff monitor
           if( monitor ) {
               me.engines[i].getChild("contingency").setValue(constant.TRUE);
           }
       }
       elsif( !augmentation and me.engines[i].getChild("contingency").getValue() ) {
           me.engines[i].getChild("contingency").setValue(constant.FALSE);
       }
   }
}


# =======================
# SECONDARY NOZZLE BUCKET
# =======================

Bucket = {};

Bucket.new = func {
   obj = { parents : [Bucket],

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
           engines : nil,

           slave : { "mach" : nil }
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
   propname = getprop("/systems/engines/slave/mach");
   me.slave["mach"] = props.globals.getNode(propname);

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
   obj = { parents : [AirDoor],

           ENGINESMACH : 0.26,
           ENGINE4KT : 220.0,

           engines : nil,
           engcontrols : nil,

           slave : { "asi" : nil, "mach" : nil }
         };

   obj.init();

   return obj;
};

AirDoor.init = func {
   me.engines = props.globals.getNode("/systems/engines").getChildren("engine");
   me.engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");

   propname = getprop("/systems/engines/slave/asi");
   me.slave["asi"] = props.globals.getNode(propname);
   propname = getprop("/systems/engines/slave/mach");
   me.slave["mach"] = props.globals.getNode(propname);
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
   obj = { parents : [Intake],

           MAXRAMP : 50.0,
           MINRAMP : 0.0,
           MAXMACH : 2.02,
           MINMACH : 1.3,
           OFFSETMACH : 0.0,

           engines : nil,

           slave : { "mach" : nil }
         };

   obj.init();

   return obj;
};

Intake.init = func {
   propname = getprop("/systems/engines/slave/mach");
   me.slave["mach"] = props.globals.getNode(propname);

   me.engines = props.globals.getNode("/systems/engines").getChildren("engine");

   me.OFFSETMACH = me.MAXMACH - me.MINMACH;
}

# ramp position
Intake.schedule = func {
   speedmach = me.slave["mach"].getChild("indicated-mach").getValue();
   if( speedmach <= me.MINMACH ) {
       ramppercent = me.MINRAMP;
   }
   elsif( speedmach > me.MINMACH and speedmach < me.MAXMACH ) {
       stepmach = speedmach - me.MINMACH;
       coef = stepmach / me.OFFSETMACH;
       ramppercent = me.MAXRAMP * coef;
   }
   else {
       ramppercent = me.MAXRAMP;
   }

   for( i=0; i<4; i=i+1 ) {
       me.engines[i].getChild("ramp-percent").setValue(ramppercent);
   }
}
