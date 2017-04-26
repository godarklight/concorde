# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# =============
# CREW CALLOUTS 
# =============

Voice = {};

Voice.new = func {
   var obj = { parents : [Voice,Callout.new(),State.new(),Emergency.new("/systems/voice")],

               autopilotsystem : nil,

               phase : Voicephase.new("/systems/voice"),
               sensor : Voicesensor.new("/systems/voice"),
               intelligence : VoiceAI.new(),
               crewvoice : Crewvoice.new(),
               lastcheck : Checklist.new("/systems/voice"),

               MODIFYSEC : 15.0,                                 # to modify something
               ABSENTSEC : 15.0,                                 # less attention
               HOLDINGSEC : 5.0,

               rates : 0.0,                                      # variable time step

               ready : constant.FALSE,

               AGLLEVELFT : { "2500ft" : 2500, "1000ft" : 1000, "800ft" : 800, "500ft" : 500, "400ft" : 400, "300ft" : 300,
                              "200ft" : 200, "100ft" : 100, "50ft" : 50, "40ft" : 40, "30ft" : 30, "20ft" : 20, "15ft" : 15 },

               altitudeselect : constant.FALSE,
               selectft : 0.0,
               delayselectftsec : 0,
               vertical : "",

               category : constant.FALSE,
               alert : constant.FALSE,
               decision : constant.FALSE,
               decisiontogo : constant.FALSE,

               SPEEDLEVELKT : { "240kt" : 240, "100kt" : 100, "60kt" : 60 },

               v1 : constant.FALSE,
               v2 : constant.FALSE,

               FLAREDEG : 12.5,

               fueltransfert : constant.FALSE,

               airport : "",
               runway : "",

               real : constant.FALSE,                            # real checklist
               automata : "",
               automata2 : ""
         };

   obj.init();

   return obj;
}

Voice.init = func {
   me.selectft = me.dependency["autoflight"].getChild("altitude-select").getValue();

   me.callout = "holding";
   
   settimer( func { me.schedule(); }, constant.HUMANSEC );
}

Voice.set_relation = func( autopilot, copilot, engineer ) {
    me.autopilotsystem = autopilot;
    
    me.crewvoice.set_relation( copilot, engineer );
}

Voice.set_rates = func( steps ) {
    me.rates = steps;

    me.phase.set_rates( me.rates );
}

# disable at startup
Voice.startupexport = func {
   var disable = me.itself["root-ctrl"].getChild("disable").getValue();
   
   # disable voice at startup
   if( disable ) {
       me.set_service(constant.FALSE);
   }
}

Voice.crewtextexport = func {
    me.crewvoice.textexport();
}

# enable crew
Voice.serviceexport = func {
   if( !me.dependency["crew"].getChild("serviceable").getValue() ) {
       me.nochecklistinit();
   }
}

# enable voice
Voice.enableexport = func {
   var disable = me.itself["root-ctrl"].getChild("disable").getValue();
   var serviceable = !disable;
       
   me.set_service(serviceable);
}

Voice.toggleexport = func {
   if( me.dependency["crew"].getChild("serviceable").getValue() ) {
       me.groundexport();
   }
}

Voice.set_service = func( serviceable ) {
   me.itself["root"].getChild("serviceable").setValue(serviceable);
   me.itself["menu"].getChild("enabled").setValue(serviceable);
}


# -------------------------------
# ground checklists not in flight
# -------------------------------
Voice.afterlandingexport = func {
   if( me.intelligence.has_crew() ) {
       var result = constant.FALSE;

       # abort takeoff
       if( me.is_holding() ) {
           result = constant.TRUE;
       }

       # aborted takeoff before V1
       elsif( me.is_takeoff() and !me.v1 ) {
           result = constant.TRUE;
       }

       # after landing
       elsif( me.is_taxiway() ) {
           result = constant.TRUE;
       }

       # abort taxi
       elsif( me.is_started() or me.is_runway() ) {
           result = constant.TRUE;
       }

       if( result ) {
           me.afterlandinginit();
       }
   }
}

Voice.parkingexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_terminal() ) {
           me.parkinginit();
       }
   }
}

Voice.stopoverexport = func {
   if( me.intelligence.has_crew() ) {
       # at FG start, default is holding without checklist.
       if( me.is_gate() or ( me.is_holding() or me.is_takeoff() ) ) {
           me.set_startup();
           me.stopoverinit();
       }
   }
}

Voice.externalexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_gate() ) {
           me.externalinit();
       }
   }
}

Voice.preliminaryexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_gate() ) {
           me.preliminaryinit();
       }
   }
}

Voice.cockpitexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_gate() ) {
           me.cockpitinit();
       }
   }
}

Voice.beforestartexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_gate() ) {
           me.beforestartinit();
       }
   }
}

Voice.enginestartexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_gate() ) {
           me.enginestartinit();
       }
   }
}

Voice.pushbackexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_gate() ) {
           me.pushbackinit();
       }
   }
}

Voice.afterstartexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_started() ) {
           me.afterstartinit();
       }
   }
}

Voice.taxiexport = func {
   if( me.intelligence.has_crew() ) {
       # at FG start, default is holding without checklist.
       if( me.is_started() or ( me.is_holding() or me.is_takeoff() ) ) {
           me.set_startup();
           me.taxiinit();
       }
   }
}

Voice.beforetakeoffexport = func {
   if( me.intelligence.has_crew() ) {
       if( me.is_holding() or me.is_takeoff() ) {
           me.set_startup();
           me.beforetakeoffinit();
       }
   }
}


# ------------------------------------------
# flight checklists can be trained on ground
# ------------------------------------------
Voice.aftertakeoffexport = func {
   if( me.intelligence.has_crew() ) {
       me.aftertakeoffinit();
   }
}

Voice.climbexport = func {
   if( me.intelligence.has_crew() ) {
       me.climbinit();
   }
}

Voice.transsonicexport = func {
   if( me.intelligence.has_crew() ) {
       me.transsonicinit();
   }
}

Voice.descentexport = func {
   if( me.intelligence.has_crew() ) {
       me.descentinit();
   }
}

Voice.approachexport = func {
   if( me.intelligence.has_crew() ) {
       me.approachinit();
   }
}

Voice.beforelandingexport = func {
   if( me.intelligence.has_crew() ) {
       me.beforelandinginit();
   }
}

Voice.groundexport = func {
   if( me.intelligence.has_AI() ) {
       var presets = me.dependency["crew-ctrl"].getChild("presets").getValue();

       if( presets == 0 ) {
           me.beforetakeoffexport();
       }

       elsif( presets == 1 ) {
           me.taxiexport();
       }

       elsif( presets == 2 ) {
           me.stopoverexport();
       }
   }
}


# --------------------
# emergency procedures
# --------------------
Voice.fourengineflameoutexport = func {
   if( me.intelligence.has_crew() ) {
       me.nochecklistinit();
       me.fourengineflameoutinit();
   }
}

Voice.fourengineflameoutmach1export = func {
   if( me.intelligence.has_crew() ) {
       me.nochecklistinit();
       me.fourengineflameoutmach1init();
   }
}


# ------------------------
# to unlock checklists bug
# ------------------------
Voice.abortexport = func {
   me.nochecklistinit();

   me.captainfeedback("abort");
}


