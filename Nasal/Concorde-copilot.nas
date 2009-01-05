# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains checklist tasks.


# ===============
# VIRTUAL COPILOT
# ===============

Virtualcopilot = {};

Virtualcopilot.new = func {
   var obj = { parents : [Virtualcopilot,Virtualcrew,Checklist,System],

           airbleedsystem : nil,
           autopilotsystem : nil,
           electricalsystem : nil,
           flightsystem : nil,
           mwssystem : nil,
           voicecrew : nil,
 
           nightlighting : Nightlighting.new(),

           FUELSEC : 30.0,
           CRUISESEC : 10.0,
           TAKEOFFSEC : 5.0,

           rates : 0.0,

           VLA41KT : 300.0,
           VLA15KT : 250.0,
           MARGINKT : 25.0,

           speedkt : 0.0,

           FL41FT : 41000.0,
           FL15FT : 15000.0,
           NOSEFT : 600.0,                                # nose retraction

           aglft : 0.0,
           altitudeft : 0.0,

           STEPFTPM : 100.0,
           GLIDEFTPM : -1500.0,                           # best glide (guess)

           descentftpm : 0.0,

           VISORUP : 0,
           VISORDOWN : 1,
           NOSE5DEG : 2,
           NOSEDOWN : 3,

           emergency : constant.FALSE
         };

   obj.init();

   return obj;
};

Virtualcopilot.init = func {
   var path = "/systems/copilot";

   me.inherit_system(path);
   me.inherit_checklist(path);
   me.inherit_virtualcrew(path);

   me.rates = me.TAKEOFFSEC;
   me.run();
}

Virtualcopilot.set_relation = func( airbleed, autopilot, electrical, flight, lighting, mws, voice ) {
   me.airbleedsystem = airbleed;
   me.autopilotsystem = autopilot;
   me.electricalsystem = electrical;
   me.flightsystem = flight;
   me.mwssystem = mws;
   me.voicecrew = voice;

   me.nightlighting.set_relation( lighting );
}


Virtualcopilot.toggleexport = func {
   var launch = constant.FALSE;

   if( !me.itself["copilot"].getChild("activ").getValue() ) {
       launch = constant.TRUE;
   }

   me.itself["copilot"].getChild("activ").setValue(launch);
       
   if( launch and !me.is_running() ) {
       # must switch again lights
       me.nightlighting.set_task();

       me.schedule();
       me.slowschedule();
   }
}

Virtualcopilot.slowschedule = func {
   me.reset();

   me.rates = me.FUELSEC;

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.timestamp();
   }

   me.runslow();
}

Virtualcopilot.schedule = func {
   me.reset();

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.routine();
   }
   else {
       me.rates = me.CRUISESEC;
       me.itself["root"].getChild("activ").setValue(constant.FALSE);
   }

   me.run();
}

Virtualcopilot.fastschedule = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.unexpected();
   }
}

Virtualcopilot.runslow = func {
   if( me.itself["copilot"].getChild("activ").getValue() ) {
       me.rates = me.speed_ratesec( me.rates );
       settimer( func { me.slowschedule(); }, me.rates );
   }
}

Virtualcopilot.run = func {
   if( me.itself["copilot"].getChild("activ").getValue() ) {
       me.set_running();

       me.rates = me.speed_ratesec( me.rates );
       settimer( func { me.schedule(); }, me.rates );
   }
}

Virtualcopilot.unexpected = func {
   me.emergency = constant.FALSE;

   if( me.itself["copilot"].getChild("activ").getValue() ) {
       me.checklist = me.dependency["voice"].getChild("checklist").getValue();

       me.speedkt = me.noinstrument["airspeed"].getValue();
       me.altitudeft = me.noinstrument["altitude"].getValue();

       # 4 engines flame out
       me.engine4flameout();

       me.timestamp();
   }

   else {
       me.autopilotsystem.realhuman();
   }

   me.dependency["crew"].getChild("emergency").setValue(me.emergency);
}

