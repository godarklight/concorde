# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# current nasal version doesn't accept :
# - array of class objects (array of integer works).



# =================
# ELECTRICAL SYSTEM
# =================

Electrical = {};

Electrical.new = func {
   obj = { parents : [Electrical],
           parser : ElectricalXML.new(),
           csd : ConstantSpeedDrive.new(),
           ELECSEC : 1.0                                  # refresh rate
         };

   obj.csd.set_rate( obj.ELECSEC );

   return obj;
};

Electrical.set_rate = func( rates ) {
   me.ELECSEC = rates;
   me.csd.set_rate( me.ELECSEC );
}

Electrical.schedule = func {
    me.csd.schedule();
    me.parser.schedule();
}

Electrical.slowschedule = func {
    me.groundservice();
    me.parser.slowschedule();
}

# connection with delay by ground operator
Electrical.groundservice = func {
    aglft = noinstrument.get_agl_ft();
    speedkt = noinstrument.get_speed_kt();

    if( aglft <  15 and speedkt < 15 ) {
        powervolt = 600.0;
    }
    else {
        powervolt = 0.0;
    }

   setprop("/systems/electrical/suppliers/ground-service",powervolt);
}

Electrical.has_specific() = func {
    volts =  getprop("/systems/electrical/outputs/specific");
    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > 20 ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Electrical.has_autopilot1() = func {
    volts =  getprop("/systems/electrical/outputs/autopilot1");
    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > 0 ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Electrical.has_autopilot2() = func {
    volts =  getprop("/systems/electrical/outputs/autopilot2");
    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > 0 ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Electrical.has_ground_power() = func {
    volts =  getprop("/systems/electrical/outputs/probe/ac-gpb");
    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > 110 ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}


# ===================
# CSD OIL TEMPERATURE
# ===================

ConstantSpeedDrive = {};

ConstantSpeedDrive.new = func {
   obj = { parents : [ConstantSpeedDrive],

           ELECSEC : 1.0,                                 # refresh rate

           engcontrols : nil,
           engines : nil
         };

   obj.init();

   return obj;
};

ConstantSpeedDrive.init = func {
   me.engines = props.globals.getNode("/engines").getChildren("engine");
   me.engcontrols = props.globals.getNode("/controls/engines").getChildren("engine");
}

ConstantSpeedDrive.set_rate = func( rates ) {
   me.ELECSEC = rates;
}

# oil temperature
ConstantSpeedDrive.schedule = func {
   for( i=0; i<4; i=i+1 ) {
       csd = me.engcontrols[i].getChild("csd").getValue();
       if( csd ) {
           csdpressurepsi = me.engines[i].getChild("oil-pressure-psi").getValue();
       }
       else {
           csdpressurepsi = 0.0;
       }

       # not real
       result = me.engines[i].getChild("csd-oil-psi").getValue();
       if( result != csdpressurepsi ) {
           interpolate("/engines/engine[" ~ i ~ "]/csd-oil-psi",csdpressurepsi,me.ELECSEC);
       }

       oatdegc = noinstrument.get_degc();

       # connected
       if( csd ) {
           egtdegf = me.engines[i].getChild("egt_degf").getValue();
           egtdegc = constant.fahrenheit_to_celsius( egtdegf );
       }

       # not real
       result = me.engines[i].getChild("csd-inlet-degc").getValue();
       if( csd ) {
           inletdegc = egtdegc / 3.3;
       }
       # scale until 0 deg C
       else {
           inletdegc = result * 0.95;
       }
       if( inletdegc < oatdegc ) {
           inletdegc = oatdegc;
       }
       if( result != inletdegc ) {
           interpolate("/engines/engine[" ~ i ~ "]/csd-inlet-degc",inletdegc,me.ELECSEC);
       }

       # not real
       result = me.engines[i].getChild("csd-diff-degc").getValue();
       if( csd ) {
           diffdegc = egtdegc / 17.0;
       }
       # scale until 0 deg C
       else {
           diffdegc = result * 0.95;
       }
       if( result != diffdegc ) {
           interpolate("/engines/engine[" ~ i ~ "]/csd-diff-degc",diffdegc,me.ELECSEC);
       }
   }
}


# =================
# ELECTRICAL PARSER
# =================
# current nasal version cannot store array of class objects (supplier, bus, output, connector).

ElectricalXML = {};

ElectricalXML.new = func {
   obj = { parents : [ElectricalXML],
           config : nil,
           passes : 0.0,
           iterations : nil,
           suppliers : nil,
           nb_suppliers : 0.0,
           supplier_names : LookupName.new(),
           buses : nil,
           nb_buses : 0.0,
           bus_names : LookupName.new(),
           outputs : nil,
           nb_outputs : 0.0,
           output_names : LookupName.new(),
           connectors : nil,
           nb_connectors : 0.0
         };

   obj.init();

   return obj;
};

# creates all propagate variables
ElectricalXML.init = func {
   me.config = props.globals.getNode("/systems/electrical/internal/config");
   me.forced = props.globals.getNode("/systems/electrical/internal/iterations-forced").getValue();
   me.iterations = props.globals.getNode("/systems/electrical/internal/iterations");

   component = ElectricalComponent.new();

   me.suppliers = me.config.getChildren("supplier");
   me.nb_suppliers = size( me.suppliers );
   for( i = 0; i < me.nb_suppliers; i = i+1 ) {
        # lookup table accelerates the search of connectors
        name = me.suppliers[i].getChild("name").getValue();
        me.supplier_names.add( name );

        component.set_supplier( me.suppliers[i] );
        component.charge();
   }

   me.buses = me.config.getChildren("bus");
   me.nb_buses = size( me.buses );
   for( i = 0; i < me.nb_buses; i = i+1 ) {
        # lookup table accelerates the search of connectors
        name = me.buses[i].getChild("name").getValue();
        me.bus_names.add( name );

        component.set_bus( me.buses[i] );
        component.charge();
   }

   me.outputs = me.config.getChildren("output");
   me.nb_outputs = size( me.outputs );
   for( i = 0; i < me.nb_outputs; i = i+1 ) {
        # lookup table accelerates the search of connectors
        name = me.outputs[i].getChild("name").getValue();
        me.output_names.add( name );

        component.set_output( me.outputs[i] );
        component.charge();
   }

   me.connectors = me.config.getChildren("connector");
   me.nb_connectors = size( me.connectors );
}

# battery discharge
ElectricalXML.slowschedule = func {
   component = ElectricalComponent.new();
   for( i = 0; i < me.nb_suppliers; i = i+1 ) {
        component.set_supplier( me.suppliers[i] );
        component.discharge();
   }
}

ElectricalXML.schedule = func {
   component = ElectricalComponent.new();
   me.clear( component );

   # suppliers, not real, always works
   for( i = 0; i < me.nb_suppliers; i = i+1 ) {
        component.set_supplier( me.suppliers[i] );
        component.supply();
   }

   if( getprop("/systems/electrical/serviceable") ) {
        iter = 0;
        connector = ElectricalConnector.new();
        remain = "true";
        while( remain == "true" ) {
            remain = "false";
            for( i = 0; i < me.nb_connectors; i = i+1 ) {
                 connector.set( me.connectors[i] );
                 if( !me.supply( connector ) ) {
                     remain = "true";
                 }
            }
            iter = iter + 1;
       }

       # makes last iterations for voltages in parallel
       for( j = 0; j < me.forced; j = j+1 ) {
            for( i = 0; i < me.nb_connectors; i = i+1 ) {
                 connector.set( me.connectors[i] );
                 me.supply( connector );
            }
            iter = iter + 1;
       }

       me.iterations.setValue(iter);
   }

   # failure : no voltage
   else {
       for( i = 0; i < me.nb_buses; i = i+1 ) {
            component.set_bus( me.buses[i] );
            component.propagate( constant.FALSE );
       }

       for( i = 0; i < me.nb_outputs; i = i+1 ) {
            component.set_output( me.outputs[i] );
            component.propagate( constant.FALSE );
       }
   }
}

ElectricalXML.supply = func( connector ) {
   found = constant.FALSE;

   output = connector.get_output();

   # propagate voltage
   component2 = me.find( output );
   if( component2.is_exist() ) {
       if( !component2.is_propagate() ) {
           switch = connector.get_switch();

            # switch off means no voltage
            if( !switch ) {
                component2.propagate( constant.FALSE );
                found = constant.TRUE;
            }

            else {
                input = connector.get_input();
                component = me.find( input );
                if( component.is_exist() ) {

                    # input knows its voltage
                    if( component.is_propagate() ) {
                        volts = component.get_volts();
                        component2.propagate( volts );
                        found = constant.TRUE;
                    }
                }
            }
       }

       # already solved
       else {
           volts = component2.get_volts();
           if( volts == 0 ) {
               switch = connector.get_switch();

               # voltages in parallel : if no voltage, can accept another connection
               if( switch ) {
                   input = connector.get_input();
                   component = me.find( input );
                   if( component.is_exist() ) {

                       # input knows its voltage
                       if( component.is_propagate() ) {
                           volts = component.get_volts();
                           component2.propagate( volts );
                       }
                   }
               }
           }

           found = constant.TRUE;
       }
   }

   return found;
}

# lookup tables accelerates the search !!!
ElectricalXML.find = func( ident ) {
   found = "false";
   result = ElectricalComponent.new();

   if( found == "false" ) {
       i = me.supplier_names.find( ident );
       if( i != nil ) {
           result.set_supplier( me.suppliers[i] ); 
           found = "true";
       }
   }

   if( found == "false" ) {
       i = me.bus_names.find( ident );
       if( i != nil ) {
           result.set_bus( me.buses[i] ); 
           found = "true";
       }
   }

   if( found == "false" ) {
       i = me.output_names.find( ident );
       if( i != nil ) {
           result.set_output( me.outputs[i] ); 
           found = "true";
       }
   }

   if( found == "false" ) {
       print("Electrical : component not found ", ident);
   }

   return result;
}

ElectricalXML.clear = func( component ) {
   for( i = 0; i < me.nb_suppliers; i = i+1 ) {
        component.set_supplier( me.suppliers[i] );
        component.clear();
   }

   for( i = 0; i < me.nb_buses; i = i+1 ) {
        component.set_bus( me.buses[i] );
        component.clear();
   }

   for( i = 0; i < me.nb_outputs; i = i+1 ) {
        component.set_output( me.outputs[i] );
        component.clear();
   }
}


# =========
# COMPONENT
# =========

ElectricalComponent = {};

ElectricalComponent.new = func {
   obj = { parents : [ElectricalComponent],
           type : "",
           nb_charges : 0,         # number of batteries
           node : nil
         };

   return obj;
};

# is object class known ?
ElectricalComponent.is_exist = func {
   return( me.type != "" );
}

# is voltage known ?
ElectricalComponent.is_propagate = func {
   if( me.node != nil ) {
       result = me.node.getChild("propagate").getValue();
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# present voltage
ElectricalComponent.get_volts = func {
   if( me.type == "supplier" or me.type == "bus" or me.type == "output" ) {
       # takes the 1st property
       state = me.node.getChild("prop").getValue();
       result = getprop(state);
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# specifies the object class
ElectricalComponent.set_supplier = func( node ) {
   me.type = "supplier";
   me.node = node;
}

ElectricalComponent.set_bus = func( node ) {
   me.type = "bus";
   me.node = node;
}

ElectricalComponent.set_output = func( node ) {
   me.type = "output";
   me.node = node;
}

# battery charge
ElectricalComponent.charge = func {
   if( me.type == "supplier" ) {
       kind = me.node.getChild("kind").getValue();

       if( kind == "battery" ) {
           amps = me.node.getChild("amps").getValue();

           # 1 variable per battery
           state = "/systems/electrical/suppliers/battery-amps[" ~ me.nb_charges ~ "]";
           me.node.getNode(state,constant.TRUE).setValue(amps);

           me.node.getNode("charge",constant.TRUE).setValue(state);
           me.nb_charges = me.nb_charges + 1;
       }
   }

   me.node.getNode("propagate",constant.TRUE).setValue(constant.FALSE);
}

# battery discharge
ElectricalComponent.discharge = func {
   if( me.type == "supplier" ) {
       kind = me.node.getChild("kind").getValue();

       if( kind == "battery" ) {
           state = me.node.getChild("prop").getValue();
           volts = me.node.getChild("volts").getValue();

           setprop(state, volts);
           me.node.getChild("propagate").setValue(constant.TRUE);
       }

       elsif( kind == "alternator" ) {
       }

       else {
           print("Electrical : supplier not found ", kind);
       }
   }
} 

# supplies voltage
ElectricalComponent.supply = func {
   if( me.type == "supplier" ) {
       kind = me.node.getChild("kind").getValue();

       # discharge only
       if( kind == "battery" ) {
       }

       elsif( kind == "alternator" ) {
           state = me.node.getChild("prop").getValue();
           rpm = me.node.getChild("rpm-source").getValue();
           volts = me.node.getChild("volts").getValue();

           value = getprop(rpm);
           if( value > volts ) {
               value = volts;
           }

           setprop(state, value);
           me.node.getChild("propagate").setValue(constant.TRUE);
       }

       else {
           print("Electrical : supplier not found ", kind);
       }
   }
} 

# propagates voltage to all properties
ElectricalComponent.propagate = func( volts ) {
   if( me.type == "bus" or me.type == "output" ) {
       allprops = me.node.getChildren("prop");

       for( i = 0; i < size( allprops ); i = i+1 ) {
            state = allprops[i].getValue();
            setprop(state, volts);
       }

       me.node.getChild("propagate").setValue(constant.TRUE);
   }
}

# reset propagate
ElectricalComponent.clear = func() {
   if( me.type == "bus" or me.type == "output" ) {
       me.node.getChild("propagate").setValue(constant.FALSE);
   }
   elsif( me.type == "supplier" ) {
       kind = me.node.getChild("kind").getValue();

       # always knows its voltage
       if( kind == "battery" ) {
       }

       elsif( kind == "alternator" ) {
           me.node.getChild("propagate").setValue(constant.FALSE);
       }

       else {
           print("Electrical : clear not found ", kind);
       }
   }
}


# =========
# CONNECTOR
# =========

ElectricalConnector = {};

ElectricalConnector.new = func {
   obj = { parents : [ElectricalConnector],
           node : nil
         };

   return obj;
};

ElectricalConnector.set = func( node ) {
   me.node = node;
}

ElectricalConnector.get_input = func {
   input = me.node.getChild("input").getValue();
   return input;
}

ElectricalConnector.get_output = func {
   output = me.node.getChild("output").getValue();
   return output;
}

ElectricalConnector.get_switch = func {
    # switch is optional, on by default
    node2 = me.node.getNode("switch");
    if( node2 == nil ) {
        switch = constant.TRUE;
    }
          
    # switch should always have a property !
    else {
        child = node2.getChild("prop");
        if( child == nil ) {
            switch = constant.TRUE;
        }
        else {
            switch = getprop(child.getValue());
        }
    }

    return switch;
}


# ============
# LOOKUP TABLE
# ============

LookupName = {};

LookupName.new = func {
   obj = { parents : [LookupName],
           components : [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                         nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                         nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                         nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                         nil,nil,nil,nil,nil,nil,nil,nil,nil,nil],
           nb_components : 0,
           MAX_COMPONENTS : 50
         };

   return obj;
};

LookupName.add = func( name ) {
    j = me.nb_components;
    if( me.nb_components >= me.MAX_COMPONENTS ) {
         print( "Electrical: number of components exceeded ! ", me.MAX_COMPONENTS );
    }
    else {
        me.components[ j ] = name;
        me.nb_components = j + 1;
    }
}

LookupName.find = func( ident ) {
    index = nil;

    for( i = 0; i < me.nb_components; i = i+1 ) {
         if( me.components[i] == ident ) {
             index = i;
             break;
         }
    }

    return index;
}


# ========
# LIGHTING
# ========

# the material animation is for instruments : no blend of fluorescent and flood.
Lighting = {};

Lighting.new = func {
   obj = { parents : [Lighting],

           electricalsystem : nil,

# internal lights
           LIGHTFULL : 1.0,
           LIGHTINVISIBLE : 0.00001,                      # invisible offset
           LIGHTNO : 0.0,

           invisible : constant.TRUE,                     # force a change on 1st recover, then alternate

           fluorescent : "",
           fluorescentnorm : "",
           floods : [ "", "", "", "" ],
           floodnorms : [ "", "", "", "" ],
           nbfloods : 3,
           powerfailure : constant.FALSE,

# landing light
           EXTENDSEC : 8.0,                                # time to extend a landing light
           ROTATIONSEC : 2.0,                              # time to rotate a landing light
           RETRACTNORM : 0.0,
           ERRORNORM : 0.1,                                # Nasal interpolate may not reach 1.0
           EXTENDNORM : 1.0,
           ROTATIONNORM : 1.2,
           MAXKT : 365.0,                                  # speed of automatic blowback

           mainlanding : nil,
           landingtaxi : nil,

# slaves
           slave : [ nil, nil ],
           asi : 0,
           radioaltimeter : 1
         };

   obj.init();

   return obj;
};

Lighting.init = func {
   propname = getprop("/systems/lighting/slave/asi");
   me.slave[me.asi] = props.globals.getNode(propname);
   propname = getprop("/systems/lighting/slave/radio-altimeter");
   me.slave[me.radioaltimeter] = props.globals.getNode(propname);

   me.mainlanding = props.globals.getNode("/controls/lighting/external").getChildren("main-landing");
   me.landingtaxi = props.globals.getNode("/controls/lighting/external").getChildren("landing-taxi");

   # norm is user setting, light is animation
   me.fluorescent = "/controls/lighting/crew/roof-light";
   me.fluorescentnorm = "/controls/lighting/crew/roof-norm";

   me.floods[0] = "/controls/lighting/crew/captain/flood-light";
   me.floods[1] = "/controls/lighting/crew/center/flood-light";
   me.floods[2] = "/controls/lighting/crew/engineer/flood-light";

   me.floodnorms[0] = "/controls/lighting/crew/captain/flood-norm";
   me.floodnorms[1] = "/controls/lighting/crew/center/flood-norm";
   me.floodnorms[2] = "/controls/lighting/crew/engineer/flood-norm";

   strobe_switch = props.globals.getNode("controls/lighting/strobe", constant.FALSE);
   aircraft.light.new("controls/lighting/external/strobe", [0.03, 1.20], strobe_switch);
}

Lighting.set_relation = func( electrical ) {
   me.electricalsystem = electrical;
}

Lighting.schedule = func {
   if( getprop("/systems/lighting/serviceable") ) {
       if( me.landingextended() ) {
           me.extendexport();
       }
   }

   me.internal();
}

Lighting.landingextended = func {
   extension = constant.FALSE;

   # because of motor failure, may be extended with switch off, or switch on and not yet extended
   for( i=0; i < 2; i=i+1) {
        if( me.mainlanding[i].getChild("norm").getValue() > 0 or
            me.mainlanding[i].getChild("extend").getValue() ) {
            extension = constant.TRUE;
            break;
        }
        if( me.landingtaxi[i].getChild("norm").getValue() > 0 or
            me.landingtaxi[i].getChild("extend").getValue() ) {
            extension = constant.TRUE;
            break;
        }
   }

   return extension;
}

# automatic blowback
Lighting.landingblowback = func {
   if( me.slave[me.asi].getChild("indicated-speed-kt").getValue() > me.MAXKT ) {
       for( i=0; i < 2; i=i+1) {
            if( me.mainlanding[i].getChild("extend").getValue() ) {
                me.mainlanding[i].getChild("extend").setValue(constant.FALSE);
            }
            if( me.landingtaxi[i].getChild("extend").getValue() ) {
                me.landingtaxi[i].getChild("extend").setValue(constant.FALSE);
            }
       }
   }
}

# compensate approach attitude
Lighting.landingrotate = func {
   # pitch at approach
   if( me.slave[me.radioaltimeter].getChild("indicated-altitude-ft").getValue() > constantaero.AGLTOUCHFT ) {
       target = me.ROTATIONNORM;
   }

   # ground taxi
   else {
       target = me.EXTENDNORM;
   }

   return target;
}

Lighting.landingmotor = func( light, present, target ) {
   if( present < me.RETRACTNORM + me.ERRORNORM ) {
       if( target == me.EXTENDNORM ) {
           durationsec = me.EXTENDSEC;
       }
       elsif( target == me.ROTATIONNORM ) {
           durationsec = me.EXTENDSEC + me.ROTATIONSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   elsif( present > me.EXTENDNORM - me.ERRORNORM and present < me.EXTENDNORM + me.ERRORNORM ) {
       if( target == me.RETRACTNORM ) {
           durationsec = me.EXTENDSEC;
       }
       elsif( target == me.ROTATIONNORM ) {
           durationsec = me.ROTATIONSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   elsif( present > me.ROTATIONNORM - me.ERRORNORM ) {
       if( target == me.RETRACTNORM ) {
           durationsec = me.ROTATIONSEC + me.EXTENDSEC;
       }
       elsif( target == me.EXTENDNORM ) {
           durationsec = me.EXTENDSEC;
       }
       else {
           durationsec = 0.0;
       }
   }

   # motor in movement
   else {
       durationsec = 0.0;
   }

   if( durationsec > 0.0 ) {
       interpolate(light,target,durationsec);
   }
}

Lighting.extendexport = func {
   if( me.electricalsystem.has_specific() ) {

       # automatic blowback
       me.landingblowback();

       # activate electric motors
       target = me.landingrotate();

       for( i=0; i < 2; i=i+1 ) {
            if( me.mainlanding[i].getChild("extend").getValue() ) {
                value = target;
            }
            else {
                value = me.RETRACTNORM;
            }

            result = me.mainlanding[i].getChild("norm").getValue();
            if( result != value ) {
                light = "/controls/lighting/external/main-landing[" ~ i ~ "]/norm";
                me.landingmotor( light, result, value );
            }

            if( me.landingtaxi[i].getChild("extend").getValue() ) {
                value = target;
            }
            else {
                value = me.RETRACTNORM;
            }
 
            result = me.landingtaxi[i].getChild("norm").getValue();
            if( result != value ) {
                light = "/controls/lighting/external/landing-taxi[" ~ i ~ "]/norm";
                me.landingmotor( light, result, value );
            }
       }
   }
}

Lighting.internal = func {
   # clear all lights
   if( !me.electricalsystem.has_specific() or !getprop("/systems/lighting/serviceable") ) {
       me.powerfailure = constant.TRUE;
       me.failure();
   }

   # recover from failure
   elsif( me.powerfailure ) {
       me.powerfailure = constant.FALSE;
       me.recover();
   }
}

Lighting.failure = func {
   me.fluofailure();
   me.floodfailure();
}

Lighting.fluofailure = func {
   setprop(me.fluorescent,me.LIGHTNO);
}

Lighting.floodfailure = func {
   for( i=0; i < me.nbfloods; i=i+1 ) {
        setprop(me.floods[i],me.LIGHTNO);
   }
}

Lighting.recover = func {
   me.fluorecover();
   me.floodrecover();
}

Lighting.fluorecover = func {
   if( !me.powerfailure ) {
       me.failurerecover(me.fluorescentnorm,me.fluorescent,constant.FALSE);
   }
}

Lighting.floodrecover = func {
   if( !getprop("/controls/lighting/crew/roof") and !me.powerfailure ) {
       for( i=0; i < me.nbfloods; i=i+1 ) {
            # may change a flood light, during a fluo lighting
            me.failurerecover(me.floodnorms[i],me.floods[i],me.invisible);
       }
   }
}

# was no light, because of failure, or the knob has changed
Lighting.failurerecover = func( propnorm, proplight, offset ) {
   norm = getprop(propnorm);
   if( norm != getprop(proplight) ) {

       # flood cannot recover from fluorescent light without a change
       if( offset ) {
           if( norm > me.LIGHTNO and me.invisible ) {
               norm = norm - me.LIGHTINVISIBLE;
           }
       }

       setprop(proplight,norm);
   }
}

Lighting.floodexport = func {
   me.floodrecover();
}

Lighting.roofexport = func {
   if( getprop("/controls/lighting/crew/roof") ) {
       value = me.LIGHTFULL;

       # no blend with flood
       me.floodfailure();
   }
   else {
       value = me.LIGHTNO;

       me.invisible = !me.invisible;

       me.floodrecover();
   }

   setprop(me.fluorescentnorm,value);
   me.fluorecover();
}