# ----------------------
# to unlock callouts bug
# ----------------------
Voice.taxiwayexport = func {
   me.taxiwayinit();
}

Voice.terminalexport = func {
   me.terminalinit();
}

Voice.gateexport = func {
   me.gateinit();
}

Voice.takeoffexport = func {
   me.takeoffinit();
}

Voice.flightexport = func {
   me.flightinit();
}

Voice.landingexport = func {
   me.landinginit();
}


# ------------
# voice checks
# ------------
Voice.captainfeedback = func( action ) {
   if( me.is_state() ) {
       # no voice
   }
   
   else {
       me.crewvoice.nowmember( action, "captain", "allways" );
   }
}

Voice.captaincheck = func( action ) {
   if( me.is_state() ) {
       # no voice
   }

   elsif( me.is_beforetakeoff() ) {
       me.crewvoice.nowmember( action, "captain", "beforetakeoff" );
   }
   
   elsif( me.is_aftertakeoff() ) {
       me.crewvoice.nowmember( action, "captain", "aftertakeoff" );
   }

   elsif( me.is_afterstart() ) {
       me.crewvoice.nowmember( action, "captain", "afterstart" );
   }

   elsif( me.is_taxi() ) {
       me.crewvoice.nowmember( action, "captain", "taxi" );
   }

   elsif( me.is_afterlanding() ) {
       me.crewvoice.nowmember( action, "captain", "afterlanding" );
   }

   else {
       print("captain check not found : ", action);
   }
}

Voice.pilotcheck = func( action, argument = "" ) {
   if( me.is_state() ) {
       # no voice
   }
   
   else {
       me.itself["root"].getChild("argument").setValue( argument );

       if( me.is_beforestart() ) {
           me.crewvoice.nowmember( action, "pilot", "beforestart" );
       }

       elsif( me.is_pushback() ) {
           me.crewvoice.nowmember( action, "pilot", "pushback" );
       }

       elsif( me.is_afterstart() ) {
           me.crewvoice.nowmember( action, "pilot", "afterstart" );
       }

       else {
           print("pilot check not found : ", action);
       }
   }
}

Voice.engineercheck = func( action ) {
   if( me.is_state() ) {
       # no voice
   }
   
   elsif( me.is_aftertakeoff() ) {
       me.crewvoice.nowmember( action, "engineer", "aftertakeoff" );
   }

   elsif( me.is_climb() ) {
       me.crewvoice.nowmember( action, "engineer", "climb" );
   }

   elsif( me.is_transsonic() ) {
       me.crewvoice.nowmember( action, "engineer", "transsonic" );
   }

   elsif( me.is_descent() ) {
       me.crewvoice.nowmember( action, "engineer", "descent" );
   }

   elsif( me.is_approach() ) {
       me.crewvoice.nowmember( action, "engineer", "approach" );
   }

   elsif( me.is_beforelanding() ) {
       me.crewvoice.nowmember( action, "engineer", "beforelanding" );
   }

   elsif( me.is_afterlanding() ) {
       me.crewvoice.nowmember( action, "engineer", "afterlanding" );
   }

   elsif( me.is_parking() ) {
       me.crewvoice.nowmember( action, "engineer", "parking" );
   }

   elsif( me.is_stopover() ) {
       me.crewvoice.nowmember( action, "engineer", "stopover" );
   }

   elsif( me.is_cockpit() ) {
       me.crewvoice.nowmember( action, "engineer", "cockpit" );
   }

   elsif( me.is_beforestart() ) {
       me.crewvoice.nowmember( action, "engineer", "beforestart" );
   }

   elsif( me.is_pushback() ) {
       me.crewvoice.nowmember( action, "engineer", "pushback" );
   }

   elsif( me.is_taxi() ) {
       me.crewvoice.nowmember( action, "engineer", "taxi" );
   }

   elsif( me.is_beforetakeoff() ) {
       me.crewvoice.nowmember( action, "engineer", "beforetakeoff" );
   }

   else {
       print("engineer check not found : ", action);
   }
}


# -----------
# voice calls
# -----------
Voice.pilotcall = func( action ) {
   var result = "";

   if( me.is_holding() or me.is_takeoff() or me.is_aftertakeoff() ) {
       result = me.crewvoice.stepmember( action, "pilot", "takeoff" );
   }

   elsif( me.is_beforelanding() or me.is_landing() ) {
       result = me.crewvoice.stepmember( action, "pilot", "landing" );
   }

   elsif( me.is_goaround() ) {
       result = me.crewvoice.stepmember( action, "pilot", "goaround" );
   }

   else {
       print("call not found : ", action);
   }

   return result;
}

Voice.captaincall = func( action ) {
   var result = "";

   if( me.is_holding() ) {
       result = me.crewvoice.stepmember( action, "captain", "takeoff" );
   }

   else {
       print("captain call not found : ", action);
   }

   return result;
}

Voice.engineercall = func( action ) {
   var result = "";

   if( me.is_holding() or me.is_takeoff() or me.is_aftertakeoff() ) {
       result = me.crewvoice.stepmember( action, "engineer", "takeoff" );
   }

   elsif( me.is_beforelanding() or me.is_landing() ) {
       result = me.crewvoice.stepmember( action, "engineer", "landing" );
   }

   else {
       print("engineer call not found : ", action);
   }

   return result;
}


Voice.schedule = func {
   if( me.itself["root"].getChild("serviceable").getValue() ) {
       me.set_rates( me.ABSENTSEC );

       me.vertical = me.dependency["autoflight"].getChild("vertical").getValue();
       
       me.phase.schedule();
       me.sensor.schedule();

       me.crewvoice.schedule();

       me.nextcallout();

       me.whichcallout();
       me.whichchecklist();

       me.playvoices();
   }

   else {
       me.rates = me.ABSENTSEC;

       me.nocalloutinit();
       me.nochecklistinit();
       me.noemergencyinit();
   }
   
   settimer( func { me.schedule(); }, me.rates );
}

Voice.nextcallout = func {
   if( me.is_landing() or me.is_beforelanding() ) {
       me.landing();
   }
   elsif( me.is_takeoff() or me.is_aftertakeoff() ) {
       me.takeoff();
   }
   # not on taxi
   elsif( me.is_holding() and !me.is_runway() ) {
       me.holding();
   }
   elsif( me.is_goaround() ) {
       me.goaround();
   }
   elsif( !me.phase.on_ground() ) {
       me.flight();
   }
}

# the voice must work with and without virtual crew.
Voice.whichcallout = func {
   # user is on ground
   if( !me.is_moving() ) {
       me.userground();
   }

   # user has performed a go around
   elsif( me.vertical == "goaround" and ( me.is_landing() or me.is_goaround() ) ) {
       if( me.is_landing() ) {
           me.goaroundinit();
       }
   }

   # checklists required all crew members.
   elsif( !me.phase.on_ground() ) {
       me.userair();
   }
}

Voice.whichchecklist = func {
   if( me.intelligence.has_crew() ) {
       # AI triggers automatically checklists
       if( me.intelligence.has_AI() and !me.is_emergency() ) {

           # aircraft is climbing
           if( me.phase.is_climb_threshold() ) {
               me.crewclimb();
           }

           # aircraft is descending
           elsif( me.phase.is_descent_threshold() ) {
               me.crewdescent();
           }

           # aircraft cruise
           elsif( !me.phase.on_ground() ) {
               me.crewcruise();
           }
       }
   }

   else {
       me.nochecklistinit();
   }
}

