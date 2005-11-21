# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron


# current nasal version doesn't accept :
# - more than multiplication on 1 line.
# - variable with hyphen or underscore.
# - boolean (can only test IF TRUE); replaced by strings.
# - object oriented classes.

# ================
# HYDRAULIC SYSTEM
# ================

HYDENGINEPSI = 34.0;                           # engine oil pressure to get hydraulic pressure
HYDNORMALPSI = 4000.0;                         # normal hydraulic pressure
HYDRATGREENPSI = 3850.0;                       # RAT green hydraulic pressure
HYDRATYELLOWPSI = 3500.0;                      # RAT yellow hydraulic pressure
HYDFAILUREPSI = 3400.0;                        # abnormal hydraulic pressure
HYDNOPSI = 0.0;
HYDCOEF = HYDFAILUREPSI / HYDENGINEPSI;
HYDRATKT = 150;                                # speed to get hydraulic pressure by RAT (can land)

# hydraulic system
hydraulicschedule = func {
   circuits = props.globals.getNode("/systems/hydraulic/circuits/").getChildren("circuit");
   if( getprop("/systems/hydraulic/serviceable") ) { 
       engines = props.globals.getNode("/engines/").getChildren("engine");
       # not named controls, otherwise lost controls.setFlaps() !!
       control = props.globals.getNode("/controls/hydraulic/circuits/").getChildren("circuit");

       rat = getprop("/systems/hydraulic/rat/deployed");
       if( rat == "on" ) {
           speedkt = getprop("/velocities/airspeed-kt");
       }

       oil1psi = HYDNOPSI;
       if( engines[0].getChild("running").getValue() or
           engines[0].getChild("starter").getValue() ) {
           oil1psi = engines[0].getChild("oil-pressure-psi").getValue();
           if( oil1psi == nil ) {
               oil1psi = HYDNOPSI;
           }
       }
       oil2psi = HYDNOPSI;
       if( engines[1].getChild("running").getValue() or
           engines[1].getChild("starter").getValue() ) {
           oil2psi = engines[1].getChild("oil-pressure-psi").getValue();
           if( oil2psi == nil ) {
               oil2psi = HYDNOPSI;
           }
       }
       oil3psi = HYDNOPSI;
       if( engines[2].getChild("running").getValue() or
           engines[2].getChild("starter").getValue() ) {
           oil3psi = engines[2].getChild("oil-pressure-psi").getValue();
           if( oil3psi == nil ) {
               oil3psi = HYDNOPSI;
           }
       }
       oil4psi = HYDNOPSI;
       if( engines[3].getChild("running").getValue() or
           engines[3].getChild("starter").getValue() ) {
           oil4psi = engines[3].getChild("oil-pressure-psi").getValue();
           if( oil4psi == nil ) {
               oil4psi = HYDNOPSI;
           }
       }

       # green : engines 1 & 2 and RAT
       pressurepsi = HYDNOPSI;
       if( control[0].getChild("onloada").getValue() ) {
           pressurepsi = pressurepsi + HYDCOEF * oil1psi;
       }
       if( control[0].getChild("onloadb").getValue() ) {
           pressurepsi = pressurepsi + HYDCOEF * oil2psi;
       }
       if( rat == "on" ) {
           if( speedkt != nil ) {
               if( speedkt > HYDRATKT ) {
                   pressurepsi = pressurepsi + HYDRATGREENPSI;
               }
           }
       }
       if( pressurepsi >= HYDNORMALPSI ) {
           pressurepsi = HYDNORMALPSI;
       }
       circuits[0].getChild("pressure-psi").setValue(pressurepsi);

       # yellow : engines 2 & 4 and RAT
       pressurepsi = HYDNOPSI;
       if( control[1].getChild("onloada").getValue() ) {
           pressurepsi = pressurepsi + HYDCOEF * oil2psi;
       }
       if( control[1].getChild("onloadb").getValue() ) {
           pressurepsi = pressurepsi + HYDCOEF * oil4psi;
       }
       if( rat == "on" ) {
           if( speedkt != nil ) {
               if( speedkt > HYDRATKT ) {
                   pressurepsi = pressurepsi + HYDRATYELLOWPSI;
               }
           }
       }
       if( pressurepsi >= HYDNORMALPSI ) {
           pressurepsi = HYDNORMALPSI;
       }
       circuits[1].getChild("pressure-psi").setValue(pressurepsi);

       # blue : engines 3 & 4
       pressurepsi = HYDNOPSI;
       if( control[2].getChild("onloada").getValue() ) {
           pressurepsi = pressurepsi + HYDCOEF * oil3psi;
       }
       if( control[2].getChild("onloadb").getValue() ) {
           pressurepsi = pressurepsi + HYDCOEF * oil4psi;
       }
       if( pressurepsi >= HYDNORMALPSI ) {
           pressurepsi = HYDNORMALPSI;
       }
       circuits[2].getChild("pressure-psi").setValue(pressurepsi);
   }


   # failure
   else {
       for( i=0; i <= 2; i=i+1 ) {
            circuits[i].getChild("pressure-psi").setValue(HYDNOPSI);
       }
   }
}

# test RAT
rattestexport = func {
    if( getprop("/systems/hydraulic/rat/test") == "on" ) {
        setprop("/systems/hydraulic/rat/selector[0]/test","");
        setprop("/systems/hydraulic/rat/selector[1]/test","");
        setprop("/systems/hydraulic/rat/test","");
    }
    elsif( getprop("/systems/hydraulic/rat/selector[0]/test") == "on" or
           getprop("/systems/hydraulic/rat/selector[1]/test") == "on" ) {
        setprop("/systems/hydraulic/rat/test","on");

        # shows the light
        settimer(rattestexport, 2.5);
    }
}

# deploy RAT 
ratdeployexport = func {
    if( getprop("/systems/hydraulic/rat/deploying") == "on" ) {
        setprop("/systems/hydraulic/rat/deploying","");
        setprop("/systems/hydraulic/rat/deployed","on");
    }
    elsif( getprop("/systems/hydraulic/rat/selector[0]/on") or 
           getprop("/systems/hydraulic/rat/selector[1]/on") ) {

        if( getprop("/systems/hydraulic/rat/deployed") != "on" and
            getprop("/systems/hydraulic/rat/deploying") != "on" ) {
            setprop("/systems/hydraulic/rat/deploying","on");

            # delay of deployment
            settimer(ratdeployexport, 1.5);
        }
    }
}
