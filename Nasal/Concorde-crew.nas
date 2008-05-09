# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains checklist tasks.


# ============
# VIRTUAL CREW
# ============

Virtualcrew = {};

Virtualcrew.new = func {
   var obj = { parents : [Virtualcrew], 

           generic : Generic.new(),

           TASKSEC : 2.0,
           DELAYSEC : 1.0,

           task : constant.FALSE,
           taskend : constant.TRUE,

           state : ""
         };

    return obj;
}

Virtualcrew.init_ancestor2 = func {
    var obj = Virtualcrew.new();

    me.generic = obj.generic;
    me.TASKSEC = obj.TASKSEC;
    me.DELAYSEC = obj.DELAYSEC;
    me.task = obj.task;
    me.taskend = obj.taskend;
    me.state = obj.state;
}

Virtualcrew.toggleclick = func( message = "" ) {
    if( message != "" ) {
        me.log( message );
    }

    # first task to do.
    me.task = constant.TRUE;

    me.generic.toggleclick();
}

Virtualcrew.log = func( message ) {
    me.state = me.state ~ " " ~ message;
}

Virtualcrew.getlog = func {
    return me.state;
}

Virtualcrew.reset = func {
    me.state = "";

    me.task = constant.FALSE;
    me.taskend = constant.TRUE;
}

Virtualcrew.can = func {
    # still something to do, must wait.
    if( me.task ) {
        me.taskend = constant.FALSE;
    }

    return !me.task;
}

Virtualcrew.randoms = func( steps ) {
    if( !me.taskend ) {
        steps = me.TASKSEC + rand() * me.DELAYSEC;
    }

    return steps;
} 


# ================
# VIRTUAL ENGINEER
# ================

Virtualengineer = {};

Virtualengineer.new = func {
   var obj = { parents : [Virtualengineer,Virtualcrew,System], 

           autopilotsystem : nil,
           fuelsystem : nil,

           navigation : Navigation.new(),
           nightlighting : Nightlighting.new(),

           GROUNDSEC : 30.0,
           CRUISESEC : 15.0,
           REHEATSEC : 4.0,

           rates : 0.0,

           crew : nil,
           crewcontrol : nil,
           engineer : nil,
           engines : nil,
           allengines : nil,

           SAFEFT : 1500.0,

           aglft : 0.0,

           CLIMBMACH : 0.7,
           CRUISEMACH : 1.95,

           speedmach : 0.0,

           SCHEDULEAPPROACH : 1,
           SCHEDULENORMAL : 0,

           MAXPERCENT : 53.6,                                # maximum on ground
           CGPERCENT : 0.3,

           activ : constant.FALSE,
           running : constant.FALSE,
           checklist : ""
         };

    obj.init();

    return obj;
}

Virtualengineer.init = func {
    me.init_ancestor("/systems/crew/engineer");
    me.init_ancestor2();

    me.crew = props.globals.getNode("/systems/crew");
    me.crewcontrol = props.globals.getNode("/controls/crew");
    me.engineer = props.globals.getNode("/systems/crew/engineer");
    me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
    me.allengines = props.globals.getNode("/controls/engines");

    settimer( func { me.setweighthuman(); }, me.CRUISESEC );
}

Virtualengineer.set_relation = func( autopilot, fuel, lighting ) {
    me.autopilotsystem = autopilot;
    me.fuelsystem = fuel;
    me.nightlighting.set_relation( lighting );
}

Virtualengineer.toggleexport = func {
    var launch = constant.FALSE;

    if( !me.crewcontrol.getChild("engineer").getValue() ) {
        launch = constant.TRUE;
    }
 
    me.crewcontrol.getChild("engineer").setValue(launch);

    if( launch and !me.running ) {
        me.schedule();
    }
}

Virtualengineer.reheatexport = func {
    # at first engine 2 3.
    if( !me.has_reheat() ) {
        for( var i = 1; i <= 2 ; i = i+1 ) {
             me.engines[i].getChild("reheat").setValue( constant.TRUE );
        }
 
        me.toggleclick("reheat-2-3");

        # then, engineer sets engines 1 4.
        settimer(func { me.reheatcron(); }, me.REHEATSEC);
    }

    else {
        for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
             me.engines[i].getChild("reheat").setValue( constant.FALSE );
        }
 
        me.toggleclick("reheat-off");
    }
}