Voice.userground = func {
    var curairport = me.noinstrument["presets"].getChild("airport-id").getValue();
    var currunway = me.noinstrument["presets"].getChild("runway").getValue();

    
    # user has started all engines
    if( me.sensor.is_allengines() ) {
        if( me.is_landing() ) {
            # when missed by callout
            if( me.phase.is_speed_below( 20 ) ) {
                me.landingend();
            }
        }
        
        # taxi with all engines, without AI
        elsif( me.is_taxiway() ) {
        }
        
        # taxi with all engines
        elsif( me.is_terminal() ) {
        }
       
        else {
            if( !me.is_taxiway() and !me.is_holding() ) {
                me.takeoffinit();
            }

            # user has relocated on ground
            if( !me.is_takeoff() and !me.is_holding() ) {
                # flight may trigger at FG startup !
                if( curairport != me.airport or currunway != me.runway ) {
                    me.takeoffinit();
                }
            }

            # user has set parking brakes at runway threshold
            if( me.is_takeoff() ) {
                if( me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
                    me.holdinginit();
                }
            }
        }
    }

    # user has stopped all engines
    elsif( me.sensor.is_noengines() ) {
        me.gateinit();
    }

    # user has stopped inboard engines
    elsif( !me.dependency["engine"][constantaero.ENGINE2].getChild("running").getValue() and
           !me.dependency["engine"][constantaero.ENGINE3].getChild("running").getValue() ) {
        me.terminalinit();
    }


    me.airport = curairport;
    me.runway = currunway;
}

Voice.userair = func {
    # aircraft is climbing
    if( me.phase.is_climb_threshold() and me.phase.is_agl_climb() ) {
        me.flightinit();
    }

    # aircraft is descending
    elsif( me.phase.is_descent_threshold() ) {
        if( me.phase.is_altitude_approach() ) {
            me.landinginit();
        }

        else {
            me.flightinit();
        }
    }

    # aircraft is flying
    elsif( !me.is_takeoff() ) {
        me.flightinit();
    }
}

Voice.crewcruise = func {
    if( me.phase.is_altitude_cruise() ) {
        # waits for checklist end
        if( !me.is_transsonic() ) {
            me.cruiseclimbinit();
        }
    }

    elsif( me.phase.is_mach_climb() ) {
        me.flightinit();
    }

    elsif( !me.is_takeoff() and !me.is_aftertakeoff() ) {
        me.flightinit();
    }
}

Voice.crewclimb = func {
    if( me.phase.is_altitude_cruise() ) {
        # waits for checklist end
        if( !me.is_transsonic() ) {
            me.cruiseclimbinit();
        }
    }

    # transsonic
    elsif( me.phase.is_mach_supersonic() ) {
        me.transsonicinit();
    }

    # subsonic
    elsif( me.phase.is_mach_climb() ) {
        if( !me.lastcheck.is_climb() ) {
            me.climbinit();
        }
    }

    # starting climb
    elsif( !me.is_takeoff() and !me.is_aftertakeoff() ) {
        me.flightinit();
    }
}

Voice.crewdescent = func {
    # landing
    if( me.phase.is_agl_landing() ) {
        # impossible just after a takeoff, must climb enough
        if( !me.is_takeoff() ) {
            if( !me.lastcheck.is_beforelanding() ) {
                me.beforelandinginit();
            }
        }
    }

    # approaching
    elsif( me.phase.is_altitude_approach() ) {
        if( !me.lastcheck.is_approach() ) {
            me.approachinit();
        }
    }

    # ending cruise
    elsif( me.phase.is_mach_supersonic() ) {
        me.descentinit();
    }
}

Voice.sendcallout = func {
   me.itself["root"].getChild("callout").setValue(me.callout);
   me.itself["automata"][0].setValue( me.automata );
   me.itself["automata"][1].setValue( me.automata2 );
}

Voice.sendchecklist = func {
   me.itself["root"].getChild("checklist").setValue(me.checklist);
   me.itself["root"].getChild("real").setValue(me.real);
}

Voice.sendemergency = func {
   me.itself["root"].getChild("emergency").setValue(me.emergency);
   me.itself["root"].getChild("real").setValue(me.real);
}

Voice.playvoices = func {
   if( me.crewvoice.willplay() ) {
       me.set_rates( constant.HUMANSEC );
   }

   me.crewvoice.playvoices( me.rates );
}

Voice.calloutinit = func( state, state2, state3 ) {
   me.callout = state;
   me.automata = state2;
   me.automata2 = state3;

   me.phase.set_level();

   me.sendcallout();
}

Voice.checklistinit = func( state, real ) {
   me.checklist = state;
   me.real = real;

   # red : processing
   if( me.real ) {
       me.itself["display"].getChild("processing").setValue(me.checklist);
   }

   else {
       var processing = me.itself["display"].getChild("processing").getValue();

       # blue : completed
       if( processing != "" ) {
           me.lastcheck.checklist = processing;

           me.itself["display"].getChild("processing").setValue("");
           me.itself["display"].getChild("completed").setValue(me.lastcheck.checklist);
       }
   }

   me.unset_completed();

   me.sendchecklist();
}

Voice.emergencyinit = func( state, real ) {
   me.emergency = state;
   me.real = real;

   # red : processing
   if( me.real ) {
       me.itself["display"].getChild("processing").setValue(me.emergency);
   }

   else {
       var processing = me.itself["display"].getChild("processing").getValue();

       # blue : completed
       if( processing != "" ) {
           me.itself["display"].getChild("processing").setValue("");
           me.itself["display"].getChild("completed").setValue(processing);
       }
   }

   me.unset_completed();

   me.sendemergency();
}


# -------
# NOTHING
# -------
Voice.noemergencyinit = func {
   me.emergencyinit( "", constant.FALSE );
}

Voice.nochecklistinit = func {
   me.checklistinit( "", constant.FALSE );
}

Voice.nocalloutinit = func {
   me.calloutinit( "voice is disabled", "", "" );
}


# -------
# TAXIWAY
# -------
Voice.taxiwayinit = func {
   var result = constant.TRUE;

   if( me.is_taxiway() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "taxiway", "", "" );
   }
}


# -------------
# AFTER LANDING
# -------------
Voice.afterlandinginit = func {
   var result = constant.TRUE;

   if( me.is_afterlanding() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "afterlanding", constant.TRUE );
   }
}


# --------
# TERMINAL
# --------
Voice.terminalinit = func {
   var result = constant.TRUE;

   if( me.is_terminal() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "terminal", "", "" );
   }
}


# -------
# PARKING
# -------
Voice.parkinginit = func {
   var result = constant.TRUE;

   if( me.is_parking() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "parking", constant.TRUE );
   }
}


# ----
# GATE
# ----
Voice.gateinit = func {
   var result = constant.TRUE;

   if( me.is_gate() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "gate", "", "", constant.FALSE );
   }
}


# --------
# STOPOVER
# --------
Voice.stopoverinit = func {
   var result = constant.TRUE;

   if( me.is_stopover() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "stopover", constant.TRUE );
   }
}


# --------
# EXTERNAL
# --------
Voice.externalinit = func {
   var result = constant.TRUE;

   if( me.is_external() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "external", constant.TRUE );
   }
}


