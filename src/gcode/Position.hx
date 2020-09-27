package gcode;

class Position {
    private var map:Map<String, Float>;

    public inline function new(?map:Map<String, Float>) {
        this.map = (map == null ? [] : map);
    }

    static public function makeEmpty(crds:Array<String>):Position {
        var posObj = new Position();
        for (crd in crds)
            posObj.set(crd);

        return posObj;
    }

    public inline function set(crd:String, pos:Float=0) {
        map[crd] = pos;
    }

    public inline function get(crd:String):Null<Float> {
        return map[crd];
    }

    public inline function inc(crd:String, pos:Float) {
        if (has(crd))
            map[crd] += pos;
        else
            set(crd, pos);
    }

    public inline function dec(crd:String, pos:Float) {
        if (has(crd))
            map[crd] -= pos;
        else
            set(crd, -pos);
    }

    public function add(rhs:Position):Position {
        var posObj = new Position();

        for (crd=>pos in map)
            if (rhs.has(crd))
                posObj.set(crd, pos + rhs.get(crd));

        return posObj;
    }

    public function sub(rhs:Position):Position {
        var posObj = new Position();

        for (crd=>pos in map)
            if (rhs.has(crd))
                posObj.set(crd, pos - rhs.get(crd));

        return posObj;
    }

    public inline function has(crd:String):Bool {
        return map.exists(crd);
    }

    public inline function exists(crd:String):Bool return has(crd);
}