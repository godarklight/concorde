# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron

# current nasal version doesn't accept :
# - too many operations on 1 line.
# - variable with hyphen.



# ==============
# INITIALIZATION
# ==============

# the possible relations :
# - pumpsystem : Pump.new(),                              inside another system / instrument, to synchronize the objects.
# - me.electricalsystem = electrical;                     local pointer to the global object, to call its nasal code.
# - <slave>/instrumentation/altimeter[0]</slave>          tag in the instrumentation / system initialization, to read the properties.
# - <static-port>/systems/static</static-port>            tag in the instrumentation file, to customize a C++ instrument.
# - /position/altitude-agl-ft, /velocities/mach.          no relation to an instrument / system failure, use NoInstrument.
setrelations = func {
   autopilotsystem.set_relation( autothrottlesystem, electricalsystem );
   fuelsystem.set_relation( electricalsystem );
   hydraulicsystem.set_relation( electricalsystem );
   pressuresystem.set_relation( airbleedsystem, electricalsystem );
   tanksystem.set_relation( airbleedsystem, electricalsystem );
   enginesystem.set_relation( autopilotsystem );
   lightingsystem.set_relation( electricalsystem );

   INSinstrument.set_relation( electricalsystem );
   TMOinstrument.set_relation( electricalsystem );
   TCASinstrument.set_relation( electricalsystem );
}

synchronize1sec = func {
   electricalsystem.set_rate( fuelsystem.PUMPSEC );
   hydraulicsystem.set_rate( fuelsystem.PUMPSEC );
   airbleedsystem.set_rate( fuelsystem.PUMPSEC );
   enginesystem.set_rate( fuelsystem.PUMPSEC );
}

# 1 seconds cron
sec1cron = func {
   electricalsystem.schedule();
   fuelsystem.schedule();
   hydraulicsystem.schedule();
   airbleedsystem.schedule();
   enginesystem.schedule();
   lightingsystem.schedule();

   # schedule the next call
   settimer(sec1cron,fuelsystem.PUMPSEC);
}

# 3 seconds cron
sec3cron = func {
   autopilotsystem.schedule();
   TCASinstrument.schedule();
   INSinstrument.schedule();

   # schedule the next call
   settimer(sec3cron,autopilotsystem.AUTOPILOTSEC);
}

# 5 seconds cron
sec5cron = func {
   CGinstrument.schedule();
   IASinstrument.schedule();
   machinstrument.schedule();
   autothrottlesystem.schedule();
   pressuresystem.schedule();
   enginesystem.slowschedule();

   # schedule the next call
   settimer(sec5cron,pressuresystem.PRESSURIZESEC);
}

# 15 seconds cron
sec15cron = func {
   TMOinstrument.schedule();
   INSinstrument.slowschedule();
   GPWSsystem.schedule();

   # schedule the next call
   settimer(sec15cron,15);
}

# 30 seconds cron
sec30cron = func {
   tanksystem.schedule();

   # schedule the next call
   settimer(sec30cron,tanksystem.TANKSEC);
}

# 60 seconds cron
sec60cron = func {
   electricalsystem.slowschedule();
   airbleedsystem.slowschedule();

   # schedule the next call
   settimer(sec60cron,60);
}

# general initialization
init = func {
   setrelations();
   synchronize1sec();

   # schedule the 1st call
   settimer(sec1cron,0);
   settimer(sec3cron,0);
   settimer(sec5cron,0);
   settimer(sec15cron,0);
   settimer(sec30cron,0);
   settimer(sec60cron,0);
}

# objects must be here, otherwise local to init()
constant = Concorde.Constant.new();
constantaero = Concorde.ConstantAero.new();
electricalsystem = Concorde.Electrical.new();
hydraulicsystem = Concorde.Hydraulic.new();
airbleedsystem = Concorde.Airbleed.new();
pressuresystem = Concorde.Pressurization.new();
fuelsystem = Concorde.Fuel.new();
tanksystem = Concorde.Tank.new();
autopilotsystem = Concorde.Autopilot.new();
autothrottlesystem = Concorde.Autothrottle.new();
GPWSsystem = Concorde.Gpws.new();
enginesystem = Concorde.Engine.new();
lightingsystem = Concorde.Lighting.new();

CGinstrument = Concorde.CenterGravity.new();
IASinstrument = Concorde.Airspeed.new();
machinstrument = Concorde.Machmeter.new();
TMOinstrument = Concorde.Temperature.new();
INSinstrument = Concorde.Inertial.new();
TCASinstrument = Concorde.Traffic.new();
markerinstrument = Concorde.Markerbeacon.new();
RATinstrument = Concorde.Rat.new();
doorinstrument = Concorde.Doors.new();
genericinstrument = Concorde.Generic.new();
noinstrument = Concorde.NoInstrument.new();

init();
