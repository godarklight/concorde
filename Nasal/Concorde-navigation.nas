# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ==========================
# INERTIAL NAVIGATION SYSTEM
# ==========================

Inertial = {};

Inertial.new = func {
   var obj = { parents : [Inertial,System],

           inss : nil,
           last : nil,
           route : nil,
           waypoints : nil,

           SELECTORGROUND : -3,
           SELECTORHEADING : -2,
           SELECTORTRACK : -1,
           SELECTORPOS : 0,
           SELECTORWPTPOS : 1,
           SELECTORWPTTIME : 2,
           SELECTORWIND : 3,
           SELECTORSTATUS : 4,

           MODEOFF : -2,
           MODEALIGN : 0,
           MODENAV : 1,
           MODEATT : 2,

           QUALITYPOOR : 9,
           QUALITYREADY : 5,
           QUALITYGOOD : 1,

           ACTIONGROUND : 4,
           ACTIONATT : 2,
           ACTIONOFF : 0,

           ALIGNEDSEC : 900,                                # 15 minutes
           QUALITYSEC : 225,
           INSSEC : 3,

           GROUNDFT : 20,

           GROUNDKT : 75,

           MAXWPTNM : 9999.0,
           MAXXTKNM : 999.99,

           UNKNOWN : -999,

           bearingdeg : 0.0,
           trackdeg : 0.0,

           waypoint : ""
         };

   obj.init();

   return obj;
};

Inertial.init = func {
   me.inss = props.globals.getNode("/instrumentation").getChildren("ins");

   me.init_ancestor("/instrumentation/ins[0]");

   me.last = me.slave["autopilot"].getChild("wp-last");
   me.waypoints = me.slave["autopilot"].getChildren("wp");
}

Inertial.red_ins = func {
   var result = constant.FALSE;

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        if( me.inss[i].getNode("light/warning").getValue() ) {
            result = constant.TRUE;
            break;
        }
   }

   return result;
}

Inertial.schedule = func {
   var ACvoltage = me.slave["electric"].getChild("specific").getValue();

   if( ACvoltage ) {
       me.track();
       me.display();
       me.alertlight();
   } 

   me.alignment();

   me.failure();
}

Inertial.computeexport = func {
   if( me.slave["electric"].getChild("specific").getValue() ) {
       me.display();
   } 
}

Inertial.alertlight = func {
   var value = 0.0;
   var speedfps = 0.0;
   var rangenm = 0.0;
   var alert = constant.FALSE;

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        value = me.waypoints[0].getChild("dist").getValue();
        if( value != nil and value != "" ) {
            speedfps = me.inss[i].getNode("computed/ground-speed-fps").getValue();
            rangenm = speedfps * constant.MINUTETOSECOND * constant.FEETTONM;

            # alert 1 minute before track change
            if( value < rangenm ) {
                alert = constant.TRUE;
            }
        } 

        # send to all remote INS
        me.inss[i].getNode("light/alert").setValue(alert);
   }
}

