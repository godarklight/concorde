# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains checklist tasks.


# ================
# VIRTUAL ENGINEER
# ================

Virtualengineer = {};

Virtualengineer.new = func {
   obj = { parents : [Virtualengineer,System], 

           autopilotsystem : nil,
           fuelsystem : nil,

           navigation : Navigation.new(),

           GROUNDSEC : 30.0,
           CRUISESEC : 15.0,
           rates : 0.0,

           crew : nil,
           crewcontrol : nil,
           engineer : nil,
           engines : nil,
           lighting : nil,

           SAFEFT : 1500.0,

           aglft : 0.0,

           CRUISEMACH : 1.95,

           MAXPERCENT : 53.6,                                # maximum on ground
           CGPERCENT : 0.3,

           activ : constant.FALSE,
           state : ""
         };

    obj.init();

    return obj;
}

Virtualengineer.init = func {
    me.init_ancestor("/systems/crew/engineer");

    me.crew = props.globals.getNode("/systems/crew");
    me.crewcontrol = props.globals.getNode("/controls/crew");
    me.engineer = props.globals.getNode("/systems/crew/engineer");
    me.engines = props.globals.getNode("/controls/engines").getChildren("engine");

    settimer( func { me.reset(); }, me.CRUISESEC );
    settimer( func { me.schedule(); }, me.CRUISESEC );
}

Virtualengineer.set_relation = func( autopilot, fuel ) {
    me.autopilotsystem = autopilot;
    me.fuelsystem = fuel;
}

Virtualengineer.toggleexport = func {
   if( !me.crewcontrol.getChild("engineer").getValue() ) {
       me.crewcontrol.getChild("engineer").setValue(constant.TRUE);

       if( me.crew.getChild("serviceable").getValue() ) {
           me.supervisor();
       }
       else {
           me.engineer.getChild("activ").setValue(constant.FALSE);
       }
   }
   else {
       me.crewcontrol.getChild("engineer").setValue(constant.FALSE);
   }
}

Virtualengineer.reset = func {
    me.setweighthuman();
}

Virtualengineer.schedule = func {
    if( me.crew.getChild("serviceable").getValue() ) {
        me.supervisor();
    }
    else {
        me.rates = me.GROUNDSEC;
        me.engineer.getChild("activ").setValue(constant.FALSE);
    }

    me.navigation.schedule();

    settimer( func { me.schedule(); }, me.rates );
}

Virtualengineer.supervisor = func {
    me.activ = constant.FALSE;
    me.rates = me.GROUNDSEC;


    if( me.crewcontrol.getChild("engineer").getValue() ) {
        me.state = "";

        me.aglft = me.noinstrument["agl"].getValue();
        if( me.aglft > constantaero.APPROACHFT ) {
            me.rates = constant.rates( me.CRUISESEC );
        }

        checklist = me.crew.getChild("checklist").getValue();

        if( checklist == "taxi" ) {
            me.activ = constant.TRUE;
            me.afterlanding();
        }

        elsif( checklist != "gate" and checklist != "parking" ) {
            me.activ = constant.TRUE;
            me.flight();
        }


        me.allways();

        me.engineer.getChild("state").setValue(me.state);
        me.engineer.getChild("time").setValue(getprop("/sim/time/gmt-string"));
    }

    me.engineer.getChild("activ").setValue(me.activ);
}

Virtualengineer.allways = func {
    me.setweight();
}

Virtualengineer.flight = func {
    me.fuel();
    me.rating();
}

Virtualengineer.afterlanding = func {
    me.fuel();
    me.rating();

    # taxi with outboard engines
    if( !me.engines[1].getChild("cutoff").getValue() or
        !me.engines[2].getChild("cutoff").getValue() ) {
        for( i=1; i<3; i=i+1 ) {
             me.engines[i].getChild("cutoff").setValue(constant.TRUE);
        }

        me.log("2engines");
    }
}

Virtualengineer.rating = func {
    rating = "takeoff";
    flight = "climb";

    if( me.aglft > me.SAFEFT ) {
        rating = "flight";
    }

    if( me.autopilotsystem.has_altitude_hold() ) {
        flight = "cruise";
    }

    else {
        speedmach = me.noinstrument["mach"].getValue();
        # see check-list
        if( speedmach > me.CRUISEMACH ) {
            flight = "cruise";
        }
    }

    me.applyrating( flight, rating );
}

Virtualengineer.applyrating = func( flight, rating ) {
    for( i=0; i<4; i=i+1 ) {
         flightnow = me.engines[i].getChild("rating-flight").getValue();
         if( flightnow != flight ) {
             me.engines[i].getChild("rating-flight").setValue(flight);
         }

         # flight once safe
         ratingnow = me.engines[i].getChild("rating").getValue();
         if( ratingnow != rating and rating == "flight" ) {
             if( !getprop("/controls/gear/gear-down") ) {
                 me.engines[i].getChild("rating").setValue(rating);
             }
         }
    }
}

