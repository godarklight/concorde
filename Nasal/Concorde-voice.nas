# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# =============
# CREW CALLOUTS 
# =============

Callout = {};

Callout.new = func {
   obj = { parents : [Callout],

           autopilotsystem : nil,

           ap : nil,
           crew : nil,
           crewcontrol : nil,
           presets : nil,
           sound : nil,
           voice : nil,

           MODIFYSEC : 15.0,                                 # to modify something
           ABSENTSEC : 15.0,                                 # less attention
           HOLDINGSEC : 5.0,
           REPEATSEC : 4.0,                                  # between 2 messages
           CONVERSATIONSEC : 3.0,                            # until next message
           HUMANSEC : 1.0,                                   # human reaction time
           MINIMIZEDSEC : 0.0,

           maximizeds : 0.0,                                 # time out
           rates : 0.0,                                      # variable time step

           ratio1s : 0.0,                                    # 1 s
           ratiostep : 0.0,                                  # rates

           MAXFPM : 7000.0,                                  # max descent rate
           CLIMBFPM : 100.0,
           DECAYFPM : -50.0,                                 # not zero, to avoid false alarm
           DESCENTFPM : -100.0,
           FINALFPM : -1000.0,

           FLIGHTLEVELFT : 10000.0,
           FINALFT : 1000.0,
           LIFTOFFFT : 20.0,
           MAXFT : 0.0,

           altitudeft : 0.0,
           lastaltitudeft : 0.0,
           altitudeselect : constant.FALSE,
           selectft : 0.0,
           delayselectftsec : 0,
           reactionft : 0.0,
           vertical : "",

           level10000 : 0,

           aglft : 0.0,
           decision : constant.FALSE,
           decisiontogo : constant.FALSE,

           V240KT : 240.0,
           V2FULLKT : 220.0,
           V2EMPTYKT : 205.0,                                # guess
           VRFULLKT : 195.0,
           VREMPTYKT : 180.0,                                # guess
           V1FULLKT : 165.0,
           VREFFULLKT : 162.0,
           VREFEMPTYKT : 152.0,
           V1EMPTYKT : 150.0,                                # guess
           V100KT : 100.0,
           AIRSPEEDKT : 40.0,
           TAXIKT : 10.0,
           DECAYKT : 0.0,
           FINALKT : 0.0,

           v2 : constant.FALSE,

           speedkt : 0.0,
           lastspeedkt : 0.0,
           reactionkt : 0.0,
           groundkt : 0.0,

           DECAYKTPS : -1.0,                                 # climb
           FINALKTPS : -3.0,                                 # descent

           FULLLB : 408000.0,
           EMPTYLB : 203000.0,

           gear : 0.0,
           lastgear : 0.0,
           nose : 0.0,
           lastnose : 0.0,

           airport : "",
           runway : "",

           # pilot not in command
           phrase : "",
           delaysec : 0.0,                                   # delay this phrase
           nextsec : 0.0,                                    # delay the next phrase
           pilottakeoff : { "brakes3" : "", "brakes2" : "", "brakes1" : "", "brakes" : "",
                            "airspeed" : "", "100kt" : "", "V1" : "", "VR" : "", "V2" : "", "240kt" : "" },
           pilotclimb : { "liftoff" : "" },
           pilotlanding : { "glideslope" : "", "100kt" : "", "75kt" : "", "40kt" : "", "20kt" : "" },
           pilotgoaround : { "positivclimb" : "" },
           allwaystakeoff : { "negativvsi" : "", "airspeeddecay" : "" },
           allwayslanding : { "goaroundset" : "", "vsiexcess" : "", "approachspeed" : "",
                              "100fttogo" : "", "decisionheight" : "" },
           allwaysflight : { "altitudeset" : "", "1000fttogo" : "", "altimetercheck" : "" },
           allways : { "gearup" : "", "5greens" : "" },

           # engineer
           phraseengineer : "",
           delayengineersec : 0.0,
           engineertakeoff : { "100kt" : "" },
           engineerlanding : { "2500ft" : "", "1000ft" : "", "800ft" : "", "500ft" : "",
                               "400ft" : "", "300ft" : "", "200ft" : "", "100ft" : "",
                               "50ft" : "", "40ft" : "", "30ft" : "", "20ft" : "", "15ft" : "" },

           asynchronous : constant.FALSE,

           checklist : "",
           automata : "",
           automata2 : "",
           minimized : constant.TRUE,

           hearsound : constant.FALSE,
           hearvoice : constant.FALSE,
           seetext : constant.TRUE,

# centered in the vision field, 1 line, 10 seconds.
           textbox : screen.window.new( nil, -200, 1, 10 ),

           slave : { "altimeter" : nil, "asi" : nil, "engine" : nil, "gear" : nil, "ins" : nil,
                     "ivsi" : nil, "nav" : nil, "nose" : nil, "radioaltimeter" : nil },
           noinstrument : { "weight" : "" }
         };

   obj.init();

   return obj;
}

