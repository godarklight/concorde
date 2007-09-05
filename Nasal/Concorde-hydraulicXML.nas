# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ================
# HYDRAULIC PARSER
# ================
HydraulicXML = {};

HydraulicXML.new = func {
   obj = { parents : [HydraulicXML],

           HYDSEC : 1.0,

           config : nil,
           hydraulic : nil,
           iterations : nil,

           components : HydComponentArray.new(),
           connections : HydConnectionArray.new()
         };

   obj.init();

   return obj;
};

# creates all propagate variables
HydraulicXML.init = func {
   me.config = props.globals.getNode("/systems/hydraulic/internal/config");
   me.hydraulic = props.globals.getNode("/systems/hydraulic");
   me.iterations = props.globals.getNode("/systems/hydraulic/internal/iterations");

   suppliers = me.config.getChildren("supplier");
   nb_suppliers = size( suppliers );
   for( i = 0; i < nb_suppliers; i = i+1 ) {
        me.components.add_supplier( suppliers[i], me.HYDSEC );
        component = me.components.get_supplier( i );
        component.fill();
   }

   circuits = me.config.getChildren("circuit");
   nb_circuits = size( circuits );
   for( i = 0; i < nb_circuits; i = i+1 ) {
        me.components.add_circuit( circuits[i], me.HYDSEC );
        component = me.components.get_circuit( i );
        component.fill();
   }

   connections = me.config.getChildren("connection");
   nb_connections = size( connections );
   for( i = 0; i < nb_connections; i = i+1 ) {
        me.connections.add( connections[i] );
   }
}

HydraulicXML.set_rate = func( rates ) {
    me.HYDSEC = rates;
}

HydraulicXML.schedule = func {
   me.clear();

   # suppliers, not real, always works
   for( i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.pressurize();
   }

   if( me.hydraulic.getChild("serviceable").getValue() ) {
        iter = 0;
        remain = constant.TRUE;
        while( remain ) {
            remain = constant.FALSE;
            for( i = 0; i < me.connections.count(); i = i+1 ) {
                 connection = me.connections.get( i );
                 if( !me.pressurize( connection ) ) {
                     remain = constant.TRUE;
                 }
            }
            iter = iter + 1;
       }

       me.iterations.setValue(iter);
   }

   # failure : no pressure
   else {
       for( i = 0; i < me.components.count_circuit(); i = i+1 ) {
            component = me.components.get_circuit( i );
            component.propagate();
       }
   }

   me.apply();
}

HydraulicXML.pressurize = func( connection ) {
   found = constant.FALSE;

   output = connection.get_output();

   # propagate pressure
   component2 = me.components.find( output );
   if( component2 != nil ) {
       if( !component2.is_propagate() ) {
           switch = connection.get_switch();

            # switch off means no pressure
            if( !switch ) {
                component2.propagate();
                found = constant.TRUE;
            }

            else {
                input = connection.get_input();
                component = me.components.find( input );
                if( component != nil ) {

                    # input knows its pressure
                    if( component.is_propagate() ) {
                        component2.propagate( component );
                        found = constant.TRUE;
                    }
                }
            }
       }

       # already solved
       else {
           switch = connection.get_switch();

           # reservoir can accept pressurization
           if( switch ) {
               input = connection.get_input();
               component = me.components.find( input );
               if( component != nil ) {

                   # input knows its pressure
                   if( component.is_propagate() ) {
                       component2.propagate( component );
                   }
               }
           }

           found = constant.TRUE;
       }
   }

   return found;
}

HydraulicXML.apply = func {
   for( i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.apply();
   }

   for( i = 0; i < me.components.count_circuit(); i = i+1 ) {
        component = me.components.get_circuit( i );
        component.apply();
   }
}

HydraulicXML.clear = func {
   for( i = 0; i < me.components.count_supplier(); i = i+1 ) {
        component = me.components.get_supplier( i );
        component.clear();
   }

   for( i = 0; i < me.components.count_circuit(); i = i+1 ) {
        component = me.components.get_circuit( i );
        component.clear();
   }
}


# ===============
# COMPONENT ARRAY
# ===============

HydComponentArray = {};

HydComponentArray.new = func {
   obj = { parents : [HydComponentArray],

           supplier_name : [],
           circuit_name :  [],

           suppliers : [],
           nb_suppliers : 0,

           circuits : [],
           nb_circuits : 0,
         };

   return obj;
};