Virtualengineer.reheatcron = func {
    if( me.has_reheat() ) {
        me.engines[0].getChild("reheat").setValue( constant.TRUE );
        me.engines[3].getChild("reheat").setValue( constant.TRUE );
 
        me.toggleclick("reheat-1-4");
    }
}

Virtualengineer.has_reheat = func {
    var augmentation = constant.FALSE;

    for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
         if( me.engines[i].getChild("reheat").getValue() ) {
             augmentation = constant.TRUE;
             break;
         }
    }

    return augmentation;
}

Virtualengineer.slowschedule = func {
    me.navigation.schedule();
}

Virtualengineer.schedule = func {
    me.reset();

    if( me.crew.getChild("serviceable").getValue() ) {
        me.supervisor();
    }
    else {
        me.rates = me.GROUNDSEC;
        me.engineer.getChild("activ").setValue(constant.FALSE);
    }

    me.run();
}

Virtualengineer.run = func {
    if( me.crewcontrol.getChild("engineer").getValue() ) {
        me.running = constant.TRUE;
        me.rates = constant.rates( me.rates );
        settimer( func { me.schedule(); }, me.rates );
    }
    else {
        me.running = constant.FALSE;
    }
}

Virtualengineer.supervisor = func {
    me.activ = constant.FALSE;
    me.rates = me.GROUNDSEC;


    if( me.crewcontrol.getChild("engineer").getValue() ) {
        me.speedmach = me.noinstrument["mach"].getValue();

        me.aglft = me.noinstrument["agl"].getValue();

        if( me.aglft > constantaero.APPROACHFT ) {
            me.rates = me.CRUISESEC;
        }

        me.checklist = me.slave["voice"].getChild("checklist").getValue();

        if( me.checklist == "gate" or me.checklist == "parking" ) {
        }

        elsif( me.checklist == "taxi" ) {
            me.activ = constant.TRUE;
            me.afterlanding();
        }

        else {
            me.activ = constant.TRUE;
            me.flight();
        }

        me.allways();

        me.rates = me.randoms( me.rates );

        me.engineer.getChild("state").setValue(me.getlog());
        me.engineer.getChild("time").setValue(getprop("/sim/time/gmt-string"));
    }

    me.engineer.getChild("activ").setValue(me.activ);
}

Virtualengineer.allways = func {
    me.setweight();
    me.enginecontrol();
    me.nightlighting.engineer( me );
}

Virtualengineer.flight = func {
    me.fuel();
    me.enginerating();
    me.groundidle( constant.FALSE );
}

Virtualengineer.afterlanding = func {
    me.fuel();
    me.enginerating();
    me.groundidle( constant.TRUE );
    me.taxioutboard();
}

Virtualengineer.groundidle = func( set ) {
    if( me.can() ) {
        var path = "";

        path = "ground-idle14";

        if( me.allengines.getChild(path).getValue() != set ) {
            me.allengines.getChild(path).setValue( set );
        }

        path = "ground-idle23";

        if( me.allengines.getChild(path).getValue() != set ) {
            me.allengines.getChild(path).setValue( set );
        }
    }
}

Virtualengineer.taxioutboard = func {
    for( i=1; i<=2; i=i+1 ) {
         if( me.can() ) {
             # taxi with outboard engines
             if( !me.engines[i].getChild("cutoff").getValue() ) {
                 me.engines[i].getChild("cutoff").setValue(constant.TRUE);
                 me.toggleclick("stop-engine-" ~ i);
             }
         }
    }
}

Virtualengineer.enginerating = func {
    if( me.can() ) {
        var rating = "takeoff";
        var flight = "climb";

        if( me.aglft > me.SAFEFT ) {
            rating = "flight";
        }

        if( me.autopilotsystem.has_altitude_hold() ) {
            flight = "cruise";
        }

        else {
            # see check-list
            if( me.speedmach > me.CRUISEMACH ) {
                flight = "cruise";
            }
        }

        me.applyrating( flight, rating );
    }
}

