package gcode;

import sys.net.Socket;
import haxe.io.Bytes;
import sys.io.File;
import gcode.Position;
using gcode.MathUtils;
using gcode.StringTools;

class GCode {
    public var ioSettings:IOSettings;
    public var axisNames:AxisNames;
    public var extruderSettings:ExtruderSettings;
    private var isRelative:Bool = true;
    private var currentPosition:Position;
    public var positionHistory:Array<Array<Float>> = [];
    public var toolSpeedHistory:Array<ToolSpeedState> = [];
    public var toolSpeed:Float = 0;
    private var extrude:Bool = false;

    public function new(?ioSettings:IOSettings, ?axisNames:AxisNames,
    ?extruderSettings:ExtruderSettings) {
        if (ioSettings == null)
            this.ioSettings = {
                commentChar: ';',
                outputDigits: 6,
                // Direct write settings
                directWrite: false,
                directWriteMode: DirectWriteMode.Socket,
                printerHost: 'localhost',
                printerPort: 8000,
                baudRate: 250000,
                twoWayComm: true
            }
        else
            this.ioSettings = ioSettings;

        if (axisNames == null)
            this.axisNames = {
                x: 'x',
                y: 'y',
                z: 'z',
                i: 'i',
                j: 'j',
                k: 'k'
            }
        else
            this.axisNames = axisNames;

        if (extruderSettings == null)
            this.extruderSettings = {
                filamentDiameter: 1.75,
                layerHeight: 0.19,
                extrusionWidth: 0.35,
                extrusionMultiplier: 1
            }
        else
            this.extruderSettings = extruderSettings;

        // Set current position to zero.
        // currentPosition = new Position();
        currentPosition = Position.makeEmpty(
            ['x', 'y', 'z', 'i', 'j', 'k']
        );
    }

    public function init() {
        // File opening
        if (this.ioSettings.lineEnd == null) {
            openFile(false);
            this.ioSettings.lineEnd = '\n';
            this.ioSettings.binary = false;
        } else {
            openFile(true);
            this.ioSettings.binary = true;
        }
    }

    /**
     * Renames axis to the supplied variables.
     * @param x (optional) x-axis name.
     * @param y (optional) y-axis name.
     * @param z (optional) z-axis name.
     */
    public function renameAxis(?x:String, ?y:String, ?z:String) {
        if (x != null)
            axisNames.x = x;
        if (y != null)
            axisNames.y = y;
        if (z != null)
            axisNames.z = z;
    }

    /**
     * Opens file as specified in `ioSettings.outFile`.
     * 
     * @param binary if true, output is handled as binary.
     * @return `true` if operation succeeded.
     */
    private function openFile(binary:Bool=false):Bool {
        #if sys
        // Close FileOutput currently open
        if (ioSettings.fileOutput != null)
            ioSettings.fileOutput.close();

        // Attempt to open 'outFile'
        if (ioSettings.outFile != null) {
            try {
                ioSettings.fileOutput = File.write(ioSettings.outFile,
                    binary);

                return true;
            } catch(e:Any) {
                trace('IO Exception: '+Std.string(e));
            }
        }
        #end

        return false;
    }

    /**
     * Writes header to outputs from `ioSettings`.
     * 
     * If `aerotechInclude` is true, its header text is appended. In
     * addition, if `headerPath` is supplied, this will also be
     * pushed to the output stream.
     */
    private function writeHeader() {
        #if sys
        if (ioSettings.aerotechInclude) {
            final header = File.read("./marginals/header.txt", false);
            writeOut(null, header.readAll().toString().splitLines());
            header.close(); 
        }
        if (ioSettings.headerPath != null) {
            final header = File.read(ioSettings.headerPath, false);
            writeOut(null, header.readAll().toString().splitLines());
            header.close(); 
        }
        #end
    }

