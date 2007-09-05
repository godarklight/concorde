# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# =============
# CREW CALLOUTS 
# =============

Callout = {};

Callout.new = func {
   obj = { parents : [Callout,System],

           autopilotsystem : nil,

           flightlevel : Altitudeperception.new(),
           acceleration : Speedperception.new(),
           crewvoice : Crewvoice.new(),

           ap : nil,
           crew : nil,
           presets : nil,

           MODIFYSEC : 15.0,                                 # to modify something
           ABSENTSEC : 15.0,                                 # less attention
           HOLDINGSEC : 5.0,

           rates : 0.0,                                      # variable time step

           CLIMBFPM : 100.0,
           DECAYFPM : -50.0,                                 # not zero, to avoid false alarm
           DESCENTFPM : -100.0,
           FINALFPM : -1000.0,

           CRUISEFT : 50000.0,
           FINALFT : 1000.0,
           ALERTFT : 300.0,
           FLAREFT : 100.0,

           altitudeft : 0.0,
           lastaltitudeft : 0.0,
           altitudeselect : constant.FALSE,
           selectft : 0.0,
           delayselectftsec : 0,
           vertical : "",

           aglft : 0.0,
           category : constant.FALSE,
           alert : constant.FALSE,
           decision : constant.FALSE,
           decisiontogo : constant.FALSE,

           V240KT : 240.0,
           V100KT : 100.0,
           AIRSPEEDKT : 60.0,

           v2 : constant.FALSE,

           speedkt : 0.0,
           lastspeedkt : 0.0,
           groundkt : 0.0,

           FLAREDEG : 12.5,

           fueltransfert : constant.FALSE,

           gear : 0.0,
           lastgear : 0.0,
           nose : 0.0,
           lastnose : 0.0,

           airport : "",
           runway : "",

           # pilot not in command
           pilottakeoff : {},
           pilotclimb : {},
           pilotlanding : {},
           pilotgoaround : {},
           allwaystakeoff : {},
           allwayslanding : {},
           allwaysflight : {},
           allways : {},

           # engineer
           engineertakeoff : {},
           engineerlanding : {},
           engineerflight : {},

           checklist : "",
           automata : "",
           automata2 : ""
         };

   obj.init();

   return obj;
}

Callout.init = func {
   me.ap = props.globals.getNode("/controls/autoflight");
   me.crew = props.globals.getNode("/systems/crew");
   me.presets = props.globals.getNode("/sim/presets");

   me.init_ancestor("/systems/crew/voice");

   me.selectft = me.ap.getChild("altitude-select").getValue();

   me.inittext();

   settimer( func { me.schedule(); }, constant.HUMANSEC );
}

Callout.inittable = func( path, table ) {
   node = props.globals.getNode(path).getChildren("message");
   for( i=0; i < size(node); i=i+1 ) {
        key = node[i].getChild("action").getValue();
        text = node[i].getChild("text").getValue();
        table[key] = text;
   }
}

Callout.inittext = func {
   me.inittable("/systems/crew/voice/checklists/takeoff/pilot[0]", me.pilottakeoff );
   me.inittable("/systems/crew/voice/checklists/takeoff/pilot[1]", me.pilotclimb );
   me.inittable("/systems/crew/voice/checklists/takeoff/pilot[2]", me.allwaystakeoff );
   me.inittable("/systems/crew/voice/checklists/takeoff/engineer[0]", me.engineertakeoff );

   me.inittable("/systems/crew/voice/checklists/landing/pilot[0]", me.pilotlanding );
   me.inittable("/systems/crew/voice/checklists/landing/pilot[1]", me.allwayslanding );
   me.inittable("/systems/crew/voice/checklists/landing/engineer[0]", me.engineerlanding );

   me.inittable("/systems/crew/voice/checklists/goaround/pilot[0]", me.pilotgoaround );

   me.inittable("/systems/crew/voice/checklists/flight/pilot[0]", me.allwaysflight );
   me.inittable("/systems/crew/voice/checklists/flight/engineer[0]", me.engineerflight );

   me.inittable("/systems/crew/voice/checklists/all/pilot[0]", me.allways );
}