# -------------------------------
# COCKPIT PRELIMINARY PREPARATION
# -------------------------------
Voice.preliminaryinit = func {
   var result = constant.TRUE;

   if( me.is_preliminary() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "preliminary", constant.TRUE );
   }
}


# -------------------
# COCKPIT PREPARATION
# -------------------
Voice.cockpitinit = func {
   var result = constant.TRUE;

   if( me.is_cockpit() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "cockpit", constant.TRUE );
   }
}


# ------------
# BEFORE START
# ------------
Voice.beforestartinit = func {
   var result = constant.TRUE;

   if( me.is_beforestart() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "beforestart", constant.TRUE );
   }
}


# ------------
# ENGINE START
# ------------
Voice.enginestartinit = func {
   var result = constant.TRUE;

   if( me.is_enginestart() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "enginestart", constant.TRUE );
   }
}


# --------
# PUSHBACK
# --------
Voice.pushbackinit = func {
   var result = constant.TRUE;

   if( me.is_pushback() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "pushback", constant.TRUE );
   }
}


# -------
# STARTED
# -------
Voice.startedinit = func {
   var result = constant.TRUE;

   if( me.is_started() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "started", constant.FALSE );
   }
}


# -----------
# AFTER START
# -----------
Voice.afterstartinit = func {
   var result = constant.TRUE;

   if( me.is_afterstart() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "afterstart", constant.TRUE );
   }
}


# ----
# TAXI
# ----
Voice.taxiinit = func {
   var result = constant.TRUE;

   if( me.is_taxi() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "taxi", constant.TRUE );
   }
}


# ------
# RUNWAY
# ------
Voice.runwayinit = func {
   var result = constant.TRUE;

   if( me.is_runway() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "runway", constant.FALSE );
   }
}


# --------------
# BEFORE TAKEOFF
# --------------
Voice.beforetakeoffinit = func {
   var result = constant.TRUE;

   if( me.is_beforetakeoff() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "beforetakeoff", constant.TRUE );
   }
}


# -------
# HOLDING
# -------
Voice.holdinginit = func {
   var result = constant.TRUE;

   if( me.is_holding() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "holding", "holding", "holding" );
   }
}

Voice.holding = func {
   me.set_rates( me.HOLDINGSEC );

   if( me.automata2 == "holding" ) {
       if( !me.dependency["gear-ctrl"].getChild("brake-parking-lever").getValue() ) {
           if( me.dependency["captain-ctrl"].getChild("countdown").getValue() ) {
               me.automata2 = me.captaincall( "brakes3" );
           }

           else {
               me.takeoffinit();
           }
       }
   }

   elsif( me.automata2 == "brakes3" ) {
       me.automata2 = me.captaincall( "brakes2" );
   }

   elsif( me.automata2 == "brakes2" ) {
       me.automata2 = me.captaincall( "brakes1" );
   }

   elsif( me.automata2 == "brakes1" ) {
       me.automata2 = me.captaincall( "brakes" );
   }
   else {
       me.takeoffinit();
   }

   me.sendchecklist();
}


# -------
# TAKEOFF
# -------
Voice.takeoffinit = func ( overwrite = 0 ) {
   var result = constant.TRUE;

   if( me.is_takeoff() ) {
       result = constant.FALSE;
   }

   if( result or overwrite ) {
       me.calloutinit( "takeoff", "takeoff", "takeoff" );

       me.v1 = constant.FALSE;
       me.v2 = constant.FALSE;
   }
}

Voice.takeoff = func {
   me.set_rates( constant.HUMANSEC );

   me.takeoffpilot();

   if( !me.crewvoice.is_asynchronous() ) {
       me.takeoffclimb();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.takeoffallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.flightallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.checkallways();
   }

   me.sendchecklist();
}

Voice.takeoffallways = func {
   if( !me.phase.on_ground() ) {
       if( me.phase.is_climb_decay() ) {
           me.crewvoice.stepmember( "negativvsi", "allways", "takeoff", constant.TRUE );
       }

       elsif( me.phase.is_speed_approach() and
              (  me.phase.is_climb_decrease() or
                 ( me.v2 and
                   me.phase.is_speed_below( me.sensor.Vkt( constantaero.V2EMPTYKT,
                                                           constantaero.V2FULLKT ) ) ) ) ) {
           me.crewvoice.stepmember( "airspeeddecay", "allways", "takeoff", constant.TRUE );
       }
   }
}

Voice.takeoffclimb = func {
   if( me.automata2 == "takeoff" ) {
       if( me.phase.is_climb_threshold() and me.phase.is_agl_liftoff() ) {
           me.automata2 = me.crewvoice.stepmember( "liftoff", "pilot", "climb" );
           if( me.intelligence.has_AI() ) {
               me.aftertakeoffinit();
           }
       }
   }
}

Voice.takeoffpilot = func {
   if( me.automata == "takeoff" ) {
       if( me.phase.is_speed_above( me.SPEEDLEVELKT["60kt"] ) ) {
           me.automata = me.pilotcall( "airspeed" );
       }
   }

   elsif( me.automata == "airspeed" ) {
       if( me.phase.is_speed_above( me.SPEEDLEVELKT["100kt"] ) ) {
           me.automata = me.pilotcall( "100kt" );
           me.engineercall( "100kt" );
       }
   }

   elsif( me.automata == "100kt" ) {
       if( me.phase.is_speed_above( me.sensor.Vkt( constantaero.V1EMPTYKT,
                                                   constantaero.V1FULLKT ) ) ) {
           me.automata = me.pilotcall( "V1" );
           me.v1 = constant.TRUE;
       }
   }

   elsif( me.automata == "V1" ) {
       if( me.phase.is_speed_above( me.sensor.Vkt( constantaero.VREMPTYKT,
                                                   constantaero.VRFULLKT ) ) ) {
           me.automata = me.pilotcall( "VR" );
       }
   }

   elsif( me.automata == "VR" ) {
       if( me.phase.is_speed_above( me.sensor.Vkt( constantaero.V2EMPTYKT,
                                                   constantaero.V2FULLKT ) ) ) {
           me.automata = me.pilotcall( "V2" );
           me.v2 = constant.TRUE;
       }
   }

   elsif( me.automata == "V2" ) {
       if( me.phase.is_speed_above( me.SPEEDLEVELKT["240kt"] ) ) {
           me.automata = me.pilotcall( "240kt" );
       }
   }

   # aborted takeoff
   if( me.automata != "takeoff" ) {
       if( me.phase.is_speed_below( 20 ) ) {
           me.takeoffinit( constant.TRUE );
       }
   }
}


# -------------
# AFTER TAKEOFF
# -------------
Voice.aftertakeoffinit = func {
   var result = constant.TRUE;

   if( me.is_aftertakeoff() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "aftertakeoff", constant.TRUE );
   }
}


# ------
# FLIGHT 
# ------
Voice.flightinit = func {
   var result = constant.TRUE;

   if( me.is_flight() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "flight", "", "" );
   }
}

Voice.flight = func {
   me.flightallways();

   if( !me.crewvoice.is_asynchronous() ) {
       me.checkallways();
   }

   me.sendchecklist();
}

