# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains checklist tasks.


# ============
# VIRTUAL CREW
# ============

Virtualcrew = {};

Virtualcrew.new = func( path ) {
   var obj = { parents : [Virtualcrew,State.new(),CommonCheck.new(path)], 

               generic : Generic.new(),

               GROUNDSEC : 15.0,                               # to reach the ground
               CREWSEC : 10.0,                                 # to complete the task
               TASKSEC : 2.0,                                  # between 2 tasks
               DELAYSEC : 1.0,                                 # random delay

               task : constant.FALSE,
               taskend : constant.TRUE,
               taskground : constant.FALSE,
               taskcrew : constant.FALSE,
               taskallways : constant.FALSE,
  
               activ : constant.FALSE,
               running : constant.FALSE,
               
               altitudeft : 0.0,

               speedkt : 0.0,

               activity : ""
         };
    
    return obj;
}

Virtualcrew.toggleclick = func( message = "" ) {
    me.done( message );

    if( !me.is_state() ) {
        me.generic.toggleclick();
    }
}

Virtualcrew.done = func( message = "" ) {
    if( message != "" ) {
        me.log( message );
    }

    # first task to do.
    me.task = constant.TRUE;

    # still something to do, must wait.
    me.reset_end();
}

Virtualcrew.done_ground = func( message = "" ) {
    # procedure to execute with delay
    me.taskground = constant.TRUE;

    me.done( message );
}

Virtualcrew.done_crew = func( message = "" ) {
    # procedure to execute with delay
    me.taskcrew = constant.TRUE;

    me.done( message );
}

Virtualcrew.done_allways = func {
    # cannot complete, but must perform allways tasks
    me.taskallways = constant.TRUE;
}

Virtualcrew.log = func( message ) {
    if( !me.is_state() ) {
        me.activity = me.activity ~ " " ~ message;
    }
}

Virtualcrew.getlog = func {
    return me.activity;
}

Virtualcrew.reset = func {
    me.activity = "";
    me.activ = constant.FALSE;
    me.running = constant.FALSE;

    me.task = constant.FALSE;
    me.taskend = constant.TRUE;
}

Virtualcrew.set_activ = func {
    me.activ = constant.TRUE;
}

Virtualcrew.is_activ = func {
    return me.activ;
}

Virtualcrew.set_running = func {
    me.running = constant.TRUE;
}

Virtualcrew.is_running = func {
    return me.running;
}

Virtualcrew.wait_ground = func {
    return me.taskground;
}

Virtualcrew.reset_ground = func {
    me.taskground = constant.FALSE;
}

Virtualcrew.wait_crew = func {
    return me.taskcrew;
}

Virtualcrew.reset_crew = func {
    me.taskcrew = constant.FALSE;
}

Virtualcrew.reset_end = func {
    me.taskend = constant.FALSE;
}

Virtualcrew.can = func {
    var result = constant.FALSE;
    
    # when restoring a state, tasks are immediate
    if( !me.task or me.is_state() ) {
        result = constant.TRUE;
    }
    
    return result;
}

Virtualcrew.randoms = func( steps ) {
    # doesn't overwrite, if no task to do
    if( !me.taskend ) {
        var margins  = rand() * me.DELAYSEC;

        if( me.taskground ) {
            steps = me.GROUNDSEC;
        }

        elsif( me.taskcrew ) {
            steps = me.CREWSEC;
        }

        else {
            steps = me.TASKSEC;
        }

        steps = steps + margins;
    }

    return steps;
} 

Virtualcrew.timestamp = func {
    var action = me.itself["root"].getChild("state").getValue();

    # save last real action
    if( action != "" ) {
        me.itself["root"].getChild("state-last").setValue(action);
    }

    me.itself["root"].getChild("state").setValue(me.getlog());
    me.itself["root"].getChild("time").setValue(me.noinstrument["time"].getValue());
}

# other crew member tells, that he has completed
Virtualcrew.completed = func {
    if( me.can() ) {
        me.set_completed();
    }
}

Virtualcrew.has_completed = func {
    var result = constant.FALSE;

    # except if still something to do, or allways tasks
    if( me.can() and !me.taskallways ) {
        result = me.is_completed();
    }

    me.taskallways = constant.FALSE;
 
    return result;
}