Callout.set_relation = func( autopilot ) {
    me.autopilotsystem = autopilot;
}

Callout.set_rates = func( steps ) {
    me.rates = steps;

    me.flightlevel.set_rates( me.rates );
    me.acceleration.set_rates( me.rates );
}

Callout.crewtextexport = func {
    me.crewvoice.textexport();
}

Callout.schedule = func {
   if( me.crew.getChild("serviceable").getValue() ) {
       me.set_rates( me.ABSENTSEC );

       me.vertical = me.ap.getChild("vertical").getValue();
       me.speedkt = me.slave["asi"].getChild("indicated-speed-kt").getValue();
       me.groundkt = me.slave["ins"].getChild("ground-speed-fps").getValue() * constant.FPSTOKT;
       me.altitudeft = me.slave["altimeter"].getChild("indicated-altitude-ft").getValue();
       me.aglft = me.slave["radio-altimeter"].getChild("indicated-altitude-ft").getValue();
       me.speedfpm = me.slave["ivsi"].getChild("indicated-speed-fpm").getValue();
       me.gear = me.slave["gear"].getChild("position-norm").getValue();
       me.nose = me.slave["nose"].getChild("pos-norm").getValue();

       # 1 cycle
       me.flightlevel.schedule( me.speedfpm );
       me.acceleration.schedule( me.speedkt, me.lastspeedkt );

       me.crewvoice.schedule();

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

       me.snapshot();
   }

   else {
       me.rates = me.ABSENTSEC;
       me.crew.getChild("checklist").setValue("no crew");
   }

   settimer( func { me.schedule(); }, me.rates );
}

