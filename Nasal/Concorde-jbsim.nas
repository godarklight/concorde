# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron

# current nasal version doesn't accept :
# - too many operations on 1 line.
# - variable with hyphen (?).



# ==============
# INITIALIZATION
# ==============

# the possible relations :
# - pumpsystem : Pump.new(),
#   inside another system / instrument, to synchronize the objects.

# - me.electricalsystem = electrical;
#   local pointer to the global object, to call its nasal code.

# - <slave>/instrumentation/altimeter[0]</slave>
#   tag in the instrumentation / system initialization, to read the properties.

# - <static-port>/systems/static</static-port>
#   tag in the instrumentation file, to customize a C++ instrument.

# - <noinstrument>/position/altitude-agl-ft</noinstrument>.
#   no relation to an instrument / system failure.

putinrelation = func {
   autopilotsystem.set_relation( autothrottlesystem );

   copilotcrew.set_relation( autopilotsystem );
   engineercrew.set_relation( autopilotsystem, fuelsystem );
   calloutcrew.set_relation( autopilotsystem );
}

synchronize1sec = func {
   electricalsystem.set_rate( fuelsystem.PUMPSEC );
   hydraulicsystem.set_rate( fuelsystem.PUMPSEC );
   airbleedsystem.set_rate( fuelsystem.PUMPSEC );
   enginesystem.set_rate( fuelsystem.PUMPSEC );
}

# 1 seconds cron (only, to spare frame rate)
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
   autopilotsystem.slowschedule();
   autothrottlesystem.schedule();
   pressuresystem.schedule();
   enginesystem.slowschedule();

   # schedule the next call
   settimer(sec5cron,pressuresystem.PRESSURIZESEC);
}

# 15 seconds cron
sec15cron = func {
   TMOinstrument.schedule();
   GPWSsystem.schedule();

   # schedule the next call
   settimer(sec15cron,15);
}

# 30 seconds cron
sec30cron = func {
   tankpressuresystem.schedule();

   # schedule the next call
   settimer(sec30cron,tankpressuresystem.TANKSEC);
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
   putinrelation();
   synchronize1sec();

   # schedule the 1st call
   settimer(sec1cron,0);
   settimer(sec3cron,0);
   settimer(sec5cron,0);
   settimer(sec15cron,0);
   settimer(sec30cron,0);
   settimer(sec60cron,0);

   # the 3D is soon visible (long by Cygwin)
   print("concorde systems started, version ", getprop("/sim/aircraft-version"));
}

# objects must be here, otherwise local to init()
constant = Concorde.Constant.new();
constantaero = Concorde.ConstantAero.new();
electricalsystem = Concorde.Electrical.new();
hydraulicsystem = Concorde.Hydraulic.new();
airbleedsystem = Concorde.Airbleed.new();
pressuresystem = Concorde.Pressurization.new();
fuelsystem = Concorde.Fuel.new();
tankpressuresystem = Concorde.PressurizeTank.new();
autopilotsystem = Concorde.Autopilot.new();
autothrottlesystem = Concorde.Autothrottle.new();
GPWSsystem = Concorde.Gpws.new();
enginesystem = Concorde.Engine.new();
lightingsystem = Concorde.Lighting.new();
gearsystem = Concorde.Gear.new();

CGinstrument = Concorde.CenterGravity.new();
IASinstrument = Concorde.Airspeed.new();
machinstrument = Concorde.Machmeter.new();
TMOinstrument = Concorde.Temperature.new();
INSinstrument = Concorde.Inertial.new();
TCASinstrument = Concorde.Traffic.new();
markerinstrument = Concorde.Markerbeacon.new();
RATinstrument = Concorde.Rat.new();
genericinstrument = Concorde.Generic.new();

doorsystem = Concorde.Doors.new();
seatsystem = Concorde.Seats.new();
menusystem = Menu.new();
copilotcrew = Concorde.VirtualCopilot.new();
engineercrew = Concorde.VirtualEngineer.new();
calloutcrew = Concorde.Callout.new();

setlistener("/sim/signals/fdm-initialized", init);
#init();
