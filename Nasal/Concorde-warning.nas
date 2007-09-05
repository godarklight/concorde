# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by sched are called from cron



# ===============================
# GROUND PROXIMITY WARNING SYSTEM
# ===============================

Gpws = {};

Gpws.new = func {
   obj = { parents : [Gpws,System]
         };

   obj.init();

   return obj;
};

Gpws.init = func {
   me.init_ancestor("/systems/gpws");

   # reads the user customization, JSBSim has an offset of 11 ft
   decisionft = me.slave["radio-altimeter"].getChild("dial-decision-ft").getValue();
   decisionft = decisionft + constantaero.AGLFT;
   me.slave["radio-altimeter"].getChild("decision-ft").setValue(decisionft);
}

Gpws.schedule = func {
    if( getprop("/systems/gpws/serviceable") ) {
        if( !getprop("/systems/gpws/decision-height") ) {
            decisionft = me.slave["radio-altimeter"].getChild("decision-ft").getValue();
            aglft = me.slave["radio-altimeter"].getChild("indicated-altitude-ft").getValue();

            # reset the DH light
            if( aglft > decisionft ) {
                setprop("/systems/gpws/decision-height",constant.TRUE);
            }
        }
    }
}


# =============
# ICE DETECTION
# =============

Icedetection = {};

Icedetection.new = func {
   obj = { parents : [Icedetection,System],

           antiicing : nil,
           detection : nil,
           model : nil,

# airframe heating is ignored
           temperaturedegc : {},
           durationmin : {},

           maxclouds : 0,

           inside : constant.FALSE,
           insidemin : 0,
           warning : constant.FALSE
         };

   obj.init();

   return obj;
};

Icedetection.init = func {
   me.init_ancestor("/systems/anti-icing");

   me.antiicing = props.globals.getNode("/systems/anti-icing");
   me.detection = props.globals.getNode("/systems/anti-icing/detection");
   me.model = props.globals.getNode("/controls/anti-ice/icing-model");

   me.loadmodel();

   me.maxclouds = size( me.noinstrument["cloud"] );
}

Icedetection.schedule = func {
   me.runmodel();
}

Icedetection.loadmodel = func {
   child = me.model.getNode("temperature"); 

   me.temperaturedegc["max"] = child.getChild("max-degc").getValue();
   me.temperaturedegc["min"] = child.getChild("min-degc").getValue();

   child = me.model.getNode("duration"); 

   me.durationmin["few"] = child.getChild("few-min").getValue();
   me.durationmin["scattered"] = child.getChild("scattered-min").getValue();
   me.durationmin["broken"] = child.getChild("broken-min").getValue();
   me.durationmin["overcast"] = child.getChild("overcast-min").getValue();
   me.durationmin["clear"] = child.getChild("clear-min").getValue();
}

Icedetection.runmodel = func {
   found = constant.FALSE;

   if( me.antiicing.getChild("serviceable").getValue() and
       me.slave["electric"].getChild("specific").getValue() ) {

       airdegc =  me.noinstrument["temperature"].getValue();

       if( airdegc >= me.temperaturedegc["min"] and airdegc <= me.temperaturedegc["max"] ) {
           altft = me.noinstrument["altitude"].getValue();

           for( i = 0; i < me.maxclouds; i = i+1 ) {
                coverage = me.noinstrument["cloud"][i].getChild("coverage").getValue();

                # ignores the kind of cloud
                if( coverage != "" and coverage != nil ) {
                    elevationft = me.noinstrument["cloud"][i].getChild("elevation-ft").getValue();
                    thicknessft = me.noinstrument["cloud"][i].getChild("thickness-ft").getValue();

                    # inside layer
                    if( ( altft > elevationft and altft < elevationft + thicknessft ) or
                        coverage == "clear" ) {

                        # enters layer
                        if( !me.inside ) {
                             me.inside = constant.TRUE;
                             me.insidemin = 0;
                        }

                        # ignores the coverage of cloud, and airframe speed
                        else {
                             me.insidemin = me.insidemin + 1;
                        }

                        if( me.insidemin >= me.durationmin[coverage] ) {
                             me.warning = constant.TRUE;
                        }

                        me.detection.getChild("duration-min").setValue(me.insidemin);
                        me.detection.getChild("coverage").setValue(coverage);

                        found = constant.TRUE;
                        break;
                    }
                }
           }
       }
   } 

   if( !found ) {
       me.inside = constant.FALSE;
       me.warning = constant.FALSE;
   }

   me.detection.getChild("icing").setValue(me.inside);

   me.antiicing.getChild("warning").setValue(me.warning);
}