HydComponentArray.add_supplier = func( node, rates ) {
   name = node.getChild("name").getValue();
   append(me.supplier_name, name);

   kind = node.getChild("kind").getValue();
   prop = node.getChild("prop").getValue();

   source = "";
   factor = 0;
   minpsi = 0;
   psi = 0;
   galus = 0;

   if( kind == "pump" ) {
       source = node.getChild("psi-source").getValue();
       factor = node.getChild("factor").getValue();
       minpsi = node.getChild("min-psi").getValue();
       psi = node.getChild("psi").getValue();
   }

   elsif( kind == "reservoir" ) {
       prop = node.getChild("prop").getValue();
       galus = node.getChild("gal_us").getValue();
   }


   result = HydSupplier.new( kind, prop, source, factor, minpsi, psi, galus, rates );
   append(me.suppliers, result);

   me.nb_suppliers = me.nb_suppliers + 1;
}

HydComponentArray.add_circuit = func( node, rates ) {
   name = node.getChild("name").getValue();
   append(me.circuit_name, name);

   allprops = node.getChildren("prop");
   galus = node.getChild("gal_us");

   result = HydCircuit.new( galus, allprops, rates );
   append(me.circuits, result);

   me.nb_circuits = me.nb_circuits + 1;
}

HydComponentArray.find_supplier = func( ident ) {
    result = nil;

    for( i = 0; i < me.nb_suppliers; i = i+1 ) {
         if( me.supplier_name[i] == ident ) {
             result = me.get_supplier( i );
             break;
         }
    }

    return result;
}

HydComponentArray.find_circuit = func( ident ) {
    result = nil;

    for( i = 0; i < me.nb_circuits; i = i+1 ) {
         if( me.circuit_name[i] == ident ) {
             result = me.get_circuit( i );
             break;
         }
    }

    return result;
}

# lookup tables accelerates the search !!!
HydComponentArray.find = func( ident ) {
   found = constant.FALSE;
   result = me.find_supplier( ident );

   if( result == nil ) {
       result = me.find_circuit( ident );
   }

   if( result != nil ) {
       found = constant.TRUE;
   }

   if( !found ) {
       print("Hydraulic : component not found ", ident);
   }

   return result;
}

HydComponentArray.count_supplier = func {
   return me.nb_suppliers;
}

HydComponentArray.count_circuit = func {
   return me.nb_circuits;
}

HydComponentArray.get_supplier = func( index ) {
   return me.suppliers[ index ];
}

HydComponentArray.get_circuit = func( index ) {
   return me.circuits[ index ];
}


# =========
# COMPONENT
# =========

# for inheritance, the component must be the last of parents.
HydComponent = {};

# not called by child classes !!!
HydComponent.new = func {
   obj = { parents : [HydComponent],

           HYDSEC : 1.0,

           NOGALUS : 0.0,

           NOPSI : 0.0,

           done : constant.FALSE
         };

   return obj;
};

HydComponent.init_ancestor = func {
   obj = HydComponent.new();

   me.NOGALUS = obj.NOGALUS;
   me.NOPSI = obj.NOPSI;
}

HydComponent.set_rate = func( rates ) {
   me.HYDSEC = rates;
}

# is pressure known ?
HydComponent.is_propagate = func {
   return me.done;
}

# fills reservoir
HydComponent.fill = func {
} 

# pressurize circuit
HydComponent.pressurize = func {
} 

# propagates pressure to all properties
HydComponent.propagate = func( component = nil ) {
}

# reset propagate
HydComponent.clear = func() {
   me.clear_propagate();
}

HydComponent.clear_propagate = func {
   me.done = constant.FALSE;
}

HydComponent.set_propagate = func {
   me.done = constant.TRUE;
}

HydComponent.inertia = func( prop, value ) {
   result = getprop(prop);
   if( result != value ) {
       interpolate(prop, value, me.HYDSEC);
   }
}


# ========
# SUPPLIER 
# ========

HydSupplier = {};

HydSupplier.new = func( kind, prop, source, factor, minpsi, psi, galus, rates ) {
   obj = { parents : [HydSupplier,HydComponent],

           value : 0.0,

           kind : kind,
           props : prop,
           source : source,
           factor : factor,
           minpsi : minpsi,
           psi : psi,
           galus : galus
         };

   obj.init( rates );

   return obj;
};

HydSupplier.init = func( rates ) {
   me.init_ancestor();

   me.set_rate( rates );
}

HydSupplier.get_psi = func {
   if( me.kind == "reservoir" ) {
       result = me.NOPSI;
   }
   elsif( me.kind == "pump" ) {
       result = me.value;
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }

   return result;
}

HydSupplier.get_galus = func {
   if( me.kind == "reservoir" ) {
       result = me.value;
   }
   elsif( me.kind == "pump" ) {
       result = me.NOGALUS;
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }

   return result;
}