    private function formatArgs(?x:Float, ?y:Float, ?z:Float, ?i:Float,
    ?j:Float, ?k:Float, ?kwargs:Map<String, Float>):String {
        final args:Array<String> = [];
        final formatFloat = Math.roundToString.bind(_,
            ioSettings.outputDigits);

        if (x != null)
            args.push('${axisNames.x}${formatFloat(x)}');
        if (y != null)
            args.push('${axisNames.y}${formatFloat(y)}');
        if (z != null)
            args.push('${axisNames.z}${formatFloat(z)}');
        if (i != null)
            args.push('${axisNames.i}${formatFloat(i)}');
        if (j != null)
            args.push('${axisNames.j}${formatFloat(j)}');
        if (k != null)
            args.push('${axisNames.k}${formatFloat(k)}');
        if (kwargs != null)
            for (d=>v in kwargs)
                switch (d.toLowerCase()) {
                    case 'x': if (x == null) args.push('${d}${formatFloat(v)}');
                    case 'y': if (y == null) args.push('${d}${formatFloat(v)}');
                    case 'z': if (z == null) args.push('${d}${formatFloat(v)}');
                    case 'i': if (i == null) args.push('${d}${formatFloat(v)}');
                    case 'j': if (j == null) args.push('${d}${formatFloat(v)}');
                    case 'k': if (k == null) args.push('${d}${formatFloat(v)}');
                    default: args.push('${d}${formatFloat(v)}');
                }
                // args.push('${d}${formatFloat(v)}');
        
        final argstr = args.join(' ');
        return argstr;
    }

    private function updateCurrentPosition(mode:MovementMode, ?x:Float,
    ?y:Float, ?z:Float, ?kwargs:Map<String, Float>) {
        if (mode == Auto)
            mode = (isRelative ? Relative : Absolute);

        if (kwargs != null)
            for (dim=>val in kwargs)
                switch (dim.toLowerCase()) {
                    case 'x': x = val;
                    case 'y': y = val;
                    case 'z': z = val;
                    default: null;
                }


        if ((axisNames.x != 'X') && (x != null)) {
            if (kwargs == null) kwargs = [];
            kwargs[axisNames.x] = x;
        }
        if ((axisNames.y != 'Y') && (y != null)) {
            if (kwargs == null) kwargs = [];
            kwargs[axisNames.y] = y;
        }
        if ((axisNames.z != 'Z') && (z != null)) {
            if (kwargs == null) kwargs = [];
            kwargs[axisNames.z] = z;
        }

        if (mode == Relative) {
            if (x != null)
                currentPosition.inc('x', x);
            if (y != null)
                currentPosition.inc('y', y);
            if (z != null)
                currentPosition.inc('z', z);
        } else {
            if (x != null)
                currentPosition.set('x', x);
            if (y != null)
                currentPosition.set('y', y);
            if (z != null)
                currentPosition.set('z', z);
        }

        var x = currentPosition.get('x');
        var y = currentPosition.get('y');
        var z = currentPosition.get('z');

        positionHistory.push([x, y, z]);
        final lenPosHist = positionHistory.length;
        if (
            (toolSpeedHistory.length == 0) ||
            (toolSpeedHistory[toolSpeedHistory.length-1].speed != toolSpeed)
        )
            toolSpeedHistory.push({
                index: lenPosHist-1,
                speed: toolSpeed
            });
    }

    private function writeOut(?line:String, ?lines:Array<String>) {
        if (ioSettings.fileOutput == null)
            return;

        if (lines != null)
            for (line in lines)
                writeOut(line);

        if (line != null) {
            line = line.rstrip() + ioSettings.lineEnd;

            if (ioSettings.binary)
                ioSettings.fileOutput.write(Bytes.ofString(line));
            else
                ioSettings.fileOutput.writeString(line);
        }
    }

