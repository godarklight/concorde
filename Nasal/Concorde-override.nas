# WARNING :
# - nasal overriding may not work on some platforms (Cygwin).
# - put all code in comment to recover the default behaviour.


# ========================
# OVERRIDING NASAL GLOBALS
# ========================

# joystick may move until listener is triggered.
globals.Concorde.enginesystem = nil;


# one cannot override the joystick flight controls;
# but the mechanical channel should not fail.


# overrides the joystick axis handler to catch a goaround
override_throttleAxis = controls.throttleAxis;

controls.throttleAxis = func {
    if( globals.Concorde.enginesystem == nil ) {
        override_throttleAxis();
    }
    else {
        var val = cmdarg().getNode("setting").getValue();
        if(size(arg) > 0) { val = -val; }

        var position = (1 - val)/2;

        globals.Concorde.enginesystem.set_throttle( position );
    }
}


# overrides the gear handler to catch an hydraulic failure
override_gearDown = controls.gearDown;

controls.gearDown = func( sign ) {
    if( sign < 0 ) {
        if( globals.Concorde.gearsystem.can_up() ) {
            override_gearDown( sign );
        }

        # 2) neutral, once retracted
        if( getprop("/gear/gear[0]/position-norm") == globals.Concorde.constantaero.GEARUP ) {
            setprop("/controls/gear/hydraulic",globals.Concorde.constant.FALSE);
        }
    }
    elsif( sign > 0 ) {
        # remove neutral to get hydraulics
        setprop("/controls/gear/hydraulic",globals.Concorde.constant.TRUE);

        if( globals.Concorde.gearsystem.can_down() ) {
            override_gearDown( sign );
        }
    }
}


# overrides the flaps handler to catch an hydraulic failure
override_flapsDown = controls.flapsDown;

controls.flapsDown = func( sign ) {
    if( sign < 0 ) {
        if( globals.Concorde.noseinstrument.can_up() ) {
            override_flapsDown( sign );
        }
    }
    elsif( sign > 0 ) {
        if( globals.Concorde.noseinstrument.can_down() ) {
            override_flapsDown( sign );
        }
    }
}


# overrides the brake handler to catch an hydraulic failure
override_applyBrakes = controls.applyBrakes;

controls.applyBrakes = func(v, which = 0) {
    if( globals.Concorde.hydraulicsystem.brakes_pedals( v ) ) {
        # default
        override_applyBrakes( v, which );
    }
}


# overrides the parking brake handler to catch an hydraulic failure
override_applyParkingBrake = controls.applyParkingBrake;

controls.applyParkingBrake = func(v) {
    if (!v) { return; }
    globals.Concorde.hydraulicsystem.brakesparkingexport();
    var p = "/controls/gear/brake-parking-lever";
    var i = getprop(p);
    return i;
}


# overrides engine start
override_startEngine = controls.startEngine;

controls.startEngine = func {
    override_startEngine();

    globals.Concorde.enginesystem.cutoffexport();
}