Inertial.display = func {
   var aligned = constant.FALSE;
   var selector = 0;
   var nbwaypoints = 0;
   var j = 0;
   var digit = 0;
   var pos = 0;
   var left = 0.0;
   var right = 0.0;
   var value = 0.0;
   var value_str = "";
   var last_ident = "";
   var node = nil;
   var latdeg = me.noinstrument["position"].getChild("latitude-deg").getValue();
   var londeg = me.noinstrument["position"].getChild("longitude-deg").getValue();


   # may input waypoints
   me.route = me.slave["autopilot"].getNode("route").getChildren("wp");
   nbwaypoints = me.slave["autopilot"].getNode("route/num").getValue();

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        selector = me.inss[i].getNode("control/selector").getValue();
        aligned = me.inss[i].getNode("msu/aligned").getValue();

        left = me.UNKNOWN;
        right = me.UNKNOWN;

        # present track
        if( selector == me.SELECTORGROUND ) {
            right = me.inss[i].getNode("computed/ground-speed-fps").getValue() * constant.FPSTOKT;

            if( right < me.GROUNDKT ) {
                left = me.noinstrument["true"].getValue();
            }
            else {
                left = me.trackdeg;
            }
        }

        # cross track distance
        elsif( selector == me.SELECTORHEADING ) {
            left = me.noinstrument["true"].getValue();
        }

        # cross track distance
        elsif( selector == me.SELECTORTRACK ) {
            left = me.inss[i].getNode("computed/leg-course-error-nm").getValue();
            right = me.inss[i].getNode("computed/leg-course-deviation-deg").getValue();
        }

        # current position
        elsif( selector == me.SELECTORPOS ) {
            if( aligned ) {
                left = latdeg;
                right = londeg;
            }
        }

        # waypoint
        elsif( selector >= me.SELECTORWPTPOS and selector <= me.SELECTORWPTTIME ) {
            j = me.inss[i].getNode("control/waypoint").getValue();
  
            if( j <= nbwaypoints ) {
                j = j - 1;
                node = me.route[j];

                # position
                if( selector == me.SELECTORWPTPOS ) {
                    left = node.getChild("latitude-deg").getValue();
                    right = node.getChild("longitude-deg").getValue();
                }

                # distance and time.
                elsif( aligned ) {
                    node = nil;

                    # only the first 2 waypoints.
                    if( j < 2 ) {
                        node = me.waypoints[j];
                    }

                    # search for last one.
                    else {
                        last_ident = me.last.getChild("id").getValue();

                        for( var k = 0; k < nbwaypoints; k = k+1 ) {
                             if( me.route[k].getChild("id").getValue() == last_ident ) {
                                 # only if displays the last one.
                                 if( k == j ) {
                                     node = me.last;
                                 }
                                 break;
                             }
                        }
                    }

                    if( node != nil ) {
                        value = node.getChild("dist").getValue();

                        # node doesn't exist, if no waypoint yet.
                        if( value !=  nil ) {
                            if( value > me.MAXWPTNM ) {
                                value = me.MAXWPTNM;
                            }

                            left = value;

                            # replace 99:59 by 99.59, because the right display is a double.
                            value_str = node.getChild("eta").getValue();

                            pos = find(":",value_str);
                            if( pos >= 0 ) {
                                value = num(substr( value_str, 0, pos ));
                                pos = pos + 1;
                                value_str = substr( value_str, pos, size( value_str ) - pos );
                                value = value + num(value_str) * constant.MINUTETODECIMAL;
                            }
                            else {
                                value = 0.0;
                            }

                            right = value;
                        }
                    }
                }
            }
        }

        # wind
        elsif( selector == me.SELECTORWIND ) {
            if( me.slave["radio-altimeter"].getChild("indicated-altitude-ft").getValue() > me.GROUNDFT ) {
                left = me.inss[i].getNode("computed/wind-from-heading-deg").getValue();
                right = me.inss[i].getNode("computed/wind-speed-kt").getValue();
            }
        }

        # desired track & status
        elsif( selector == me.SELECTORSTATUS ) {
            left = me.inss[i].getNode("computed/leg-true-course-deg").getValue();

            right = 0;
            digit = 1;

            for( var k = 5; k >= 0; k = k-1 ) {
                 value = me.inss[i].getNode("msu/status[" ~ k ~ "]").getValue() * digit;
                 right += value;
                 digit *= 10;
            }
        }

        me.inss[i].getNode("data/left").setValue(left);
        me.inss[i].getNode("data/right").setValue(right);
   }
}

Inertial.track = func {
   var offsetdeg = 0.0;
   var offsetrad = 0.0;
   var distancenm = 0.0;
   var offsetnm = 0.0;
   var id = me.waypoints[0].getChild("id").getValue();

   # new waypoint
   if( id != me.waypoint and id != nil ) {
       me.waypoint = id;

       # initial track
       me.bearingdeg = me.noinstrument["track"].getValue();
       for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
            me.inss[i].getNode("computed/leg-true-course-deg").setValue(me.bearingdeg);
       }
   }

   # deviation from initial track
   if( me.waypoint != "" ) {
       me.trackdeg = me.noinstrument["track"].getValue();
       offsetdeg = me.trackdeg - me.bearingdeg;
       offsetdeg = constant.crossnorth( offsetdeg );

       distancenm = me.waypoints[0].getChild("dist").getValue();
       offsetrad = offsetdeg * constant.DEGTORAD;
       offsetnm = math.sin( offsetrad ) * distancenm;

       if( offsetnm > me.MAXXTKNM ) {
           offsetnm = me.MAXXTKNM;
       }
       elsif( offsetnm < - me.MAXXTKNM ) {
           offsetnm = - me.MAXXTKNM;
       }

       for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
            me.inss[i].getNode("computed/leg-course-deviation-deg").setValue(offsetdeg);
            me.inss[i].getNode("computed/leg-course-error-nm").setValue(offsetnm);
       }
   }
}

Inertial.failure = func {
   var warning = constant.FALSE;

   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        if( !me.inss[i].getChild("serviceable").getValue() or
            !me.inss[i].getNode("msu/aligned").getValue() ) {
            warning = constant.TRUE;
        }
        else {
            warning = constant.FALSE;
        }

        me.inss[i].getNode("light/warning").setValue( warning );
   }
}