    public function write(statementIn:String, respNeeded:Bool=false):String {
        if (
            ioSettings.printLines ||
            (
                (ioSettings.printLines == null) &&
                (ioSettings.outFile == null)
            )
        )
            trace(statementIn);

        writeOut(statementIn);

        final statement = Bytes.ofString(statementIn + ioSettings.lineEnd);
        if (ioSettings.directWrite) {
            switch (ioSettings.directWriteMode) {
                case DirectWriteMode.Socket: {
                    #if sys
                    if (ioSettings.socket == null) {
                        ioSettings.socket = new Socket();
                        ioSettings.socket.connect(
                            new sys.net.Host(ioSettings.printerHost),
                            ioSettings.printerPort
                        );
                    }

                    // ioSettings.socket.write(statement.toString());
                    ioSettings.socket.output.write(statement);
                    if (ioSettings.twoWayComm) {
                        final response = ioSettings.socket.input.read(8192);
                        final responseStr = response.toString();
                        if (responseStr.charAt(0) != '%') {
                            trace(responseStr);
                            return responseStr;
                        }

                        return responseStr.substr(1);
                    }
                    #end
                }
                case DirectWriteMode.Serial: {
                    // TODO: Create a serial interface.
                }
                default: null;
            }
        }
        // TODO: Implement direct socket writing.

        return 'OK';
    }

    public function setHome(?x:Float, ?y:Float, ?z:Float,
    ?kwargs:Map<String, Float>) {
        final args:String = formatArgs(
            x, y, z, null, null, null, kwargs
        );

        final space:String = (args.length > 0 ? ' ' : '');

        write('G92' + space + args +
            ' ${ioSettings.commentChar}set home');
        updateCurrentPosition(Absolute, x, y, z, kwargs);
    }

    public function resetHome() {
        write('G92.1 ${ioSettings.commentChar}reset position to machine' 
        + ' coordinates without moving');
    }

    public function relative() {
        if (!isRelative) {
            write('G91 ${ioSettings.commentChar}relative');
            isRelative = true;
        }
    }

    public function absolute() {
        if (isRelative) {
            write('G90 ${ioSettings.commentChar}absolute');
            isRelative = false;
        }
    }

    public function feed(rate:Float) {
        write('G1 F$rate');
        toolSpeed = rate;
    }

    /**
     * [G4]_ Pauses the machine of a specified period of time.
     * @param time time in milliseconds
     */
    public function dwell(time:Float) {
        write('G4 P$time');
    }

    public function setup() {
        writeHeader();

        if (isRelative)
            write('G91 ${ioSettings.commentChar}relative');
        else
            write('G90 ${ioSettings.commentChar}absolute');
    }

    public function teardown(wait:Bool=true) {
        #if sys
        if (ioSettings.fileOutput != null) {
            if (ioSettings.aerotechInclude) {
                final footer = File.read("./marginals/footer.txt", false);
                writeOut(null, footer.readAll().toString().splitLines());
                footer.close();
            }
            if (ioSettings.footerPath != null) {
                final footer = File.read(ioSettings.footerPath, false);
                writeOut(null, footer.readAll().toString().splitLines());
                footer.close();
            }
            ioSettings.fileOutput.close();
        }

        if (ioSettings.socket != null) {
            ioSettings.socket.close();
        }
        #end
    }

    public function home(?f:Float) {
        absMove(0, 0, 0, f);
    }

