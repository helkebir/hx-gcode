package gcode;

class MathUtils {
    static public inline function absInt(cl:Class<Math>, i:Int):Int {
        if (i < 0)
            return -i;
        else
            return i;
    }

    static public function roundTo(cl:Class<Math>, v:Float, d:Int):Float {
        final pow:Float = Math.pow(v, d);

        return Math.round(v*pow)/pow;
    }

    static public function roundToString(cl:Class<Math>, v:Float, d:Int):String {
        final pow:Float = Math.pow(10, d);
        final round:Float = Math.round(v*pow)/pow;

        final floor:Int = Math.floor(round);
        var decimals:String = '${round-floor}'.substr(2, d);
        if (decimals == '')
            decimals = '0';

        return '${floor}.${decimals}';
    }
}