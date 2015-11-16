{
  my $BASEPATH = "/sys/bus/w1/devices";

  enum DegreeUnits <C F>;

  grammar RPi::Device::DS18B20::Grammar {
    token TOP {
      (<hexcode> ' ') ** 9 ': crc=' <hexcode> ' ' $<valid> = ['YES' || 'NO'] \n
      (<hexcode> ' ') ** 9 't=' $<temperature> = [ \d+ ] \n
    }
    
    token hexcode {
      <[ a..f 0..9 ]> ** 2
    }
  }
  
  class RPi::Device::DS18B20::Sensor {
    has DegreeUnits $.units is rw = C;
    has Str $.id;
    
    method read() returns Rat {
      my $path = $BASEPATH ~ "/28-" ~ $.id ~ "/w1_slave";

      # Ensure the file exists that we're going to take readings from.
      die "Unable to locate: $path - can't take sensor reading"
        if ! $path.IO.e;

      # Parse the output present in the sensor's device file.
      my $match = RPi::Device::DS18B20::Grammar.parse(~$path.IO.slurp);

      # The sensor will print 'YES' if the input is valid, and 'NO' if not.
      # When valid, convert to the request degree units and return.
      if (~$<valid> eq 'YES') {
        # Temperature is reported in 1/1000's of a degree - divide by 100 to
        # get the actual value.
        my $temp = (+$<temperature>)/1000;

        # If needed, do conversion to the Fahrenheit temperature scale.
        ($!units == C) ?? $temp !! self.convert-to-fahrenheit($temp);
      } else {
        return Nil;
      }
    }

    method convert-to-fahrenheit(Rat $temp) returns Rat {
      return ($temp * 1.8) + 32
    }
  }

  class RPi::Device::DS18B20 {
    submethod BUILD {
      if (! $BASEPATH.IO.e) {
        die "Unable to locate: $BASEPATH - is the wp-gpio kernel module loaded?"
      }
    }
    
    method detect-sensors() {
      # Get a list of the unique ID's for each potential sensor plugged into the RPi.
      my @sensors = flat $BASEPATH.IO.dir.map: { m/^ $BASEPATH "/28-" (<[ a..f 0..9]>+) $/ ?? $/[0].Str !! () };

      # Create a new Sensor object for each matching ID.
      return @sensors.map: { RPi::Device::DS18B20::Sensor.new(id => $_) };
    }

    method get-sensor(Str $id) returns RPi::Device::DS18B20::Sensor {
      # Search for the specified sensor ID in the list of detected devices
      # and return it if found.
       return (self.detect-sensors.first: { $_.id eq $id } || Nil)
    }
  }
}
