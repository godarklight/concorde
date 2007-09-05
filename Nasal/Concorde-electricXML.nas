# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =================
# ELECTRICAL PARSER
# =================
ElectricalXML = {};

ElectricalXML.new = func {
   obj = { parents : [ElectricalXML],

           config : nil,
           electrical : nil,
           iterations : nil,

           components : ElecComponentArray.new(),
           connectors : ElecConnectorArray.new()
         };

   obj.init();

   return obj;
};

# creates all propagate variables
ElectricalXML.init = func {
   me.config = props.globals.getNode("/systems/electrical/internal/config");
   me.electrical = props.globals.getNode("/systems/electrical");
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

   if( me.electrical.getChild("serviceable").getValue() ) {
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
            component.propagate();
       }

       for( i = 0; i < me.components.count_output(); i = i+1 ) {
            component = me.components.get_output( i );
            component.propagate();
       }
   }

   me.apply();
}

ElectricalXML.supply = func( connector ) {
   found = constant.FALSE;

   output = connector.get_output();

   # propagate voltage
   component2 = me.components.find( output );
   if( component2 != nil ) {
       if( !component2.is_propagate() ) {
           switch = connector.get_switch();

            # switch off means no voltage
            if( !switch ) {
                component2.propagate();
                found = constant.TRUE;
            }

            else {
                input = connector.get_input();
                component = me.components.find( input );
                if( component != nil ) {

                    # input knows its voltage
                    if( component.is_propagate() ) {
                        component2.propagate( component );
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
                   if( component != nil ) {

                       # input knows its voltage
                       if( component.is_propagate() ) {
                           component2.propagate( component );
                       }
                   }
               }
           }

           found = constant.TRUE;
       }
   }

   return found;
}

ElectricalXML.apply = func {
   for( i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.apply();
   }

   for( i = 0; i < me.components.count_bus(); i = i+1 ) {
        component = me.components.get_bus( i );
        component.apply();
   }

   for( i = 0; i < me.components.count_output(); i = i+1 ) {
        component = me.components.get_output( i );
        component.apply();
   }
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

ElecComponentArray = {};

ElecComponentArray.new = func {
   obj = { parents : [ElecComponentArray],

           supplier_name : [],
           bus_name :      [],
           output_name :   [],

           suppliers : [],
           nb_charges : 0,                                        # number of batteries
           nb_suppliers : 0,

           buses :    [],
           nb_buses : 0,

           outputs : [],
           nb_outputs : 0
         };

   return obj;
};

ElecComponentArray.add_supplier = func( node ) {
   name = node.getChild("name").getValue();
   append(me.supplier_name, name);

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

   result = ElecSupplier.new( kind, state, rpm, volts, charge, amps );
   append(me.suppliers, result);

   me.nb_suppliers = me.nb_suppliers + 1;
}

ElecComponentArray.add_bus = func( node ) {
   name = node.getChild("name").getValue();
   append(me.bus_name, name);

   allprops = node.getChildren("prop");

   result = ElecBus.new( allprops );
   append(me.buses, result);

   me.nb_buses = me.nb_buses + 1;
}

ElecComponentArray.add_output = func( node ) {
   name = node.getChild("name").getValue();
   append(me.output_name, name);

   prop = node.getChild("prop").getValue();

   result = ElecOutput.new( prop );
   append(me.outputs, result);

   me.nb_outputs = me.nb_outputs + 1;
}

ElecComponentArray.find_supplier = func( ident ) {
    result = nil;

    for( i = 0; i < me.nb_suppliers; i = i+1 ) {
         if( me.supplier_name[i] == ident ) {
             result = me.get_supplier( i );
             break;
         }
    }

    return result;
}

ElecComponentArray.find_bus = func( ident ) {
    result = nil;

    for( i = 0; i < me.nb_buses; i = i+1 ) {
         if( me.bus_name[i] == ident ) {
             result = me.get_bus( i );
             break;
         }
    }

    return result;
}

ElecComponentArray.find_output = func( ident ) {
    result = nil;

    for( i = 0; i < me.nb_outputs; i = i+1 ) {
         if( me.output_name[i] == ident ) {
             result = me.get_output( i );
             break;
         }
    }

    return result;
}

# lookup tables accelerates the search !!!
ElecComponentArray.find = func( ident ) {
   found = constant.FALSE;
   result = me.find_supplier( ident );

   if( result == nil ) {
       result = me.find_bus( ident );
   }

   if( result == nil ) {
       result = me.find_output( ident );
   }

   if( result != nil ) {
       found = constant.TRUE;
   }

   if( !found ) {
       print("Electrical : component not found ", ident);
   }

   return result;
}

ElecComponentArray.count_supplier = func {
   return me.nb_suppliers;
}

ElecComponentArray.count_bus = func {
   return me.nb_buses;
}

ElecComponentArray.count_output = func {
   return me.nb_outputs;
}

ElecComponentArray.get_supplier = func( index ) {
   return me.suppliers[ index ];
}

ElecComponentArray.get_bus = func( index ) {
   return me.buses[ index ];
}

ElecComponentArray.get_output = func( index ) {
   return me.outputs[ index ];
}


# =========
# COMPONENT
# =========

# for inheritance, the component must be the last of parents.
ElecComponent = {};

# not called by child classes !!!
ElecComponent.new = func {
   obj = { parents : [ElecComponent],

           NOVOLT : 0.0,

           done : constant.FALSE
         };

   return obj;
};

ElecComponent.init_ancestor = func {
   obj = ElecComponent.new();

   me.NOVOLT = obj.NOVOLT;
   me.done = obj.done;
}

# is voltage known ?
ElecComponent.is_propagate = func {
   return me.done;
}

# battery charge
ElecComponent.charge = func {
   me.clear_propagate();
}

# battery discharge
ElecComponent.discharge = func {
} 

# supplies voltage
ElecComponent.supply = func {
} 

# propagates voltage to all properties
ElecComponent.propagate = func( component = nil ) {
}

# reset propagate
ElecComponent.clear = func() {
}

ElecComponent.clear_propagate = func {
   me.done = constant.FALSE;
}

ElecComponent.set_propagate = func {
   me.done = constant.TRUE;
}

ElecComponent.log = func( message, value ) {
   message = "Electrical: " ~ message ~ " ";
   print( message, value );
}

ElecComponent.apply = func {
}


# ========
# SUPPLIER 
# ========

ElecSupplier = {};

ElecSupplier.new = func( kind, prop, rpm, volts, state, amps ) {
   obj = { parents : [ElecSupplier,ElecComponent],

           value : 0.0,

           kind : kind,
           rpm : rpm,
           volts : volts,
           state : state,
           amps : amps,

           props : prop
         };

   obj.init_ancestor();

   return obj;
};

# present voltage
ElecSupplier.get_volts = func {
   value = getprop(me.props);

   if( value == nil ) {
       value = me.NOVOLT;
   }

   return value;
}

# battery charge
ElecSupplier.charge = func {
   if( me.kind == "battery" ) {
       me.value = me.amps;
   }

   me.clear_propagate();
}

# battery discharge
ElecSupplier.discharge = func {
   if( me.kind == "battery" ) {
       me.set_propagate();
   }

   elsif( me.kind == "alternator" ) {
   }

   else {
       me.log("supplier not found ", me.kind);
   }
} 

# supplies voltage
ElecSupplier.supply = func {
   # discharge only
   if( me.kind == "battery" ) {
   }

   elsif( me.kind == "alternator" ) {
       me.value = getprop(me.rpm);
       if( me.value == nil ) {
           me.value = me.NOVOLT;
       }
       elsif( me.value > me.volts ) {
           me.value = me.volts;
       }

       me.set_propagate();
   }

   else {
       me.log("supplier not found ", me.kind);
   }
} 

# reset propagate
ElecSupplier.clear = func() {
   # always knows its voltage
   if( me.kind == "battery" ) {
   }

   elsif( me.kind == "alternator" ) {
       me.clear_propagate();
   }

   else {
       me.log("clear not found ", me.kind);
   }
}

ElecSupplier.apply = func {
   setprop(me.props,me.value);
}


# ===
# BUS
# ===

ElecBus = {};

ElecBus.new = func( allprops ) {
   obj = { parents : [ElecBus,ElecComponent],

           values : [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,
                     0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0],

           MAXPROPS : 20,

           nb_props : 0,
           props : ["","","","","","","","","","",
                    "","","","","","","","","",""]
         };

   obj.init( allprops );

   return obj;
};

ElecBus.init = func( allprops ) {
   me.init_ancestor();

   me.nb_props = size( allprops );
   if( me.nb_props > me.MAXPROPS ) {
       me.log( "number of properties exceeded !", me.nb_props );
       me.nb_props = me.MAXPROPS;
   }

   for( i = 0; i < me.nb_props; i = i+1 ) {
        me.props[ i ] = allprops[i].getValue();
   }
}

# present voltage
ElecBus.get_volts = func {
   if( me.nb_props == 0 ) {
       value = me.NOVOLT;
   }

   # takes the 1st property
   else {
       value = me.values[0];
   }

   if( value == nil ) {
       value = me.NOVOLT;
   }

   return value;
}

# propagates voltage to all properties
ElecBus.propagate = func( component = nil ) {
   if( component == nil ) {
       volts = me.NOVOLT;
   }
   else {
       volts = component.get_volts();
   }

   for( i = 0; i < me.nb_props; i = i+1 ) {
        me.values[i] = volts;
   }

   me.set_propagate();
}

# reset propagate
ElecBus.clear = func() {
   me.clear_propagate();
}

ElecBus.apply = func {
   for( i = 0; i < me.nb_props; i = i+1 ) {
        state = me.props[i];
        setprop(state, me.values[i]);
   }
}


# ======
# OUTPUT
# ======

ElecOutput = {};

ElecOutput.new = func( prop ) {
   obj = { parents : [ElecOutput,ElecComponent],

           value : 0.0,

           props : prop
         };

   obj.init_ancestor();

   return obj;
};

# present voltage
ElecOutput.get_volts = func {
   return me.value;
}

# propagates voltage to all properties
ElecOutput.propagate = func( component = nil ) {
   if( component == nil ) {
       volts = me.NOVOLT;
   }
   else {
       volts = component.get_volts();
   }

   me.value = volts;

   me.set_propagate();
}

# reset propagate
ElecOutput.clear = func() {
   me.clear_propagate();
}

ElecOutput.apply = func {
   setprop(me.props,me.value);
}


# ===============
# CONNECTOR ARRAY
# ===============

ElecConnectorArray = {};

ElecConnectorArray.new = func {
   obj = { parents : [ElecConnectorArray],

           connectors      :  [],
           nb_connectors : 0
         };

   return obj;
};

ElecConnectorArray.add = func( node ) {
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

   result = ElecConnector.new( input, output, prop );
   append(me.connectors, result);

   me.nb_connectors = me.nb_connectors + 1;
}

ElecConnectorArray.count = func {
   return me.nb_connectors;
}

ElecConnectorArray.get = func( index ) {
   return me.connectors[ index ];
}


# =========
# CONNECTOR
# =========

ElecConnector = {};

ElecConnector.new = func( input, output, prop ) {
   obj = { parents : [ElecConnector],

           input : input,
           output : output,
           prop : prop
         };

   return obj;
};

ElecConnector.get_input = func {
   return me.input;
}

ElecConnector.get_output = func {
   return me.output;
}

ElecConnector.get_switch = func {
    # switch is optional, on by default
    if( me.prop == "" ) {
        switch = constant.TRUE;
    }
    else {
        switch = getprop(me.prop);
    }

    return switch;
}
