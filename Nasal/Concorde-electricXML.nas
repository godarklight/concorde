# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =================
# ELECTRICAL PARSER
# =================
ElectricalXML = {};

ElectricalXML.new = func {
   var obj = { parents : [ElectricalXML],

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
   var children = nil;
   var nb_children = 0;
   var component = nil;

   me.config = props.globals.getNode("/systems/electrical/internal/config");
   me.electrical = props.globals.getNode("/systems/electrical");
   me.forced = props.globals.getNode("/systems/electrical/internal/iterations-forced").getValue();
   me.iterations = props.globals.getNode("/systems/electrical/internal/iterations");

   children = me.config.getChildren("supplier");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_supplier( children[i] );
        component = me.components.get_supplier( i );
        component.charge();
   }

   children = me.config.getChildren("bus");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_bus( children[i] );
        component = me.components.get_bus( i );
        component.charge();
   }

   children = me.config.getChildren("output");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.components.add_output( children[i] );
        component = me.components.get_output( i );
        component.charge();
   }

   children = me.config.getChildren("connector");
   nb_children = size( children );
   for( var i = 0; i < nb_children; i = i+1 ) {
        me.connectors.add( children[i] );
   }
}

# battery discharge
ElectricalXML.slowschedule = func {
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.discharge();
   }
}

ElectricalXML.schedule = func {
   var component = nil;
   var iter = 0;
   var remain = constant.FALSE;

   me.clear();

   # suppliers, not real, always works
   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.supply();
   }

   if( me.electrical.getChild("serviceable").getValue() ) {
        iter = 0;
        remain = constant.TRUE;
        while( remain ) {
            remain = constant.FALSE;
            for( var i = 0; i < me.connectors.count(); i = i+1 ) {
                 component = me.connectors.get( i );
                 if( !me.supply( component ) ) {
                     remain = constant.TRUE;
                 }
            }
            iter = iter + 1;
       }

       # makes last iterations for voltages in parallel
       for( var j = 0; j < me.forced; j = j+1 ) {
            for( var i = 0; i < me.connectors.count(); i = i+1 ) {
                 component = me.connectors.get( i );
                 me.supply( component );
            }
            iter = iter + 1;
       }

       me.iterations.setValue(iter);
   }

   # failure : no voltage
   else {
       for( var i = 0; i < me.components.count_bus(); i = i+1 ) {
            component = me.components.get_bus( i );
            component.propagate();
       }

       for( var i = 0; i < me.components.count_output(); i = i+1 ) {
            component = me.components.get_output( i );
            component.propagate();
       }
   }

   me.apply();
}

ElectricalXML.supply = func( connector ) {
   var volts = 0.0;
   var found = constant.FALSE;
   var switch = constant.FALSE;
   var input = nil;
   var component = nil;
   var component2 = nil;
   var output = nil;

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
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.apply();
   }

   for( var i = 0; i < me.components.count_bus(); i = i+1 ) {
        component = me.components.get_bus( i );
        component.apply();
   }

   for( var i = 0; i < me.components.count_output(); i = i+1 ) {
        component = me.components.get_output( i );
        component.apply();
   }
}

ElectricalXML.clear = func {
   var component = nil;

   for( var i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.clear();
   }

   for( var i = 0; i < me.components.count_bus(); i = i+1 ) {
        component = me.components.get_bus( i );
        component.clear();
   }

   for( var i = 0; i < me.components.count_output(); i = i+1 ) {
        component = me.components.get_output( i );
        component.clear();
   }
}


# ===============
# COMPONENT ARRAY
# ===============

ElecComponentArray = {};