Callout.init = func {
   me.ap = props.globals.getNode("/controls/autoflight");
   me.crew = props.globals.getNode("/systems/crew");
   me.crewcontrol = props.globals.getNode("/controls/crew");
   me.presets = props.globals.getNode("/sim/presets");
   me.sound = props.globals.getNode("/sim/sound/voices");
   me.voice = props.globals.getNode("/systems/crew/voice");

   propname = getprop("/systems/crew/voice/slave/altimeter");
   me.slave["altimeter"] = props.globals.getNode(propname);
   propname = getprop("/systems/crew/voice/slave/asi");
   me.slave["asi"] = props.globals.getNode(propname);
   propname = getprop("/systems/crew/voice/slave/engine");
   me.slave["engine"] = props.globals.getNode(propname).getChildren("engine");
   propname = getprop("/systems/crew/voice/slave/gear");
   me.slave["gear"] = props.globals.getNode(propname);
   propname = getprop("/systems/crew/voice/slave/ins");
   me.slave["ins"] = props.globals.getNode(propname);
   propname = getprop("/systems/crew/voice/slave/ivsi");
   me.slave["ivsi"] = props.globals.getNode(propname);
   propname = getprop("/systems/crew/voice/slave/nav");
   me.slave["nav"] = props.globals.getNode(propname);
   propname = getprop("/systems/crew/voice/slave/nose");
   me.slave["nose"] = props.globals.getNode(propname);
   propname = getprop("/systems/crew/voice/slave/radioaltimeter");
   me.slave["radioaltimeter"] = props.globals.getNode(propname);

   me.noinstrument["weight"] = getprop("/systems/crew/voice/noinstrument/weight");

   me.minimized = me.crew.getChild("minimized").getValue();

   me.hearsound = me.sound.getChild("enabled").getValue();

   me.MINIMIZEDSEC = me.crewcontrol.getChild("minimized-s").getValue();
   me.ratio1s = 1 / me.HUMANSEC;

   me.selectft = me.ap.getChild("altitude-select").getValue();

   me.inittext();

   settimer( calloutcron, me.HUMANSEC );
}

Callout.inittable = func( node, table ) {
   for( i=0; i < size(node); i=i+1 ) {
        key = node[i].getChild("action").getValue();
        text = node[i].getChild("text").getValue();
        table[key] = text;
   }
}

Callout.inittext = func {
   childs = props.globals.getNode("/systems/crew/voice/checklists/takeoff/pilot[0]").getChildren("message");
   me.inittable( childs, me.pilottakeoff );
   childs = props.globals.getNode("/systems/crew/voice/checklists/takeoff/pilot[1]").getChildren("message");
   me.inittable( childs, me.pilotclimb );
   childs = props.globals.getNode("/systems/crew/voice/checklists/takeoff/pilot[2]").getChildren("message");
   me.inittable( childs, me.allwaystakeoff );
   childs = props.globals.getNode("/systems/crew/voice/checklists/takeoff/engineer[0]").getChildren("message");
   me.inittable( childs, me.engineertakeoff );

   childs = props.globals.getNode("/systems/crew/voice/checklists/landing/pilot[0]").getChildren("message");
   me.inittable( childs, me.pilotlanding );
   childs = props.globals.getNode("/systems/crew/voice/checklists/landing/pilot[1]").getChildren("message");
   me.inittable( childs, me.allwayslanding );
   childs = props.globals.getNode("/systems/crew/voice/checklists/landing/engineer[0]").getChildren("message");
   me.inittable( childs, me.engineerlanding );

   childs = props.globals.getNode("/systems/crew/voice/checklists/goaround/pilot[0]").getChildren("message");
   me.inittable( childs, me.pilotgoaround );

   childs = props.globals.getNode("/systems/crew/voice/checklists/flight/pilot[0]").getChildren("message");
   me.inittable( childs, me.allwaysflight );

   childs = props.globals.getNode("/systems/crew/voice/checklists/all/pilot[0]").getChildren("message");
   me.inittable( childs, me.allways );
}