Virtualengineer.applyrating = func( flight, rating ) {
    var flightnow = "";
    var ratingnow = "";

    for( var i=0; i<constantaero.NBENGINES; i=i+1 ) {
         if( me.can() ) {
             flightnow = me.engines[i].getChild("rating-flight").getValue();
             if( flightnow != flight ) {
                 me.engines[i].getChild("rating-flight").setValue(flight);
                 me.toggleclick("rating-" ~ i ~ "-" ~ flight);
             }
         }

         # flight once safe
         if( me.can() ) {
             ratingnow = me.engines[i].getChild("rating").getValue();
             if( ratingnow != rating and rating == "flight" ) {
                 if( !getprop("/controls/gear/gear-down") ) {
                     me.engines[i].getChild("rating").setValue(rating);
                     me.toggleclick("rating-" ~ i ~ "-" ~ rating);
                 }
             }
         }
    }
}

Virtualengineer.enginecontrol = func {
    if( me.can() ) {
        var result = 0;
        var present = 0;

        me.allengines.getChild("schedule-auto").setValue( constant.TRUE );

        # see check-list
        if( me.speedmach > me.CLIMBMACH ) {
            result = me.SCHEDULENORMAL;
        }

        # approach
        elsif( me.checklist == "landing" ) {
            result = me.SCHEDULEAPPROACH;
        }

        # normal or flyover at takeoff
        else {
            result = me.allengines.getChild("schedule").getValue();
            if( result > me.SCHEDULENORMAL ) {
                result = me.SCHEDULENORMAL;
            }
        }

        if( me.allengines.getChild("schedule").getValue() != result ) {
            me.allengines.getChild("schedule").setValue( result );
            me.toggleclick("engine-schedule");
        }
   }
}

# set weight datum
Virtualengineer.setweight = func {
    if( me.can() ) {

        # after fuel loading
        var reset = me.slave["fuel2"].getChild("reset").getValue();

        # after 1 reset of fuel consumed
        if( !reset ) {
            for( var i = 0; i < constantaero.NBENGINES; i = i+1 ) {
                 if( me.slave["fuel-consumed"][i].getChild("reset").getValue() ) {
                     reset = constant.TRUE;
                     break;
                 }
            }
        }

        if( reset ) {
            me.setweighthuman();
            me.toggleclick("set-weight");
        }
    }
}

Virtualengineer.setweighthuman = func {
    var totalkg = me.slave["fuel"].getChild("total-kg").getValue();

    me.fuelsystem.setweighthuman( totalkg );
}

Virtualengineer.fuel = func {
    if( me.can() ) {
        var engine = constant.FALSE;
        var forward = constant.FALSE;
        var aft = constant.FALSE;
        var afttrim = constant.FALSE;
        var max = 0.0;
        var min = 0.0;
        var cg = 0.0;
        var mean = 0.0;

        if( me.slave["cg"].getChild("serviceable").getValue() ) {
            max = me.slave["cg"].getChild("max-percent").getValue();
            min = me.slave["cg"].getChild("min-percent").getValue();
            cg = me.slave["cg"].getChild("percent").getValue();

            engine = constant.FALSE;
            afttrim = constant.FALSE;

            # emergency
            if( cg < min ) {
                me.log("below-min");
                aft = constant.TRUE;
                engine = constant.TRUE;
                afttrim = constant.TRUE;
            }
            elsif( cg > max ) {
                me.log("above-max");
                forward = constant.TRUE;
                engine = constant.TRUE;
            }

            # above 250 kt beyond 10000 ft
            elsif( me.noinstrument["altitude"].getValue() > constantaero.APPROACHFT ) {
                mean = min + ( max - min ) / 2;

                if( cg < mean - me.CGPERCENT ) {
                    me.log("aft");
                    aft = constant.TRUE;
                    engine = constant.TRUE;
                }

                # don't move on ground, if within limits
                elsif( cg > mean + me.CGPERCENT and cg > me.MAXPERCENT ) {
                    me.log("forward");
                    forward = constant.TRUE;
                    engine = constant.TRUE;
                }
           }

           me.applyfuel( forward, aft, engine, afttrim );
       }


       if( me.engineer.getNode("cg/aft").getValue() != aft or
           me.engineer.getNode("cg/forward").getValue() != forward ) {
           me.engineer.getNode("cg/aft").setValue(aft);
           me.engineer.getNode("cg/forward").setValue(forward);

           me.toggleclick();
       }
    }
}

