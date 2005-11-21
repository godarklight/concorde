# Like the real Concorde : see http://www.concordesst.com.

# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron

# current nasal version doesn't accept :
# - more than multiplication on 1 line.
# - variable with hyphen or underscore.
# - boolean (can only test IF TRUE); replaced by strings.
# - object oriented classes.


# ==============
# INITIALIZATION
# ==============

# fuel configuration
presetfuel = func {
   # default is 0
   fuel = getprop("/sim/presets/fuel");
   if( fuel == nil ) {
       fuel = 0;
   }
   fillings = props.globals.getNode("/sim/presets/tanks").getChildren("filling");
   if( fuel < 0 or fuel >= size(fillings) ) {
       fuel = 0;
   } 
   presets = fillings[fuel].getChildren("tank");
   tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
   for( i=0; i < size(presets); i=i+1 ) {
        child = presets[i].getChild("level-gal_us");
        if( child != nil ) {
            level = child.getValue();
            tanks[i].getChild("level-gal_us").setValue(level);
        }
   } 
}

# 1 seconds cron
sec1cron = func {
#   feedengineschedulecpp();
   feedengineschedule();
   hydraulicschedule();

   # schedule the next call
   settimer(sec1cron,PUMPSEC);
}

# 3 seconds cron
sec3cron = func {
   tasschedule();
   autopilotschedule();
   tcasschedule();

   # schedule the next call
   settimer(sec3cron,AUTOPILOTSEC);
}

# 5 seconds cron
sec5cron = func {
   vmoktschedule();
   inslightschedule();
   airbleedschedule();

   # schedule the next call
   settimer(sec5cron,PRESSURIZESEC);
}

# 15 seconds cron
sec15cron = func {
   tmodegcschedule();
   insfuelschedule();

   # schedule the next call
   settimer(sec15cron,15);
}

# 30 seconds cron
sec30cron = func {
   bucketdegschedule();
   tankpressureschedule();

   # schedule the next call
   settimer(sec30cron,30);
}

# 60 seconds cron
sec60cron = func {
   # delay to call ground power
   groundserviceschedule();

   # schedule the next call
   settimer(sec60cron,60);
}

# general initialization
init = func {
   initfuel();
   presetfuel();
   initautopilot();

   # schedule the 1st call
#   if( getprop("/instrumentation/inst-vertical-speed-indicator/nasal") ) {
#       settimer(calcverticalfpscron,0);
#   }
   settimer(flashinglightcron,0);
   settimer(sec1cron,0);
   settimer(sec3cron,0);
   settimer(sec5cron,0);
   settimer(sec15cron,0);
   settimer(sec30cron,0);
   settimer(sec60cron,0);
}

init();
