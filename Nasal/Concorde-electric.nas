# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =================
# ELECTRICAL SYSTEM
# =================

Electrical = {};

Electrical.new = func {
   obj = { parents : [Electrical],

           parser : ElectricalXML.new(),
           csd : ConstantSpeedDrive.new(),

           ELECSEC : 1.0,                                 # refresh rate

           SERVICEVOLT : 600.0,
           GROUNDVOLT : 110.0,
           SPECIFICVOLT : 20.0,

           outputs : nil,
           power : nil,

           noinstrument : { "agl" : "", "airspeed" : "" }
         };

   obj.init();

   return obj;
};

Electrical.init = func {
   me.noinstrument["agl"] = getprop("/systems/electrical/noinstrument/agl");
   me.noinstrument["airspeed"] = getprop("/systems/electrical/noinstrument/airspeed");

   me.outputs = props.globals.getNode("/systems/electrical/outputs");
   me.power = props.globals.getNode("/systems/electrical/power");

   me.csd.set_rate( me.ELECSEC );
}

Electrical.set_rate = func( rates ) {
   me.ELECSEC = rates;
   me.csd.set_rate( me.ELECSEC );
}

Electrical.schedule = func {
    me.csd.schedule();
    me.parser.schedule();

    me.power.getChild("autopilot1").setValue( me.has_autopilot1() );
    me.power.getChild("autopilot2").setValue( me.has_autopilot2() );
    me.power.getChild("ground-service").setValue( me.has_ground_power() );
    me.power.getChild("specific").setValue( me.has_specific() );
}

Electrical.slowschedule = func {
    me.groundservice();
    me.parser.slowschedule();
}

# connection with delay by ground operator
Electrical.groundservice = func {
    aglft = getprop(me.noinstrument["agl"]);
    speedkt = getprop(me.noinstrument["airspeed"]);

    if( aglft <  15 and speedkt < 15 ) {
        powervolt = me.SERVICEVOLT;
    }
    else {
        powervolt = 0.0;
    }

   setprop("/systems/electrical/suppliers/ground-service",powervolt);
}

Electrical.has_specific = func {
    volts =  me.outputs.getChild("specific").getValue();
    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.SPECIFICVOLT ) {
        result = constant.TRUE;
    }
    else {
        result = constant.FALSE;
    }

    return result;
}