Virtualengineer.applyfuel = func( forward, aft, engine, afttrim) {
    var pump6 = constant.FALSE;
    var pump8 = constant.FALSE;
    var auxilliary = constant.FALSE;

    # pumps
    var empty5 = me.fuelsystem.empty("5");
    var empty5A = me.fuelsystem.empty("5A");
    var empty6 = me.fuelsystem.empty("6");
    var empty7 = me.fuelsystem.empty("7");
    var empty7A = me.fuelsystem.empty("7A");
    var empty8 = me.fuelsystem.empty("8");
    var empty9 = me.fuelsystem.empty("9");
    var empty10 = me.fuelsystem.empty("10");
    var empty11 = me.fuelsystem.empty("11");

    # no 2D panel
    me.fuelsystem.aft2Dhuman( constant.FALSE );


    # shut all unused pumps
    me.fuelsystem.pumphuman( "5", !empty5 );
    me.fuelsystem.pumphuman( "7", !empty7 );
    me.fuelsystem.pumphuman( "5A", constant.FALSE );
    me.fuelsystem.pumphuman( "7A", constant.FALSE );

    if( empty5 and !empty6 ) {
        pump6 = constant.TRUE;
    }
    me.fuelsystem.pumphuman( "6", pump6 );

    if( empty7 and !empty8 ) {
        pump8 = constant.TRUE;
    }
    me.fuelsystem.pumphuman( "8", pump8 );

    # engineer normally uses auto trim
    me.fuelsystem.pumphuman( "9", constant.FALSE );
    me.fuelsystem.pumphuman( "10", constant.FALSE );
    me.fuelsystem.pumphuman( "11", constant.FALSE );

    me.fuelsystem.shutstandbyhuman();


    # aft trim
    me.fuelsystem.afttrimhuman( afttrim );


    # transfers auxilliary tanks
    if( empty5 and empty6 ) {
        if( !empty5A ) {
            auxilliary = constant.TRUE;
            me.fuelsystem.transvalvehuman( "5A", constant.TRUE );
            me.fuelsystem.pumphuman( "5A", constant.TRUE );
        }
    }
    if( empty7 and empty8 ) {
        if( !empty7A ) {
            auxilliary = constant.TRUE;
            me.fuelsystem.transvalvehuman( "7A", constant.TRUE );
            me.fuelsystem.pumphuman( "7A", constant.TRUE );
        }
    }
    if( auxilliary ) {
        me.log("auxilliary");
    }


    # low level (emergency)
    if( me.fuelsystem.lowlevel() ) {
        me.fuelsystem.offautohuman();

        # avoid aft CG  
        if( ( forward or !aft ) and !empty11 ) {
            me.log("low-level");
            me.fuelsystem.pumphuman( "11", constant.TRUE );
            me.fuelsystem.enginehuman( constant.TRUE );
            me.fuelsystem.forwardhuman( constant.TRUE );
        }
        elsif( !empty9 or !empty10 ) {
            me.log("low-level");
            me.fuelsystem.pumphuman( "9", !empty9 );
            me.fuelsystem.pumphuman( "10", !empty10 );
            me.fuelsystem.enginehuman( constant.TRUE );
            me.fuelsystem.afthuman( constant.TRUE );
        }
        # last fuel
        elsif( !empty11 ) {
            me.log("low-level");
            me.fuelsystem.pumphuman( "11", constant.TRUE );
            me.fuelsystem.enginehuman( constant.TRUE );
            me.fuelsystem.forwardhuman( constant.TRUE );
        }
        else {
            me.fuelsystem.enginehuman( constant.FALSE );
        }
    }

    # aft transfert
    elsif( aft ) {
        me.fuelsystem.forwardautohuman( constant.FALSE );
    }

    # forward transfert
    elsif( forward ) {
        me.fuelsystem.forwardautohuman( constant.TRUE );
    }

    # no transfert
    else {
        me.fuelsystem.offautohuman();
        me.fuelsystem.enginehuman( constant.FALSE );
    }
}


# ===============
# VIRTUAL COPILOT
# ===============

Virtualcopilot = {};