Voice.flightallways = func {
   if( !me.dependency["crew"].getChild("unexpected").getValue() ) {
       altitudeft = me.dependency["autoflight"].getChild("altitude-select").getValue();
       if( me.selectft != altitudeft ) {
           me.selectft = altitudeft;
           me.delayselectftsec = me.rates;
       }
       elsif( me.delayselectftsec > 0 ) {
           if( me.delayselectftsec >= me.MODIFYSEC ) {
               if( me.crewvoice.stepmember( "altitudeset", "allways", "flight" ) ) {
                   me.delayselectftsec = 0;
               }
           }
           else {
               me.delayselectftsec = me.delayselectftsec + me.rates;
           }
       }


       if( !me.altitudeselect ) { 
           if( me.vertical == "altitude-acquire" ) {
               if( me.autopilotsystem.is_engaged() and
                   !me.autopilotsystem.altitudelight_on( me.phase.get_altitudeft(), me.selectft ) ) {
                   me.altitudeselect = constant.TRUE;
               }
           }
       }
       else { 
           if( me.autopilotsystem.is_engaged() and
               me.autopilotsystem.altitudelight_on( me.phase.get_altitudeft(), me.selectft ) ) {
               if( me.crewvoice.stepmember( "1000fttogo", "allways", "flight" ) ) {
                   me.altitudeselect = constant.FALSE;
               }
           }       
       }


       if( me.phase.is_altitude_level() ) {
           me.crewvoice.stepmember( "altimetercheck", "allways", "flight" );

           if( me.dependency["engineer"].getNode("cg/forward").getValue() ) {
               me.fueltransfert = constant.TRUE;
               me.crewvoice.stepmember( "cgforward", "engineer", "flight" );
           }
           elsif( me.dependency["engineer"].getNode("cg/aft").getValue() ) {
               me.fueltransfert = constant.TRUE;
               me.crewvoice.stepmember( "cgaft", "engineer", "flight" );
           }
           else {
               me.fueltransfert = constant.FALSE;
               me.crewvoice.stepmember( "cgcorrect", "engineer", "flight" );
           }
       }
       elsif( me.phase.is_altitude_transition() ) {
           me.crewvoice.stepmember( "transition", "allways", "flight" );
       }

       # fuel transfert is completed :
       # - climb at 26000 ft.
       # - cruise above 50000 ft.
       # - descent to 38000 ft.
       # - approach to 10000 ft.
       elsif( me.fueltransfert and
              !me.dependency["engineer"].getNode("cg/forward").getValue() and
              !me.dependency["engineer"].getNode("cg/aft").getValue() ) {
           if( ( me.autopilotsystem.is_engaged() and
               ( me.autopilotsystem.is_altitude_acquire() or
                 me.autopilotsystem.is_altitude_hold() ) ) or
               me.phase.is_altitude_cruise() or me.phase.is_altitude_approach() ) {
               me.fueltransfert = constant.FALSE;
               me.crewvoice.stepmember( "cgcorrect", "engineer", "flight" );
           }
       }
   } 
}


# -----
# CLIMB 
# -----
Voice.climbinit = func {
   var result = constant.TRUE;

   if( me.is_climb() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "climb", constant.TRUE );
   }
}


# ----------------
# TRANSSONIC CLIMB
# ----------------
Voice.transsonicinit = func {
   var result = constant.TRUE;

   if( me.is_transsonic() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "transsonic", constant.TRUE );
   }
}


# ------------
# CRUISE CLIMB 
# ------------
Voice.cruiseclimbinit = func {
   var result = constant.TRUE;

   if( me.is_cruiseclimb() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "cruiseclimb", constant.FALSE );
   }
}


# -------
# DESCENT
# -------
Voice.descentinit = func {
   var result = constant.TRUE;

   if( me.is_descent() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "descent", constant.TRUE );
   }
}


# ---------------
# BEFORE APPROACH
# ---------------
Voice.approachinit = func {
   var result = constant.TRUE;

   if( me.is_approach() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "approach", constant.TRUE );
   }
}


# --------------
# BEFORE LANDING
# --------------
Voice.beforelandinginit = func {
   var result = constant.TRUE;

   if( me.is_beforelanding() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.checklistinit( "beforelanding", constant.TRUE );
   }
}


# -------
# LANDING
# -------
Voice.landinginit = func {
   var result = constant.TRUE;

   if( me.is_landing() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "landing", "landing", "landing" );

       me.category = constant.FALSE;
       me.alert = constant.FALSE;
       me.decision = constant.FALSE;
       me.decisiontogo = constant.FALSE;
   }
}

Voice.landing = func {
   me.set_rates( constant.HUMANSEC );

   me.landingengineer();

   if( !me.crewvoice.is_asynchronous() ) {
       me.landingpilot();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.landingallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.checkallways();
   }

   me.sendchecklist();
}

Voice.landingpilot = func {
   if( me.automata2 == "landing" ) {
       if( me.dependency["nav"].getChild("in-range").getValue() ) {
           if( me.autopilotsystem.is_engaged() and
               me.dependency["autoflight"].getChild("heading").getValue() == "nav1-hold" ) {
               me.automata2 = me.pilotcall( "beambar" );
           }
       }
   }
   elsif( me.automata2 == "beambar" ) {
       if( me.dependency["nav"].getChild("in-range").getValue() and
           me.dependency["nav"].getChild("has-gs").getValue() ) {
           if( me.autopilotsystem.is_engaged() and
               me.dependency["autoflight"].getChild("altitude").getValue() == "gs1-hold" ) {
               me.automata2 = me.pilotcall( "glideslope" );
           }
       }
   }
   elsif( me.automata2 == "glideslope" ) {
       if( me.phase.is_speed_below( 100 ) ) {
           me.automata2 = me.pilotcall( "100kt" );
       }
   }
   elsif( me.automata2 == "100kt" ) {
       if( me.phase.is_speed_below( 75 ) ) {
           me.automata2 = me.pilotcall( "75kt" );
       }
   }
   elsif( me.automata2 == "75kt" ) {
       if( me.phase.is_speed_below( 40 ) ) {
           me.automata2 = me.pilotcall( "40kt" );
       }
   }
   elsif( me.automata2 == "40kt" ) {
       if( me.phase.is_speed_below( 20 ) ) {
           me.automata2 = me.pilotcall( "20kt" );
           # wake up AI
           me.landingend();
       }
   }
}

Voice.landingend = func {
   if( me.intelligence.has_AI() ) {
       me.afterlandinginit();
   }
   else {
       me.taxiwayinit();
   }
}