Callout.set_relation = func( autopilot ) {
    me.autopilotsystem = autopilot;
}

# everything is parametrized by HUMANSEC
Callout.set_rates = func( steps ) {
    me.rates = steps;
    me.ratiostep = me.rates / me.HUMANSEC;

    me.DECAYKT = me.DECAYKTPS * me.rates;
    me.FINALKT = me.FINALKTPS * me.rates;

    me.MAXFT = me.MAXFPM * me.rates / constant.MINUTETOSECOND;
}

calloutcron = func {
    calloutcrew.schedule();
}

Callout.schedule = func {
   if( me.crew.getChild("serviceable").getValue() ) {
       me.set_rates( me.ABSENTSEC );

       me.vertical = me.ap.getChild("vertical").getValue();
       me.speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();
       me.groundkt = me.slave["ins"].getChild("ground-speed-fps").getValue() * constant.FPSTOKT;
       me.altitudeft = me.slave["altimeter"].getChild("indicated-altitude-ft").getValue();
       me.aglft = me.slave["radioaltimeter"].getChild("indicated-altitude-ft").getValue();
       me.speedfpm = me.slave["ivsi"].getChild("indicated-speed-fpm").getValue();
       me.gear = me.slave["gear"].getChild("position-norm").getValue();
       me.nose = me.slave["nose"].getChild("pos-norm").getValue();

       # 1 cycle
       me.reactionft = me.speedfpm / constant.MINUTETOSECOND;
       me.reactionkt = me.speedkt - me.lastspeedkt;

       if( me.hearsound ) {
           me.hearvoice = me.crewcontrol.getNode("voice/sound").getValue();
       }
       me.seetext = me.crewcontrol.getNode("voice/text").getValue();

       me.whichchecklist();

       if( me.checklist == "landing" ) {
           me.landing();
       }
       elsif( me.checklist == "flight" ) {
           me.flight();
       }
       elsif( me.checklist == "takeoff" ) {
           me.takeoff();
       }
       elsif( me.checklist == "holding" ) {
           me.holding();
       }
       elsif( me.checklist == "goaround" ) {
           me.goaround();
       }

       me.playvoices();
       me.cleartext();

       me.snapshot();
   }

   else {
       me.rates = me.ABSENTSEC;
   }

   settimer( calloutcron, me.rates );
}