Electrical.has_autopilot1 = func {
    volts =  me.outputs.getChild("autopilot1").getValue();
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

Electrical.has_autopilot2 = func {
    volts =  me.outputs.getChild("autopilot2").getValue();
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

Electrical.has_ground_power = func {
    volts =  me.outputs.getNode("probe").getChild("ac-gpb").getValue();
    if( volts == nil ) {
        result = constant.FALSE;
    }
    elsif( volts > me.GROUNDVOLT ) {
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

           engines : nil,

           noinstrument : { "temperature" : "" },
           slave : { "engine" : nil, "engine2" : nil }
         };

   obj.init();

   return obj;
};

ConstantSpeedDrive.init = func {
   me.noinstrument["temperature"] = getprop("/systems/electrical/noinstrument/temperature");

   propname = getprop("/systems/electrical/slave/engine");
   me.slave["engine"] = props.globals.getNode(propname).getChildren("engine");
   propname = getprop("/systems/electrical/slave/engine2");
   me.slave["engine2"] = props.globals.getNode(propname).getChildren("engine");

   me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
}

ConstantSpeedDrive.set_rate = func( rates ) {
   me.ELECSEC = rates;
}

# oil temperature
ConstantSpeedDrive.schedule = func {
   for( i=0; i<4; i=i+1 ) {
       csd = me.engines[i].getChild("csd").getValue();
       if( csd ) {
           csdpressurepsi = me.slave["engine"][i].getChild("oil-pressure-psi").getValue();
       }
       else {
           csdpressurepsi = 0.0;
       }

       # not real
       result = me.slave["engine2"][i].getChild("csd-oil-psi").getValue();
       if( result != csdpressurepsi ) {
           interpolate("/systems/engines/engine[" ~ i ~ "]/csd-oil-psi",csdpressurepsi,me.ELECSEC);
       }

       oatdegc = getprop(me.noinstrument["temperature"]);

       # connected
       if( csd ) {
           egtdegf = me.slave["engine"][i].getChild("egt_degf").getValue();
           egtdegc = constant.fahrenheit_to_celsius( egtdegf );
       }

       # not real
       result = me.slave["engine2"][i].getChild("csd-inlet-degc").getValue();
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
           interpolate("/systems/engines/engine[" ~ i ~ "]/csd-inlet-degc",inletdegc,me.ELECSEC);
       }

       # not real
       result = me.slave["engine2"][i].getChild("csd-diff-degc").getValue();
       if( csd ) {
           diffdegc = egtdegc / 17.0;
       }
       # scale until 0 deg C
       else {
           diffdegc = result * 0.95;
       }
       if( result != diffdegc ) {
           interpolate("/systems/engines/engine[" ~ i ~ "]/csd-diff-degc",diffdegc,me.ELECSEC);
       }
   }
}


# =================
# ELECTRICAL PARSER
# =================
ElectricalXML = {};

ElectricalXML.new = func {
   obj = { parents : [ElectricalXML],

           config : nil,
           passes : 0.0,
           iterations : nil,

           components : ComponentArray.new(),
           connectors : ConnectorArray.new()
         };

   obj.init();

   return obj;
};

# creates all propagate variables
ElectricalXML.init = func {
   me.config = props.globals.getNode("/systems/electrical/internal/config");
   me.forced = props.globals.getNode("/systems/electrical/internal/iterations-forced").getValue();
   me.iterations = props.globals.getNode("/systems/electrical/internal/iterations");

   suppliers = me.config.getChildren("supplier");
   nb_suppliers = size( suppliers );
   for( i = 0; i < nb_suppliers; i = i+1 ) {
        me.components.add_supplier( suppliers[i] );
        component = me.components.get_supplier( i );
        component.charge();
   }

   buses = me.config.getChildren("bus");
   nb_buses = size( buses );
   for( i = 0; i < nb_buses; i = i+1 ) {
        me.components.add_bus( buses[i] );
        component = me.components.get_bus( i );
        component.charge();
   }

   outputs = me.config.getChildren("output");
   nb_outputs = size( outputs );
   for( i = 0; i < nb_outputs; i = i+1 ) {
        me.components.add_output( outputs[i] );
        component = me.components.get_output( i );
        component.charge();
   }

   connectors = me.config.getChildren("connector");
   nb_connectors = size( connectors );
   for( i = 0; i < nb_connectors; i = i+1 ) {
        me.connectors.add( connectors[i] );
   }
}

# battery discharge
ElectricalXML.slowschedule = func {
   for( i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.discharge();
   }
}

ElectricalXML.schedule = func {
   me.clear();

   # suppliers, not real, always works
   for( i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.supply();
   }

   if( getprop("/systems/electrical/serviceable") ) {
        iter = 0;
        remain = constant.TRUE;
        while( remain ) {
            remain = constant.FALSE;
            for( i = 0; i < me.connectors.count(); i = i+1 ) {
                 connector = me.connectors.get( i );
                 if( !me.supply( connector ) ) {
                     remain = constant.TRUE;
                 }
            }
            iter = iter + 1;
       }

       # makes last iterations for voltages in parallel
       for( j = 0; j < me.forced; j = j+1 ) {
            for( i = 0; i < me.connectors.count(); i = i+1 ) {
                 connector = me.connectors.get( i );
                 me.supply( connector );
            }
            iter = iter + 1;
       }

       me.iterations.setValue(iter);
   }

   # failure : no voltage
   else {
       for( i = 0; i < me.components.count_bus(); i = i+1 ) {
            component = me.components.get_bus( i );
            component.propagate( 0.0 );
       }

       for( i = 0; i < me.components.count_output(); i = i+1 ) {
            component = me.components.get_output( i );
            component.propagate( 0.0 );
       }
   }
}

ElectricalXML.supply = func( connector ) {
   found = constant.FALSE;

   output = connector.get_output();

   # propagate voltage
   component2 = me.components.find( output );
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
                component = me.components.find( input );
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
                   component = me.components.find( input );
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

ElectricalXML.clear = func {
   for( i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.clear();
   }

   for( i = 0; i < me.components.count_bus(); i = i+1 ) {
        component = me.components.get_bus( i );
        component.clear();
   }

   for( i = 0; i < me.components.count_output(); i = i+1 ) {
        component = me.components.get_output( i );
        component.clear();
   }
}


# ===============
# COMPONENT ARRAY
# ===============

ComponentArray = {};

ComponentArray.new = func {
   obj = { parents : [ComponentArray],

           supplier_name : ["","","","","","","","","",""],
           bus_name :      ["","","","","","","","","","",
                            "","","","","","","","","","",
                            "","","","","","","","","","",
                            "","","","","","","","","","",
                            "","","","","","","","","",""],
           output_name :   ["","","","","","","","","","",
                            "","","","","","","","","","",
                            "","","","","","","","","","",
                            "","","","","","","","","","",
                            "","","","","","","","","",""],

           MAXSUPPLIERS : 10,
           suppliers : [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil],
           nb_charges : 0,                                        # number of batteries
           nb_suppliers : 0,

           MAXBUSES : 50,
           buses :    [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                       nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                       nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                       nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                       nil,nil,nil,nil,nil,nil,nil,nil,nil,nil],
           MAXPROPS : 20,
           bus_prop : ["","","","","","","","","","",
                       "","","","","","","","","",""],
           nb_buses : 0,

           MAXOUTPUTS : 50,
           outputs : [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                      nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                      nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                      nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                      nil,nil,nil,nil,nil,nil,nil,nil,nil,nil],
           nb_outputs : 0
         };

   return obj;
};

ComponentArray.add_supplier = func( node ) {
   if( me.nb_suppliers >= me.MAXSUPPLIERS ) {
       print( "Electrical: number of suppliers exceeded ! ", me.MAXSUPPLIERS );
   }

   else {
       name = node.getChild("name").getValue();
       me.supplier_name[ me.nb_suppliers ] = name;

       kind = node.getChild("kind").getValue();

       state = "";
       rpm = "";
       charge = "";
       amps = 0;

       if( kind == "alternator" ) {
           state = node.getChild("prop").getValue();
           rpm = node.getChild("rpm-source").getValue();
       }

       # 1 variable per battery
       elsif( kind == "battery" ) {
           state = node.getChild("prop").getValue();

           charge = "/systems/electrical/suppliers/battery-amps[" ~ me.nb_charges ~ "]";
           me.nb_charges = me.nb_charges + 1;
           node.getNode("charge",constant.TRUE).setValue(charge);

           amps = node.getChild("amps").getValue();
       }

       volts = node.getChild("volts").getValue();

       result = ElectricalComponent.new();
       result.create_supplier( kind, state, rpm, volts, charge, amps );
       me.suppliers[ me.nb_suppliers ] = result;

       me.nb_suppliers = me.nb_suppliers + 1;
   }
}

ComponentArray.add_bus = func( node ) {
   if( me.nb_buses >= me.MAXBUSES ) {
       print( "Electrical: number of buses exceeded ! ", me.MAXBUSES );
   }

   else {
       name = node.getChild("name").getValue();
       me.bus_name[ me.nb_buses ] = name;

       allprops = node.getChildren("prop");
       nbprops = size( allprops );

       for( i = 0; i < me.MAXPROPS; i = i+1 ) {
            if( i < nbprops ) {
                state = allprops[i].getValue();
            }
            else {
                state = "";
            }
            me.bus_prop[ i ] = state;
       }

       result = ElectricalComponent.new();
       result.create_bus( me.bus_prop );
       me.buses[ me.nb_buses ] = result;

       me.nb_buses = me.nb_buses + 1;
   }
}

ComponentArray.add_output = func( node ) {
   if( me.nb_outputs >= me.MAXOUTPUTS ) {
       print( "Electrical: number of outputs exceeded ! ", me.MAXOUTPUTS );
   }

   else {
       name = node.getChild("name").getValue();
       me.output_name[ me.nb_outputs ] = name;

       prop = node.getChild("prop").getValue();

       result = ElectricalComponent.new();
       result.create_output( prop );
       me.outputs[ me.nb_outputs ] = result;

       me.nb_outputs = me.nb_outputs + 1;
   }
}

ComponentArray.find_supplier = func( ident ) {
    result = ElectricalComponent.new();

    for( i = 0; i < me.MAXSUPPLIERS; i = i+1 ) {
         if( me.supplier_name[i] == ident ) {
             result = me.get_supplier( i );
             break;
         }
    }

    return result;
}

ComponentArray.find_bus = func( ident ) {
    result = ElectricalComponent.new();

    for( i = 0; i < me.MAXBUSES; i = i+1 ) {
         if( me.bus_name[i] == ident ) {
             result = me.get_bus( i );
             break;
         }
    }

    return result;
}

ComponentArray.find_output = func( ident ) {
    result = ElectricalComponent.new();

    for( i = 0; i < me.MAXOUTPUTS; i = i+1 ) {
         if( me.output_name[i] == ident ) {
             result = me.get_output( i );
             break;
         }
    }

    return result;
}

# lookup tables accelerates the search !!!
ComponentArray.find = func( ident ) {
   result = me.find_supplier( ident );
   found = result.is_exist();

   if( !found ) {
       result = me.find_bus( ident );
       found = result.is_exist();
   }

   if( !found ) {
       result = me.find_output( ident );
       found = result.is_exist();
   }

   if( !found ) {
       print("Electrical : component not found ", ident);
   }

   return result;
}

ComponentArray.count_supplier = func {
   return me.nb_suppliers;
}

ComponentArray.count_bus = func {
   return me.nb_buses;
}

ComponentArray.count_output = func {
   return me.nb_outputs;
}

ComponentArray.get_supplier = func( index ) {
   return me.suppliers[ index ];
}

ComponentArray.get_bus = func( index ) {
   return me.buses[ index ];
}

ComponentArray.get_output = func( index ) {
   return me.outputs[ index ];
}


# =========
# COMPONENT
# =========

ElectricalComponent = {};

ElectricalComponent.new = func {
   obj = { parents : [ElectricalComponent],

           index : -1,
           done : constant.FALSE,

# supplier
           kind : "",
           rpm : "",
           volts : 0,
           state : "",
           amps : 0,

# bus
           MAXPROPS : 20,
           props : ["","","","","","","","","","",
                    "","","","","","","","","",""],

           type : ""
         };

   return obj;
};

# is object class known ?
ElectricalComponent.is_exist = func {
   return( me.type != "" );
}

# is voltage known ?
ElectricalComponent.is_propagate = func {
   return me.done;
}

# present voltage
ElectricalComponent.get_volts = func {
   if( me.type == "supplier" or me.type == "bus" or me.type == "output" ) {
       # takes the 1st property
       state = me.props[0];
       result = getprop(state);
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# creates the object class
ElectricalComponent.create_supplier = func( kind, prop, rpm, volts, state, amps ) {
   me.type = "supplier";

   me.kind = kind;
   me.props[0] = prop;
   me.rpm = rpm;
   me.volts = volts;
   me.state = state;
   me.amps = amps;
}

ElectricalComponent.create_bus = func( props ) {
   me.type = "bus";

   for( i = 0; i < me.MAXPROPS; i = i+1 ) {
        me.props[ i ] = props[ i ];
   }
}

ElectricalComponent.create_output = func( prop ) {
   me.type = "output";

   me.props[0] = prop;
}

ElectricalComponent.create_none = func {
   me.type = "";
}

# battery charge
ElectricalComponent.charge = func {
   if( me.type == "supplier" ) {
       if( me.kind == "battery" ) {
           setprop(me.state,me.amps);
       }
   }

   me.clear_propagate();
}

# battery discharge
ElectricalComponent.discharge = func {
   if( me.type == "supplier" ) {
       if( me.kind == "battery" ) {
           setprop(me.props[0], me.volts);
           me.set_propagate();
       }

       elsif( me.kind == "alternator" ) {
       }

       else {
           print("Electrical : supplier not found ", me.kind);
       }
   }
} 

# supplies voltage
ElectricalComponent.supply = func {
   if( me.type == "supplier" ) {
       # discharge only
       if( me.kind == "battery" ) {
       }

       elsif( me.kind == "alternator" ) {
           value = getprop(me.rpm);
           if( value > me.volts ) {
               value = me.volts;
           }

           setprop(me.props[0], value);
           me.set_propagate();
       }

       else {
           print("Electrical : supplier not found ", me.kind);
       }
   }
} 

# propagates voltage to all properties
ElectricalComponent.propagate = func( volts ) {
   if( me.type == "bus" or me.type == "output" ) {
       for( i = 0; i < me.MAXPROPS; i = i+1 ) {
            state = me.props[i];

            # last
            if( state == "" ) {
                break;
            }

            setprop(state, volts);
       }

       me.set_propagate();
   }
}

# reset propagate
ElectricalComponent.clear = func() {
   if( me.type == "bus" or me.type == "output" ) {
       me.clear_propagate();
   }
   elsif( me.type == "supplier" ) {
       # always knows its voltage
       if( me.kind == "battery" ) {
       }

       elsif( me.kind == "alternator" ) {
           me.clear_propagate();
       }

       else {
           print("Electrical : clear not found ", me.kind);
       }
   }
}

ElectricalComponent.clear_propagate = func {
   me.done = constant.FALSE;
}

ElectricalComponent.set_propagate = func {
   me.done = constant.TRUE;
}


# ===============
# CONNECTOR ARRAY
# ===============

ConnectorArray = {};

ConnectorArray.new = func {
   obj = { parents : [ConnectorArray],

           MAXCONNECTORS : 100,
           connectors      :  [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
                               nil,nil,nil,nil,nil,nil,nil,nil,nil,nil],
           nb_connectors : 0
         };

   return obj;
};

ConnectorArray.add = func( node ) {
   if( me.nb_connectors >= me.MAXCONNECTORS ) {
       print( "Electrical: number of connectors exceeded ! ", me.MAXCONNECTORS );
   }

   else {
       input = node.getChild("input").getValue();
       output = node.getChild("output").getValue();

       prop = "";

       switch = node.getNode("switch");
       if( switch != nil ) {
           child = switch.getChild("prop");
           # switch should always have a property !
           if( child != nil ) {
               prop = child.getValue();
           }
       }

       result = ElectricalConnector.new();
       result.create( input, output, prop );
       me.connectors[ me.nb_connectors ] = result;

       me.nb_connectors = me.nb_connectors + 1;
   }
}

ConnectorArray.count = func {
   return me.nb_connectors;
}

ConnectorArray.get = func( index ) {
   return me.connectors[ index ];
}


# =========
# CONNECTOR
# =========

ElectricalConnector = {};

ElectricalConnector.new = func {
   obj = { parents : [ElectricalConnector],

           input : "",
           output : "",
           prop : ""
         };

   return obj;
};

ElectricalConnector.create = func( input, output, prop ) {
   me.input = input;
   me.output = output;
   me.prop = prop;
}

ElectricalConnector.get_input = func {
   return me.input;
}

ElectricalConnector.get_output = func {
   return me.output;
}

ElectricalConnector.get_switch = func {
    # switch is optional, on by default
    if( me.prop == "" ) {
        switch = constant.TRUE;
    }
    else {
        switch = getprop(me.prop);
    }

    return switch;
}


# ========
# LIGHTING
# ========

Lighting = {};

Lighting.new = func {
   obj = { parents : [Lighting],

           internal : LightLevel.new(),
           landing : LandingLight.new()
         };

   obj.init();

   return obj;
};

Lighting.init = func {
   strobe_switch = props.globals.getNode("controls/lighting/strobe", constant.FALSE);
#   aircraft.light.new("controls/lighting/external/strobe", 0.03, 1.20, strobe_switch);
   aircraft.light.new("controls/lighting/external/strobe", [ 0.03, 1.20 ], strobe_switch);
}

Lighting.set_relation = func( electrical ) {
   me.landing.set_relation( electrical );
   me.internal.set_relation( electrical );
}

Lighting.schedule = func {
   me.landing.schedule();
   me.internal.schedule();
}

Lighting.extendexport = func {
   me.landing.extendexport();
}

Lighting.floodexport = func {
   me.internal.floodexport();
}

Lighting.roofexport = func {
   me.internal.roofexport();
}


# =============
# LANDING LIGHT
# =============

LandingLight = {};

LandingLight.new = func {
   obj = { parents : [LandingLight],

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

           slave : { "asi" : nil, "electric" : nil, "radioaltimeter" : nil }
         };

   obj.init();

   return obj;
};

LandingLight.init = func {
   propname = getprop("/systems/lighting/slave/asi");
   me.slave["asi"] = props.globals.getNode(propname);
   propname = getprop("/systems/lighting/slave/electric");
   me.slave["electric"] = props.globals.getNode(propname);
   propname = getprop("/systems/lighting/slave/radio-altimeter");
   me.slave["radioaltimeter"] = props.globals.getNode(propname);

   me.mainlanding = props.globals.getNode("/controls/lighting/external").getChildren("main-landing");
   me.landingtaxi = props.globals.getNode("/controls/lighting/external").getChildren("landing-taxi");
}

LandingLight.schedule = func {
   if( getprop("/systems/lighting/serviceable") ) {
       if( me.landingextended() ) {
           me.extendexport();
       }
   }
}

LandingLight.landingextended = func {
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
LandingLight.landingblowback = func {
   if( me.slave["asi"].getChild("indicated-speed-kt").getValue() > me.MAXKT ) {
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
LandingLight.landingrotate = func {
   # pitch at approach
   if( me.slave["radioaltimeter"].getChild("indicated-altitude-ft").getValue() > constantaero.AGLTOUCHFT ) {
       target = me.ROTATIONNORM;
   }

   # ground taxi
   else {
       target = me.EXTENDNORM;
   }

   return target;
}

LandingLight.landingmotor = func( light, present, target ) {
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

LandingLight.extendexport = func {
   if( me.slave["electric"].getChild("specific").getValue() ) {

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


# ===========
# LIGHT LEVEL
# ===========

# the material animation is for instruments : no blend of fluorescent and flood.
LightLevel = {};

LightLevel.new = func {
   obj = { parents : [LightLevel],

# internal lights
           LIGHTFULL : 1.0,
           LIGHTINVISIBLE : 0.00001,                      # invisible offset
           LIGHTNO : 0.0,

           invisible : constant.TRUE,                     # force a change on 1st recover, then alternate

           fluorescent : "",
           fluorescentnorm : "",
           floods : [ "", "", "", "", "" ],
           floodnorms : [ "", "", "", "", "" ],
           nbfloods : 4,
           powerfailure : constant.FALSE,

           slave : { "electric" : nil }
         };

   obj.init();

   return obj;
};

LightLevel.init = func {
   propname = getprop("/systems/lighting/slave/electric");
   me.slave["electric"] = props.globals.getNode(propname);

   # norm is user setting, light is animation
   me.fluorescent = "/controls/lighting/crew/roof-light";
   me.fluorescentnorm = "/controls/lighting/crew/roof-norm";

   me.floods[0] = "/controls/lighting/crew/captain/flood-light";
   me.floods[1] = "/controls/lighting/crew/copilot/flood-light";
   me.floods[2] = "/controls/lighting/crew/center/flood-light";
   me.floods[3] = "/controls/lighting/crew/engineer/flood-light";

   me.floodnorms[0] = "/controls/lighting/crew/captain/flood-norm";
   me.floodnorms[1] = "/controls/lighting/crew/copilot/flood-norm";
   me.floodnorms[2] = "/controls/lighting/crew/center/flood-norm";
   me.floodnorms[3] = "/controls/lighting/crew/engineer/flood-norm";
}

LightLevel.schedule = func {
   # clear all lights
   if( !me.slave["electric"].getChild("specific").getValue() or
       !getprop("/systems/lighting/serviceable") ) {
       me.powerfailure = constant.TRUE;
       me.failure();
   }

   # recover from failure
   elsif( me.powerfailure ) {
       me.powerfailure = constant.FALSE;
       me.recover();
   }
}

LightLevel.failure = func {
   me.fluofailure();
   me.floodfailure();
}

LightLevel.fluofailure = func {
   setprop(me.fluorescent,me.LIGHTNO);
}

LightLevel.floodfailure = func {
   for( i=0; i < me.nbfloods; i=i+1 ) {
        setprop(me.floods[i],me.LIGHTNO);
   }
}

LightLevel.recover = func {
   me.fluorecover();
   me.floodrecover();
}

LightLevel.fluorecover = func {
   if( !me.powerfailure ) {
       me.failurerecover(me.fluorescentnorm,me.fluorescent,constant.FALSE);
   }
}

LightLevel.floodrecover = func {
   if( !getprop("/controls/lighting/crew/roof") and !me.powerfailure ) {
       for( i=0; i < me.nbfloods; i=i+1 ) {
            # may change a flood light, during a fluo lighting
            me.failurerecover(me.floodnorms[i],me.floods[i],me.invisible);
       }
   }
}

# was no light, because of failure, or the knob has changed
LightLevel.failurerecover = func( propnorm, proplight, offset ) {
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

LightLevel.floodexport = func {
   me.floodrecover();
}

LightLevel.roofexport = func {
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
