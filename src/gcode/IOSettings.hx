package gcode;

import gcode.DirectWriteMode;

typedef IOSettings = {
    var outputDigits:Int;
    var commentChar:String;
    var ?printLines:Bool;
    var ?outFile:String;
    var ?fileOutput:sys.io.FileOutput;
    var ?lineEnd:String;
    var ?binary:Bool;
    var ?aerotechInclude:Bool;

    // Marginals
    var ?headerPath:String;
    var ?footerPath:String;

    // Direct write settings
    var ?directWrite:Bool;
    var ?directWriteMode:DirectWriteMode;
    var ?printerHost:String;
    var ?printerPort:Int;
    var ?baudRate:Int;
    var ?twoWayComm:Bool;
    var ?socket:sys.net.Socket;
}