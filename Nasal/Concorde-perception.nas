# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# This file is common to voice and crew


# =====
# STATE
# =====

State = {};

State.new = func {
   var obj = { parents : [State], 

               has_state : constant.FALSE
             };

   return obj;
}

State.set_state = func( set ) {
    me.has_state = set;
}

State.is_state = func {
    return me.has_state;
}


# =======
# CALLOUT
# =======

Callout = {};

Callout.new = func {
   var obj = { parents : [Callout], 
               
               callout : "holding"                   # otherwise startup is a long time without callout
             };
   
   return obj;
}

Callout.is_flight = func {
    var result = constant.FALSE;

    if( me.callout == "flight" ) {
        result = constant.TRUE;
    }

    return result;
}

Callout.is_landing = func {
    var result = constant.FALSE;

    if( me.callout == "landing" ) {
        result = constant.TRUE;
    }

    return result;
}

Callout.is_goaround = func {
    var result = constant.FALSE;

    if( me.callout == "goaround" ) {
        result = constant.TRUE;
    }

    return result;
}

Callout.is_taxiway = func {
    var result = constant.FALSE;

    if( me.callout == "taxiway" ) {
        result = constant.TRUE;
    }

    return result;
}

Callout.is_terminal = func {
    var result = constant.FALSE;

    if( me.callout == "terminal" ) {
        result = constant.TRUE;
    }

    return result;
}

Callout.is_gate = func {
    var result = constant.FALSE;

    if( me.callout == "gate" ) {
        result = constant.TRUE;
    }

    return result;
}

Callout.is_holding = func {
    var result = constant.FALSE;

    if( me.callout == "holding" ) {
        result = constant.TRUE;
    }

    return result;
}

Callout.is_takeoff = func {
    var result = constant.FALSE;

    if( me.callout == "takeoff" ) {
        result = constant.TRUE;
    }

    return result;
}


# =========
# CHECKLIST
# =========

Checklist = {};

Checklist.new = func( path ) {
   var obj = { parents : [Checklist,System.new( path )], 

               checklist : ""
             };

   return obj;
}

Checklist.set_checklist = func {
    me.checklist = me.dependency["voice"].getChild("checklist").getValue();
}