    public function move(?x:Float, ?y:Float, ?z:Float, ?f:Float,
    rapid:Bool=false, ?kwargs:Map<String, Float>) {
        var xMove:Float; var yMove:Float;
        var xDist:Float; var yDist:Float;
        var currentExtruderPos:Float;
        
        if (extrude && (!kwargs.exists('E'))) {
            if (!isRelative) {
                xMove = (x == null ? currentPosition.get('x') : x);
                yMove = (y == null ? currentPosition.get('y') : y);
                xDist = Math.abs(xMove - currentPosition.get('x'));
                yDist = Math.abs(yMove - currentPosition.get('y'));
                currentExtruderPos = currentPosition.get('E');
            } else {
                xDist = (x == null ? 0 : x);
                yDist = (y == null ? 0 : y);
                currentExtruderPos = 0;
            }

            final lineLen = Math.sqrt(xDist*xDist + yDist*yDist);
            
            final lH = extruderSettings.layerHeight;
            final eW = extruderSettings.extrusionWidth;
            final area = lH*(eW - lH) + (Math.PI/4)*(lH*lH);
            
            final volume = area*lineLen;

            final fD = extruderSettings.filamentDiameter;
            final eM = extruderSettings.extrusionMultiplier;
            final filamentLen = ((4*volume)/(Math.PI*fD*fD))*eM;
            kwargs['E'] = filamentLen*currentExtruderPos;
        }

        if (kwargs == null)
            kwargs = [];

        if (f != null) {
            kwargs['f'] = f;
            toolSpeed = f;
        }

        updateCurrentPosition(Auto, x, y, z, kwargs);
        
        final args = formatArgs(x, y, z, null, null, null, kwargs);
        final cmd = (rapid ? 'G0 ' : 'G1 ');
        write(cmd + args);
    }

    public function absMove(?x:Float, ?y:Float, ?z:Float, ?f:Float,
    rapid:Bool=false, ?kwargs:Map<String, Float>) {
        if (isRelative) {
            absolute();
            move(x, y, z, f, rapid, kwargs);
            relative();
        } else {
            move(x, y, z, f, rapid, kwargs);
        }
    }
    
    public function rapid(?x:Float, ?y:Float, ?z:Float, ?f:Float,
    ?kwargs:Map<String, Float>) {
        move(x, y, z, f, true, kwargs);
    }

    public function absRapid(?x:Float, ?y:Float, ?z:Float, ?f:Float,
    ?kwargs:Map<String, Float>) {
        absMove(x, y, z, f, true, kwargs);
    }

    public function retract(retraction:Float) {
        if (!extrude) {
            move(null, null, null, false, ['E' => -retraction]);
        } else {
            extrude = false;
            move(null, null, null, false, ['E' => -retraction]);
            extrude = true;
        }
    }

    public function arc(?x:Float, ?y:Float, ?z:Float,
    direction:RotationDirection=Clockwise, ?radius:Float,
    ?helixDim:String, helixLen:Float=0, ?kwargs:Map<String, Float>) {

        final dims:Map<String, Float> = (kwargs == null ? [] : kwargs);
        if (x != null)
            dims['x'] = x;
        if (y != null)
            dims['y'] = y;
        if (z != null)
            dims['z'] = z;

        if ([for (crd in dims.keys()) crd].length != 2) {
            trace('Must specify two of x, y, or z.');
            return;
        }

        final dimensions = [for (k in dims.keys()) k.toLowerCase()];
        var planeSelector:String;
        var axis:String;

        if (
            (dimensions.indexOf('x') >= 0) &&
            (dimensions.indexOf('y') >= 0)
        ) {
            planeSelector = 'G17 ${ioSettings.commentChar}XY-plane';
            axis = helixDim;
        } else if (dimensions.indexOf('x') >= 0) {
            planeSelector = 'G18 ${ioSettings.commentChar}XZ-plane';
            dimensions.remove('x');
            axis = dimensions[0].toUpperCase();
        } else if (dimensions.indexOf('y') >= 0) {
            planeSelector = 'G19 ${ioSettings.commentChar}YZ-plane';
            dimensions.remove('y');
            axis = dimensions[0].toUpperCase();
        } else {
            trace('Must specify two of x, y, or z.');
            return;
        }

        if (axisNames.z != 'Z')
            axis = axisNames.z;

        final command:String = switch (direction) {
            case Clockwise: 'G2';
            case Counterclockwise: 'G3';
        }

        final values = [for (_=>v in dims) v];
        var dist:Float;
        if (isRelative) {
            dist = Math.sqrt(values[0]*values[0] + values[1]*values[1]);
        } else {
            final k = [for (ky in dims.keys()) ky];
            final cp = currentPosition;
            dist = Math.sqrt(
                (cp.get(k[0]) - values[0])*(cp.get(k[0]) - values[0]) +
                (cp.get(k[1]) - values[1])*(cp.get(k[1]) - values[1])
            );
        }

        if (radius == null) {
            radius = dist/2;
        } else if (Math.abs(radius) < dist/2) {
            trace('Radius $radius too small for distance $dist.');
            return;
        }

        // TODO: Implement extrusion code.
        // if (extrude) { }

        if (axis != null)
            write('G16 X Y $axis ${ioSettings.commentChar}coordinate'
            + ' axis assignment');
        write(planeSelector);
        final args = formatArgs(
            null, null, null, null, null, null, dims
        );
        
        if (helixDim == null) {
            write('$command $args R${Math.roundToString(radius,ioSettings.outputDigits)}');
        } else {
            write('$command $args R${Math.roundToString(radius, ioSettings.outputDigits)} G1 ${helixDim.toUpperCase()}${dims[helixDim]}');
        }

        updateCurrentPosition(Auto, null, null, null, dims);
    }

