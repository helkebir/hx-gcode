package gcode;

class StringTools {
    static public function rstrip(str:String):String {
        var trimIdx:Int = str.length;
        for (i in (str.length-1)...0)
            if (str.charAt(i) == ' ')
                trimIdx--;

        return str.substring(0, trimIdx);
    }

    static public function splitLines(str:String):Array<String> {
		return ~/\r\n|\n|\r/g.split(str);
	}
}