Virtualcopilot.routine = func {
   me.rates = me.CRUISESEC;

   if( !me.dependency["crew"].getChild("emergency").getValue() ) {
       if( me.itself["copilot"].getChild("activ").getValue() ) {
           me.checklist = me.dependency["voice"].getChild("checklist").getValue();

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

   me.itself["root"].getChild("activ").setValue(me.is_activ());
}

Virtualcopilot.engine4flameout = func {
   # hold heading and speed, during engine start
   if( me.altitudeft > constantaero.APPROACHFT ) {
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
    me.rates = me.TAKEOFFSEC;

    me.speedkt = me.noinstrument["airspeed"].getValue();
    me.altitudeft = me.noinstrument["altitude"].getValue();
    me.aglft = me.noinstrument["agl"].getValue();

    if( me.is_beforetakeoff() ) {
        me.set_activ();
        me.beforetakeoff();
        me.rates = me.TAKEOFFSEC;
    }

    elsif( me.is_taxi() ) {
        me.set_activ();
        me.taxi();
    }

    elsif( me.is_afterstart() ) {
        me.set_activ();
        me.afterstart();
    }

    elsif( me.is_enginestart() ) {
        me.set_activ();
        me.completed();
    }

    elsif( me.is_beforestart() ) {
        me.set_activ();
        me.beforestart();
    }

    elsif( me.is_cockpit() ) {
        me.set_activ();
        me.cockpit();
    }

    elsif( me.is_preliminary() ) {
        me.completed();
    }

    elsif( me.is_external() ) {
        me.completed();
    }

    elsif( me.is_stopover() ) {
        me.set_activ();
        me.stopover();
    }

    elsif( me.is_parking() ) {
        me.set_activ();
        me.parking();
    }

    elsif( me.is_afterlanding() ) {
        me.set_activ();
        me.afterlanding();
    }

    elsif( me.is_beforelanding() ) {
        me.set_activ();
        me.beforelanding();
        me.rates = me.TAKEOFFSEC;
    }

    elsif( me.is_approach() ) {
        me.set_activ();
        me.approach();
        me.rates = me.TAKEOFFSEC;
    }

    elsif( me.is_descent() ) {
        me.set_activ();
        me.descent();
    }

    elsif( me.is_transsonic() ) {
        me.set_activ();
        me.transsonic();
    }

    elsif( me.is_climb() ) {
        me.set_activ();
        me.climb();
    }

    elsif( me.is_aftertakeoff() ) {
        me.set_activ();
        me.aftertakeoff();
        me.rates = me.TAKEOFFSEC;
    }


    me.allways();

    return me.is_activ();
}


# ------
# FLIGHT
# ------
Virtualcopilot.allways = func {
    if( me.altitudeft > constantaero.APPROACHFT ) {
        me.nosevisor( me.VISORUP );
    }

    if( me.altitudeft > constantaero.TRANSITIONFT ) {
        me.altimeter();
    }

    me.nightlighting.copilot( me );
}

Virtualcopilot.aftertakeoff = func {
    me.landinggear( constant.FALSE );
    
    # waits for V2
    if( me.aglft > constantaero.REHEATFT ) {
        me.mainlanding( constant.FALSE );
        me.landingtaxi( constant.FALSE );

        me.mwsrecallcaptain();

        me.nosevisor( me.VISORDOWN );

        # otherwise disturbing
        me.takeoffmonitor( constant.FALSE );

        me.completed();
    }
}

Virtualcopilot.climb = func {
    me.taxiturn( constant.FALSE );

    me.completed();
}

Virtualcopilot.transsonic = func {
    me.completed();
}

Virtualcopilot.descent = func {
    me.completed();
}

Virtualcopilot.approach = func {
    me.taxiturn( constant.TRUE );

    me.nosevisor( me.VISORDOWN );

    # relocation in flight
    me.takeoffmonitor( constant.FALSE );

    me.completed();
}

Virtualcopilot.beforelanding = func {
    me.landinggear( constant.TRUE );
    me.nosevisor( me.NOSEDOWN );
    me.brakelever();

    me.mainlanding( constant.TRUE );

    # relocation in flight
    me.takeoffmonitor( constant.FALSE );

    me.completed();
}


# ------
# GROUND
# ------
Virtualcopilot.afterlanding = func {
    me.nosevisor( me.NOSE5DEG );

    me.landingtaxi( constant.TRUE );
    me.mainlanding( constant.FALSE );

    me.completed();
}

Virtualcopilot.parking = func {
    me.mainlanding( constant.FALSE );
    me.landingtaxi( constant.FALSE );
    me.taxiturn( constant.FALSE );

    me.nosevisor( me.VISORUP );

    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         me.ins( i, constantaero.INSALIGN );
    }

    me.completed();
}

Virtualcopilot.stopover = func {
    me.allinverter( constant.FALSE );

    me.completed();
}

Virtualcopilot.cockpit = func {
    me.allinverter( constant.TRUE );

    me.completed();
}

Virtualcopilot.beforestart = func {
    if( me.can() ) {
        if( !me.is_completed() ) {
            if( !me.wait_ground() ) {
                me.voicecrew.pilotcheck( "clearance" );

                # must wait for ATC answer
                me.done_ground();
            }

            else {
                me.reset_ground();

                me.voicecrew.pilotcheck( "clear" );

                me.completed();
            }
        }
    }
}

Virtualcopilot.afterstart = func {
    me.grounddisconnect();

    me.flightchannelcaptain();

    if( me.has_completed() ) {
        me.voicecrew.pilotcheck( "completed" );
        me.voicecrew.startedinit();
    }
}

Virtualcopilot.taxi = func {
    me.nosevisor( me.NOSE5DEG );

    me.landingtaxi( constant.TRUE );
    me.mainlanding( constant.FALSE );

    me.completed();
}

Virtualcopilot.beforetakeoff = func {
    me.mainlanding( constant.TRUE );
    me.landingtaxi( constant.FALSE );
    me.taxiturn( constant.TRUE );

    me.mwsrecallcaptain();
    me.mwsinhibitcaptain();

    me.takeoffmonitor( constant.TRUE );

    me.completed();
}


# ---------------------
# MASTER WARNING SYSTEM
# ---------------------
Virtualcopilot.mwsinhibitcaptain = func {
    if( me.can() ) {
        if( !me.dependency["mws"].getChild("inhibit").getValue() ) {
            if( me.is_busy() ) {
                me.dependency["mws"].getChild("inhibit").setValue(constant.TRUE);
                me.toggleclick("inhibit");
            }

            else {
                me.done_crew("not-inhibit");
                me.voicecrew.engineercheck( "inhibit" );
            }
        }
    }
}

Virtualcopilot.mwsrecallcaptain = func {
    if( me.can() ) {
        if( !me.is_recall() ) {
            if( me.is_busy() ) {
                me.mwssystem.recallexport();
                me.toggleclick("recall");
            }

            else {
                me.done_crew("not-recall");
                me.voicecrew.engineercheck( "recall" );
            }
        }
    }
}


# ---------------
# FLIGHT CONTROLS
# ---------------
Virtualcopilot.allinverter = func( value ) {
    me.inverter( "blue", value );
    me.inverter( "green", value );
}

Virtualcopilot.inverter = func( color, value ) {
    if( me.can() ) {
        var path = "inverter-" ~ color;

        if( me.dependency["electric-dc"].getChild(path).getValue() != value ) {
            me.dependency["electric-dc"].getChild(path).setValue(value);
            me.toggleclick(path);
        }
    }
}

Virtualcopilot.is_flightchannel = func {
    var result = constant.TRUE;

    if( me.can() ) {
        if( !me.dependency["channel"].getChild("rudder-blue").getValue() or
            me.dependency["channel"].getChild("rudder-mechanical").getValue() or
            !me.dependency["channel"].getChild("inner-blue").getValue() or
            me.dependency["channel"].getChild("inner-mechanical").getValue() or
            !me.dependency["channel"].getChild("outer-blue").getValue() or
            me.dependency["channel"].getChild("outer-mechanical").getValue() ) {
            result = constant.FALSE;

            me.done_crew("channel-not-blue");
        }

        if( result ) {
            me.reset_crew();
        }
    }

    # captain must reset channels
    return result;
}

Virtualcopilot.flightchannel = func {
    if( me.can() ) {
        if( !me.dependency["channel"].getChild("rudder-blue").getValue() or
            me.dependency["channel"].getChild("rudder-mechanical").getValue() ) {
            me.dependency["channel"].getChild("rudder-blue").setValue(constant.TRUE);
            me.dependency["channel"].getChild("rudder-mechanical").setValue(constant.FALSE);

            me.flightsystem.resetexport();
            me.toggleclick("rudder-channel");
        }

        elsif( !me.dependency["channel"].getChild("inner-blue").getValue() or
            me.dependency["channel"].getChild("inner-mechanical").getValue() ) {
            me.dependency["channel"].getChild("inner-blue").setValue(constant.TRUE);
            me.dependency["channel"].getChild("inner-mechanical").setValue(constant.FALSE);

            me.flightsystem.resetexport();
            me.toggleclick("inner-channel");
        }

        elsif( !me.dependency["channel"].getChild("outer-blue").getValue() or
            me.dependency["channel"].getChild("outer-mechanical").getValue() ) {
            me.dependency["channel"].getChild("outer-blue").setValue(constant.TRUE);
            me.dependency["channel"].getChild("outer-mechanical").setValue(constant.FALSE);

            me.flightsystem.resetexport();
            me.toggleclick("outer-channel");
        }
    }
}

Virtualcopilot.flightchannelcaptain = func {
    if( me.is_busy() ) {
        me.flightchannel();
    }

    elsif( !me.is_flightchannel() ) {
        me.voicecrew.pilotcheck( "channel" );
    }
}


# -------
# ENGINES
# -------
Virtualcopilot.takeoffmonitor = func( set ) {
    if( me.can() ) {
        var path = "armed";

        if( me.dependency["to-monitor"].getChild(path).getValue() != set ) {
            me.dependency["to-monitor"].getChild(path).setValue( set );
            me.toggleclick("to-monitor");
        }
    }
}


# ---------
# AUTOPILOT
# ---------
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


# ----
# GEAR
# ----
Virtualcopilot.brakelever = func {
    if( me.can() ) {
        # disable
        if( me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
            controls.applyParkingBrake(1);
            me.toggleclick("brake-parking");
        }
    }
}

Virtualcopilot.landinggear = func( landing ) {
    if( me.can() ) {
        if( !landing ) {
            if( me.dependency["gear-ctrl"].getChild("gear-down").getValue() ) {
                if( me.aglft > constantaero.GEARFT and me.speedkt > constantaero.GEARKT ) {
                    controls.gearDown(-1);
                    me.toggleclick("gear-up");
                }

                # waits
                else {
                    me.done();
                }
            }

            elsif( me.dependency["gear-ctrl"].getChild("hydraulic").getValue() ) {
                if( me.dependency["gear"].getValue() == globals.Concorde.constantaero.GEARUP ) {
                    controls.gearDown(-1);
                    me.toggleclick("gear-neutral");
                }

                # waits
                else {
                    me.done();
                }
            }
        }

        elsif( !me.dependency["gear-ctrl"].getChild("gear-down").getValue() ) {
            if( me.aglft < constantaero.LANDINGFT and me.speedkt < constantaero.GEARKT ) {
                controls.gearDown(1);
                me.toggleclick("gear-down");
            }

            # waits
            else {
                me.done();
            }
        }
    }
}


# ----
# NOSE
# ----
Virtualcopilot.nosevisor = func( targetpos ) {
    if( me.can() ) {
        var currentpos = 0;
        var child = nil;


        # not to us to create the property
        child = me.dependency["flaps"].getChild("current-setting");
        if( child == nil ) {
            currentpos = me.VISORUP;
        }
        else {
            currentpos = child.getValue();
        }

        pos = targetpos - currentpos;
        if( pos != 0 ) {
            # - must be up above 270 kt.
            # - down only below 220 kt.
            if( ( targetpos <= me.VISORDOWN and me.speedkt < constantaero.NOSEKT ) or
                ( targetpos > me.VISORDOWN and me.speedkt < constantaero.GEARKT ) ) {
                controls.flapsDown( pos );
                me.toggleclick("nose");
            }

            # waits
            else {
                me.done();
            }
        }
    }
}


# ----------
# NAVIGATION
# ----------
Virtualcopilot.altimeter = func {
    if( me.can() ) {
        if( me.dependency["altimeter"].getChild("setting-inhg").getValue() != constantISA.SEA_inhg ) {
            me.dependency["altimeter"].getChild("setting-inhg").setValue(constantISA.SEA_inhg);
            me.toggleclick("altimeter");
        }
    }
}

Virtualcopilot.ins = func( index, mode ) {
    if( me.can() ) {
        if( me.dependency["ins"][index].getNode("msu").getChild("mode").getValue() != mode ) {
            me.dependency["ins"][index].getNode("msu").getChild("mode").setValue(mode);
            me.toggleclick("ins-" ~ index);
        }
    }
}


# --------
# LIGHTING
# --------
Virtualcopilot.mainlanding = func( set ) {
    var path = "";

    # optional in checklist
    if( !me.itself["copilot"].getChild("landing-lights").getValue() ) {
        set = constant.FALSE;
    }

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "main-landing[" ~ i ~ "]/extend";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("landing-extend-" ~ i);
             }
         }

         path = "main-landing[" ~ i ~ "]/on";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("landing-on-" ~ i);
             }
         }
    }
}