# =====================
# MASTER WARNING SYSTEM
# =====================

Mws = {};

Mws.new = func {
   obj = { parents : [Mws],

           cginstrument : nil,

           airbleedsystem : nil,
           electricalsystem : nil,
           enginesystem : nil,
           flightsystem : nil,
           hydraulicsystem : nil,
           antiicingsystem : nil,
           pressuresystem : nil,
           tankpressuresystem : nil,

           nbambers : 0,
           amberwords : [ "air", "electrical", "fuel", "hydraulics" ],
           nbamber4s : 0,
           amber4words : [ "intake" ],

           nbreds : 0,
           redwords : [ "cg", "doors", "electrical", "feel", "ice", "pfc", "pressure" ],
           nbred4s : 0,
           red4words : [ "engine", "intake" ],

           ambers : nil,
           mwscontrol : nil,
           reds : nil
         };

   obj.init();

   return obj;
};

Mws.init = func {
   me.ambers = props.globals.getNode("/systems/mws/amber");
   me.mwscontrol = props.globals.getNode("/controls/mws");
   me.reds = props.globals.getNode("/systems/mws/red");

   me.nbambers = size( me.amberwords );
   me.nbamber4s = size( me.amber4words );

   me.nbreds = size( me.redwords );
   me.nbred4s = size( me.red4words );
}

Mws.set_relation = func( cg, airbleed, electrical, engine, flight, fuel, hydraulical, ice,
                         pressure, tankpressure ) {
   me.cginstrument = cg;

   me.airbleedsystem = airbleed;
   me.electricalsystem = electrical;
   me.enginesystem = engine;
   me.flightsystem = flight;
   me.fuelsystem = fuel;
   me.hydraulicsystem = hydraulical;
   me.antiicingsystem = ice;
   me.pressuresystem = pressure;
   me.tankpressuresystem = tankpressure;
}

Mws.cancelexport = func {
   me.cancel();
   me.recall();
}

Mws.recallexport = func {
   me.mwscontrol.getChild("inhibit").setValue(constant.FALSE);

   me.cancel();
   me.recall();
   me.instantiate();
}

Mws.schedule = func {
   # avoid false warning caused by FDM or system initialization
   if( constant.system_ready() ) {
       me.instantiate();
   }
   else {
       me.cancelexport();
   }
}

