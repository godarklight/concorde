Autothrottle = {};

Autothrottle.new = func {
  var obj = { parents : [Autothrottle,System],
    GROUNDAUTOPILOT: 0,  # Autothrotle for take off. No.
    MINAUTOPILOTFT: 50,  # Minimum feet to engage autothrottle
    SPEEDLIGHT: 3,       # When the speed aquire light goes out (in knots difference).
    CRUISEMACH: 2.02,    # Speed to cruise in max cruise mode.
  };

   obj.init();
   return obj;
};
#===AUTOTHROTTLE STARTUP/INIT===#

Autothrottle.init = func {
  me.inherit_system("/systems/autothrottle");
  me.channelengage = {0:0, 1:0};
  me.is_max_climb = 0;
  me.is_speed_aquire = 0;
  me.is_autothrottle_engaged = 0;
  me.atdiscexport();
}

Autothrottle.display = func(vartype, varvalue) {
  me.itself["autoflight"].getChild(vartype).setValue(varvalue);
}

Autothrottle.atsetdefaultmode = func {
  var current_mode = me.itself["autoflight"].getChild('speed').getValue();
  if ( current_mode == '' ) {
    me.atspeedholdexport();
  }
}

Autothrottle.atchannel = func {
  var is_at1_engaged = me.itself['channel'][0].getChild('engage').getValue();
  var is_at2_engaged = me.itself['channel'][1].getChild('engage').getValue();
  var current_ft = me.dependency['radio-altimeter'][0].getChild('indicated-altitude-ft').getValue();

  me.channelengage[0] = is_at1_engaged;
  me.channelengage[1] = is_at2_engaged;

  #Because takeoff with autothrottle is so wrong...
  if ( me.channelengage[0] or me.channelengage[1] ) {
    if ( current_ft < me.MINAUTOPILOTFT ) {
      if ( ! me.GROUNDAUTOPILOT ) {
        gui.popupTip("Cannot engage the autothrottle while on the ground!");
        me.itself['channel'][0].getChild('engage').setValue(0);
        me.itself['channel'][1].getChild('engage').setValue(0);
        me.channelengage[0] = 0;
        me.channelengage[1] = 0;
      }
    }
  }
  if ( me.channelengage[0] or me.channelengage[1] ) {
    me.is_autothrottle_engaged = 1;
    me.atsetdefaultmode();
    me.atengage();
  } else {
    me.is_autothrottle_engaged = 0;
    me.atdiscspeed();
    me.atdiscexport();
    me.atengage();
  }
}

Autothrottle.atengage = func {
  me.itself['locks'].getChild('speed').setValue(me.itself['autoflight'].getChild('speed').getValue());
}

Autothrottle.speedacquire = func {

}



#=== AT DISCONNECT ===#

Autothrottle.atdiscspeed = func {
#This function disables the autothrottle
  me.itself['autoflight'].getChild('speed').setValue('');
}

Autothrottle.atdiscexport = func {
#This function physically disconnects the autothrottle
  me.display('speed-display', '');
  me.itself['channel'][0].getChild('engage').setValue(0);
  me.itself['channel'][1].getChild('engage').setValue(0);
  me.is_max_climb = 0;
}

Autothrottle.atdiscmaxclimbexport = func {
#This function makes it go into speed hold mode
  me.is_max_climb = 0;
  var current_mach = me.dependency['mach'][0].getChild('indicated-mach').getValue();
  if ( current_mach > 2 ) {
    me.atmachexport();
    me.mach(me.CRUISEMACH);
  } else {
    me.atspeedholdexport();
  }
}

#=== MODES ===#

Autothrottle.idle = func {
  for (var i = 0; i < 4 ; i = i + 1) {
    me.dependency['engine'][i].getChild('throttle').setValue(0);
  }
}

Autothrottle.full = func {
  for (var i = 0; i < 4; i = i + 1) {
    me.dependency['engine'][i].getChild('throttle').setValue(1);
  }
}