Callout.whichchecklist = func {
   curairport = me.presets.getChild("airport-id").getValue();
   currunway = me.presets.getChild("runway").getValue();


   # ground speed, because wind distorts asi
   if( me.aglft < constantaero.AGLTOUCHFT and me.groundkt < constantaero.TAXIKT ) {
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
   elsif( !me.flightlevel.insideft( me.altitudeft, me.lastaltitudeft ) ) {
       me.flightinit();
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

Callout.playvoices = func {
   if( me.crewvoice.willplay() ) {
       me.set_rates( constant.HUMANSEC );
   }

   me.crewvoice.playvoices( me.rates );
}

Callout.Vkt = func( minkt, maxkt ) {
    weightlb = me.noinstrument["weight"].getValue();

    valuekt = constantaero.Vkt( weightlb, minkt, maxkt );

    return valuekt;
}


# ----
# GATE
# ----
Callout.gateinit = func {
   me.checklist = "gate";
   me.automata = "";
   me.automata2 = "";

   me.flightlevel.setlevel( me.altitudeft );
}


# -------
# PARKING
# -------
Callout.parkinginit = func {
   me.checklist = "parking";
   me.automata = "";
   me.automata2 = "";

   me.flightlevel.setlevel( me.altitudeft );
}


# -------
# HOLDING
# -------
Callout.holdinginit = func {
   me.checklist = "holding";
   me.automata = "holding";
   me.automata2 = "holding";

   me.flightlevel.setlevel( me.altitudeft );
}

Callout.holding = func {
   me.set_rates( me.HOLDINGSEC );

   if( me.automata == "holding" ) {
       if( !getprop("/controls/gear/brake-parking-lever") ) {
           me.automata = me.crewvoice.steppilot( "brakes3", me.pilottakeoff );
       }
   }

   elsif( me.automata == "brakes3" ) {
       me.automata = me.crewvoice.steppilot( "brakes2", me.pilottakeoff );
   }

   elsif( me.automata == "brakes2" ) {
       me.automata = me.crewvoice.steppilot( "brakes1", me.pilottakeoff );
   }

   elsif( me.automata == "brakes1" ) {
       me.automata = me.crewvoice.steppilot( "brakes", me.pilottakeoff );
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

   me.flightlevel.setlevel( me.altitudeft );
}

Callout.takeoff = func {
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
}

Callout.takeoffallways = func {
   if( me.aglft > constantaero.AGLTOUCHFT ) {
       if( me.speedfpm < me.DECAYFPM and me.aglft > constantaero.AGLTOUCHFT ) {
           me.crewvoice.stepallways( "negativvsi", me.allwaystakeoff, constant.TRUE );
       }

       elsif( me.speedkt < constantaero.APPROACHKT and
              (  me.acceleration.approachdecrease() or
                 ( me.v2 and
                   me.speedkt < me.acceleration.velocitykt( me.Vkt( constantaero.V2EMPTYKT,
                                                                    constantaero.V2FULLKT ) ) ) ) ) {
           me.crewvoice.stepallways( "airspeeddecay", me.allwaystakeoff, constant.TRUE );
       }
   }
}

Callout.takeoffclimb = func {
   if( me.automata2 == "takeoff" ) {
       if( me.speedfpm > 0 and me.aglft >= constantaero.GEARFT ) {
           me.automata2 = me.crewvoice.steppilot( "liftoff", me.pilotclimb );
       }
   }
}

Callout.takeoffpilot = func {
   if( me.automata == "takeoff" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.AIRSPEEDKT ) ) {
           me.automata = me.crewvoice.steppilot( "airspeed", me.pilottakeoff );
       }
   }

   elsif( me.automata == "airspeed" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.V100KT ) ) {
           me.automata = me.crewvoice.steppilot( "100kt", me.pilottakeoff );
           me.crewvoice.stepengineer( "100kt", me.engineertakeoff );
       }
   }

   elsif( me.automata == "100kt" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.Vkt( constantaero.V1EMPTYKT,
                                                             constantaero.V1FULLKT ) ) ) {
           me.automata = me.crewvoice.steppilot( "V1", me.pilottakeoff );
       }
   }

   elsif( me.automata == "V1" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.Vkt( constantaero.VREMPTYKT,
                                                             constantaero.VRFULLKT ) ) ) {
           me.automata = me.crewvoice.steppilot( "VR", me.pilottakeoff );
       }
   }

   elsif( me.automata == "VR" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.Vkt( constantaero.V2EMPTYKT,
                                                             constantaero.V2FULLKT ) ) ) {
           me.automata = me.crewvoice.steppilot( "V2", me.pilottakeoff );
           me.v2 = constant.TRUE;
       }
   }

   elsif( me.automata == "V2" ) {
       if( me.speedkt >= me.acceleration.velocitykt( me.V240KT ) ) {
           me.automata = me.crewvoice.steppilot( "240kt", me.pilottakeoff );
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

   me.flightlevel.setlevel( me.altitudeft );
}

Callout.flight = func {
   me.flightallways();

   if( !me.crewvoice.is_asynchronous() ) {
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
               if( me.crewvoice.stepallways( "altitudeset", me.allwaysflight ) ) {
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
               if( me.crewvoice.stepallways( "1000fttogo", me.allwaysflight ) ) {
                   me.altitudeselect = constant.FALSE;
               }
           }       
       }


       if( me.flightlevel.levelchange( me.altitudeft ) ) {
           me.crewvoice.stepallways( "altimetercheck", me.allwaysflight );

           if( me.slave["engineer"].getNode("cg/forward").getValue() ) {
               me.fueltransfert = constant.TRUE;
               me.crewvoice.stepengineer( "cgforward", me.engineerflight );
           }
           elsif( me.slave["engineer"].getNode("cg/aft").getValue() ) {
               me.fueltransfert = constant.TRUE;
               me.crewvoice.stepengineer( "cgaft", me.engineerflight );
           }
           else {
               me.fueltransfert = constant.FALSE;
               me.crewvoice.stepengineer( "cgcorrect", me.engineerflight );
           }
       }
       elsif( me.flightlevel.transitionchange( me.altitudeft ) ) {
           me.crewvoice.stepallways( "transition", me.allwaysflight );
       }

       # fuel transfert is completed :
       # - climb at 26000 ft.
       # - cruise above 50000 ft.
       # - descent to 38000 ft.
       # - approach to 10000 ft.
       elsif( me.fueltransfert and
              !me.slave["engineer"].getNode("cg/forward").getValue() and
              !me.slave["engineer"].getNode("cg/aft").getValue() ) {
           if( ( me.autopilotsystem.is_engaged() and
               ( me.autopilotsystem.is_altitude_acquire() or
                 me.autopilotsystem.is_altitude_hold() ) ) or
               me.altitudeft > me.CRUISEFT or me.altitudeft < constantaero.APPROACHFT ) {
               me.fueltransfert = constant.FALSE;
               me.crewvoice.stepengineer( "cgcorrect", me.engineerflight );
           }
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
   me.category = constant.FALSE;
   me.alert = constant.FALSE;
   me.decision = constant.FALSE;
   me.decisiontogo = constant.FALSE;

   me.flightlevel.setlevel( me.altitudeft );
}

Callout.landing = func {
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
}

Callout.landingpilot = func {
   if( me.automata2 == "landing" ) {
       if( me.slave["nav"].getChild("in-range").getValue() ) {
           if( me.autopilotsystem.is_engaged() and
               me.ap.getChild("heading").getValue() == "nav1-hold" ) {
               me.automata2 = me.crewvoice.steppilot( "beambar", me.pilotlanding );
           }
       }
   }
   elsif( me.automata2 == "beambar" ) {
       if( me.slave["nav"].getChild("in-range").getValue() and
           me.slave["nav"].getChild("has-gs").getValue() ) {
           if( me.autopilotsystem.is_engaged() and
               me.ap.getChild("altitude").getValue() == "gs1-hold" ) {
               me.automata2 = me.crewvoice.steppilot( "glideslope", me.pilotlanding );
           }
       }
   }
   elsif( me.automata2 == "glideslope" ) {
       if( me.speedkt < me.acceleration.velocitykt( 100 ) ) {
           me.automata2 = me.crewvoice.steppilot( "100kt", me.pilotlanding );
       }
   }
   elsif( me.automata2 == "100kt" ) {
       if( me.speedkt < me.acceleration.velocitykt( 75 ) ) {
           me.automata2 = me.crewvoice.steppilot( "75kt", me.pilotlanding );
       }
   }
   elsif( me.automata2 == "75kt" ) {
       if( me.speedkt < me.acceleration.velocitykt( 40 ) ) {
           me.automata2 = me.crewvoice.steppilot( "40kt", me.pilotlanding );
       }
   }
   elsif( me.automata2 == "40kt" ) {
       if( me.speedkt < me.acceleration.velocitykt( 20 ) ) {
           me.automata2 = me.crewvoice.steppilot( "20kt", me.pilotlanding );
       }
   }
   else {
       me.taxiinit();
   }
}

Callout.landingengineer = func {
   if( me.automata == "landing" ) {
       if( me.aglft < me.flightlevel.climbft( 2500 ) ) {
           me.automata = me.crewvoice.stepengineer( "2500ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "2500ft" ) {
       if( me.aglft < me.flightlevel.climbft( 1000 ) ) {
           me.automata = me.crewvoice.stepengineer( "1000ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "1000ft" ) {
       if( me.aglft < me.flightlevel.climbft( 800 ) ) {
           me.automata = me.crewvoice.stepengineer( "800ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "800ft" ) {
       if( me.aglft < me.flightlevel.climbft( 500 ) ) {
           me.automata = me.crewvoice.stepengineer( "500ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "500ft" ) {
       if( me.aglft < me.flightlevel.climbft( 400 ) ) {
           me.automata = me.crewvoice.stepengineer( "400ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "400ft" ) {
       if( me.aglft < me.flightlevel.climbft( 300 ) ) {
           me.automata = me.crewvoice.stepengineer( "300ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "300ft" ) {
       if( me.aglft < me.flightlevel.climbft( 200 ) ) {
           me.automata = me.crewvoice.stepengineer( "200ft", me.engineerlanding );
       }
   }

   elsif( me.automata == "200ft" ) {
       if( me.aglft < me.flightlevel.climbft( 100 ) ) {
           me.automata = me.crewvoice.stepengineer( "100ft", me.engineerlanding );
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
       if( me.aglft < me.flightlevel.climbft( 15 ) ) {
           me.automata = me.crewvoice.stepengineer( "15ft", me.engineerlanding );
       }
   }
}

# can be faster
Callout.landingtouchdown = func( limitft ) {
   if( 15 <= limitft and me.aglft < me.flightlevel.climbft( 15 ) ) {
       me.automata = me.crewvoice.stepengineer( "15ft", me.engineerlanding );
   }
   elsif( 20 <= limitft and me.aglft < me.flightlevel.climbft( 20 ) ) {
       me.automata = me.crewvoice.stepengineer( "20ft", me.engineerlanding );
   }
   elsif( 30 <= limitft and me.aglft < me.flightlevel.climbft( 30 ) ) {
       me.automata = me.crewvoice.stepengineer( "30ft", me.engineerlanding );
   }
   elsif( 40 <= limitft and me.aglft < me.flightlevel.climbft( 40 ) ) {
       me.automata = me.crewvoice.stepengineer( "40ft", me.engineerlanding );
   }
   elsif( 50 <= limitft and me.aglft < me.flightlevel.climbft( 50 ) ) {
       me.automata = me.crewvoice.stepengineer( "50ft", me.engineerlanding );
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
           if( me.crewvoice.stepallways( "goaroundset", me.allwayslanding ) ) {
               me.delayselectftsec = 0;
           }
       }
       else {
           me.delayselectftsec = me.delayselectftsec + me.rates;
       }
   }

   if( me.aglft < me.FLAREFT and
       me.slave["attitude"].getChild("indicated-pitch-deg").getValue() > me.FLAREDEG ) {
       me.crewvoice.stepallways( "attitude", me.allwayslanding, constant.TRUE );
   }

   elsif( me.aglft < me.FINALFT and me.speedfpm < me.FINALFPM ) {
       me.crewvoice.stepallways( "vsiexcess", me.allwayslanding, constant.TRUE );
   }

   elsif( !me.category and me.slave["autopilot"].getChild("land3").getValue() ) {
       me.crewvoice.stepallways( "category3", me.allwayslanding );
       me.category = constant.TRUE;
   }

   elsif( !me.category and me.slave["autopilot"].getChild("land2").getValue() ) {
       me.crewvoice.stepallways( "category2", me.allwayslanding );
       me.category = constant.TRUE;
   }

   elsif( !me.alert and me.slave["autopilot"].getChild("land2").getValue() and
          me.aglft < me.flightlevel.climbft( me.ALERTFT ) ) {
       me.crewvoice.stepallways( "alertheight", me.allwayslanding );
       me.alert = constant.TRUE;
   }

   elsif( !me.decisiontogo and
          me.aglft <
          me.flightlevel.climbft( me.slave["radio-altimeter"].getChild("decision-ft").getValue() + 100 ) ) {
       me.crewvoice.stepallways( "100fttogo", me.allwayslanding );
       me.decisiontogo = constant.TRUE;
   }

   elsif( me.decisiontogo and !me.decision and
          me.aglft <
          me.flightlevel.climbft( me.slave["radio-altimeter"].getChild("decision-ft").getValue() ) ) {
       me.crewvoice.stepallways( "decisionheight", me.allwayslanding );
       me.decision = constant.TRUE;
   }

   elsif( me.aglft < me.FINALFT and !me.decision and
         ( me.acceleration.finaldecrease() or
           me.speedkt < me.acceleration.velocitykt( me.Vkt( constantaero.VREFEMPTYKT,
                                                            constantaero.VREFFULLKT ) ) ) ) {
       me.crewvoice.stepallways( "approachspeed", me.allwayslanding, constant.TRUE );
   }
}


# ----
# TAXI
# ----
Callout.taxiinit = func {
   me.checklist = "taxi";
   me.automata = "";
   me.automata2 = "";

   me.flightlevel.setlevel( me.altitudeft );
}


# ---------
# GO AROUND
# ---------
Callout.goaroundinit = func {
   me.checklist = "goaround";
   me.automata = "goaround";
   me.automata2 = "goaround";

   me.flightlevel.setlevel( me.altitudeft );
}

Callout.goaround = func {
   me.set_rates( constant.HUMANSEC );

   if( me.automata == "goaround" ) {
       if( me.speedfpm > 0 ) {
           me.automata = me.crewvoice.steppilot( "positivclimb", me.pilotgoaround );
       }
   }

   if( !me.crewvoice.is_asynchronous() ) {
       me.takeoffallways();
   }

   if( !me.crewvoice.is_asynchronous() ) {
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
           if( !me.crewvoice.stepallways( "5greens", me.allways ) ) {
               change = constant.FALSE;
           }
       }

       if( change ) {
           me.lastnose = me.nose;
       }
   }

   if( me.gear != me.lastgear ) {
       change = constant.TRUE;
       # on pull of lever
       if( me.lastgear == 1.0 and me.gear < 1.0 ) {
           if( !me.crewvoice.stepallways( "gearup", me.allways ) ) {
               change = constant.FALSE;
           }
       }

       if( change ) {
           me.lastgear = me.gear;
       }
   }
}


# ==========
# CREW VOICE 
# ==========

Crewvoice = {};

Crewvoice.new = func {
   obj = { parents : [Crewvoice,System],

           voicebox : Voicebox.new(),

           CONVERSATIONSEC : 4.0,                            # until next message
           REPEATSEC : 4.0,                                  # between 2 messages

           sound : nil,
           voicecontrol : nil,

           # pilot not in command
           phrase : "",
           delaysec : 0.0,                                   # delay this phrase
           nextsec : 0.0,                                    # delay the next phrase

           # engineer
           phraseengineer : "",
           delayengineersec : 0.0,

           asynchronous : constant.FALSE,

           hearsound : constant.FALSE,
           hearvoice : constant.FALSE
         };

   obj.init();

   return obj;
}

Crewvoice.init = func {
   me.init_ancestor("/systems/crew/voice");

   me.voicecontrol = props.globals.getNode("/controls/crew/voice");
   me.sound = props.globals.getNode("/sim/sound/voices");

   me.hearsound = me.sound.getChild("enabled").getValue();
}

Crewvoice.textexport = func {
   feedback = me.voicebox.textexport();

   # also to test sound
   if( me.voicebox.is_on() ) {
       me.talkpilot( feedback );
   }
   else {
       me.talkengineer( feedback );
   }
}

Crewvoice.schedule = func {
   if( me.hearsound ) {
       me.hearvoice = me.voicecontrol.getNode("sound").getValue();
   }

   me.voicebox.schedule();
}

Crewvoice.stepallways = func( state, table, repeat = 0 ) {
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

Crewvoice.steppilot = func( state, table ) {
   me.talkpilot( table[state] );

   if( me.phrase == "" ) {
       print("missing voice text : ",state);
   }

   me.asynchronous = constant.TRUE;

   return state;
}

Crewvoice.talkpilot = func( phrase ) {
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
   me.phraseengineer = phrase;
   me.delayengineersec = 0;
}

Crewvoice.willplay = func {
   if( me.phrase != "" or me.phraseengineer != "" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
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
           if( me.hearvoice ) {
               me.sound.getChild("copilot").setValue(me.phrase);
               me.slave["copilot2"].getNode("teeth").setValue(constant.TRUE);
           }
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
           if( me.hearvoice ) {
               me.sound.getChild("pilot").setValue(me.phraseengineer);
               me.slave["engineer2"].getNode("teeth").setValue(constant.TRUE);
           }
           me.voicebox.sendtext(me.phraseengineer, constant.TRUE);
           me.phraseengineer = "";
       }
   }
   else {
       me.delayengineersec = me.delayengineersec - rates;
   }

   if( me.nextsec > 0 ) {
       me.nextsec = me.nextsec - rates;
   }

   me.asynchronous = constant.FALSE;
}


# ================
# SPEED PERCEPTION
# ================

Speedperception = {};

Speedperception.new = func {
   obj = { parents : [Speedperception],

           ratiostep : 0.0,                                  # rates

           DECAYKT : 0.0,
           FINALKT : 0.0,

           reactionkt : 0.0,

           DECAYKTPS : -1.0,                                 # climb
           FINALKTPS : -3.0                                  # descent
         };

   obj.init();

   return obj;
}

Speedperception.init = func {
}

Speedperception.set_rates = func( rates ) {
    me.ratiostep = rates / constant.HUMANSEC;

    me.DECAYKT = me.DECAYKTPS * rates;
    me.FINALKT = me.FINALKTPS * rates;
}

Speedperception.schedule = func( speedkt, lastspeedkt ) {
    me.reactionkt = speedkt - lastspeedkt;
}

Speedperception.approachdecrease = func {
    if( me.reactionkt < me.DECAYKT ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Speedperception.finaldecrease = func {
    if( me.reactionkt < me.FINALKT ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Speedperception.velocitykt = func( speedkt ) {
    valuekt = speedkt - me.reactionkt * me.ratiostep;

    return valuekt;
}


# ===================
# ALTITUDE PERCEPTION
# ===================

Altitudeperception = {};

Altitudeperception.new = func {
   obj = { parents : [Altitudeperception],

           ratio1s : 0.0,                                    # 1 s
           ratiostep : 0.0,                                  # rates

           TRANSITIONFT : 18000.0,
           FLIGHTLEVELFT : 10000.0,
           MARGINFT : 200.0,                                 # for altitude detection

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
   valueft = altitudeft - me.reactionft * ( me.ratiostep + me.ratio1s );

   return valueft;
}

Altitudeperception.insideft = func( altitudeft, targetft ) {
    if( altitudeft >= targetft - me.MAXFT and altitudeft <= targetft + me.MAXFT  ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Altitudeperception.inside = func {
    if( !me.levelabove and !me.levelbelow ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Altitudeperception.aboveft = func( altitudeft, targetft, marginft ) {
    if( altitudeft > targetft + marginft  ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Altitudeperception.belowft = func( altitudeft, targetft, marginft ) {
    if( altitudeft < targetft - marginft  ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Altitudeperception.setlevel = func( altitudeft ) {
   if( altitudeft < 10000 ) {
       level = 0;
   }
   elsif( altitudeft >= 10000 and altitudeft < 20000 ) {
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

   levelft = me.level10000 * me.FLIGHTLEVELFT;
   me.levelabove = me.aboveft( altitudeft, levelft, me.MARGINFT );
   me.levelbelow = me.belowft( altitudeft, levelft, me.MARGINFT );

   if( altitudeft > me.TRANSITIONFT ) {
       me.transition = constant.TRUE;
   }
   else {
       me.transition = constant.FALSE;
   }
}

Altitudeperception.levelchange = func( altitudeft ) {
   result = constant.FALSE;

   # below current flight level
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

   # above current flight level
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

   # returns to current flight level
   if( !result and me.level10000 > 0 ) {
       currentft = me.climbft( me.level10000 * me.FLIGHTLEVELFT );

       below = me.belowft( altitudeft, currentft, me.MARGINFT );
       above = me.aboveft( altitudeft, currentft, me.MARGINFT );

       if( ( me.levelabove or me.inside() ) and below ) {
           result = constant.TRUE;
           me.levelabove= constant.FALSE;
           me.levelbelow = constant.TRUE;
       }
       elsif( ( me.levelbelow or me.inside() ) and above ) {
           result = constant.TRUE;
           me.levelabove = constant.TRUE;
           me.levelbelow = constant.FALSE;
       }
       else {
           result = constant.FALSE;
           me.levelabove = above;
           me.levelbelow = below;
       }
   }

   return result;
}

Altitudeperception.transitionchange = func( altitudeft ) {
   levelft = me.climbft( me.TRANSITIONFT );

   if( ( !me.transition and me.aboveft( altitudeft, levelft, me.MARGINFT ) ) or
       ( me.transition and me.belowft( altitudeft, levelft, me.MARGINFT ) ) ) {
       me.transition = !me.transition;
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}
