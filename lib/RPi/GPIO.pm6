enum RPiGPIOMode <SIMPLE BCM>;
enum RPiPinMode  <INPUT OUTPUT>;

class RPi::GPIO {
  use RPi::Wiring;
  use NativeCall;
  use POSIX;
  
  has RPiGPIOMode $.mode;

  has @!gpio-pins;
  has %.initial-state;
  
  submethod BUILD(:$mode)  {
    my $uid = getuid();

    # The GPIO setup routines must be run as the root user.
    die "RPi must be initialized as root" if ($uid != 0);

    given $mode {
      when SIMPLE {
        # Use the simplified pin numbering scheme implemented by the WiringPi library.
        RPi::Wiring::setup();
        given RPi::Wiring::board-revision() {
          when 1 { @!gpio-pins = 0..16 };
          when 2 { @!gpio-pins = 0..20 };
        }
      }
      
      when BCM {
        # Use the Broadcom GPIO pin numberings.
        RPi::Wiring::setup-gpio();
        do given RPi::Wiring::board-revision() {
          when 1 { @!gpio-pins = (flat 0, 1, 4, 7..11, 14, 15, 17, 18, 21..25) };
          when 2 { @!gpio-pins = (flat 2, 3, 4, 7..11, 14, 15, 17, 18, 22..25, 27..31) };
        }
      }
    }

    $!mode = $mode;

    # Preserve the initial state of the GPIO pins so that they can be restored upon
    # exit, if requested.
    %!initial-state = self.gpio-pins().map: { ($_ => RPi::Wiring::digital-read($_)) };
  }
  
  method gpio-pins() {
    return @!gpio-pins;
  }
  
  method setup(Int $channel where $channel >= 0, RPiPinMode $mode) {
    RPi::Wiring::set-pin-mode($channel, $mode)
  }
}