Checklist.is_nochecklist = func {
    var result = constant.FALSE;

    if( me.checklist == "" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_aftertakeoff = func {
    var result = constant.FALSE;

    if( me.checklist == "aftertakeoff" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_climb = func {
    var result = constant.FALSE;

    if( me.checklist == "climb" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_transsonic = func {
    var result = constant.FALSE;

    if( me.checklist == "transsonic" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_cruiseclimb = func {
    var result = constant.FALSE;

    if( me.checklist == "cruiseclimb" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_descent = func {
    var result = constant.FALSE;

    if( me.checklist == "descent" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_approach = func {
    var result = constant.FALSE;

    if( me.checklist == "approach" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_beforelanding = func {
    var result = constant.FALSE;

    if( me.checklist == "beforelanding" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_afterlanding = func {
    var result = constant.FALSE;

    if( me.checklist == "afterlanding" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_parking = func {
    var result = constant.FALSE;

    if( me.checklist == "parking" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_stopover = func {
    var result = constant.FALSE;

    if( me.checklist == "stopover" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_external = func {
    var result = constant.FALSE;

    if( me.checklist == "external" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_preliminary = func {
    var result = constant.FALSE;

    if( me.checklist == "preliminary" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_cockpit = func {
    var result = constant.FALSE;

    if( me.checklist == "cockpit" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_beforestart = func {
    var result = constant.FALSE;

    if( me.checklist == "beforestart" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_enginestart = func {
    var result = constant.FALSE;

    if( me.checklist == "enginestart" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_pushback = func {
    var result = constant.FALSE;

    if( me.checklist == "pushback" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_started = func {
    var result = constant.FALSE;

    if( me.checklist == "started" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_afterstart = func {
    var result = constant.FALSE;

    if( me.checklist == "afterstart" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_taxi = func {
    var result = constant.FALSE;

    if( me.checklist == "taxi" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_runway = func {
    var result = constant.FALSE;

    if( me.checklist == "runway" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_beforetakeoff = func {
    var result = constant.FALSE;

    if( me.checklist == "beforetakeoff" ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.set_startup = func {
    me.dependency["crew"].getChild("startup").setValue( constant.TRUE );
}

Checklist.unset_startup = func {
    me.dependency["crew"].getChild("startup").setValue( constant.FALSE );
}

Checklist.is_startup = func {
    var result = constant.FALSE;

    if( me.dependency["crew"].getChild("startup").getValue() ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.set_completed = func {
    me.dependency["crew"].getChild("completed").setValue( constant.TRUE );
}

Checklist.unset_completed = func {
    me.dependency["crew"].getChild("completed").setValue( constant.FALSE );

    # reset keyboard detection
    me.dependency["crew-ctrl"].getChild("recall").setValue( constant.FALSE );
}

Checklist.is_completed = func {
    var result = constant.FALSE;

    if( me.dependency["crew"].getChild("completed").getValue() ) {
        result = constant.TRUE;
    }

    return result;
}

Checklist.is_recall = func {
    var result = constant.FALSE;

    if( me.dependency["crew-ctrl"].getChild("recall").getValue() ) {
        result = constant.TRUE;
    }

    return result;
}


# =========
# EMERGENCY
# =========

Emergency = {};

Emergency.new = func( path ) {
   var obj = { parents : [Emergency, Checklist.new( path )], 

               emergency : ""
             };

   return obj;
}

Emergency.set_emergency = func {
    me.emergency = me.dependency["voice"].getChild("emergency").getValue();
}

Emergency.is_emergency = func {
    var result = constant.FALSE;

    if( me.emergency != "" ) {
        result = constant.TRUE;
    }

    return result;
}

Emergency.is_fourengineflameout = func {
    var result = constant.FALSE;

    if( me.emergency == "fourengineflameout" ) {
        result = constant.TRUE;
    }

    return result;
}

Emergency.is_fourengineflameoutmach1 = func {
    var result = constant.FALSE;

    if( me.emergency == "fourengineflameoutmach1" ) {
        result = constant.TRUE;
    }

    return result;
}


# ===========
# VOICE PHASE 
# ===========

Voicephase = {};

Voicephase.new = func( path ) {
   var obj = { parents : [Voicephase,System.new(path)],
   
               acceleration : Speedperception.new(),
               flightlevel : Altitudeperception.new(),

               CLIMBFASTFPM : 750,
               CLIMBFPM : 100,
               LEVELFPM : 0,
               DECAYFPM : -50,                       # not zero, to avoid false alarm
               DESCENTFPM : -100,
               DESCENTFASTFPM : -750,
               FINALFPM : -1000,

               aglft : 0.0,
               altitudeft : 0.0,
               
               lastaltitudeft : 0.0,
               
               mach : 0.0,
               
               groundkt : 0.0,
               speedkt : 0.0,

               lastspeedkt : 0.0,
               
               speedfpm : 0.0
         };

   return obj;
}

Voicephase.set_rates = func( steps ) {
    me.flightlevel.set_rates( steps );
    me.acceleration.set_rates( steps );
}

Voicephase.set_level = func {
   me.flightlevel.setlevel( me.altitudeft );
}

Voicephase.schedule = func ( emergency = 0 ) {
   me.mach = me.dependency["mach"].getChild("indicated-mach").getValue();
   me.groundkt = me.dependency["ins-computed"].getChild("ground-speed-fps").getValue() * constant.FPSTOKT;
   me.aglft = me.dependency["radio-altimeter"].getChild("indicated-altitude-ft").getValue();
   me.speedfpm = me.dependency["ivsi"].getChild("indicated-speed-fps").getValue() * constant.MINUTETOSECOND;
   
   me.airspeedperception( emergency );
   me.altitudeperception( emergency );
   
   me.acceleration.schedule( me.speedkt, me.lastspeedkt );

   # 1 cycle
   me.flightlevel.schedule( me.speedfpm );
   
   # snapshot
   me.lastspeedkt = me.speedkt;
   me.lastaltitudeft = me.altitudeft;
}

Voicephase.altitudeperception = func( emergency ) {
   if( me.dependency["altimeter"].getChild("serviceable").getValue() and !emergency ) {
       me.altitudeft = me.dependency["altimeter"].getChild("indicated-altitude-ft").getValue()
   }
   else {
       me.altitudeft = me.noinstrument["altitude"].getValue();
   }
}

Voicephase.airspeedperception = func( emergency ) {
   if( me.dependency["airspeed"].getChild("serviceable").getValue() and
       !me.dependency["airspeed"].getChild("failure-flag").getValue() and !emergency ) {
       me.speedkt = me.dependency["airspeed"].getChild("indicated-speed-kt").getValue()
   }
   else {
       me.speedkt = me.noinstrument["airspeed"].getValue();
   }
}

Voicephase.on_ground = func {
   var result = constant.FALSE;

   if( me.aglft < constantaero.AGLTOUCHFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_agl_liftoff = func {
   var result = constant.FALSE;

   if( me.aglft > constantaero.LIFTOFFFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_agl_climb = func {
   var result = constant.FALSE;

   if( me.aglft > constantaero.CLIMBFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_agl_reheat = func {
   var result = constant.FALSE;

   if( me.aglft > constantaero.REHEATFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_agl_landing = func {
   var result = constant.FALSE;

   if( me.aglft < constantaero.LANDINGFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_agl_below = func( thresholdft ) {
   var result = constant.FALSE;

   if( me.aglft < thresholdft ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_agl_below_level = func( thresholdft ) {
   var result = constant.FALSE;

   if( me.aglft < me.flightlevel.climbft( thresholdft ) ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_mach_climb = func {
   var result = constant.FALSE;

   if( me.mach > constantaero.CLIMBMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_mach_supersonic = func {
   var result = constant.FALSE;

   if( me.mach >= constantaero.SOUNDMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_mach_cruise = func {
   var result = constant.FALSE;

   if( me.mach >= constantaero.REHEATMACH ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_climb_fast = func {
   var result = constant.FALSE;

   if( me.speedfpm > me.CLIMBFASTFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_climb_threshold = func {
   var result = constant.FALSE;

   if( me.speedfpm > me.CLIMBFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_climb_decrease = func {
   return me.acceleration.climbdecrease();
}

Voicephase.is_climb_decay = func {
   var result = constant.FALSE;

   if( me.speedfpm < me.DECAYFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_climb_visible = func {
   var result = constant.FALSE;

   if( me.speedfpm > me.LEVELFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_descent_threshold = func {
   var result = constant.FALSE;

   if( me.speedfpm < me.DESCENTFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_descent_fast = func {
   var result = constant.FALSE;

   if( me.speedfpm < me.DESCENTFASTFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_descent_final = func {
   var result = constant.FALSE;

   if( me.speedfpm < me.FINALFPM ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_final_decrease = func {
   return me.acceleration.finaldecrease();
}

Voicephase.is_speed_approach = func {
   var result = constant.FALSE;

   if( me.speedkt < constantaero.APPROACHKT ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_speed_below = func( thresholdkt ) {
   var result = constant.FALSE;

   if( me.speedkt < me.acceleration.velocitykt( thresholdkt ) ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_speed_above = func( thresholdkt ) {
   var result = constant.FALSE;

   if( me.speedkt >= me.acceleration.velocitykt( thresholdkt ) ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_altitude_cruise = func {
   var result = constant.FALSE;

   if( me.altitudeft >= constantaero.CRUISEFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_altitude_level = func {
   var result = constant.FALSE;

   if( me.flightlevel.levelchange( me.altitudeft ) ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_altitude_transition = func {
   var result = constant.FALSE;

   if( me.flightlevel.transitionchange( me.altitudeft ) ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_altitude_approach = func {
   var result = constant.FALSE;

   if( me.altitudeft < constantaero.APPROACHFT ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_altitude_below = func( thresholdft ) {
   var result = constant.FALSE;

   if( me.altitudeft < thresholdft ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.is_altitude_above = func( thresholdft ) {
   var result = constant.FALSE;

   if( me.altitudeft >= thresholdft ) {
       result = constant.TRUE;
   }

   return result;
}

Voicephase.get_altitudeft = func {
   return me.altitudeft;
}


# ============
# VOICE SENSOR 
# ============

Voicesensor = {};

Voicesensor.new = func( path ) {
   var obj = { parents : [Voicesensor,System.new(path)],

               gear : 0.0,
               lastgear : 0.0,
               
               nose : 0.0,
               lastnose : 0.0
         };

   return obj;
}

Voicesensor.schedule = func {
   me.gear = me.dependency["gear"].getValue();
   me.nose = me.dependency["nose"].getValue();
   
   me.snapshot_nose();
}

Voicesensor.snapshot_gear = func {
   me.lastgear = me.gear;
}

Voicesensor.snapshot_nose = func {
   me.lastnose = me.nose;
}

Voicesensor.is_nose_change = func {
   var result = constant.FALSE;

   if( me.nose != me.lastnose ) {
       result = constant.TRUE;
   }

   return result;
}

Voicesensor.is_nose_down = func {
   var result = constant.FALSE;

   if( me.nose == constantaero.NOSEDOWN ) {
       result = constant.TRUE;
   }

   return result;
}

Voicesensor.is_nose_up = func {
   var result = constant.FALSE;

   if( me.nose == constantaero.NOSEUP ) {
       result = constant.TRUE;
   }

   return result;
}

Voicesensor.is_gear_change = func {
   var result = constant.FALSE;

   if( me.gear != me.lastgear ) {
       result = constant.TRUE;
   }

   return result;
}

Voicesensor.is_gear_down = func {
   var result = constant.FALSE;

   if( me.gear == constantaero.GEARDOWN ) {
       result = constant.TRUE;
   }

   return result;
}

Voicesensor.is_gear_up = func {
   var result = constant.FALSE;

   if( me.gear == constantaero.GEARUP ) {
       result = constant.TRUE;
   }

   return result;
}

Voicesensor.is_lastgear_down = func {
   var result = constant.FALSE;

   if( me.lastgear == constantaero.GEARDOWN ) {
       result = constant.TRUE;
   }

   return result;
}

Voicesensor.is_allengines = func {
    var result = constant.TRUE;

    for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
         if( !me.dependency["engine"][i].getChild("running").getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}

Voicesensor.is_inboardengines = func {
    var result = constant.TRUE;

    for( var i = constantaero.ENGINE2; i <= constantaero.ENGINE3; i = i + 1 ) {
         if( !me.dependency["engine"][i].getChild("running").getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}

Voicesensor.is_noengines = func {
    var result = constant.TRUE;

    for( var i = 0; i < constantaero.NBENGINES; i = i + 1 ) {
         if( me.dependency["engine"][i].getChild("running").getValue() ) {
             result = constant.FALSE;
             break;
         }
    }

    return result;
}

Voicesensor.has_reheat = func {
    var augmentation = constant.FALSE;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.dependency["engine-ctrl"][i].getChild("reheat").getValue() ) {
             augmentation = constant.TRUE;
             break;
         }
    }

    return augmentation;
}

Voicesensor.Vkt = func( minkt, maxkt ) {
    var weightlb = me.noinstrument["weight"].getValue();
    var valuekt = constantaero.Vkt( weightlb, minkt, maxkt );

    return valuekt;
}


# ================
# SPEED PERCEPTION
# ================

Speedperception = {};

Speedperception.new = func {
   var obj = { parents : [Speedperception],

               ratiostep : 0.0,                                  # rates

               DECAYKT : 0.0,
               FINALKT : 0.0,

               reactionkt : 0.0,

               DECAYKTPS : -2.0,                                 # climb
               FINALKTPS : -3.0                                  # descent
         };

   return obj;
}

Speedperception.set_rates = func( rates ) {
    me.ratiostep = rates / constant.HUMANSEC;

    me.DECAYKT = me.DECAYKTPS * rates;
    me.FINALKT = me.FINALKTPS * rates;
}

Speedperception.schedule = func( speedkt, lastspeedkt ) {
    me.reactionkt = speedkt - lastspeedkt;
}

Speedperception.climbdecrease = func {
    var result = constant.FALSE;

    if( me.reactionkt < me.DECAYKT ) {
        result = constant.TRUE;
    }

    return result;
}

Speedperception.finaldecrease = func {
    var result = constant.FALSE;

    if( me.reactionkt < me.FINALKT ) {
        result = constant.TRUE;
    }

    return result;
}

Speedperception.velocitykt = func( speedkt ) {
    var valuekt = speedkt - me.reactionkt * me.ratiostep;

    return valuekt;
}


# ===================
# ALTITUDE PERCEPTION
# ===================

Altitudeperception = {};

Altitudeperception.new = func {
   var obj = { parents : [Altitudeperception],

               ratio1s : 0.0,                                    # 1 s
               ratiostep : 0.0,                                  # rates

               FLIGHTLEVELFT : 10000,  
               MARGINFT : 200,                                   # for altitude detection

               MAXFT : 0.0,

               reactionft : 0.0,

               level10000 : 0,                                   # current flight level
               levelabove : constant.TRUE,                       # above sea level
               levelbelow : constant.FALSE,
               transition : constant.FALSE                       # below transition level
         };

   obj.init();

   return obj;
}

Altitudeperception.init = func {
   me.ratio1s = 1 / constant.HUMANSEC;
}

Altitudeperception.set_rates = func( steps ) {
   me.ratiostep = steps / constant.HUMANSEC;

   me.MAXFT = constantaero.MAXFPM * steps / constant.MINUTETOSECOND;
}

Altitudeperception.schedule = func( speedfpm ) {
   me.reactionft = speedfpm / constant.MINUTETOSECOND;
}

Altitudeperception.climbft = func( altitudeft ) {
   # adds 1 seconds for better matching
   var valueft = altitudeft - me.reactionft * ( me.ratiostep + me.ratio1s );

   return valueft;
}

Altitudeperception.insideft = func( altitudeft, targetft ) {
    var result = constant.FALSE;

    if( altitudeft >= targetft - me.MAXFT and altitudeft <= targetft + me.MAXFT  ) {
        result = constant.TRUE;
    }

    return result;
}

Altitudeperception.inside = func {
    var result = constant.FALSE;

    if( !me.levelabove and !me.levelbelow ) {
        result = constant.TRUE;
    }

    return result;
}

Altitudeperception.aboveft = func( altitudeft, targetft, marginft ) {
    var result = constant.FALSE;

    if( altitudeft > targetft + marginft  ) {
        result = constant.TRUE;
    }

    return result;
}

Altitudeperception.belowft = func( altitudeft, targetft, marginft ) {
    var result = constant.FALSE;

    if( altitudeft < targetft - marginft  ) {
        result = constant.TRUE;
    }

    return result;
}

Altitudeperception.setlevel = func( altitudeft ) {
   var levelft = 0.0;

   # default
   var level = 0;

   if( altitudeft >= 10000 and altitudeft < 20000 ) {
       level = 1;
   }
   elsif( altitudeft >= 20000 and altitudeft < 30000 ) {
       level = 2;
   }
   elsif( altitudeft >= 30000 and altitudeft < 40000 ) {
       level = 3;
   }
   elsif( altitudeft >= 40000 and altitudeft < 50000 ) {
       level = 4;
   }
   elsif( altitudeft >= 50000 ) {
       level = 5;
   }

   me.level10000 = level;

   # snapshot
   levelft = me.level10000 * me.FLIGHTLEVELFT;
   me.levelabove = me.aboveft( altitudeft, levelft, me.MARGINFT );
   me.levelbelow = me.belowft( altitudeft, levelft, me.MARGINFT );

   if( altitudeft > constantaero.TRANSITIONFT ) {
       me.transition = constant.TRUE;
   }
   else {
       me.transition = constant.FALSE;
   }
}

Altitudeperception.levelchange = func( altitudeft ) {
   var level = 0;
   var previousft = 0.0;
   var nextft = 0.0;
   var currentft = 0.0;
   var below = constant.FALSE;
   var above = constant.FALSE;
   var result = constant.FALSE;

   # reaches lower flight level
   if( me.level10000 > 0 ) {
       level = me.level10000 - 1;
       previousft = me.climbft( level * me.FLIGHTLEVELFT );
       if( altitudeft < previousft ) {
           result = constant.TRUE;
           me.level10000 = level;
           me.levelabove= constant.FALSE;
           me.levelbelow = constant.TRUE;
       }
   }

   # reaches higher flight level
   if( !result ) {
       level = me.level10000 + 1;
       nextft = me.climbft( level * me.FLIGHTLEVELFT );
       if( altitudeft > nextft ) {
           result = constant.TRUE;
           me.level10000 = level;
           me.levelabove = constant.TRUE;
           me.levelbelow = constant.FALSE;
       }
   }

   # crosses current flight level
   if( !result and me.level10000 > 0 ) {
       currentft = me.climbft( me.level10000 * me.FLIGHTLEVELFT );

       below = me.belowft( altitudeft, currentft, me.MARGINFT );
       above = me.aboveft( altitudeft, currentft, me.MARGINFT );

       if( me.levelabove and below ) {
           result = constant.TRUE;
           me.levelabove= constant.FALSE;
           me.levelbelow = constant.TRUE;
       }
       elsif( me.levelbelow and above ) {
           result = constant.TRUE;
           me.levelabove = constant.TRUE;
           me.levelbelow = constant.FALSE;
       }
       else {
           result = constant.FALSE;
       }
   }

   return result;
}

Altitudeperception.transitionchange = func( altitudeft ) {
   var result = constant.FALSE;
   var levelft = me.climbft( constantaero.TRANSITIONFT );

   if( ( !me.transition and me.aboveft( altitudeft, levelft, me.MARGINFT ) ) or
       ( me.transition and me.belowft( altitudeft, levelft, me.MARGINFT ) ) ) {
       me.transition = !me.transition;
       result = constant.TRUE;
   }

   return result;
}