Mws.instantiate = func {
   # 4
   for( i = 0; i <= 3; i = i+1 ) {
        if( me.reds.getChild( me.recallpath( "engine" ), i ).getValue() ) {
            if( me.enginesystem.red_engine( i ) ) {
                me.setred( "engine", i );
            }
        }

        if( me.reds.getChild( me.recallpath( "intake" ), i ).getValue() ) {
            if( me.hydraulicsystem.red_intake( i ) ) {
                me.setred( "intake", i );
            }
        }

        # amber
        if( me.ambers.getChild( me.recallpath( "intake" ), i ).getValue() ) {
            if( me.enginesystem.amber_intake( i ) ) {
                me.setamber( "intake", i );
            }
        }
   }

   # red
   if( me.reds.getChild( me.recallpath( "cg" ) ).getValue() ) {
       if( me.cginstrument.red_cg() ) {
           me.setred( "cg" );
       }
   }

   if( me.reds.getChild( me.recallpath( "doors" ) ).getValue() ) {
       if( me.airbleedsystem.red_doors() or me.electricalsystem.red_doors() ) {
           me.setred( "doors" );
       }
   }

   if( me.reds.getChild( me.recallpath( "electrical" ) ).getValue() ) {
       if( me.electricalsystem.red_electrical() ) {
           me.setred( "electrical" );
       }
   }

   if( me.reds.getChild( me.recallpath( "feel" ) ).getValue() ) {
       if( me.hydraulicsystem.red_feel() ) {
           me.setred( "feel" );
       }
   }

   if( me.reds.getChild( me.recallpath( "ice" ) ).getValue() ) {
       if( me.antiicingsystem.red_ice() ) {
           me.setred( "ice" );
       }
   }

   if( me.reds.getChild( me.recallpath( "pfc" ) ).getValue() ) {
       if( me.flightsystem.red_pfc() ) {
           me.setred( "pfc" );
       }
   }

   if( me.reds.getChild( me.recallpath( "pressure" ) ).getValue() ) {
       if( me.pressuresystem.red_pressure() ) {
           me.setred( "pressure" );
       }
   }

   # amber
   if( me.ambers.getChild( me.recallpath( "air" ) ).getValue() ) {
       if( me.airbleedsystem.amber_air() ) {
           me.setamber( "air" );
       }
   }

   if( me.ambers.getChild( me.recallpath( "electrical" ) ).getValue() ) {
       if( me.electricalsystem.amber_electrical() ) {
           me.setamber( "electrical" );
       }
   }

   if( me.ambers.getChild( me.recallpath( "fuel" ) ).getValue() ) {
       if( me.fuelsystem.amber_fuel() or me.tankpressuresystem.amber_fuel() ) {
           me.setamber( "fuel" );
       }
   }

   if( me.ambers.getChild( me.recallpath( "hydraulics" ) ).getValue() ) {
       if( me.hydraulicsystem.amber_hydraulics() ) {
           me.setamber( "hydraulics" );
       }
   }
}

Mws.cancel = func {
   for( i = 0; i < me.nbred4s ; i = i+1 ) {
        for( j = 0; j < 4 ; j = j+1 ) {
             me.reds.getChild( me.red4words[i], j ).setValue( constant.FALSE );
        }
   }

   for( i = 0; i < me.nbamber4s ; i = i+1 ) {
        for( j = 0; j < 4 ; j = j+1 ) {
             me.ambers.getChild( me.amber4words[i], j ).setValue( constant.FALSE );
        }
   }

   for( i = 0; i < me.nbreds ; i = i+1 ) {
        me.reds.getChild( me.redwords[i] ).setValue( constant.FALSE );
   }

   for( i = 0; i < me.nbambers ; i = i+1 ) {
        me.ambers.getChild( me.amberwords[i] ).setValue( constant.FALSE );
   }
}

Mws.recall = func {
   for( i = 0; i < me.nbred4s ; i = i+1 ) {
        for( j = 0; j < 4 ; j = j+1 ) {
             me.reds.getChild( me.recallpath( me.red4words[i] ), j ).setValue( constant.TRUE );
        }
   }

   for( i = 0; i < me.nbamber4s ; i = i+1 ) {
        for( j = 0; j < 4 ; j = j+1 ) {
             me.ambers.getChild( me.recallpath( me.amber4words[i] ), j ).setValue( constant.TRUE );
        }
   }

   for( i = 0; i < me.nbreds ; i = i+1 ) {
        me.reds.getChild( me.recallpath( me.redwords[i] ) ).setValue( constant.TRUE );
   }

   for( i = 0; i < me.nbambers ; i = i+1 ) {
        me.ambers.getChild( me.recallpath( me.amberwords[i] ) ).setValue( constant.TRUE );
   }
}

Mws.setred = func( name, index = 0 ) {
   me.reds.getChild( name, index ).setValue( constant.TRUE );
   me.reds.getChild( me.recallpath( name ), index ).setValue( constant.FALSE );
}

Mws.setamber = func( name, index = 0 ) {
   me.ambers.getChild( name, index ).setValue( constant.TRUE );
   me.ambers.getChild( me.recallpath( name ), index ).setValue( constant.FALSE );
}

Mws.recallpath = func( name ) {
   result = name ~ "-recall";

   return result;
}