Voice.landingengineer = func {
   if( me.automata == "landing" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["2500ft"] ) ) {
           me.automata = me.engineercall( "2500ft" );
       }
   }

   elsif( me.automata == "2500ft" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["1000ft"] ) ) {
           me.automata = me.engineercall( "1000ft" );
       }
   }

   elsif( me.automata == "1000ft" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["800ft"] ) ) {
           me.automata = me.engineercall( "800ft" );
       }
   }

   elsif( me.automata == "800ft" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["500ft"] ) ) {
           me.automata = me.engineercall( "500ft" );
       }
   }

   elsif( me.automata == "500ft" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["400ft"] ) ) {
           me.automata = me.engineercall( "400ft" );
       }
   }

   elsif( me.automata == "400ft" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["300ft"] ) ) {
           me.automata = me.engineercall( "300ft" );
       }
   }

   elsif( me.automata == "300ft" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["200ft"] ) ) {
           me.automata = me.engineercall( "200ft" );
       }
   }

   elsif( me.automata == "200ft" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["100ft"] ) ) {
           me.automata = me.engineercall( "100ft" );
       }
   }

   elsif( me.automata == "100ft" ) {
       me.landingtouchdown( me.AGLLEVELFT["50ft"] );
   }

   elsif( me.automata == "50ft" ) {
       me.landingtouchdown( me.AGLLEVELFT["40ft"] );
   }

   elsif( me.automata == "40ft" ) {
       me.landingtouchdown( me.AGLLEVELFT["30ft"] );
   }

   elsif( me.automata == "30ft" ) {
       me.landingtouchdown( me.AGLLEVELFT["20ft"] );
   }

   elsif( me.automata == "20ft" ) {
       if( me.phase.is_agl_below_level( me.AGLLEVELFT["15ft"] ) ) {
           me.automata = me.engineercall( "15ft" );
       }
   }
}

# can be faster
Voice.landingtouchdown = func( limitft ) {
   if( 15 <= limitft and me.phase.is_agl_below_level( me.AGLLEVELFT["15ft"] ) ) {
       me.automata = me.engineercall( "15ft" );
   }
   elsif( 20 <= limitft and me.phase.is_agl_below_level( me.AGLLEVELFT["20ft"] ) ) {
       me.automata = me.engineercall( "20ft" );
   }
   elsif( 30 <= limitft and me.phase.is_agl_below_level( me.AGLLEVELFT["30ft"] ) ) {
       me.automata = me.engineercall( "30ft" );
   }
   elsif( 40 <= limitft and me.phase.is_agl_below_level( me.AGLLEVELFT["40ft"] ) ) {
       me.automata = me.engineercall( "40ft" );
   }
   elsif( 50 <= limitft and me.phase.is_agl_below_level( me.AGLLEVELFT["50ft"] ) ) {
       me.automata = me.engineercall( "50ft" );
   }
}

Voice.landingallways = func {
   var altitudeft = me.dependency["autoflight"].getChild("altitude-select").getValue();

   if( me.selectft != altitudeft ) {
       me.selectft = altitudeft;
       me.delayselectftsec = me.rates;
   }
   elsif( me.delayselectftsec > 0 ) {
       if( me.delayselectftsec >= me.MODIFYSEC ) {
           if( me.crewvoice.stepmember( "goaroundset", "allways", "landing" ) ) {
               me.delayselectftsec = 0;
           }
       }
       else {
           me.delayselectftsec = me.delayselectftsec + me.rates;
       }
   }

   if( me.phase.is_agl_below( me.AGLLEVELFT["100ft"] ) and
       me.dependency["attitude"].getChild("indicated-pitch-deg").getValue() > me.FLAREDEG ) {
       me.crewvoice.stepmember( "attitude", "allways", "landing", constant.TRUE );
   }

   elsif( me.phase.is_agl_below( me.AGLLEVELFT["1000ft"] ) and me.phase.is_descent_final() ) {
       me.crewvoice.stepmember( "vsiexcess", "allways", "landing", constant.TRUE );
   }

   elsif( !me.category and me.dependency["autopilot"].getChild("land3").getValue() ) {
       me.crewvoice.stepmember( "category3", "allways", "landing" );
       me.category = constant.TRUE;
   }

   elsif( !me.category and me.dependency["autopilot"].getChild("land2").getValue() ) {
       me.crewvoice.stepmember( "category2", "allways", "landing" );
       me.category = constant.TRUE;
   }

   elsif( !me.alert and me.dependency["autopilot"].getChild("land2").getValue() and
          me.phase.is_agl_below_level( me.AGLLEVELFT["300ft"] ) ) {
       me.crewvoice.stepmember( "alertheight", "allways", "landing" );
       me.alert = constant.TRUE;
   }

   elsif( !me.decisiontogo and
          me.phase.is_agl_below_level( me.dependency["radio-altimeter"].getChild("decision-ft").getValue() + me.AGLLEVELFT["100ft"] ) ) {
       me.crewvoice.stepmember( "100fttogo", "allways", "landing" );
       me.decisiontogo = constant.TRUE;
   }

   elsif( me.decisiontogo and !me.decision and
          me.phase.is_agl_below_level( me.dependency["radio-altimeter"].getChild("decision-ft").getValue() ) ) {
       me.crewvoice.stepmember( "decisionheight", "allways", "landing" );
       me.decision = constant.TRUE;
   }

   elsif( me.phase.is_agl_below( me.AGLLEVELFT["1000ft"] ) and !me.decision and
         ( me.phase.is_final_decrease() or
           me.phase.is_speed_below( me.sensor.Vkt( constantaero.VREFEMPTYKT,
                                                   constantaero.VREFFULLKT ) ) ) ) {
       me.crewvoice.stepmember( "approachspeed", "allways", "landing", constant.TRUE );
   }
}


# ---------
# GO AROUND
# ---------
Voice.goaroundinit = func {
   var result = constant.TRUE;

   if( me.is_goaround() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.calloutinit( "goaround", "goaround", "goaround" );
   }
}

Voice.goaround = func {
   me.set_rates( constant.HUMANSEC );

   if( me.automata == "goaround" ) {
       if( me.phase.is_climb_visible() ) {
           me.automata = me.pilotcall( "positivclimb" );
           if( me.intelligence.has_AI() ) {
               me.aftertakeoffinit();
           }

           me.flightinit();
       }
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.takeoffallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.checkallways();
   }

   me.sendchecklist();
}


# ------
# ALWAYS 
# ------
Voice.checkallways = func {
   var change = constant.FALSE;

   if( me.sensor.is_nose_change() or me.sensor.is_gear_change() ) {
       change = constant.TRUE;
       if( me.sensor.is_nose_down() and me.sensor.is_gear_down() ) {
           if( !me.crewvoice.stepmember( "5greens", "allways", "allways" ) ) {
               change = constant.FALSE;
           }
       }

       if( change ) {
           me.sensor.snapshot_nose();
       }
   }

   if( me.sensor.is_gear_change() ) {
       change = constant.TRUE;
       # on pull of lever
       if( me.sensor.is_lastgear_down() and !me.sensor.is_gear_down() ) {
           if( !me.crewvoice.stepmember( "gearup", "allways", "allways" ) ) {
               change = constant.FALSE;
           }
       }

       if( change ) {
           me.sensor.snapshot_gear();
       }
   }
}


# ---------------------
# FOUR ENGINE FLAME OUT
# ---------------------
Voice.fourengineflameoutinit = func {
   var result = constant.TRUE;

   if( me.is_fourengineflameout() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.emergencyinit( "fourengineflameout", constant.TRUE );
   }
}

# ----------------------------------
# FOUR ENGINE FLAME OUT (SUPERSONIC)
# ----------------------------------
Voice.fourengineflameoutmach1init = func {
   var result = constant.TRUE;

   if( me.is_fourengineflameoutmach1() ) {
       result = constant.FALSE;
   }

   if( result ) {
       me.emergencyinit( "fourengineflameoutmach1", constant.TRUE );
   }
}


# ========
# VOICE AI 
# ========

VoiceAI = {};

VoiceAI.new = func {
   var obj = { parents : [VoiceAI,System.new("/systems/voice")]
         };

   return obj;
}