# set weight datum
Virtualengineer.setweight = func {
    # after fuel loading
    reset = me.slave["fuel2"].getChild("reset").getValue();

    # after 1 reset of fuel consumed
    if( !reset ) {
        for( i = 0; i < 4; i = i+1 ) {
             if( me.slave["fuel-consumed"][i].getChild("reset").getValue() ) {
                 reset = constant.TRUE;
                 break;
             }
        }
    }

    if( reset ) {
        me.log("set-weight");
        me.setweighthuman();
    }
}

Virtualengineer.setweighthuman = func {
    totalkg = me.slave["fuel"].getChild("total-kg").getValue();
    me.fuelsystem.setweighthuman( totalkg );
}

Virtualengineer.fuel = func {
    forward = constant.FALSE;
    aft = constant.FALSE;

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

    me.engineer.getNode("cg/aft").setValue(aft);
    me.engineer.getNode("cg/forward").setValue(forward);
}

Virtualengineer.applyfuel = func( forward, aft, engine, afttrim) {
    # no 2D panel
    me.fuelsystem.aft2Dhuman( constant.FALSE );

    # pumps
    empty5 = me.fuelsystem.empty("5");
    empty5A = me.fuelsystem.empty("5A");
    empty6 = me.fuelsystem.empty("6");
    empty7 = me.fuelsystem.empty("7");
    empty7A = me.fuelsystem.empty("7A");
    empty8 = me.fuelsystem.empty("8");
    empty9 = me.fuelsystem.empty("9");
    empty10 = me.fuelsystem.empty("10");
    empty11 = me.fuelsystem.empty("11");


    # shut all unused pumps
    me.fuelsystem.pumphuman( "5", !empty5 );
    me.fuelsystem.pumphuman( "7", !empty7 );
    me.fuelsystem.pumphuman( "5A", constant.FALSE );
    me.fuelsystem.pumphuman( "7A", constant.FALSE );

    if( empty5 and !empty6 ) {
        pump6 = constant.TRUE;
    }
    else {
        pump6 = constant.FALSE;
    }
    me.fuelsystem.pumphuman( "6", pump6 );

    if( empty7 and !empty8 ) {
        pump8 = constant.TRUE;
    }
    else {
        pump8 = constant.FALSE;
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
    auxilliary = constant.FALSE;
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

Virtualengineer.log = func( message ) {
    me.state = me.state ~ " " ~ message;
}


# ===============
# VIRTUAL COPILOT
# ===============

Virtualcopilot = {};

Virtualcopilot.new = func {
   obj = { parents : [Virtualcopilot,System],

           autopilotsystem : nil,
           mwssystem : nil,
 
           copilot : nil,
           crew : nil,
           crewcontrol : nil,
           flaps : nil,
           lighting : nil,
           mwscontrol : nil,

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

           recalled : { "before" : constant.FALSE, "after" : constant.FALSE },

           activ : constant.FALSE,
           emergency : constant.FALSE,
           state : "",
           checklist : ""
         };

   obj.init();

   return obj;
};

Virtualcopilot.init = func {
   me.copilot = props.globals.getNode("/systems/crew/copilot");
   me.crew = props.globals.getNode("/systems/crew");
   me.crewcontrol = props.globals.getNode("/controls/crew");
   me.flaps = props.globals.getNode("/sim/flaps");
   me.lighting = props.globals.getNode("/controls/lighting");
   me.mwscontrol = props.globals.getNode("/controls/mws");

   me.init_ancestor("/systems/crew/copilot");

   settimer( func { me.slowschedule(); }, me.TAKEOFFSEC );
}

Virtualcopilot.set_relation = func( autopilot, mws ) {
   me.autopilotsystem = autopilot;
   me.mwssystem = mws;
}

Virtualcopilot.toggleexport = func {
   if( !me.crewcontrol.getChild("copilot").getValue() ) {
       me.crewcontrol.getChild("copilot").setValue(constant.TRUE);
   }
   else {
       me.crewcontrol.getChild("copilot").setValue(constant.FALSE);
   }
       
   if( me.crew.getChild("serviceable").getValue() ) {
       me.unexpected();
       me.routine();
   }
   else {
       me.copilot.getChild("activ").setValue(constant.FALSE);
   }
}

Virtualcopilot.schedule = func {
   if( me.crew.getChild("serviceable").getValue() ) {
       me.unexpected();
   }
}

Virtualcopilot.slowschedule = func {
   if( me.crew.getChild("serviceable").getValue() ) {
       me.routine();
   }
   else {
       me.rates = constant.rates( me.CRUISESEC );
       me.copilot.getChild("activ").setValue(constant.FALSE);
   }

   settimer( func { me.slowschedule(); }, me.rates );
}

Virtualcopilot.unexpected = func {
   me.emergency = constant.FALSE;

   if( me.crewcontrol.getChild("copilot").getValue() ) {
       me.state = "";
       me.checklist = me.crew.getChild("checklist").getValue();

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
   me.rates = constant.rates( me.CRUISESEC );

   if( !me.crew.getChild("emergency").getValue() ) {
       if( me.crewcontrol.getChild("copilot").getValue() ) {
           me.state = "";
           me.checklist = me.crew.getChild("checklist").getValue();

           # normal procedures
           if ( me.normal() ) {
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

           me.speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();

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
   me.recallreset();
}

Virtualcopilot.beforetakeoff = func {
   me.nosevisor( constant.FALSE, constant.FALSE );
   me.landinglights( constant.FALSE );

   # may take off with inhibit
   if( !me.mwscontrol.getChild("inhibit").getValue() ) {
       me.recall("before");
   }

   setprop("/instrumentation/takeoff-monitor/armed",constant.TRUE);
}

Virtualcopilot.aftertakeoff = func {
   me.landinggear( constant.FALSE );
   me.nosevisor( constant.FALSE, constant.FALSE );
   me.landinglights( constant.FALSE );

   me.recall("after");

   setprop("/instrumentation/takeoff-monitor/armed",constant.FALSE);
}

Virtualcopilot.beforelanding = func {
   me.landinggear( constant.TRUE );
   me.nosevisor( constant.TRUE, constant.FALSE );
   me.landinglights( constant.TRUE );

   # disable
   if( getprop("/controls/gear/brake-parking-lever") ) {
       controls.applyParkingBrake(1);
   }

   # relocation in flight
   setprop("/instrumentation/takeoff-monitor/armed",constant.FALSE);
}

Virtualcopilot.afterlanding = func {
   me.nosevisor( constant.TRUE, constant.TRUE );
}

Virtualcopilot.allways = func {
}

Virtualcopilot.recallreset = func {
   if( me.recalled["before"] and me.recalled["after"] ) {
       me.recalled["before"] = constant.FALSE;
       me.recalled["after"] = constant.FALSE;
   }
}

Virtualcopilot.recall = func( name ) {
   # only once
   if( !me.recalled[name] ) {
       me.mwssystem.recallexport();
       me.recalled[name] = constant.TRUE;
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
   if( !landing and me.aglft > constantaero.GEARFT ) {
       if( me.speedkt > me.GEARKT ) {
           controls.gearDown(-1);
       }
   }
   elsif( landing and me.aglft < constantaero.LANDINGFT ) {
       if( me.speedkt < me.GEARKT ) {
           controls.gearDown(1);
       }
   }
}

Virtualcopilot.nosevisor = func( landing, taxi ) {
    targetpos = 0;

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

    # not to us to create the property
    child = me.flaps.getChild("current-setting");
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
            me.log("nose");
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
    for( i=0; i < 2; i=i+1 ) {
         me.lighting.getNode("external/main-landing[" ~ i ~ "]/extend").setValue( set );
         me.lighting.getNode("external/main-landing[" ~ i ~ "]/on").setValue( set );
    }
}

Virtualcopilot.landingtaxi = func( set ) {
    for( i=0; i < 2; i=i+1 ) {
         me.lighting.getNode("external/landing-taxi[" ~ i ~ "]/extend").setValue( set );
         me.lighting.getNode("external/landing-taxi[" ~ i ~ "]/on").setValue( set );
    }
}

Virtualcopilot.taxiturn = func( set ) {
    for( i=0; i < 2; i=i+1 ) {
         me.lighting.getNode("external/taxi-turn[" ~ i ~ "]/on").setValue( set );
    }
}

Virtualcopilot.timestamp = func {
    me.copilot.getChild("state").setValue(me.state);
    me.copilot.getChild("time").setValue(getprop("/sim/time/gmt-string"));
}

Virtualcopilot.log = func( message ) {
    me.state = me.state ~ " " ~ message;
}


# ==========
# NAVIGATION
# ==========

Navigation = {};

Navigation.new = func {
   obj = { parents : [Navigation,System], 

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
   groundfps = me.slave["ins"].getNode("ground-speed-fps").getValue();
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

   me.altitudeft = me.slave["altimeter"].getChild("indicated-altitude-ft").getValue();
   selectft = me.ap.getChild("altitude-select").getValue();


   # waypoint
   for( i = 0; i < 3; i = i+1 ) {
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
   if( id != "" and distnm != nil ) {
       minutes = ( distnm / me.groundkt ) * constant.HOURTOMINUTE;
       speedfpm = ( targetft - me.altitudeft ) / minutes;
   }
   else {
       speedfpm = me.NOSPEEDFPM;
   }

   return speedfpm;
}

Navigation.estimatefuelkg = func( id, distnm ) {
   if( id != "" and distnm != nil ) {
       ratio = distnm / me.groundkt;
       fuelkg = me.kgph * ratio;
       fuelkg = me.totalkg - fuelkg;
       if( fuelkg < 0 ) {
           fuelkg = 0;
       }
   }
   else {
       fuelkg = me.NOFUELKG;
   }

   return fuelkg;
}