Inertial.alignment = func {
   var mode = 0;
   var aligned = constant.FALSE;
   var ready = constant.FALSE;
   var alignmentsec = 0.0;
   var step = 0.0;
   var quality = 0.0;
   var speedup = 0.0;


   for( var i = 0; i < constantaero.NBINS; i = i+1 ) {
        mode = me.inss[i].getNode("msu/mode").getValue();
        aligned = me.inss[i].getNode("msu/aligned").getValue();
        ready = me.inss[i].getNode("msu/ready").getValue();

        if( mode == me.MODEALIGN or mode == me.MODENAV ) {
            # start new alignment
            if( mode == me.MODEALIGN ) {
                if( aligned and !ready ) {
                    aligned = constant.FALSE;
                    me.lose_alignment( i, mode );
                }
            }

            # during alignment in NAV mode, ready light is on momentarily.
            elsif( mode == me.MODENAV ) {
                if( aligned and ready ) {
                    me.reach_ready( i );
                }
            }

            # alignment in ALIGN or NAV mode.
            if( !aligned or ( aligned and mode == me.MODEALIGN ) ) {
                alignmentsec = me.inss[i].getNode("msu/alignment-s").getValue();

                # ready
                if( alignmentsec >= me.ALIGNEDSEC ) {
                   aligned = constant.TRUE;
                   me.reach_alignment( i );
                }
                else {
                   me.aligning( i );
                }

                # quality measured only during alignment
                step = ( alignmentsec - math.mod( alignmentsec, me.QUALITYSEC ) ) / me.QUALITYSEC; 
                quality = me.QUALITYPOOR - step;
                if( quality < me.QUALITYGOOD ) {
                    quality = me.QUALITYGOOD;
                }

                me.set_quality( i, quality );

                speedup = getprop("/sim/speed-up");
                alignmentsec = alignmentsec + speedup * me.INSSEC;
                me.inss[i].getNode("msu/alignment-s").setValue( alignmentsec );
            }
        }

        # alignment is lost.
        else {
            me.lose_alignment( i, mode );
        }
   }
}

Inertial.reach_ready = func( index ) {
   me.inss[index].getNode("msu/ready").setValue( constant.FALSE );
}

Inertial.aligning = func( index ) {
   me.set_mode( index, me.MODEALIGN );
   me.set_action( index, me.ACTIONGROUND );
}

Inertial.reach_alignment = func( index ) {
   me.inss[index].getNode("msu/aligned").setValue( constant.TRUE );
   me.inss[index].getNode("msu/ready").setValue( constant.TRUE );

   me.set_mode( index, me.MODENAV );
}

Inertial.lose_alignment = func( index, mode ) {
   me.inss[index].getNode("msu/alignment-s").setValue( 0 );
   me.inss[index].getNode("msu/aligned").setValue( constant.FALSE );
   me.inss[index].getNode("msu/ready").setValue( constant.FALSE );

   me.set_mode( index, me.MODEALIGN );
   if( mode == me.MODEATT ) {
       me.set_action( index, me.ACTIONATT );
   }
   elsif( mode == me.MODEOFF ) {
       me.set_action( index, me.ACTIONOFF );
   }
   me.set_quality( index, me.QUALITYPOOR );
   me.set_index( index, me.QUALITYREADY );
}

Inertial.set_mode = func( index, mode ) {
   me.inss[index].getNode("msu/status[0]").setValue( mode );
}

Inertial.set_action = func( index, action ) {
   var digit = int( action / 10 );

   me.inss[index].getNode("msu/status[1]").setValue( digit );

   digit = math.mod( action, 10 );
   me.inss[index].getNode("msu/status[2]").setValue( digit );
}

Inertial.set_quality = func( index, quality ) {
   me.inss[index].getNode("msu/status[4]").setValue( quality );
}

Inertial.set_index = func( index, modeindex ) {
   me.inss[index].getNode("msu/status[5]").setValue( modeindex );
}


# =================
# AIR DATA COMPUTER
# =================

AirDataComputer = {};

AirDataComputer.new = func {
   var obj = { parents : [AirDataComputer,System],

               adcs : nil
             };

   obj.init();

   return obj;
};

AirDataComputer.init = func {
   me.init_ancestor("/instrumentation/adc[0]");

   me.adcs = props.globals.getNode("/instrumentation").getChildren("adc");
}

AirDataComputer.amber_adc = func {
    var result = constant.FALSE;

    if( !me.slave["electric"].getChild("specific").getValue() ) {
        result = constant.TRUE;
    }

    return result;
}

AirDataComputer.red_ads = func {
    var result = constant.FALSE;

    for( var i = 0; i < constantaero.NBAUTOPILOTS; i = i+1 ) {
         if( !me.adcs[i].getChild("serviceable").getValue() ) {
             result = constant.TRUE;
         }
    }

    return result;
}

AirDataComputer.schedule = func {
}
