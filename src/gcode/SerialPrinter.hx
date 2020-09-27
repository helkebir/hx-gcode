package gcode;

// TODO: Stub.
class SerialPrinter {
    public var port:String;
    public var baudRate:Int;

    public function new(port:String='/dev/tty.usbmodem1421', baudRate:Int=250000) {
        this.port = port;
        this.baudRate = baudRate;
    }
}