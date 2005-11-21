# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron

# current nasal version doesn't accept :
# - more than multiplication on 1 line.
# - variable with hyphen or underscore.
# - boolean (can only test IF TRUE); replaced by strings.
# - object oriented classes.


# =====================
# CABINE PRESSURIZATION
# =====================

# human physiology tolerates 18 mbar per minute until 8000 ft.
PRESSURIZEMBARPM = 18.0;
# 18 mbar/minute = 0.53 inhg/minute
PRESSURIZEINHGPM = PRESSURIZEMBARPM * MBARTOINHG;
# sampling
PRESSURIZESEC = 5.0;
PRESSURIZEMBAR = PRESSURIZEMBARPM / ( 60 / PRESSURIZESEC );
PRESSURIZEINHG = PRESSURIZEMBAR * MBARTOINHG;
# max descent speed around 6000 feet/minute.
PRESSURIZEFTPM = 7000.0 / ( 60 / PRESSURIZESEC );
# 8000 ft (standard atmosphere)
PRESSURIZEMININHG = 22.25;
PRESSURIZEMAXFT = 8000.0;


# leak when no pressurization
cabineleak = func {
   # ignored !
}

# cabine altitude meter
cabineftschedule = func {
   outputvolt =  getprop("/systems/electrical/outputs/specific");
   if( outputvolt != nil ) {
       if( getprop("/systems/pressurization/serviceable") and outputvolt > 20 and
           getprop("/systems/air-bleed/pressure-psi") >= 35 ) { 
           lastaltft = getprop("/systems/pressurization/altitude-sea-ft");
           aglft = getprop("/position/altitude-agl-ft");
           altseaft = getprop("/position/altitude-ft");
           seainhg = getprop("/environment/pressure-sea-level-inhg");
           pressureinhg = getprop("/environment/pressure-inhg");
           cabineinhg = getprop("/instrumentation/cabine-altitude/cabine-inhg");

   # filters startup
           if( aglft == nil or altseaft == nil or seainhg == nil or pressureinhg == nil ) {
               aglft = 0.0;
               altseaft = 0.0;
               seainhg = 29.92;
               pressureinhg = 29.92;

               targetinhg = 29.92;
               outflowinhg = 0.0;

               startup = "true";
           }

           # pressurization curve has a lower slope than aircraft descent/climb profile
           else {
               speedup = getprop("/sim/speed-up");

               # 11 ft AGL on ground (Z height of center of gravity minus Z height of main landing gear)
               aglft = aglft - 11.0;

               if( aglft > 2500.0 ) {
                   # average vertical speed of 2000 feet/minute
                   minutes = altseaft / 2000.0;
                   minutes = minutes * speedup;
                   targetinhg = seainhg - minutes * PRESSURIZEINHGPM;
                   if( targetinhg < PRESSURIZEMININHG ) {
                       targetinhg = PRESSURIZEMININHG;
                   }
               }

               # radio altimeter works below 2500 feet
               else {
                   # average landing speed of 1500 feet/minute
                   minutes = ( altseaft - aglft ) / 1500.0;
                   minutes = minutes * speedup;
                   targetinhg = seainhg - minutes * PRESSURIZEINHGPM;
                   if( targetinhg < PRESSURIZEMININHG ) {
                       targetinhg = PRESSURIZEMININHG;
                   }
               }

               startup = "false";
           }

           # ==========
           # real modes
           # ==========
           if( startup != "true" ) {
               outflowinhg = targetinhg - cabineinhg;
               if( cabineinhg < targetinhg ) {
                   if( outflowinhg > PRESSURIZEINHG ) {
                       outflowinhg = PRESSURIZEINHG;
                   }
                   cabineinhg = cabineinhg + outflowinhg;
               }
               elsif( cabineinhg > targetinhg ) {
                   if( outflowinhg < -PRESSURIZEINHG ) {
                       outflowinhg = -PRESSURIZEINHG;
                   }
                   cabineinhg = cabineinhg + outflowinhg;
               }
               # balance
               else {
                   outflowinhg = 0;
                   cabineinhg = targetinhg;
               }
           }

           # one supposes instrument calibrated by standard atmosphere
           if( outflowinhg != 0 or cabineinhg > PRESSURIZEMININHG ) {
               interpol = "true";
           }

           # above 8000 ft
           else {
               interpol = "false";
           }

           # ================
           # artificial modes
           # ================
           # relocation in flight
           if( startup != "true" ) {
               variationftpm = lastaltft - altseaft;
               if( variationftpm < -PRESSURIZEFTPM or variationftpm > PRESSURIZEFTPM ) {
                   outflowinhg = 0.0;
                   cabineinhg = targetinhg;
                   interpol = "true";        
               }
               # relocation on ground (change of airport)
               elsif( aglft < 1.0 ) {
                   outflowinhg = 0.0;
                   targetinhg = pressureinhg;
                   cabineinhg = targetinhg;
                   interpol = "true";
               }
           }

           setprop("/systems/pressurization/atmosphere-inhg",pressureinhg);
           setprop("/systems/pressurization/target-inhg",targetinhg);
           setprop("/systems/pressurization/outflow-inhg",outflowinhg);
           setprop("/systems/pressurization/altitude-sea-ft",altseaft);

           if( interpol != "true" ) {
               cabineinhg = PRESSURIZEMININHG;
           }
           cabinealtitude( cabineinhg );        
       }

       # leaks
       else {
           cabineleak();
       }


       # instrumentation
       diffpressure();
   }
}


# =========
# AIR BLEED
# =========

# detects loss of all engines
airbleedschedule = func {
   if( getprop("/systems/air-bleed/serviceable") ) {
       engines = props.globals.getNode("/engines/").getChildren("engine");
       valves = props.globals.getNode("/controls/pneumatic/").getChildren("engine");
       # or all bleed valves shut
       if( ( engines[0].getChild("running").getValue() and
             valves[0].getChild("bleed-valve").getValue() ) or
           ( engines[1].getChild("running").getValue() and
             valves[1].getChild("bleed-valve").getValue() ) or
           ( engines[2].getChild("running").getValue() and
             valves[2].getChild("bleed-valve").getValue() ) or
           ( engines[3].getChild("running").getValue() and
             valves[3].getChild("bleed-valve").getValue() ) ) {
           pressurepsi = 65.0;
       }
       else {
           groundpsi = getprop("/systems/air-bleed/ground-service-psi");
           if( groundpsi != nil ) {
               pressurepsi = groundpsi;
           }
           else {
               pressurepsi = 0.0;
           }
       }
    }
    else {
       pressurepsi = 0.0;
    }

    setprop("/systems/air-bleed/pressure-psi",pressurepsi);

    cabineftschedule();
}
