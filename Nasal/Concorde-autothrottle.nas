Autothrottle = {};

Autothrottle.new = func {
  var obj = { };

   obj.init();
   return obj;
};
#===AUTOTHROTTLE STARTUP/INIT===#
Autothrottle.init = func {
  me.inherit_system("/systems/autopilot");
  me.channelengage = {0:0, 1:0};
  me.atdiscexport();
}

Autothrottle.display = func(vartype, varvalue) {
  if ( vartype == "speed" ) {
    me.itself["autoflight"].getChild("speed-display").setValue(varvalue);
  }
}


Autothrottle.schedule = func {

}
Autothrottle.autothrottleswitch = func {
}
Autothrottle.slowschedule = func {
}
Autothrottle.iaslight = func {
}
Autothrottle.is_maxcruise = func {
}
Autothrottle.is_maxclimb = func {
}
Autothrottle.discmaxclimb = func {
}
Autothrottle.maxclimb = func {
}
Autothrottle.no_voltage = func {
}
Autothrottle.voltage = func() {
}
Autothrottle.idle = func {
}
Autothrottle.full = func {
}
Autothrottle.goaround = func {
}
Autothrottle.atdiscspeed = func {
}
Autothrottle.atdiscexport = func {
}
Autothrottle.atengage = func {
}
Autothrottle.speedacquire = func {
}
Autothrottle.speed = func( speedkt ) {
}
Autothrottle.atexport = func {
}
Autothrottle.atspeedexport = func {
}
Autothrottle.attogglespeedexport = func {
}
Autothrottle.atspeedholdexport = func {
}
Autothrottle.mach = func( speedmach ) {
}
Autothrottle.atmachexport = func {
}
Autothrottle.holdspeed = func {
}