Virtualcopilot.new = func {
   var obj = { parents : [Virtualcopilot,Virtualcrew,System],

           autopilotsystem : nil,
           mwssystem : nil,
 
           nightlighting : Nightlighting.new(),

           copilot : nil,
           crew : nil,
           crewcontrol : nil,

           CRUISESEC : 30.0,
           TAKEOFFSEC : 5.0,

           rates : 0.0,

           SOUNDMACH : 1.0,
           VLA41KT : 300.0,
           VLA15KT : 250.0,
           GEARKT : 220.0,
           MARGINKT : 25.0,

           speedkt : 0.0,

           FL41FT : 41000.0,
           FL15FT : 15000.0,
           NOSEFT : 600.0,                                # nose retraction
           MARGINFT : 100.0,

           aglft : 0.0,
           altitudeft : 0.0,

           STEPFTPM : 100.0,
           GLIDEFTPM : -1500.0,                           # best glide (guess)

           descentftpm : 0.0,

           activ : constant.FALSE,
           emergency : constant.FALSE,
           running : constant.FALSE,
           checklist : ""
         };

   obj.init();

   return obj;
};

Virtualcopilot.init = func {
   me.copilot = props.globals.getNode("/systems/crew/copilot");
   me.crew = props.globals.getNode("/systems/crew");
   me.crewcontrol = props.globals.getNode("/controls/crew");

   me.init_ancestor("/systems/crew/copilot");
   me.init_ancestor2();

   me.rates = me.TAKEOFFSEC;
   me.run();
}

Virtualcopilot.set_relation = func( autopilot, lighting, mws ) {
   me.autopilotsystem = autopilot;
   me.mwssystem = mws;
   me.nightlighting.set_relation( lighting );
}


Virtualcopilot.toggleexport = func {
   var launch = constant.FALSE;

   if( !me.crewcontrol.getChild("copilot").getValue() ) {
       launch = constant.TRUE;
   }

   me.crewcontrol.getChild("copilot").setValue(launch);
       
   if( launch and !me.running ) {
       me.slowschedule();
   }
}

Virtualcopilot.schedule = func {
   if( me.crew.getChild("serviceable").getValue() ) {
       me.unexpected();
   }
}

Virtualcopilot.slowschedule = func {
   me.reset();

   if( me.crew.getChild("serviceable").getValue() ) {
       me.routine();
   }
   else {
       me.rates = me.CRUISESEC;
       me.copilot.getChild("activ").setValue(constant.FALSE);
   }

   me.run();
}

Virtualcopilot.run = func {
   if( me.crewcontrol.getChild("copilot").getValue() ) {
       me.running = constant.TRUE;
       me.rates = constant.rates( me.rates );
       settimer( func { me.slowschedule(); }, me.rates );
   }

   else {
       me.running = constant.FALSE;
   }
}

Virtualcopilot.unexpected = func {
   me.emergency = constant.FALSE;

   if( me.crewcontrol.getChild("copilot").getValue() ) {
       me.checklist = me.slave["voice"].getChild("checklist").getValue();

       me.speedkt = me.noinstrument["airspeed"].getValue();
       me.altitudeft = me.noinstrument["altitude"].getValue();

       # 4 engines flame out
       me.engine4flameout();

       me.timestamp();
   }

   else {
       me.autopilotsystem.realhuman();
   }

   me.crew.getChild("emergency").setValue(me.emergency);
}

Virtualcopilot.routine = func {
   me.activ = constant.FALSE;
   me.rates = me.CRUISESEC;

   if( !me.crew.getChild("emergency").getValue() ) {
       if( me.crewcontrol.getChild("copilot").getValue() ) {
           me.checklist = me.slave["voice"].getChild("checklist").getValue();

           # normal procedures
           if ( me.normal() ) {
                me.rates = me.randoms( me.rates );
           }

           else {
               me.autopilotsystem.realhuman();
           }

           me.timestamp();
       }

       else {
           me.autopilotsystem.realhuman();
       }
   }

   me.copilot.getChild("activ").setValue(me.activ);
}