VoiceAI.has_AI = func {
   var result = constant.FALSE;

   # AI triggers flight checklists
   if( me.dependency["crew-ctrl"].getChild("checklist").getValue() ) {
       result = me.has_crew();
   }

   return result;
}

VoiceAI.has_crew = func {
   var result = constant.FALSE;

   if( me.itself["root"].getChild("serviceable").getValue() ) {
       if( me.dependency["copilot-ctrl"].getChild("activ").getValue() and
           me.dependency["engineer-ctrl"].getChild("activ").getValue() ) {
           result = constant.TRUE;
       }
   }

   return result;
}


# ==========
# VOICE WORD 
# ==========

Voiceword = {};

Voiceword.new = func {
   var obj = { parents : [Voiceword,System.new("/systems/voice")],

               # pilot in command
               captain :  { "takeoff" : {}, "afterstart" : {}, "taxi" : {}, "beforetakeoff" : {}, "aftertakeoff" : {}, "afterlanding" : {}, "allways" : {} },

               # pilot not in command
               pilot :  { "takeoff" : {}, "climb" : {}, "landing" : {}, "goaround" : {}, "beforestart" : {}, "pushback" : {}, "afterstart" : {} },
               
               allways : { "takeoff" : {}, "landing" : {}, "flight" : {}, "allways" : {} },

               engineer : { "takeoff" : {}, "flight" : {}, "climb" : {}, "transsonic" : {}, "descent" : {}, "approach" : {}, "landing" : {},
                            "beforelanding" : {}, "afterlanding" : {}, "parking" : {}, "stopover" : {}, "cockpit" : {}, "beforestart" : {},
                            "pushback" : {}, "taxi" : {}, "beforetakeoff" : {}, "aftertakeoff" : {} }
         };

   obj.init();
   
   return obj;
}

Voiceword.init = func {
   me.inittext();
}

Voiceword.inittable = func( path, table ) {
   var key = "";
   var text = "";
   var node = props.globals.getNode(path).getChildren("message");

   for( var i=0; i < size(node); i=i+1 ) {
        key = node[i].getChild("action").getValue();
        text = node[i].getChild("text").getValue();
        table[key] = text;
   }
}

Voiceword.inittext = func {
   me.inittable(me.itself["checklist"].getNode("beforetakeoff/engineer[0]").getPath(), me.engineer["beforetakeoff"] );
   me.inittable(me.itself["checklist"].getNode("beforetakeoff/captain[0]").getPath(), me.captain["beforetakeoff"] );

   me.inittable(me.itself["callout"].getNode("takeoff/captain").getPath(), me.captain["takeoff"] );

   me.inittable(me.itself["callout"].getNode("takeoff/pilot[0]").getPath(), me.pilot["takeoff"] );
   me.inittable(me.itself["callout"].getNode("takeoff/pilot[1]").getPath(), me.pilot["climb"] );
   me.inittable(me.itself["callout"].getNode("takeoff/pilot[2]").getPath(), me.allways["takeoff"] );
   me.inittable(me.itself["callout"].getNode("takeoff/engineer[0]").getPath(), me.engineer["takeoff"] );

   me.inittable(me.itself["checklist"].getNode("aftertakeoff/engineer[0]").getPath(), me.engineer["aftertakeoff"] );
   me.inittable(me.itself["checklist"].getNode("aftertakeoff/captain[0]").getPath(), me.captain["aftertakeoff"] );

   me.inittable(me.itself["callout"].getNode("flight/pilot[0]").getPath(), me.allways["flight"] );
   me.inittable(me.itself["callout"].getNode("flight/engineer[0]").getPath(), me.engineer["flight"] );

   me.inittable(me.itself["checklist"].getNode("climb/engineer[0]").getPath(), me.engineer["climb"] );

   me.inittable(me.itself["checklist"].getNode("transsonic/engineer[0]").getPath(), me.engineer["transsonic"] );

   me.inittable(me.itself["checklist"].getNode("descent/engineer[0]").getPath(), me.engineer["descent"] );

   me.inittable(me.itself["checklist"].getNode("approach/engineer[0]").getPath(), me.engineer["approach"] );

   me.inittable(me.itself["checklist"].getNode("beforelanding/engineer").getPath(), me.engineer["beforelanding"] );

   me.inittable(me.itself["callout"].getNode("landing/pilot[0]").getPath(), me.pilot["landing"] );
   me.inittable(me.itself["callout"].getNode("landing/pilot[1]").getPath(), me.allways["landing"] );
   me.inittable(me.itself["callout"].getNode("landing/engineer[0]").getPath(), me.engineer["landing"] );

   me.inittable(me.itself["callout"].getNode("goaround/pilot[0]").getPath(), me.pilot["goaround"] );

   me.inittable(me.itself["checklist"].getNode("afterlanding/engineer[0]").getPath(), me.engineer["afterlanding"] );
   me.inittable(me.itself["checklist"].getNode("afterlanding/captain[0]").getPath(), me.captain["afterlanding"] );

   me.inittable(me.itself["checklist"].getNode("parking/engineer[0]").getPath(), me.engineer["parking"] );

   me.inittable(me.itself["checklist"].getNode("stopover/engineer[0]").getPath(), me.engineer["stopover"] );

   me.inittable(me.itself["checklist"].getNode("cockpit/engineer[0]").getPath(), me.engineer["cockpit"] );

   me.inittable(me.itself["checklist"].getNode("beforestart/pilot[0]").getPath(), me.pilot["beforestart"] );
   me.inittable(me.itself["checklist"].getNode("beforestart/engineer[0]").getPath(), me.engineer["beforestart"] );

   me.inittable(me.itself["checklist"].getNode("pushback/pilot[0]").getPath(), me.pilot["pushback"] );
   me.inittable(me.itself["checklist"].getNode("pushback/engineer[0]").getPath(), me.engineer["pushback"] );

   me.inittable(me.itself["checklist"].getNode("afterstart/pilot[0]").getPath(), me.pilot["afterstart"] );
   me.inittable(me.itself["checklist"].getNode("afterstart/captain[0]").getPath(), me.captain["afterstart"] );

   me.inittable(me.itself["checklist"].getNode("taxi/engineer[0]").getPath(), me.engineer["taxi"] );
   me.inittable(me.itself["checklist"].getNode("taxi/captain[0]").getPath(), me.captain["taxi"] );

   me.inittable(me.itself["checklist"].getNode("all/captain[0]").getPath(), me.captain["allways"] );

   me.inittable(me.itself["callout"].getNode("all/pilot[0]").getPath(), me.allways["allways"] );
}

Voiceword.get_word = func( member, phase ) {
   if( member == "captain" ) {
       return me.captain[phase];
   }
   
   elsif( member == "pilot" ) {
       return me.pilot[phase];
   }
   
   elsif( member == "allways" ) {
       return me.allways[phase];
   }
   
   elsif( member == "engineer" ) {
       return me.engineer[phase];
   }
   
   else {
       print( "word " ~ phase ~ " not found for " ~ member );
       return "";
   }
}


# ==========
# CREW VOICE 
# ==========

Crewvoice = {};

