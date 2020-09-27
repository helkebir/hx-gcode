package;

import gcode.RotationDirection;
import gcode.GCode;

class Main {
    static function main() {
        var g = new GCode();

        // g.ioSettings.directWrite = true;
        // g.ioSettings.twoWayComm = false;
        // g.ioSettings.headerPath = './marginals/header.txt';
        // g.ioSettings.footerPath = './marginals/footer.txt';
        // g.ioSettings.outFile = './out.txt';
        g.init();

        g.setup();
        g.move(0, 1, 2, 10);
        g.move(5, 5, 2, 5, true);
        g.dwell(1000);
        g.home(10);
        g.arc(10, null, 5, RotationDirection.Counterclockwise, 20);
        g.home(5);
        g.meander(10, 5, 1, LowerLeft);
        g.home(5);
        g.teardown();

        trace(g.positionHistory);
        trace(g.toolSpeedHistory);
    }
}