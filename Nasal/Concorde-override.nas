# WARNING :
# - nasal overriding may not work on some platforms (Cygwin).
# - put all code in comment to recover the default behaviour.


# ========================
# OVERRIDING NASAL GLOBALS
# ========================


# overrides the joystick axis handler to catch a goaround
override_throttleAxis = controls.throttleAxis;

controls.throttleAxis = func {
    val = cmdarg().getNode("setting").getValue();
    if(size(arg) > 0) { val = -val; }

    # default
    override_throttleAxis();

    # last human operation
    props.setAll("/controls/engines/engine", "throttle-manual", (1 - val)/2);
}


# overrides the gear handler to catch an hydraulic failure
override_gearDown = controls.gearDown;

controls.gearDown = func( sign ) {
    if( sign < 0 ) {
        if( hydraulicsystem.gear_up() ) {
            override_gearDown( sign );
        }
    }
    elsif( sign > 0 ) {
        if( hydraulicsystem.gear_down() ) {
            override_gearDown( sign );
        }
    }
}


# overrides the flaps handler to catch an hydraulic failure
override_flapsDown = controls.flapsDown;

controls.flapsDown = func( sign ) {
    if( sign < 0 ) {
        if( hydraulicsystem.nose_up() ) {
            override_flapsDown( sign );
        }
    }
    elsif( sign > 0 ) {
        if( hydraulicsystem.nose_down() ) {
            override_flapsDown( sign );
        }
    }
}


# overrides the brake handler to catch an hydraulic failure
override_applyBrakes = controls.applyBrakes;

controls.applyBrakes = func(v, which = 0) {
    if( hydraulicsystem.has_brakes() ) {
        # default
        override_applyBrakes( v, which );
    }
}


# overrides the parking brake handler to catch an hydraulic failure
override_applyParkingBrake = controls.applyParkingBrake;

controls.applyParkingBrake = func(v) {
    if (!v) { return; }
    var p = "/controls/gear/brake-parking-lever";
    setprop(p, var i = !getprop(p));
    return i;
}