Crewvoice.new = func {
   var obj = { parents : [Crewvoice,System.new("/systems/voice")],

               copilothuman : nil,
               engineerhuman : nil,

               word : Voiceword.new(),
               voicebox : Voicebox.new(),
               
               CONVERSATIONSEC : 4.0,                            # until next message
               REPEATSEC : 4.0,                                  # between 2 messages

               # pilot in command
               phrasecaptain : "",
               delaycaptainsec : 0.0,

               # pilot not in command
               phrase : "",
               delaysec : 0.0,                                   # delay this phrase
               nextsec : 0.0,                                    # delay the next phrase

               # engineer
               phraseengineer : "",
               delayengineersec : 0.0,

               asynchronous : constant.FALSE,

               hearvoice : constant.FALSE,
               seevoice : constant.FALSE
         };

   obj.init();

   return obj;
}

Crewvoice.init = func {
   # translate phrase into sound
   me.hearvoice = me.itself["sound"].getChild("enabled").getValue();
}

Crewvoice.textexport = func {
   var feedback = me.voicebox.textexport();

   # also to test sound
   if( me.voicebox.is_on() ) {
       me.talkpilot( feedback );
   }
   else {
       me.talkengineer( feedback );
   }
}

Crewvoice.set_relation = func( copilot, engineer ) {
    me.copilothuman = copilot;
    me.engineerhuman = engineer;
}

Crewvoice.schedule = func {
   # translate phrase into animation
   me.seevoice = me.dependency["human"].getChild("serviceable").getValue();

   me.voicebox.schedule();
}

Crewvoice.stepmember = func( state, member, phase, repeat = 0 ) {
   if( member == "pilot" ) {
       me.steppilot( state, me.word.get_word( member, phase ) );
   }
   
   elsif( member == "engineer" ) {
       me.stepengineer( state, me.word.get_word( member, phase ) );
    }
   
   elsif( member == "captain" ) {
       me.stepcaptain( state, me.word.get_word( member, phase ) );
   }
   
   elsif( member == "allways" ) {
       me.stepallways( state, me.word.get_word( member, phase ), repeat );
   }
   
   else {
       print( "step " ~ state ~ " not found for " ~ member ~ " at " ~ phase );
   }
}

Crewvoice.nowmember = func( state, member, phase ) {
   var found = constant.TRUE;
   
   if( member == "pilot" ) {
       me.steppilot( state, me.word.get_word( member, phase ) );
   }
   
   elsif( member == "engineer" ) {
       me.stepengineer( state, me.word.get_word( member, phase ) );
    }
   
   elsif( member == "captain" ) {
       me.stepcaptain( state, me.word.get_word( member, phase ) );
   }
   
   else {
       found = constant.FALSE;
       print( "now " ~ state ~ " not found for " ~ member ~ " at " ~ phase );
   }

   if( found ) {
       me.playvoices( constant.HUMANSEC );
   }
}

Crewvoice.stepallways = func( state, table, repeat = 0 ) {
   var result = constant.FALSE;

   if( !me.asynchronous ) {
       if( me.nextsec <= 0 ) {
           me.phrase = table[state];
           me.delaysec = 0;

           if( repeat ) {
               me.nextsec = me.REPEATSEC;
           }

           if( me.phrase == "" ) {
               print("missing voice text : ",state);
           }

           me.asynchronous = constant.TRUE;
           result = constant.TRUE;
       }
   }

   return result;
}

Crewvoice.steppilot = func( state, table ) {
   me.talkpilot( table[state] );

   if( me.phrase == "" ) {
       print("missing voice text : ",state);
   }

   me.asynchronous = constant.TRUE;

   return state;
}

Crewvoice.talkpilot = func( phrase ) {
   if( me.phrase != "" ) {
       print("phrase overflow : ", phrase);
   }

   # add an optional argument
   if( find("%s", phrase) >= 0 ) {
       phrase = sprintf( phrase, me.itself["root"].getChild("argument").getValue() );
   }

   me.phrase = phrase;
   me.delaysec = 0;
}

Crewvoice.stepengineer = func( state, table ) {
   me.talkengineer( table[state] );

   if( me.phraseengineer == "" ) {
       print("missing voice text : ",state);
   }

   return state;
}

Crewvoice.talkengineer = func( phrase ) {
   if( me.phraseengineer != "" ) {
       print("engineer phrase overflow : ", phrase);
   }

   me.phraseengineer = phrase;
   me.delayengineersec = 0;
}

Crewvoice.stepcaptain = func( state, table ) {
   me.talkcaptain( table[state] );

   if( me.phrasecaptain == "" ) {
       print("missing voice text : ",state);
   }

   me.asynchronous = constant.TRUE;

   return state;
}

Crewvoice.talkcaptain = func( phrase ) {
   if( me.phrasecaptain != "" ) {
       print("captain phrase overflow : ", phrase);
   }

   me.phrasecaptain = phrase;
   me.delaycaptainsec = 0;
}

Crewvoice.willplay = func {
   var result = constant.FALSE;

   if( me.phrase != "" or me.phraseengineer != "" or me.phrasecaptain != "" ) {
       result = constant.TRUE;
   }

   return result;
}

Crewvoice.is_asynchronous = func {
   return me.asynchronous;
}

Crewvoice.playvoices = func( rates ) {
   # pilot not in command calls out
   if( me.delaysec <= 0 ) {
       if( me.phrase != "" ) {
           me.itself["display"].getChild("copilot").setValue(me.phrase);

           me.sendvoices( me.phrase, "copilot" );
           me.voicebox.sendtext(me.phrase);
           me.phrase = "";

           # engineer lets pilot speak
           if( me.phraseengineer != "" ) {
               me.delayengineersec = me.CONVERSATIONSEC;
           }
        }
   }
   else {
       me.delaysec = me.delaysec - rates;
   }

   # no engineer voice yet
   if( me.delayengineersec <= 0 ) {
       if( me.phraseengineer != "" ) {
           me.itself["display"].getChild("engineer").setValue(me.phraseengineer);

           me.sendvoices( me.phraseengineer, "engineer" );
           me.voicebox.sendtext(me.phraseengineer, constant.TRUE);
           me.phraseengineer = "";
       }
   }
   else {
       me.delayengineersec = me.delayengineersec - rates;
   }

   # pilot in command calls out
   if( me.delaycaptainsec <= 0 ) {
       if( me.phrasecaptain != "" ) {
           me.itself["display"].getChild("captain").setValue(me.phrasecaptain);

           me.sendvoices( me.phrasecaptain, "captain" );
           me.voicebox.sendtext(me.phrasecaptain, constant.FALSE, constant.TRUE);
           me.phrasecaptain = "";
       }
   }
   else {
       me.delaycaptainsec = me.delaycaptainsec - rates;
   }

   if( me.nextsec > 0 ) {
       me.nextsec = me.nextsec - rates;
   }

   me.asynchronous = constant.FALSE;
}

Crewvoice.sendvoices = func( sentphrase, sentcrew ) {
   if( me.hearvoice ) {
       var voice = "pilot";
       
       if( sentcrew == "copilot" ) {
           voice = "copilot";
       }
       
       me.itself["sound"].getChild(voice).setValue(sentphrase);
   }
   
   if( me.seevoice ) {
       # no animation for captain
       if( sentcrew == "copilot" ) {
           me.copilothuman.moothcron( sentphrase );
       }
       elsif( sentcrew == "engineer" ) {
           me.engineerhuman.moothcron( sentphrase );
       }
   }
}