ElecComponentArray.new = func {
   var obj = { parents : [ElecComponentArray],

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
   var state = "";
   var rpm = "";
   var charge = "";
   var amps = 0;
   var result = nil;
   var name = node.getChild("name").getValue();
   var kind = node.getChild("kind").getValue();
   var volts = node.getChild("volts").getValue();

   append(me.supplier_name, name);

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

   result = ElecSupplier.new( kind, state, rpm, volts, charge, amps );
   append(me.suppliers, result);

   me.nb_suppliers = me.nb_suppliers + 1;
}

ElecComponentArray.add_bus = func( node ) {
   var result = nil;
   var name = node.getChild("name").getValue();
   var allprops = node.getChildren("prop");

   append(me.bus_name, name);

   result = ElecBus.new( allprops );
   append(me.buses, result);

   me.nb_buses = me.nb_buses + 1;
}

ElecComponentArray.add_output = func( node ) {
   var result = nil;
   var name = node.getChild("name").getValue();
   var prop = node.getChild("prop").getValue();

   append(me.output_name, name);

   result = ElecOutput.new( prop );
   append(me.outputs, result);

   me.nb_outputs = me.nb_outputs + 1;
}

ElecComponentArray.find_supplier = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_suppliers; i = i+1 ) {
         if( me.supplier_name[i] == ident ) {
             result = me.get_supplier( i );
             break;
         }
    }

    return result;
}

ElecComponentArray.find_bus = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_buses; i = i+1 ) {
         if( me.bus_name[i] == ident ) {
             result = me.get_bus( i );
             break;
         }
    }

    return result;
}

ElecComponentArray.find_output = func( ident ) {
    var result = nil;

    for( var i = 0; i < me.nb_outputs; i = i+1 ) {
         if( me.output_name[i] == ident ) {
             result = me.get_output( i );
             break;
         }
    }

    return result;
}

# lookup tables accelerates the search !!!
ElecComponentArray.find = func( ident ) {
   var found = constant.FALSE;
   var result = me.find_supplier( ident );

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
   var obj = { parents : [ElecComponent],

           NOVOLT : 0.0,

           done : constant.FALSE
         };

   return obj;
};

ElecComponent.init_ancestor = func {
   var obj = ElecComponent.new();

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
   var obj = { parents : [ElecSupplier,ElecComponent],

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
   var value = getprop(me.props);

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
   var obj = { parents : [ElecBus,ElecComponent],

           values : [],

           nb_props : 0,
           props : []
         };

   obj.init( allprops );

   return obj;
};

ElecBus.init = func( allprops ) {
   me.init_ancestor();

   me.nb_props = size( allprops );

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        append( me.props, allprops[i].getValue() );
        append( me.values, me.NOVOLT );
   }
}

# present voltage
ElecBus.get_volts = func {
   var value = me.NOVOLT;

   # takes the 1st property
   if( me.nb_props > 0 ) {
       value = me.values[0];
   }

   if( value == nil ) {
       value = me.NOVOLT;
   }

   return value;
}

# propagates voltage to all properties
ElecBus.propagate = func( component = nil ) {
   var volts = me.NOVOLT;

   if( component != nil ) {
       volts = component.get_volts();
   }

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        me.values[i] = volts;
   }

   me.set_propagate();
}

# reset propagate
ElecBus.clear = func() {
   me.clear_propagate();
}

ElecBus.apply = func {
   var state = "";

   for( var i = 0; i < me.nb_props; i = i+1 ) {
        state = me.props[i];
        setprop(state, me.values[i]);
   }
}


# ======
# OUTPUT
# ======

ElecOutput = {};

ElecOutput.new = func( prop ) {
   var obj = { parents : [ElecOutput,ElecComponent],

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
   var volts = me.NOVOLT;

   if( component != nil ) {
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
   var obj = { parents : [ElecConnectorArray],

           connectors      :  [],
           nb_connectors : 0
         };

   return obj;
};

ElecConnectorArray.add = func( node ) {
   var prop = "";
   var child = nil;
   var result = nil;
   var input = node.getChild("input").getValue();
   var output = node.getChild("output").getValue();
   var switch = node.getNode("switch");

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
   var obj = { parents : [ElecConnector],

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
    var switch = constant.TRUE;

    # switch is optional, on by default
    if( me.prop != "" ) {
        switch = getprop(me.prop);
    }

    return switch;
}