Virtualcopilot.engine4flameout = func {
   # hold heading and speed, during engine start
   if( me.altitudeft > constantaero.APPROACHFT and me.checklist == "flight" ) {
       if( me.autopilotsystem.no_voltage() ) {
           me.emergency = constant.TRUE;
           me.log("no-autopilot");

           me.autopilotsystem.virtualhuman();

           me.keepheading();

           me.keepspeed();
       }
   }
}

# instrument failures ignored
Virtualcopilot.normal = func {
   if( me.checklist != "gate" and me.checklist != "parking" ) {
       if( me.noinstrument["mach"].getValue() < me.SOUNDMACH ) {
           me.activ = constant.TRUE;

           me.speedkt = me.noinstrument["airspeed"].getValue();
           me.altitudeft = me.noinstrument["altitude"].getValue();
           me.aglft = me.noinstrument["agl"].getValue();

           if( me.checklist == "landing" ) {
               me.beforelanding();
               me.rates = me.TAKEOFFSEC;
           }
           elsif( me.checklist == "taxi" ) {
               me.afterlanding();
           }
           else {
               if( me.checklist == "holding" ) {
                   me.holding();
               }

               if( me.aglft <= constantaero.APPROACHFT ) {
                   me.rates = me.TAKEOFFSEC;
               }

               if( me.aglft <= constantaero.GEARFT  ) {
                   me.beforetakeoff();
               }
               else {
                   me.aftertakeoff();
               }
           }

           me.allways();
       }
   }

   return me.activ;
}

Virtualcopilot.holding = func {
}

Virtualcopilot.beforetakeoff = func {
   me.nosevisor( constant.FALSE, constant.FALSE );
   me.landinglights( constant.FALSE );

   me.takeoffmonitor( constant.TRUE );
   me.antiicing( constant.TRUE );
}

Virtualcopilot.aftertakeoff = func {
   me.landinggear( constant.FALSE );
   me.nosevisor( constant.FALSE, constant.FALSE );
   me.landinglights( constant.FALSE );

   me.takeoffmonitor( constant.FALSE );
}

Virtualcopilot.beforelanding = func {
   me.landinggear( constant.TRUE );
   me.nosevisor( constant.TRUE, constant.FALSE );
   me.landinglights( constant.TRUE );
   me.brakelever();

   # relocation in flight
   me.takeoffmonitor( constant.FALSE );
}

Virtualcopilot.afterlanding = func {
   me.nosevisor( constant.TRUE, constant.TRUE );
   me.antiicing( constant.FALSE );
}

Virtualcopilot.allways = func {
    me.nightlighting.copilot( me );
}

Virtualcopilot.antiicing = func( set ) {
    var path = "";

    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         path = "static/heater[" ~ i ~ "]";

         if( me.slave["anti-icing"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.slave["anti-icing"].getNode(path).setValue( set );
                 me.toggleclick("icing-static-" ~ i);
             }
         }
    }

    for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
         path = "mast/heater[" ~ i ~ "]";

         if( me.slave["anti-icing"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.slave["anti-icing"].getNode(path).setValue( set );
                 me.toggleclick("icing-mast-" ~ i);
             }
         }
    }
}