# =============
# COMMON CHECKS
# =============

CommonCheck = {};

CommonCheck.new = func( path ) {
    var obj = { parents : [CommonCheck,Emergency.new(path)] 
              };

    return obj;
}

# ----------
# NAVIGATION
# ----------
CommonCheck.ins = func( index, mode ) {
    if( me.can() ) {
        if( me.dependency["ins"][index].getNode("msu").getChild("mode").getValue() != mode ) {
            me.dependency["ins"][index].getNode("msu").getChild("mode").setValue(mode);
            me.toggleclick("ins-" ~ index);
        }
    }
}


# ===================
# ASYNCHRONOUS CHECKS
# ===================

AsynchronousCheck = {};

AsynchronousCheck.new = func {
   var obj = { parents : [AsynchronousCheck,System.new("/systems/human")],

               completedasync : constant.TRUE
             };

   return obj;
}

AsynchronousCheck.is_change = func {
   var change = constant.FALSE;

   return change;
}

AsynchronousCheck.is_allowed = func {
   var change = constant.TRUE;

   return change;
}

# once night lighting, virtual crew must switch again lights.
AsynchronousCheck.set_task = func {
   me.completedasync = constant.FALSE;
}

AsynchronousCheck.has_task = func {
   var result = constant.FALSE;

   if( me.is_allowed() and ( me.is_change() or !me.completedasync ) ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

AsynchronousCheck.set_completed = func {
   me.completedasync = constant.TRUE;
}


# ==============
# NIGHT LIGHTING
# ==============

Nightlighting = {};

Nightlighting.new = func {
   var obj = { parents : [Nightlighting,AsynchronousCheck.new()],

               lightingsystem : nil,

               COMPASSDIM : 0.5,
               DAYNORM : 0.0,
   
               lightlevel : 0.0,
               lightcompass : 0.0,
               lightlow : constant.FALSE,

               night : constant.FALSE
         };

  return obj;
}

Nightlighting.set_relation = func( lighting ) {
    me.lightingsystem = lighting;
}

Nightlighting.copilot_task = func( task ) {
   # optional
   if( me.dependency["crew"].getChild("night-lighting").getValue() ) {

       # only once, can be customized by user
       if( me.has_task() ) {
           me.light( "copilot" );

           me.set_task();

           # flood lights
           if( task.can() ) {
               if( me.dependency["lighting-copilot"].getChild("flood-norm").getValue() != me.lightlevel ) {
                   me.dependency["lighting-copilot"].getChild("flood-norm").setValue( me.lightlevel );
                   me.lightingsystem.floodexport();
                   task.toggleclick("flood-light");
               }
           }

           # level of warning lights
           if( task.can() ) {
               if( me.dependency["lighting-copilot"].getChild("low").getValue() != me.lightlow ) {
                   me.dependency["lighting-copilot"].getChild("low").setValue( me.lightlow );
                   task.toggleclick("panel-light");
               }
           }
           if( task.can() ) {
               if( me.dependency["lighting"].getNode("center").getChild("low").getValue() != me.lightlow ) {
                   me.dependency["lighting"].getNode("center").getChild("low").setValue( me.lightlow );
                   task.toggleclick("center-light");
               }
           }
           if( task.can() ) {
               if( me.dependency["lighting"].getNode("afcs").getChild("low").getValue() != me.lightlow ) {
                   me.dependency["lighting"].getNode("afcs").getChild("low").setValue( me.lightlow );
                   task.toggleclick("afcs-light");
               }
           }

           if( task.can() ) {
               me.set_completed();
           }
       }
   }
}

Nightlighting.captain_task = func( task ) {
   # optional
   if( me.dependency["crew"].getChild("night-lighting").getValue() ) {

       # only once, can be customized by user
       if( me.has_task() ) {
           me.light( "captain" );

           me.set_task();

           # flood lights
           if( task.can() ) {
               if( me.dependency["lighting-captain"].getChild("flood-norm").getValue() != me.lightlevel ) {
                   me.dependency["lighting-captain"].getChild("flood-norm").setValue( me.lightlevel );
                   me.lightingsystem.floodexport();
                   task.toggleclick("flood-light");
               }
           }

           # level of warning lights
           if( task.can() ) {
               if( me.dependency["lighting-captain"].getChild("low").getValue() != me.lightlow ) {
                   me.dependency["lighting-captain"].getChild("low").setValue( me.lightlow );
                   task.toggleclick("panel-light");
               }
           }

           # compass light
           if( task.can() ) {
               if( me.dependency["lighting"].getNode("overhead").getChild("compass-norm").getValue() != me.lightcompass ) {
                   me.dependency["lighting"].getNode("overhead").getChild("compass-norm").setValue( me.lightcompass );
                   me.lightingsystem.compassexport( me.lightcompass );
                   task.toggleclick("compass-light");
               }
           }

           if( task.can() ) {
               me.set_completed();
           }
       }
   }
}

Nightlighting.engineer_task = func( task ) {
   # optional
   if( me.dependency["crew"].getChild("night-lighting").getValue() ) {

       # only once, can be customized by user
       if( me.has_task() ) {
           me.light( "engineer" );

           me.set_task();

           # flood lights
           if( task.can() ) {
               if( me.dependency["lighting-engineer"].getChild("flood-norm").getValue() != me.lightlevel ) {
                   me.dependency["lighting-engineer"].getChild("flood-norm").setValue( me.lightlevel );
                   me.lightingsystem.floodexport();
                   task.toggleclick("flood-light");
               }
           }

           if( task.can() ) {
               me.light( "center" );
               if( me.dependency["lighting-center"].getChild("flood-norm").getValue() != me.lightlevel ) {
                   me.dependency["lighting-center"].getChild("flood-norm").setValue( me.lightlevel );
                   me.lightingsystem.floodexport();
                   task.toggleclick("center-light");
               }
           }

           # level of warning lights
           if( task.can() ) {
               if( me.dependency["lighting-engineer"].getNode("forward").getChild("low").getValue() != me.lightlow ) {
                   me.dependency["lighting-engineer"].getNode("forward").getChild("low").setValue( me.lightlow );
                   task.toggleclick("forward-light");
               }
           }
           if( task.can() ) {
               if( me.dependency["lighting-engineer"].getNode("center").getChild("low").getValue() != me.lightlow ) {
                   me.dependency["lighting-engineer"].getNode("center").getChild("low").setValue( me.lightlow );
                   task.toggleclick("center-light");
               }
           }
           if( task.can() ) {
               if( me.dependency["lighting-engineer"].getNode("aft").getChild("low").getValue() != me.lightlow ) {
                   me.dependency["lighting-engineer"].getNode("aft").getChild("low").setValue( me.lightlow );
                   task.toggleclick("aft-light");
               }
           }

           if( task.can() ) {
               me.set_completed();
           }
       }
   }
}

Nightlighting.light = func( path ) {
   if( me.night ) {
       me.lightlevel = me.itself["lighting"].getChild(path).getValue();
       me.lightlow = constant.TRUE;
       me.lightcompass = me.COMPASSDIM;
   }
   else {
       me.lightlevel = me.DAYNORM;
       me.lightlow = constant.FALSE;
       me.lightcompass = me.DAYNORM;
   }
}

Nightlighting.is_change = func {
   var change = constant.FALSE;
   var altitudeft = me.noinstrument["altitude"].getValue();
   var sunrad = me.noinstrument["sun"].getValue();
   
   if( constant.is_lighting( sunrad, altitudeft ) ) {
       if( !me.night ) {
           me.night = constant.TRUE;
           change = constant.TRUE;
       }
   }
   else {
       if( me.night ) {
           me.night = constant.FALSE;
           change = constant.TRUE;
       }
   }
   
   return change;
}


# ================
# RADIO MANAGEMENT
# ================

RadioManagement = {};

RadioManagement.new = func {
   var obj = { parents : [RadioManagement,AsynchronousCheck.new()],

               autopilotsystem : nil,

               DESCENTFPM : -100,

               activity : "",
               target : "",
               tower : "",

               NOENTRY : -1,
               entry : -1
         };

   return obj;
};

RadioManagement.set_relation = func( autopilot ) {
   me.autopilotsystem = autopilot;
}

RadioManagement.radioexport = func( arrival ) {
   var byuser = constant.FALSE;
   var airport = me.itself["root-ctrl"].getChild("airport-id").getValue();

   if( airport != "" ) {
       byuser = constant.TRUE;
   }

   if( me.nearest_airport( constant.FALSE, byuser ) ) {
       var phase = me.select_phase( arrival );

       phase = me.get_phase( phase );

       me.set_vor( 0, nil, phase );
       me.set_vor( 1, nil, phase );
       me.set_adf( 0, nil, phase );
       me.set_adf( 1, nil, phase );
   }

   else {
       me.itself["root"].getChild("airport-phase").setValue( "not found" );
   }
}

RadioManagement.copilot_task = func( task ) {
   # optional
   if( me.dependency["radio"].getChild("set").getValue() ) {
       if( me.has_task() ) {
           me.set_task();

           # VOR 1
           if( task.can() ) {
               me.set_vor( 1, task, nil );
           }

           if( task.can() ) {
               me.set_completed();
           }
       }
   }
}

RadioManagement.captain_task = func( task ) {
   # optional
   if( me.dependency["radio"].getChild("set").getValue() ) {
       if( me.has_task() ) {
           me.set_task();

           # VOR 0
           if( task.can() ) {
               me.set_vor( 0, task, nil );
           }

           if( task.can() ) {
               me.set_completed();
           }
       }
   }
}

RadioManagement.engineer_task = func( task ) {
   # optional
   if( me.dependency["radio"].getChild("set").getValue() ) {
       if( me.has_task() ) {
           me.set_task();

           # ADF 1
           if( task.can() ) {
               me.set_adf( 0, task, nil );
           }

           # ADF 2
           if( task.can() ) {
               me.set_adf( 1, task, nil );
           }

           if( task.can() ) {
               me.set_completed();
           }
       }
   }
}

RadioManagement.set_vor = func( index, task, phase ) {
    phase = me.get_phase( phase );

    if( phase != nil ) {
        var vor = phase.getChildren("vor");

        # NAV 0 is reserved
        var radio = index + 1;

        if( index < size( vor ) ) {
            var change = constant.FALSE;
            var currentmhz = 0.0;
            var frequencymhz = 0.0;
            var frequency = nil;

            # not real : no NAV standby frequency
            frequency = vor[ index ].getChild("standby-mhz");
            if( frequency != nil ) {
                frequencymhz = frequency.getValue();
                currentmhz = me.dependency["vor"][radio].getNode("frequencies/standby-mhz").getValue();

                if( currentmhz != frequencymhz ) {
                    me.dependency["vor"][radio].getNode("frequencies/standby-mhz").setValue(frequencymhz);
                    change = constant.TRUE;
                }
            }

            frequency = vor[ index ].getChild("selected-mhz");
            if( frequency != nil ) {
                frequencymhz = frequency.getValue();
                currentmhz = me.dependency["vor"][radio].getNode("frequencies/selected-mhz").getValue();

                if( currentmhz != frequencymhz ) {
                    me.dependency["vor"][radio].getNode("frequencies/selected-mhz").setValue(frequencymhz);
                    change = constant.TRUE;
                    if( task != nil ) {
                        task.toggleclick("vor " ~ index);
                    }
                }
            }
            
            if( change ) {
                me.autopilotsystem.apsendnavexport();
                
                # feedback of AI activity
                if( index == 0 ) {
                    me.itself["root"].getChild("radio-vor").setValue( me.target );
                    me.feedback();
                }
            }
        }
    }
}

RadioManagement.set_adf = func( index, task, phase ) {
    phase = me.get_phase( phase );

    if( phase != nil ) {
        var adf = phase.getChildren("adf");

        if( index < size( adf ) ) {
            var change = constant.FALSE;
            var frequency = nil;
            var frequencykhz = 0;
            var currentkhz = 0;

            # not real : no ADF standby frequency
            frequency = adf[ index ].getChild("standby-khz");
            if( frequency != nil ) {
                frequencykhz = frequency.getValue();
                currentkhz = me.dependency["adf"][index].getNode("frequencies/standby-khz").getValue();

                if( currentkhz != frequencykhz ) {
                    me.dependency["adf"][index].getNode("frequencies/standby-khz").setValue(frequencykhz);
                    change = constant.TRUE;
                }
            }

            frequency = adf[ index ].getChild("selected-khz");
            if( frequency != nil ) {
                frequencykhz = frequency.getValue();
                currentkhz = me.dependency["adf"][index].getNode("frequencies/selected-khz").getValue();

                if( currentkhz != frequencykhz ) {
                    me.dependency["adf"][index].getNode("frequencies/selected-khz").setValue(frequencykhz);
                    change = constant.TRUE;
                    if( task != nil ) {
                        task.toggleclick("adf " ~ index);
                    }
                }
            }

            if( change ) {
                # feedback of AI activity
                if( index == 0 ) {
                    me.itself["root"].getChild("radio-adf").setValue( me.target );
                    me.feedback();
                }
            }
        }
    }
}

RadioManagement.feedback = func {
   var radiophase = "";
   var radioid = "";
   
   var targetADF = me.itself["root"].getChild("radio-adf").getValue();
   var targetVOR = me.itself["root"].getChild("radio-vor").getValue();

   
   if( targetVOR != "" and targetADF != "" ) {
       radiophase = "vor (adf)";
       if( targetVOR == targetADF ) {
           radioid = targetVOR;
       }
       else {
           radioid = targetVOR ~ " (" ~ targetADF ~ ")";
       }
   }

   elsif( targetVOR != "" ) {
       radiophase = "vor";
       radioid = targetVOR;
   }

   elsif( targetADF != "" ) {
       radiophase = "adf";
       radioid = targetADF;
   }
   
   me.itself["root"].getChild("radio-id").setValue( radioid );
   me.itself["root"].getChild("radio-phase").setValue( radiophase );
}

RadioManagement.select_phase = func( arrival ) {
   var opposite = "";
   var phase = nil;

   if( arrival ) {
       me.activity = "arrival";
       opposite = "departure";
   }

   else {
       me.activity = "departure";
       opposite = "arrival";
   }

   phase = me.itself["airport"][ me.entry ].getNode(me.activity);

   # try the opposite, if nothing
   if( phase == nil ) {
       phase = me.itself["airport"][ me.entry ].getNode(opposite);
       me.activity = me.activity ~ " (" ~ opposite ~ ")";
   }

   if( phase == nil ) {
       me.activity = "no data";
   }

   return phase;
}

RadioManagement.get_phase = func( phase ) {
   var arrival = constant.FALSE;
   var default = "";

   if( phase == nil and me.entry > me.NOENTRY ) {
       if( me.noinstrument["speed"].getValue() < me.DESCENTFPM * constant.MINUTETOSECOND ) {
           arrival = constant.TRUE;
       }

       phase = me.select_phase( arrival );
   }

   me.itself["root"].getChild("airport-phase").setValue( me.activity );

   return phase;
}

RadioManagement.is_change = func {
   var result = me.nearest_airport( constant.TRUE, constant.FALSE );

   return result;
}

RadioManagement.nearest_airport = func( bycrew, byuser ) {
   var result = constant.FALSE;
   var ignoreid = me.dependency["radio"].getChild("ignore").getValue();
   var curairport = me.noinstrument["presets"].getChild("airport-id").getValue();;
   var userairport = me.itself["root-ctrl"].getChild("airport-id").getValue();

   # keep frequencies in defaults.xml, except when input by user
   if( curairport == ignoreid and !byuser and userairport == "" ) {
       me.itself["root"].getChild("airport-id").setValue( ignoreid );
       me.itself["root"].getChild("airport-phase").setValue( "keep defaults.xml" );
   }
   else {
       result = me.get_nearest_airport( bycrew, byuser, userairport );
   }

   return result;
}

RadioManagement.get_nearest_airport = func( bycrew, byuser, userairport ) {
   var found = constant.FALSE;
   var has_navaid = constant.FALSE;
   var result = constant.FALSE;
   var index = me.NOENTRY;
   var distancenm = 0.0;
   var nearestnm = me.NOENTRY;
   var airport = "";
   var nearestid = "";
   var child = "";
   var info = nil;
   var flight = geo.aircraft_position();
   var destination = geo.Coord.new();
   

   # nearest airport
   nearestid = "";
   for(var i=0; i<size(me.itself["airport"]); i=i+1) {
       child = me.itself["airport"][ i ].getChild("airport-id");
       # <airport/>
       if ( child != nil ) {
            airport = child.getValue();

            # user is overriding virtual crew
            if( byuser ) {
                if( airport == userairport ) {
                    nearestid = airport;
                    nearestnm = 0;
                    index = i;
                    break;
                }
            }
            
            # search by virtual crew
            else {
                has_navaid = constant.TRUE;
        
                child = me.itself["airport"][ i ].getChild("arrival");
                if( child == nil ) {
                    child = me.itself["airport"][ i ].getChild("departure");
                    if( child == nil ) {
                        has_navaid = constant.FALSE;
                    }
                }
                
                # only with navaids
                if( has_navaid ) {
                    info = airportinfo( airport );

                    if( info != nil ) {
                        destination.set_latlon( info.lat, info.lon );
                        distancenm = flight.distance_to( destination ) / constant.NMTOMETER; 
                        
                        if( distancenm < constantaero.RADIONM ) {
                            # first one
                            if( nearestnm < 0 ) {
                                found = constant.TRUE;
                            }
                            elsif( distancenm < nearestnm ) {
                                found = constant.TRUE;
                            }
                            else {
                                found = constant.FALSE;
                            }
                            
                            if( found ) {
                                nearestid = airport;
                                nearestnm = distancenm;
                                index = i;
                            }
                        }
                    }
                }
            }
       }
   }


   # only within radio range, or user is overriding
   if( index != me.NOENTRY ) {
       # detect change, or user is overriding
       if( me.tower != nearestid or !bycrew or byuser ) {
           me.entry = index;

           me.target = nearestid;
           me.itself["root"].getChild("airport-id").setValue( me.target );

           result = constant.TRUE;
       }
   }


   return result;
}

RadioManagement.getAirport = func( index, path ) {
   var result = constant.FALSE;
   var child = nil;

   child = me.itself["airport"][ index ].getChild(path);
   if( child != nil ) {
       result = child.getValue();
   }

   return result;
}

RadioManagement.is_allowed = func {
   var result = constant.TRUE;

   var speedkt = me.noinstrument["airspeed"].getValue();

   if( speedkt > constantaero.TAXIKT ) {
       var aglft = me.noinstrument["agl"].getValue();
       var altft = me.noinstrument["altitude"].getValue();

       # do not change frequencies just after landing 
       if( aglft < constantaero.GEARFT ) {
           result = constant.FALSE;
       }

       # do not change frequencies during approach (RJTT is managed by crew, while RJAA is not)
       elsif( altft < constantaero.APPROACHFT ) {
           result = constant.FALSE;
       }
   }

   return result;
}

RadioManagement.set_completed = func {
   me.tower = me.target;

   me.completed = constant.TRUE;
}


# =================
# ASYNCHRONOUS CREW
# =================

AsynchronousCrew = {};

AsynchronousCrew.new = func( path ) {
    var obj = { parents : [AsynchronousCrew,System.new(path)], 
    
                nightlighting : Nightlighting.new(),
                radiomanagement : RadioManagement.new()
              };

    return obj;
}

AsynchronousCrew.set_relation = func( autopilot, lighting ) {
    me.nightlighting.set_relation( lighting );
    me.radiomanagement.set_relation( autopilot );
}

AsynchronousCrew.radioexport = func( arrival ) {
    me.radiomanagement.radioexport( arrival );
}

AsynchronousCrew.set_task = func {
    me.nightlighting.set_task();
    me.radiomanagement.set_task();
}

AsynchronousCrew.do_task = func( member, crewmember ) {
    if( member == "copilot" ) {
        me.nightlighting.copilot_task( crewmember );
        me.radiomanagement.copilot_task( crewmember );
    }
    
    elsif( member == "engineer" ) {
        me.nightlighting.engineer_task( crewmember );
        me.radiomanagement.engineer_task( crewmember );
    }
    
    elsif( member == "captain" ) {
        if( me.is_busy() ) {
            me.nightlighting.captain_task( crewmember );
            me.radiomanagement.captain_task( crewmember );
        }
    }
}

AsynchronousCrew.is_busy = func {
    var result = constant.FALSE;

    if( me.dependency["crew-ctrl"].getChild("captain-busy").getValue() ) {
        result = constant.TRUE;
    }

    return result;
}


# ====
# CREW
# ====

Crew = {};

Crew.new = func {
   var obj = { parents : [Crew,System.new("/systems/crew")],

               airbleedsystem : nil,
               autopilotsystem : nil,
               autothrottlesystem : nil,
               electricalsystem : nil,
               fuelsystem : nil,
               
               crewscreen : nil,
               
               copilotcrew : nil,
               engineercrew : nil,
               voicecrew : nil,
               
               copilothuman : nil,
               engineerhuman : nil,
                
               STATESEC : 2.0
   };

   obj.init();

   return obj;
}

Crew.init = func {
   me.presetcrew();
}

Crew.presetcrew = func {
   var dialog = me.get_preset();

   # copy to dialog
   me.itself["root"].getChild("dialog").setValue(dialog);
}

Crew.set_relation = func( airbleed, autopilot, autothrottle, electrical, fuel,
                          crew, copilot, engineer, voice, copilot2, engineer2 ) {
   me.airbleedsystem = airbleed;
   me.autopilotsystem = autopilot;
   me.autothrottlesystem = autothrottle;
   me.electricalsystem = electrical;
   me.fuelsystem = fuel;
    
   me.crewscreen = crew;
    
   me.copilotcrew = copilot;
   me.engineercrew = engineer;    
   me.voicecrew = voice;
    
   me.copilothuman = copilot2;
   me.engineerhuman = engineer2;
}

# disable at startup
Crew.startupexport = func {
   if( !me.statecron() ) {
       me.startup();
   }
   
   # disable voice at startup
   me.voicecrew.startupexport();
   
   # disable crew at startup
   if( me.itself["root-ctrl"].getChild("disable").getValue() ) {
       me.set_service(constant.FALSE);
       
       me.copilotcrew.serviceexport();
       me.engineercrew.serviceexport();
   }
}

# enable crew
Crew.enableexport = func {
   var disable = me.itself["root-ctrl"].getChild("disable").getValue();
   var serviceable = !disable;
  
   me.set_service(serviceable);
   
   me.voicecrew.serviceexport();
   
   me.copilotcrew.serviceexport();
   me.engineercrew.serviceexport();
   
   if( !serviceable ) {
       # clear crew status
       me.crewscreen.toggleexport();
   }
}

Crew.presetexport = func {
   var label = me.itself["root"].getChild("dialog").getValue();

   for( var i=0; i < size(me.itself["crew-presets"]); i=i+1 ) {
        if( me.itself["crew-presets"][i].getValue() == label ) {

            # for aicraft-data
            me.itself["root-ctrl"].getChild("presets").setValue(i);

            break;
        }
   }
}

Crew.toggleexport = func {
   me.copilotcrew.toggleexport();
   me.copilothuman.wakeupexport();
   me.engineercrew.toggleexport();
   me.engineerhuman.wakeupexport();
    
   me.voicecrew.toggleexport();
   
   me.crewscreen.toggleexport();
}

Crew.wakeupexport = func {
   me.copilothuman.wakeupexport();
   me.engineerhuman.wakeupexport();
}

Crew.set_service = func( serviceable ) {
   me.itself["root"].getChild("serviceable").setValue(serviceable);
   me.itself["menu"].getChild("enabled").setValue(serviceable);
}

Crew.startup = func {
   var disable = me.itself["root-ctrl"].getChild("disable").getValue();
   
   # automatic startup
   if( !disable and me.itself["root-ctrl"].getChild("startup").getValue() ) {
       me.crewscreen.toggleexport();
       
       me.toggleexport();
       
       var dialog = me.get_preset();
       print("virtual crew activ from " ~ dialog);
   }
}

Crew.get_preset = func {
   var value = me.itself["root-ctrl"].getChild("presets").getValue();
   var dialog = me.itself["crew-presets"][value].getValue();
   
   return dialog;
}

Crew.statecron = func {
   var found = constant.TRUE;
   var result = constant.FALSE;
   var state = "";
   
   if( me.noinstrument["state"] != nil ) {
       state = me.noinstrument["state"].getValue();
   }
   
   if( state == "takeoff" ) {
       if( me.electricalsystem.is_ready() ) {
           me.send_fuel( 1 );
           me.send_state( state );
           
           result = constant.TRUE;
       }
   }
   
   elsif( state == "climb" ) {
       if( me.electricalsystem.is_ready() ) {
           me.autopilotsystem.aptogglealtitudeexport();
           me.autopilotsystem.aptoggleheadingexport();
       
           me.autothrottlesystem.attogglespeedexport();
           me.autothrottlesystem.atmachexport();
           
           me.send_fuel( 4 );
           me.send_state( state );
           
           result = constant.TRUE;
       }
   }
   
   elsif( state == "cruise" ) {
       if( me.electricalsystem.is_ready() ) {
           me.autopilotsystem.aptogglealtitudeexport();
           me.autopilotsystem.aptoggleheadingexport();
       
           me.autothrottlesystem.attogglespeedexport();
           me.autothrottlesystem.atmachexport();
           
           me.send_fuel( 5 );           
           me.send_state( state );
           
           result = constant.TRUE;
       }
   }
   
   elsif( state == "descent" ) {
       if( me.electricalsystem.is_ready() ) {
           me.autopilotsystem.aptogglealtitudeexport();
           me.autopilotsystem.aptoggleheadingexport();
       
           me.autothrottlesystem.attogglespeedexport();
           me.autothrottlesystem.atmachexport();
           
           me.send_fuel( 6 );           
           me.send_state( state );
           
           result = constant.TRUE;
       }
   }
   
   elsif( state == "approach" ) {
       if( me.electricalsystem.is_ready() ) {
           me.autopilotsystem.aptogglealtitudeexport();
           me.autopilotsystem.aptoggleheadingexport();
       
           me.autothrottlesystem.attogglespeedexport();
           
           me.send_fuel( 0 );           
           me.send_state( state );
           
           result = constant.TRUE;
       }
   }
   
   elsif( state == "landing" ) {
       if( me.electricalsystem.is_ready() ) {
           me.autopilotsystem.aptogglealtitudeexport();
           me.autopilotsystem.aptoggleheadingexport();
       
           me.autothrottlesystem.attogglespeedexport();
           
           me.send_fuel( 0 );           
           me.send_state( state );
           
           result = constant.TRUE;
       }
   }
   
   elsif( state == "parking" ) {
       me.electricalsystem.groundserviceexport();
       me.airbleedsystem.groundserviceexport();
       me.airbleedsystem.reargroundserviceexport();
           
       me.send_fuel( 7 );           
       me.send_state( state );
           
       result = constant.TRUE;
   }
   
   elsif( state == "stopover" ) {
       me.electricalsystem.groundserviceexport();
       me.airbleedsystem.groundserviceexport();
       me.airbleedsystem.reargroundserviceexport();
           
       me.send_fuel( 3 );           
       me.send_state( state );
           
       result = constant.TRUE;
   }
   
   elsif( state == "taxi" ) {
       if( me.electricalsystem.is_ready() ) {
           me.send_fuel( 1 );           
           me.send_state( state );
           
           result = constant.TRUE;
       }
   }
   
   else {
       found = constant.FALSE;       
       result = constant.TRUE;
   }
   
   if( !result ) {
       # waits for systems initialization
       settimer(func { me.statecron(); },me.STATESEC);
   }
   
   return found;
}

Crew.send_state = func( targetstate ) {
   var message = "";
   
   # disable voice feedback
   me.voicecrew.set_state( constant.TRUE );
   
   me.copilotcrew.stateexport( targetstate );
   me.engineercrew.stateexport( targetstate );
   
   # enable voice feedback
   me.voicecrew.set_state( constant.FALSE );
   
   message = "concorde state set at " ~ targetstate;
   print(message);
}

Crew.send_fuel = func( preset ) {
   var comment = me.dependency["filling"][preset].getChild("comment").getValue();
       
   me.dependency["fuel"].setValue(comment);
   me.fuelsystem.menuexport();
}