    public function arcIJK(target:Array<Float>, center:Array<Float>,
    plane:String, direction:RotationDirection=Clockwise,
    ?helixLen:Float) {
        if (target.length != 2) {
            trace("'target'" +
            ' must be a two-tuple of floats (passed $target)');
            return;
        }
        if (center.length != 2) {
            trace("'center'" +
            ' must be a two-tuple of floats (passed $center)');
            return;
        }

        var dims:Map<String, Float>;

        if (plane == 'xy') {
            write('G17 ${ioSettings.commentChar}XY plane');
            dims = [
                'x' => target[0],
                'y' => target[1],
                'i' => target[0],
                'j' => target[1]
            ];

            if (helixLen != null)
                dims['z'] = helixLen;
        } else if (plane == 'xz') {
            write('G18 ${ioSettings.commentChar}XZ plane');
            dims = [
                'x' => target[0],
                'z' => target[1],
                'i' => target[0],
                'k' => target[1]
            ];

            if (helixLen != null)
                dims['x'] = helixLen;
        } else if (plane == 'yz') {
            write('G19 ${ioSettings.commentChar}YZ plane');
            dims = [
                'y' => target[0],
                'z' => target[1],
                'j' => target[0],
                'k' => target[1]
            ];

            if (helixLen != null)
                dims['y'] = helixLen;
        } else {
            trace('Selected plane \'$plane\' is not one of '
                + "('xy', 'yz', 'xz')");
            return;
        }

        final command:String = switch (direction) {
            case Clockwise: 'G2';
            case Counterclockwise: 'G3';
        }

        final args = formatArgs(null, null, null, null, null, null, dims);
        write('$command $args');

        updateCurrentPosition(Auto, null, null, null, dims);
    }

    public function absArc(direction:RotationDirection=Clockwise,
    ?radius:Float, ?kwargs:Map<String, Float>) {
        if (isRelative) {
            absolute();
            arc(
                null, null, null, direction, radius, null, 0, kwargs
            );
            relative();
        } else {
            arc(
                null, null, null, direction, radius, null, 0, kwargs
            );
        }
    }

    public function rect(x:Float, y:Float,
    direction:RotationDirection=Clockwise,
    start:RectangleCorner=LowerLeft) {
        switch (direction) {
            case Clockwise: {
                switch (start) {
                    case LowerLeft: {
                        move(null, y);
                        move(x);
                        move(null, -y);
                        move(-x);
                    }
                    case UpperLeft: {
                        move(x);
                        move(null, -y);
                        move(-x);
                        move(null, y);
                    }
                    case UpperRight: {
                        move(null, -y);
                        move(-x);
                        move(null, y);
                        move(x);
                    }
                    case LowerRight: {
                        move(-x);
                        move(null, y);
                        move(x);
                        move(null, -y);
                    }
                }
            }
            case Counterclockwise: {
                switch (start) {
                    case LowerLeft: {
                        move(x);
                        move(null, y);
                        move(-x);                        
                        move(null, -y);
                    }
                    case UpperLeft: {
                        move(null, -y);
                        move(x);
                        move(null, y);
                        move(-x);
                    }
                    case UpperRight: {
                        move(-x);
                        move(null, -y);
                        move(x);
                        move(null, y);
                    }
                    case LowerRight: {
                        move(null, y);
                        move(-x);
                        move(null, -y);
                        move(x);
                    }
                }
            }
        }
    }