Virtualcopilot.brakelever = func {
    if( me.can() ) {
        # disable
        if( me.slave["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
            controls.applyParkingBrake(1);
            me.toggleclick("brake-parking");
        }
    }
}

Virtualcopilot.takeoffmonitor = func( set ) {
    if( me.can() ) {
        var path = "armed";

        if( me.slave["to-monitor"].getChild(path).getValue() != set ) {
            me.slave["to-monitor"].getChild(path).setValue( set );
            me.toggleclick("to-monitor");
        }
    }
}

Virtualcopilot.keepspeed = func {
    if( !me.autopilotsystem.is_vertical_speed() ) {
        me.log("vertical-speed");
        me.autopilotsystem.apverticalexport();
        me.descentftpm = me.GLIDEFTPM;
    }

    # the copilot follows the best glide
    me.adjustglide();  
    me.autopilotsystem.verticalspeed( me.descentftpm );
}

Virtualcopilot.adjustglide = func {
    var minkt = 0;

    if( me.altitudeft > me.FL41FT ) {
        minkt = me.VLA41KT;
    }
    elsif( me.altitudeft > me.FL15FT and me.altitudeft <= me.FL41FT ) {
        minkt = me.VLA15KT;
    }
    else {
        minkt = constantaero.V2FULLKT;
    }

    # stay above VLA (lowest allowed speed)
    minkt = minkt + me.MARGINKT;

    if( me.speedkt < minkt ) {
        me.descentftpm = me.descentftpm - me.STEPFTPM;
    }
}

Virtualcopilot.keepheading = func {
    if( !me.autopilotsystem.is_lock_magnetic() ) {
        me.log("magnetic");
        me.autopilotsystem.apheadingholdexport();
    }
}

Virtualcopilot.landinggear = func( landing ) {
    if( me.can() ) {
        if( !landing and me.aglft > constantaero.GEARFT ) {
            if( me.speedkt > me.GEARKT ) {
                if( me.slave["gear-ctrl"].getChild("gear-down").getValue() ) {
                    controls.gearDown(-1);
                    me.toggleclick("gear");
                }
                elsif( me.slave["gear-ctrl"].getChild("hydraulic").getValue() and
                    me.slave["gear"].getValue() == globals.Concorde.constantaero.GEARUP ) {
                    controls.gearDown(-1);
                    me.toggleclick("gear-neutral");
                }
            }
        }
        elsif( landing and me.aglft < constantaero.LANDINGFT ) {
            if( me.speedkt < me.GEARKT ) {
                if( !me.slave["gear-ctrl"].getChild("gear-down").getValue() ) {
                    controls.gearDown(1);
                    me.toggleclick("gear");
                }
            }
        }
    }
}

Virtualcopilot.nosevisor = func( landing, taxi ) {
    if( me.can() ) {
        var targetpos = 0;
        var currentpos = 0;
        var child = nil;

        # nose 5 degrees
        if( taxi ) {
            targetpos = 2;
        }

        elsif( !landing ) {
            if( me.aglft > me.NOSEFT ) {
                # visor up
                if( me.altitudeft > ( constantaero.APPROACHFT + me.MARGINFT ) ) {
                    targetpos = 0;
                }
                # visor down
                elsif( me.altitudeft < ( constantaero.APPROACHFT - me.MARGINFT ) ) {
                    targetpos = 1;
                }
            }

            # nose 5 degrees
            else {
                targetpos = 2;
            }
        }

        elsif( landing ) {
            # nose 12 degress
            if( me.aglft < constantaero.LANDINGFT ) {
                targetpos = 3;
            }
            # visor down
            elsif( me.altitudeft < constantaero.APPROACHFT ) {
                targetpos = 1;
            }
        }

        # must be up above 270 kt
        if( me.speedkt > constantaero.NOSEKT ) {
            targetpos = 0;
        }

        # not to us to create the property
        child = me.slave["flaps"].getChild("current-setting");
        if( child == nil ) {
            currentpos = 0;
        }
        else {
            currentpos = child.getValue();
        }

        if( targetpos <= 1 or ( targetpos > 1 and me.speedkt < me.GEARKT ) ) {
            pos = targetpos - currentpos;
            if( pos != 0 ) {
                controls.flapsDown( pos );
                me.toggleclick("nose");
            }
        }
    }
}

Virtualcopilot.landinglights = func( landing ) {
    if( !landing and me.aglft > me.NOSEFT ) {
        me.landingtaxi( constant.FALSE );
        me.mainlanding( constant.FALSE );
    }

    # terminal area
    if( me.altitudeft <= constantaero.APPROACHFT ) {
        me.taxiturn( constant.TRUE );
    }
    else {
        me.taxiturn( constant.FALSE );
    }
}

Virtualcopilot.mainlanding = func( set ) {
    var path = "";

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "main-landing[" ~ i ~ "]/extend";

         if( me.slave["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.slave["lighting"].getNode(path).setValue( set );
                 me.toggleclick("landing-extend-" ~ i);
             }
         }

         path = "main-landing[" ~ i ~ "]/on";

         if( me.slave["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.slave["lighting"].getNode(path).setValue( set );
                 me.toggleclick("landing-on-" ~ i);
             }
         }
    }
}

Virtualcopilot.landingtaxi = func( set ) {
    var path = "";

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "landing-taxi[" ~ i ~ "]/extend";

         if( me.slave["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.slave["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-extend-" ~ i);
             }
         }

         path = "landing-taxi[" ~ i ~ "]/on";

         if( me.slave["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.slave["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-on-" ~ i);
             }
         }
    }
}

