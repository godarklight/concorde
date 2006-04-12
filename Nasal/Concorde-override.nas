# ========================
# OVERRIDING NASAL GLOBALS
# ========================


# overrides the joystick axis handler to catch the goaround
override_throttleAxis = controls.throttleAxis;

controls.throttleAxis = func {
    val = cmdarg().getNode("setting").getValue();
    if(size(arg) > 0) { val = -val; }

    # default
    override_throttleAxis();

    # last human operation
    props.setAll("/controls/engines/engine", "throttle-manual", (1 - val)/2);
}