Callout.whichchecklist = func {
   curairport = me.presets.getChild("airport-id").getValue();
   currunway = me.presets.getChild("runway").getValue();


   # ground speed, because wind distorts asi
   if( me.aglft < constantaero.AGLTOUCHFT and me.groundkt < me.TAXIKT ) {
       # all engines started
       if( me.checklist == "parking" ) {
           if( me.slave["engine"][0].getChild("running").getValue() and
               me.slave["engine"][1].getChild("running").getValue() and
               me.slave["engine"][2].getChild("running").getValue() and
               me.slave["engine"][3].getChild("running").getValue() ) {
               me.takeoffinit();
           }
       }

       # all engines stopped
       elsif( me.checklist == "gate" ) {
           if( !me.slave["engine"][0].getChild("running").getValue() and
               !me.slave["engine"][1].getChild("running").getValue() and
               !me.slave["engine"][2].getChild("running").getValue() and
               !me.slave["engine"][3].getChild("running").getValue() ) {
               me.parkinginit();
           }
       }

       # inboard engines stopped
       elsif( me.checklist == "taxi" ) {
           if( !me.slave["engine"][1].getChild("running").getValue() and
               !me.slave["engine"][2].getChild("running").getValue() ) {
               me.gateinit();
           }
       }

       # holds brakes at runway threshold
       elsif( me.checklist == "takeoff" ) {
           if( getprop("/controls/gear/brake-parking-lever") ) {
               me.holdinginit();
           }
       }

       # relocation on ground
       elsif( me.checklist != "takeoff" and me.checklist != "holding" ) {
           if( curairport != me.airport or currunway != me.runway or me.checklist != "taxi" ) {
               if( getprop("/controls/gear/brake-parking-lever") ) {
                   me.holdinginit();
               }
               else {
                   me.takeoffinit();
               }
           }
       }
    }

    # relocation in flight
    elsif( me.altitudeft > me.lastaltitudeft + me.MAXFT or
           me.altitudeft < me.lastaltitudeft - me.MAXFT  ) {
       if( me.checklist != "flight" ) {
           me.flightinit();
       }
   }

   # go around
   elsif( me.vertical == "goaround" ) {
       if( me.checklist == "landing" ) {
           me.goaroundinit();
       }
   }

   # climb
   elsif( me.speedfpm > me.CLIMBFPM and me.aglft > constantaero.CLIMBFT ) {
       if( me.checklist != "flight" ) {
           me.flightinit();
       }
   }

   # landing
   elsif( me.speedfpm < me.DESCENTFPM and me.aglft < constantaero.APPROACHFT ) {
       # impossible just after a takeoff, must climb enough
       if( me.checklist == "flight" ) {
           me.landinginit();
       }
   }


   me.airport = curairport;
   me.runway = currunway;

   me.crew.getChild("checklist").setValue(me.checklist);
}

Callout.snapshot = func {
   me.lastspeedkt = me.speedkt;
   me.lastaltitudeft = me.altitudeft;
   me.lastnose = me.nose;
}

Callout.acceleratekt = func( speedkt ) {
   valuekt = speedkt - me.reactionkt * me.ratiostep;

   return valuekt;
}

Callout.climbft = func( altitudeft ) {
   # adds 1 seconds for better matching
   valueft = altitudeft - me.reactionft * ( me.ratiostep + me.ratio1s );

   return valueft;
}

Callout.Vkt = func( minkt, maxkt ) {
    weightlb = getprop(me.noinstrument["weight"]);

    if( weightlb > me.FULLLB ) {
        valuekt = maxkt;
    }
    elsif( weightlb < me.EMPTYLB ) {
        valuekt = minkt;
    }
    else {
        ratio = ( me.FULLLB - weightlb ) / ( me.FULLLB - me.EMPTYLB );
        valuekt = maxkt + ( minkt - maxkt ) * ratio;
    }

   return valuekt;
}

Callout.getlevel = func {
   if( me.altitudeft < 5000 ) {
       level = 0;
   }
   elsif( me.altitudeft >= 5000 and me.altitudeft < 15000 ) {
       level = 1;
   }
   elsif( me.altitudeft >= 15000 and me.altitudeft < 25000 ) {
       level = 2;
   }
   elsif( me.altitudeft >= 25000 and me.altitudeft < 35000 ) {
       level = 3;
   }
   elsif( me.altitudeft >= 35000 and me.altitudeft < 45000 ) {
       level = 4;
   }
   elsif( me.altitudeft >= 45000 ) {
       level = 5;
   }

   return level;
}

Callout.setlevel = func {
   me.level10000 = me.getlevel();
}

Callout.levelchange = func {
   level = me.getlevel();

   if( ( level > me.level10000 and me.altitudeft >= me.climbft( level * me.FLIGHTLEVELFT ) ) or
       ( level < me.level10000 and me.altitudeft <= me.climbft( level * me.FLIGHTLEVELFT ) ) ) {
       me.level10000 = level;
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }
}