Virtualcopilot.taxiturn = func( set ) {
    var path = "";

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "taxi-turn[" ~ i ~ "]/on";

         if( me.slave["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.slave["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-turn-" ~ i);
             }
         }
    }
}

Virtualcopilot.timestamp = func {
    me.copilot.getChild("state").setValue(me.getlog());
    me.copilot.getChild("time").setValue(getprop("/sim/time/gmt-string"));
}


# ==========
# NAVIGATION
# ==========

Navigation = {};

Navigation.new = func {
   var obj = { parents : [Navigation,System], 

           ap : nil,
           engineer : nil,
           navigation : nil,
           waypoints : nil,

           DESTINATIONFT : 0.0,

           altitudeft : 0.0,

           NOSPEEDFPM : 0.0,

           SUBSONICKT : 480,                                 # estimated ground speed
           FLIGHTKT : 150,                                   # minimum ground speed

           groundkt : 0,

           SUBSONICKGPH : 20000,                             # subsonic consumption

           kgph : 0,

           NOFUELKG : -999,

           totalkg : 0
         };

   obj.init();

   return obj;
}

Navigation.init = func {
    me.init_ancestor("/systems/crew/engineer");

    me.ap = props.globals.getNode("/controls/autoflight");
    me.engineer = props.globals.getNode("/systems/crew/engineer");
    me.navigation = props.globals.getNode("/systems/crew/engineer/navigation").getChildren("wp");
    me.waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");
}

Navigation.schedule = func {
   var groundfps = me.slave["ins"].getNode("ground-speed-fps").getValue();
   var id = "";
   var distnm = 0.0;
   var targetft = 0;
   var selectft = 0.0;
   var fuelkg = 0.0;
   var speedfpm = 0.0;

   if( groundfps != nil ) {
       me.groundkt = groundfps * constant.FPSTOKT;
   }

   me.totalkg = me.slave["fuel"].getChild("total-kg").getValue();

   # on ground
   if( me.groundkt < me.FLIGHTKT ) {
       me.groundkt = me.SUBSONICKT;
       me.kgph = me.SUBSONICKGPH;
   }
   else {
       # gauge is NOT REAL
       me.kgph = me.slave["fuel"].getNode("fuel-flow-kg_ph").getValue();
   }

   me.altitudeft = me.noinstrument["altitude"].getValue();
   selectft = me.ap.getChild("altitude-select").getValue();


   # waypoint
   for( var i = 0; i < 3; i = i+1 ) {
        if( i < 2 ) {
            id = me.waypoints[i].getChild("id").getValue();
            distnm = me.waypoints[i].getChild("dist").getValue();
            targetft = selectft;
        }

        # last
        else {
            id = getprop("/autopilot/route-manager/wp-last/id"); 
            distnm = getprop("/autopilot/route-manager/wp-last/dist"); 
            targetft = me.DESTINATIONFT;
        }

        fuelkg = me.estimatefuelkg( id, distnm );
        speedfpm = me.estimatespeedfpm( id, distnm, targetft );

        # display for FDM debug, or navigation
        me.navigation[i].getChild("fuel-kg").setValue(fuelkg);
        me.navigation[i].getChild("speed-fpm").setValue(speedfpm);
   }
}

Navigation.estimatespeedfpm = func( id, distnm, targetft ) {
   var speedfpm = me.NOSPEEDFPM;
   var minutes = 0.0;

   if( id != "" and distnm != nil ) {
       minutes = ( distnm / me.groundkt ) * constant.HOURTOMINUTE;
       speedfpm = ( targetft - me.altitudeft ) / minutes;
   }

   return speedfpm;
}

Navigation.estimatefuelkg = func( id, distnm ) {
   var fuelkg = me.NOFUELKG;
   var ratio = 0.0;

   if( id != "" and distnm != nil ) {
       ratio = distnm / me.groundkt;
       fuelkg = me.kgph * ratio;
       fuelkg = me.totalkg - fuelkg;
       if( fuelkg < 0 ) {
           fuelkg = 0;
       }
   }

   return fuelkg;
}