    private function meanderPasses(minor:Float, spacing:Float):Int {
        return (minor > 0 ?
            Math.ceil(minor/spacing) :
            Math.absInt(Math.floor(minor/spacing))
        );
    }
    
    private function meanderSpacing(minor:Float, spacing:Float):Float
        return minor/meanderPasses(minor, spacing);

    public function meander(x:Float, y:Float, spacing:Float,
    start:RectangleCorner=LowerLeft, orientation:String='x',
    tail:Bool=false, ?minorFeed:Float) {
        switch (start) {
            case UpperLeft: y = -y;
            case UpperRight: {
                x = -x;
                y = -y;
            }
            case LowerLeft: x = -x;
            default: null;
        }

        var minor:Float; var major:Float;
        var minorName:String; var majorName:String;

        if (orientation == 'x') {
            major = x;
            majorName = 'x';

            minor = y;
            minorName = 'y';
        } else {
            major = y;
            majorName = 'y';

            minor = x;
            minorName = 'x';
        }

        final actualSpacing:Float = meanderSpacing(minor, spacing);
        if (Math.abs(actualSpacing) != spacing)
            write('${ioSettings.commentChar}WARNING! Meander spacing updated from $spacing to $actualSpacing');

        spacing = actualSpacing;
        var sign:Int = 1;

        var wasAbsolute:Bool = true;
        if (!isRelative)
            relative();
        else
            wasAbsolute = false;

        var majorFeed:Float = toolSpeed;
        if (minorFeed == null)
            minorFeed = toolSpeed;

        for (_ in 0...meanderPasses(minor, spacing)) {
            move(null, null, null, false, [majorName => sign*major]);
            if (minorFeed != majorFeed)
                feed(minorFeed);

            move(null, null, null, false, [minorName => spacing]);
            if (minorFeed != majorFeed)
                feed(majorFeed);
            
            sign *= -1;
        }

        if (!tail)
            move(null, null, null, false, [majorName => sign*major]);

        if (wasAbsolute)
            absolute();
    }

    public function clip(axis:String='z', direction:String='+x',
    height:Float=4) {
        final secondaryAxis = direction.charAt(1);
        var orientation:RotationDirection;
        if (height > 0)
            orientation = (direction.charAt(0) == '-' ? Clockwise : Counterclockwise);
        else 
            orientation = (direction.charAt(0) == '-' ? Counterclockwise : Clockwise);

        final radius = Math.abs(height/2);
        var kwargs = [
            secondaryAxis => 0,
            axis => height,
        ];

        arc(null, null, null, orientation, radius, null, 0, kwargs);
    }

    public function triangularWave(x:Float, y:Float, cycles:Int,
    start:RectangleCorner=UpperRight, orientation:String='x') {
        switch (start) {
            case UpperLeft: x = -x;
            case LowerLeft: {
                x = -x;
                y = -y;
            }
            case LowerRight: x = -x;
            default: null;
        }

        var minor:Float; var major:Float;
        var minorName:String; var majorName:String;

        if (orientation == 'x') {
            major = x;
            majorName = 'x';

            minor = y;
            minorName = 'y';
        } else {
            major = y;
            majorName = 'y';

            minor = x;
            minorName = 'x';
        }

        var sign:Int = 1;
        var wasAbsolute:Bool = true;

        if (!isRelative)
            relative();
        else
            wasAbsolute = false;

        for (_ in 0...(2*cycles)) {
            move(null, null, null, false, [
                minorName => sign*minor,
                majorName => major
            ]);
            sign *= -1;
        }

        if (wasAbsolute)
            absolute();
    }
}