Callout.stepallways = func( state, table, repeat = 0 ) {
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
       else {
           result = constant.FALSE;
       }
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Callout.steppilot = func( state, table ) {
   me.phrase = table[state];
   me.delaysec = 0;

   if( me.phrase == "" ) {
       print("missing voice text : ",state);
   }

   me.asynchronous = constant.TRUE;

   return state;
}

Callout.stepengineer = func( state, table ) {
   me.phraseengineer = table[state];
   me.delayengineersec = 0;

   if( me.phraseengineer == "" ) {
       print("missing voice text : ",state);
   }

   return state;
}

Callout.playvoices = func {
   if( me.phrase != "" or me.phraseengineer != "" ) {
       me.set_rates( me.HUMANSEC );
   }

   # pilot not in command calls out
   if( me.delaysec <= 0 ) {
       if( me.phrase != "" ) {
           if( me.hearvoice ) {
               me.sound.getChild("copilot").setValue(me.phrase);
           }
           if( me.seetext ) {
               me.sendtext(me.phrase);
           }
           me.phrase = "";

           # engineer lets pilot speak
           if( me.phraseengineer != "" ) {
               me.delayengineersec = me.CONVERSATIONSEC;
           }
        }
   }
   else {
       me.delaysec = me.delaysec - me.rates;
   }

   # no engineer voice yet
   if( me.delayengineersec <= 0 ) {
       if( me.phraseengineer != "" ) {
           if( me.hearvoice ) {
               me.sound.getChild("pilot").setValue(me.phraseengineer);
           }
           if( me.seetext ) {
               me.sendtext(me.phraseengineer);
           }
           me.phraseengineer = "";
       }
   }
   else {
       me.delayengineersec = me.delayengineersec - me.rates;
   }

  if( me.nextsec > 0 ) {
      me.nextsec = me.nextsec - me.rates;
  }

   me.asynchronous = constant.FALSE;
}

Callout.textexport = func {
   if( me.seetext ) {
       feedback = "crew text off";
       me.seetext = constant.FALSE;
   }
   else {
       feedback = "crew text on";
       me.seetext = constant.TRUE;
   }

   me.sendtext( feedback, constant.TRUE );
   me.crewcontrol.getNode("voice/text").setValue(me.seetext);
}

Callout.sendtext = func( text, force = 0 ) {
   if( me.seetext or force ) {
       # bright green
       me.textbox.write( text, 0, 1, 0 );
   }
}

Callout.cleartext = func {
    # limits maximized display
    if( me.MINIMIZEDSEC > 0 ) {
        if( me.crew.getChild("minimized").getValue() != me.minimized ) {
            # start timer
            if( me.minimized ) {
                me.minimized = constant.FALSE;
                me.maximizeds = 0;
            }
            else {
                me.minimized = constant.TRUE;
            }
        }

        elsif( !me.minimized ) {
            if( me.maximizeds > me.MINIMIZEDSEC ) {
                me.minimized = constant.TRUE;
                me.crew.getChild("minimized").setValue( me.minimized );
            }
            else {
                me.maximizeds = me.maximizeds + me.rates;
            }
        }
    }
}


# ----
# GATE
# ----
Callout.gateinit = func {
   me.checklist = "gate";
   me.automata = "";
   me.automata2 = "";
}


# -------
# PARKING
# -------
Callout.parkinginit = func {
   me.checklist = "parking";
   me.automata = "";
   me.automata2 = "";
}


# -------
# HOLDING
# -------
Callout.holdinginit = func {
   me.checklist = "holding";
   me.automata = "holding";
   me.automata2 = "holding";

   me.setlevel();
}

Callout.holding = func {
   me.set_rates( me.HOLDINGSEC );

   if( me.automata == "holding" ) {
       if( !getprop("/controls/gear/brake-parking-lever") ) {
           me.automata = me.steppilot( "brakes3", me.pilottakeoff );
       }
   }

   elsif( me.automata == "brakes3" ) {
       me.automata = me.steppilot( "brakes2", me.pilottakeoff );
   }

   elsif( me.automata == "brakes2" ) {
       me.automata = me.steppilot( "brakes1", me.pilottakeoff );
   }

   elsif( me.automata == "brakes1" ) {
       me.automata = me.steppilot( "brakes", me.pilottakeoff );
   }
   else {
       me.takeoffinit();
   }
}


# -------
# TAKEOFF
# -------
Callout.takeoffinit = func {
   me.checklist = "takeoff";
   me.automata = "takeoff";
   me.automata2 = "takeoff";

   me.v2 = constant.FALSE;

   me.setlevel();
}

Callout.takeoff = func {
   me.set_rates( me.HUMANSEC );

   me.takeoffpilot();

   if( !me.asynchronous ) {
       me.takeoffclimb();
   }

   if( !me.asynchronous ) {
       me.takeoffallways();
   }

   if( !me.asynchronous ) {
       me.flightallways();
   }

   if( !me.asynchronous ) {
       me.checkallways();
   }
}

Callout.takeoffallways = func {
   if( me.aglft > constantaero.AGLTOUCHFT ) {
       if( me.speedfpm < me.DECAYFPM and me.aglft > constantaero.AGLTOUCHFT ) {
           me.stepallways( "negativvsi", me.allwaystakeoff, constant.TRUE );
       }

       elsif( me.speedkt < constantaero.APPROACHKT and
              (  me.reactionkt < me.DECAYKT or
                 ( me.v2 and
                   me.speedkt < me.acceleratekt( me.Vkt( me.V2EMPTYKT, me.V2FULLKT ) ) ) ) ) {
           me.stepallways( "airspeeddecay", me.allwaystakeoff, constant.TRUE );
       }
   }
}

Callout.takeoffclimb = func {
   if( me.automata2 == "takeoff" ) {
       if( me.speedfpm > 0 and me.aglft >= me.LIFTOFFFT ) {
           me.automata2 = me.steppilot( "liftoff", me.pilotclimb );
       }
   }
}

Callout.takeoffpilot = func {
   if( me.automata == "takeoff" ) {
       if( me.speedkt >= me.acceleratekt( me.AIRSPEEDKT ) ) {
           me.automata = me.steppilot( "airspeed", me.pilottakeoff );
       }
   }

   elsif( me.automata == "airspeed" ) {
       if( me.speedkt >= me.acceleratekt( me.V100KT ) ) {
           me.automata = me.steppilot( "100kt", me.pilottakeoff );
           me.stepengineer( "100kt", me.engineertakeoff );
       }
   }

   elsif( me.automata == "100kt" ) {
       if( me.speedkt >= me.acceleratekt( me.Vkt( me.V1EMPTYKT, me.V1FULLKT ) ) ) {
           me.automata = me.steppilot( "V1", me.pilottakeoff );
       }
   }

   elsif( me.automata == "V1" ) {
       if( me.speedkt >= me.acceleratekt( me.Vkt( me.VREMPTYKT, me.VRFULLKT ) ) ) {
           me.automata = me.steppilot( "VR", me.pilottakeoff );
       }
   }

   elsif( me.automata == "VR" ) {
       if( me.speedkt >= me.acceleratekt( me.Vkt( me.V2EMPTYKT, me.V2FULLKT ) ) ) {
           me.automata = me.steppilot( "V2", me.pilottakeoff );
           me.v2 = constant.TRUE;
       }
   }

   elsif( me.automata == "V2" ) {
       if( me.speedkt >= me.acceleratekt( me.V240KT ) ) {
           me.automata = me.steppilot( "240kt", me.pilottakeoff );
       }
   }
}


# ------
# FLIGHT 
# ------
Callout.flightinit = func {
   me.checklist = "flight";
   me.automata = "";
   me.automata2 = "";

   me.setlevel();
}

Callout.flight = func {
   me.flightallways();

   if( !me.asynchronous ) {
       me.checkallways();
   }
}

Callout.flightallways = func {
   if( !me.crew.getChild("emergency").getValue() ) {
       altitudeft = me.ap.getChild("altitude-select").getValue();
       if( me.selectft != altitudeft ) {
           me.selectft = altitudeft;
           me.delayselectftsec = me.rates;
       }
       elsif( me.delayselectftsec > 0 ) {
           if( me.delayselectftsec >= me.MODIFYSEC ) {
               if( me.stepallways( "altitudeset", me.allwaysflight ) ) {
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
                   !me.autopilotsystem.altitudelight_on( me.altitudeft, me.selectft ) ) {
                   me.altitudeselect = constant.TRUE;
               }
           }
       }
       else { 
           if( me.autopilotsystem.is_engaged() and
               me.autopilotsystem.altitudelight_on( me.altitudeft, me.selectft ) ) {
               if( me.stepallways( "1000fttogo", me.allwaysflight ) ) {
                   me.altitudeselect = constant.FALSE;
               }
           }       
       }


       if( me.levelchange() ) {
           me.stepallways( "altimetercheck", me.allwaysflight );
       }
   } 
}


# -------
# LANDING
# -------
Callout.landinginit = func {
   me.checklist = "landing";
   me.automata = "landing";
   me.automata2 = "landing";
   me.decision = constant.FALSE;
   me.decisiontogo = constant.FALSE;
}

Callout.landing = func {
   me.set_rates( me.HUMANSEC );

   me.landingengineer();

   if( !me.asynchronous ) {
       me.landingpilot();
   }

   if( !me.asynchronous ) {
       me.landingallways();
   }

   if( !me.asynchronous ) {
       me.checkallways();
   }
}

Callout.landingpilot = func {
   if( me.automata2 == "landing" ) {
       if( me.slave["nav"].getChild("in-range").getValue() and
           me.slave["nav"].getChild("has-gs").getValue() ) {
           if( me.autopilotsystem.is_engaged() and
               me.ap.getChild("altitude").getValue() == "gs1-hold" ) {
               me.automata2 = me.steppilot( "glideslope", me.pilotlanding );
           }
       }
   }
   elsif( me.automata2 == "glideslope" ) {
       if( me.speedkt < me.acceleratekt( 100 ) ) {
           me.automata2 = me.steppilot( "100kt", me.pilotlanding );
       }
   }
   elsif( me.automata2 == "100kt" ) {
       if( me.speedkt < me.acceleratekt( 75 ) ) {
           me.automata2 = me.steppilot( "75kt", me.pilotlanding );
       }
   }
   elsif( me.automata2 == "75kt" ) {
       if( me.speedkt < me.acceleratekt( 40 ) ) {
           me.automata2 = me.steppilot( "40kt", me.pilotlanding );
       }
   }
   elsif( me.automata2 == "40kt" ) {
       if( me.speedkt < me.acceleratekt( 20 ) ) {
           me.automata2 = me.steppilot( "20kt", me.pilotlanding );
       }
   }
   else {
       me.taxiinit();
   }
}

Callout.landingengineer = func {
   if( me.automata == "landing" ) {
       if( me.aglft < me.climbft( 2500 ) ) {
           me.automata = me.steppilot( "2500ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "2500ft" ) {
       if( me.aglft < me.climbft( 1000 ) ) {
           me.automata = me.steppilot( "1000ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "1000ft" ) {
       if( me.aglft < me.climbft( 800 ) ) {
           me.automata = me.steppilot( "800ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "800ft" ) {
       if( me.aglft < me.climbft( 500 ) ) {
           me.automata = me.steppilot( "500ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "500ft" ) {
       if( me.aglft < me.climbft( 400 ) ) {
           me.automata = me.steppilot( "400ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "400ft" ) {
       if( me.aglft < me.climbft( 300 ) ) {
           me.automata = me.steppilot( "300ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "300ft" ) {
       if( me.aglft < me.climbft( 200 ) ) {
           me.automata = me.steppilot( "200ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "200ft" ) {
       if( me.aglft < me.climbft( 100 ) ) {
           me.automata = me.steppilot( "100ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "100ft" ) {
       me.landingtouchdown( 50 );
   }

   elsif( me.automata == "50ft" ) {
       me.landingtouchdown( 40 );
   }

   elsif( me.automata == "40ft" ) {
       me.landingtouchdown( 30 );
   }

   elsif( me.automata == "30ft" ) {
       me.landingtouchdown( 20 );
   }

   elsif( me.automata == "20ft" ) {
       if( me.aglft < me.climbft( 15 ) ) {
           me.automata = me.steppilot( "15ft", me.engineerlanding );
       }
   }
}

# can be faster
Callout.landingtouchdown = func( limitft ) {
   if( 15 >= limitft and me.aglft < me.climbft( 15 ) ) {
       me.automata = me.steppilot( "15ft", me.engineerlanding );
   }
   elsif( 20 >= limitft and me.aglft < me.climbft( 20 ) ) {
       me.automata = me.steppilot( "20ft", me.engineerlanding );
   }
   elsif( 30 >= limitft and me.aglft < me.climbft( 30 ) ) {
       me.automata = me.steppilot( "30ft", me.engineerlanding );
   }
   elsif( 40 >= limitft and me.aglft < me.climbft( 40 ) ) {
       me.automata = me.steppilot( "40ft", me.engineerlanding );
   }
   elsif( 50 >= limitft and me.aglft < me.climbft( 50 ) ) {
       me.automata = me.steppilot( "50ft", me.engineerlanding );
   }
}

Callout.landingallways = func {
   altitudeft = me.ap.getChild("altitude-select").getValue();
   if( me.selectft != altitudeft ) {
       me.selectft = altitudeft;
       me.delayselectftsec = me.rates;
   }
   elsif( me.delayselectftsec > 0 ) {
       if( me.delayselectftsec >= me.MODIFYSEC ) {
           if( me.stepallways( "goaroundset", me.allwayslanding ) ) {
               me.delayselectftsec = 0;
           }
       }
       else {
           me.delayselectftsec = me.delayselectftsec + me.rates;
       }
   }

   if( me.aglft < me.FINALFT and me.speedfpm < me.FINALFPM ) {
       me.stepallways( "vsiexcess", me.allwayslanding, constant.TRUE );
   }

   elsif( !me.decisiontogo and
          me.aglft < me.climbft( me.slave["radioaltimeter"].getChild("decision-ft").getValue() + 100 ) ) {
       me.stepallways( "100fttogo", me.allwayslanding );
       me.decisiontogo = constant.TRUE;
   }

   elsif( me.decisiontogo and !me.decision and
          me.aglft < me.climbft( me.slave["radioaltimeter"].getChild("decision-ft").getValue() ) ) {
       me.stepallways( "decisionheight", me.allwayslanding );
       me.decision = constant.TRUE;
   }

   elsif( me.aglft < me.FINALFT and !me.decision and
         ( me.reactionkt < me.FINALKT or
           me.speedkt < me.acceleratekt( me.Vkt( me.VREFEMPTYKT, me.VREFFULLKT ) ) ) ) {
       me.stepallways( "approachspeed", me.allwayslanding, constant.TRUE );
   }
}


# ----
# TAXI
# ----
Callout.taxiinit = func {
   me.checklist = "taxi";
   me.automata = "";
   me.automata2 = "";
}


# ---------
# GO AROUND
# ---------
Callout.goaroundinit = func {
   me.checklist = "goaround";
   me.automata = "goaround";
   me.automata2 = "goaround";
}

Callout.goaround = func {
   me.set_rates( me.HUMANSEC );

   if( me.automata == "goaround" ) {
       if( me.speedfpm > 0 ) {
           me.automata = me.steppilot( "positivclimb", me.pilotgoaround );
       }
   }

   if( !me.asynchronous ) {
       me.takeoffallways();
   }

   if( !me.asynchronous ) {
       me.checkallways();
   }
}


# ------
# ALWAYS 
# ------
Callout.checkallways = func {
   if( me.nose != me.lastnose or me.gear != me.lastgear ) {
       change = constant.TRUE;
       if( me.nose == 1.0 and me.gear == 1.0 ) {
           if( !me.stepallways( "5greens", me.allways ) ) {
               change = constant.FALSE;
           }
       }

       if( change ) {
           me.lastnose = me.nose;
       }
   }

   if( me.gear != me.lastgear ) {
       change = constant.TRUE;
       if( me.gear == 0.0 ) {
           if( !me.stepallways( "gearup", me.allways ) ) {
               change = constant.FALSE;
           }
       }

       if( change ) {
           me.lastgear = me.gear;
       }
   }
}