Autothrottle.setreverse = func(varvalue) {
  for (var i = 0; i < 4; i = i + 1) {
    me.dependency['engine'][i].getChild('reverser').setValue(varvalue);
  }
}

Autothrottle.is_reversed = func() {
  var vardeg = me.dependency['engine'][0].getChild('reverser-angle-rad').getValue();
  if ( vardeg > 2 ) {
    return 1;
  } else {
    return 0;
  }
}

Autothrottle.modemach = func {
  me.itself['autoflight'].getChild('speed').setValue('mach-with-throttle');
  me.atengage();
}

Autothrottle.modespeed = func {
  me.itself['autoflight'].getChild('speed').setValue('speed-with-throttle');
  me.atengage();
}

Autothrottle.modeglidescope = func {
  me.itself['autoflight'].getChild('speed').setValue('gs-with-throttle');
  me.atengage();
}

Autothrottle.modespeedpitch = func {
  me.itself['autoflight'].getChild('speed').setValue('speed-with-pitch-trim');
  me.atengage();
}

Autothrottle.modemachpitch = func {
  me.itself['autoflight'].getChild('speed').setValue('mach-with-pitch-trim');
  me.atengage();
}

#=== MODE SETTINGS ===#

Autothrottle.speed = func( speedkt ) {
  interpolate(me.itself['settings'].getChild('target-speed-kt').getPath(), speedkt , 1);
}

Autothrottle.mach = func( speedmach ) {
  interpolate(me.itself['settings'].getChild('target-speed-mach').getPath(), speedmach , 1);
}

Autothrottle.holdspeed = func {
  var current_airspeed = me.dependency['asi'][0].getChild('indicated-speed-kt').getValue();
  me.speed(current_airspeed);
}

Autothrottle.holdmach = func {
  var current_mach = me.dependency['mach'][0].getChild('indicated-mach').getValue();
  me.mach(current_mach);
}

#=== EXPORTS ===#

Autothrottle.atexport = func {
  me.atchannel();
  me.atsetdefaultmode();
}

Autothrottle.atmachexport = func {
  if ( me.is_autothrottle_engaged ) {
    me.display('speed-display', 'MH');
    me.holdmach();
    me.modemach();
  }
}

Autothrottle.atspeedexport = func {
  if ( me.is_autothrottle_engaged ) {
    me.speed(me.itself['autoflight'].getChild('speed-select').getValue());
    me.modespeed();
    var current_airspeed = me.dependency['asi'][0].getChild('indicated-speed-kt').getValue();
    var target_airspeed = me.itself['autoflight'].getChild('speed-select').getValue();
    var diff_airspeed = abs( current_airspeed - target_airspeed );
    if ( diff_airspeed < me.SPEEDLIGHT ) {
      me.display('speed-display', 'IH');
      me.is_speed_aquire = 0;
    } else {
      me.display('speed-display', 'IA');
      me.is_speed_aquire = 1;
    }
  }
}

Autothrottle.atspeedholdexport = func {
  if ( me.is_autothrottle_engaged ) {
    me.display('speed-display', 'IH');
    me.holdspeed();
    me.modespeed();
  }
}


#=== SCHEDULE ===#

Autothrottle.schedule = func {
  if ( me.is_max_climb ) {
    var max_airspeed = me.dependency['asi'][0].getChild('vmo-kt').getValue();
    me.speed(max_airspeed);
  }
  if ( me.is_speed_aquire ) {
    var current_airspeed = me.dependency['asi'][0].getChild('indicated-speed-kt').getValue();
    var target_airspeed = me.itself['settings'].getChild('target-speed-kt').getValue();
    var diff_airspeed = abs( current_airspeed - target_airspeed );
    if ( diff_airspeed < me.SPEEDLIGHT ) {
      me.display('speed-display', 'IH');
      me.is_speed_aquire = 0;
    }
  }
}