HydSupplier.fill = func {
   if( me.kind == "reservoir" ) {
       me.value = me.galus;
       me.set_propagate();
   }

   elsif( me.kind == "pump" ) {
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }
}

HydSupplier.pressurize = func {
   if( me.kind == "reservoir" ) {
   }

   elsif( me.kind == "pump" ) {
       me.value = getprop(me.source);
       me.value = me.value * me.factor;

       if( me.value > me.psi ) {
           me.value = me.psi;
       }
       elsif( me.value < me.minpsi ) {
           me.value = me.NOPSI;
       }

       me.set_propagate();
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }
} 

HydSupplier.clear = func() {
   if( me.kind == "reservoir" ) {
   }

   elsif( me.kind == "pump" ) {
       me.clear_propagate();
   }

   else {
       print("Hydraulic : supplier not found ", me.kind);
   }
}

HydSupplier.apply = func {
   me.inertia(me.props, me.value);
}


# =======
# CIRCUIT
# =======

HydCircuit = {};

HydCircuit.new = func( contentnode, allprops, rates ) {
   obj = { parents : [HydCircuit,HydComponent],

           contentgalus : 0.0,

           RESERVOIRCOEF : 0.8,

           contentprop : "",

           values : [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0],

           MAXPROPS : 10,

           nb_props : 0,
           props : ["","","","","","","","","",""]
         };

   obj.init( contentnode, allprops, rates );

   return obj;
};

HydCircuit.init = func( contentnode, allprops, rates ) {
   me.init_ancestor();

   me.set_rate( rates );

   if( contentnode != nil ) {
       me.contentprop = contentnode.getValue();
   }

   me.nb_props = size( allprops );
   if( me.nb_props > me.MAXPROPS ) {
       print( "Hydraulic: number of properties exceeded ! ", me.nb_props );
       me.nb_props = me.MAXPROPS;
   }

   for( i = 0; i < me.nb_props; i = i+1 ) {
        me.props[ i ] = allprops[i].getValue();
   }
}

HydCircuit.get_psi = func {
   # takes the 1st property
   return me.values[0];
}

HydCircuit.get_galus = func {
   return me.contentgalus;
}

# propagates pressure to all properties
HydCircuit.propagate = func( component = nil ) {
   if( component == nil ) {
       psi = me.NOPSI;
       galus = me.NOGALUS;
   }
   else {
       psi = component.get_psi();
       galus = component.get_galus();
   }

   if( me.contentgalus < galus ) {
       me.contentgalus = galus;
   }

   # pressurization with 2 circuits
   if( me.values[0] > me.NOPSI and psi > me.NOPSI ) {
       # at full load, reservoir decreases
       me.contentgalus = me.contentgalus * me.RESERVOIRCOEF;
   }

   # pressurization requires a reservoir
   if( me.contentgalus > me.NOGALUS ) {
       for( i = 0; i < me.nb_props; i = i+1 ) {
            if( me.values[i] < psi ) {
                me.values[i] = psi;
            }
        }
   }

   me.set_propagate();
}

HydCircuit.clear = func() {
   me.contentgalus = me.NOGALUS;

   for( i = 0; i < me.nb_props; i = i+1 ) {
        me.values[i] = me.NOPSI;
   }
   
   me.clear_propagate();
}

HydCircuit.apply = func {
   if( me.contentprop != "" ) {
        me.inertia( me.contentprop, me.contentgalus );
   }

   for( i = 0; i < me.nb_props; i = i+1 ) {
        me.inertia( me.props[i], me.values[i] );
   }
}


# ================
# CONNECTION ARRAY
# ================

HydConnectionArray = {};

HydConnectionArray.new = func {
   obj = { parents : [HydConnectionArray],

           connections : [],
           nb_connections : 0
         };

   return obj;
};

HydConnectionArray.add = func( node ) {
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

   result = HydConnection.new( input, output, prop );
   append(me.connections, result);

   me.nb_connections = me.nb_connections + 1;
}

HydConnectionArray.count = func {
   return me.nb_connections;
}

HydConnectionArray.get = func( index ) {
   return me.connections[ index ];
}


# ==========
# CONNECTION
# ==========

HydConnection = {};

HydConnection.new = func( input, output, prop ) {
   obj = { parents : [HydConnection],

           input : input,
           output : output,
           prop : prop
         };

   return obj;
};

HydConnection.get_input = func {
   return me.input;
}

HydConnection.get_output = func {
   return me.output;
}

HydConnection.get_switch = func {
    # switch is optional, on by default
    if( me.prop == "" ) {
        switch = constant.TRUE;
    }
    else {
        switch = getprop(me.prop);
    }

    return switch;
}
