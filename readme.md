# hx-gcode

> A lightweight G-code generation framework in Haxe, inspired my
[mecode](https://github.com/jminardi/mecode).

## Getting Started

### Prerequisites

Haxe 4.0 or later.

Note: To use sockets and serial communication, as well
as file input/output, your target needs to be one of the "`sys`"-targets
(see [Haxe API - Sys](https://api.haxe.org/Sys.html)).

### Quick Start

1. Clone this repository:
```bash
git clone https://github.com/helkebir/hx-gcode
cd hx-gcode
```

2. Alter `Main.hx` to your needs:

```hx
class Main {
    static function main() {
        var g = new GCode();
        g.init();

        g.setup();
        g.move(0, 1, 2, 10);
        g.move(5, 5, 2, 5);
        g.home(1);
        g.teardown();
    }
}
```

3. Compile and run (we use [HashLink](https://hashlink.haxe.org/) here):
```bash
haxe compile.hxml
hl main.hl
```

### Basic Usage

See [Main.hx](Main.hx) for a small demo - more elaborate examples and
documentation to be developed.

## Authors

- **Hamza El-Kebir** - [helkebir](https://github.com/helkebir)

## License

This project is licensed under the MIT License - see the
[LICENSE.md](LICENSE.md) file for details.

## Acknowledgements

This code is heavily inspired by Jack Minardi's awesome
[mecode](https://github.com/jminardi/mecode) G-code generator.