Virtualcopilot.landingtaxi = func( set ) {
    var path = "";

    # optional in checklist
    if( !me.itself["copilot"].getChild("landing-lights").getValue() ) {
        set = constant.FALSE;
    }

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "landing-taxi[" ~ i ~ "]/extend";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-extend-" ~ i);
             }
         }

         path = "landing-taxi[" ~ i ~ "]/on";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-on-" ~ i);
             }
         }
    }
}

Virtualcopilot.taxiturn = func( set ) {
    var path = "";

    for( var i=0; i < constantaero.NBAUTOPILOTS; i=i+1 ) {
         path = "taxi-turn[" ~ i ~ "]/on";

         if( me.dependency["lighting"].getNode(path).getValue() != set ) {
             if( me.can() ) {
                 me.dependency["lighting"].getNode(path).setValue( set );
                 me.toggleclick("taxi-turn-" ~ i);
             }
         }
    }
}


# ------
# GROUND
# ------
Virtualcopilot.grounddisconnect = func {
    if( me.can() ) {
        if( me.electricalsystem.has_ground() ) {
            if( !me.wait_ground() ) {
                me.voicecrew.pilotcheck( "disconnect" );

                # must wait for electrical system run (ground)
                me.done_ground();
            }

            else  {
                me.electricalsystem.groundserviceexport();

                me.reset_ground();
                me.done();
            }
        }

        elsif( me.airbleedsystem.has_groundservice() ) {
            if( !me.wait_ground() ) {
                # must wait for air bleed system run (ground)
                me.done_ground();
            }

            else  {
                me.airbleedsystem.groundserviceexport();

                me.reset_ground();
                me.done();
            }
        }

        elsif( me.airbleedsystem.has_reargroundservice() ) {
            if( !me.wait_ground() ) {
                # must wait for temperature system run (ground)
                me.done_ground();
            }

            else  {
                me.airbleedsystem.reargroundserviceexport();

                me.reset_ground();
                me.done();
            }
        }
    }
}
