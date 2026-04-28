// SMD Slide Switch (2-Pin Variant, Extended Position)
// Origin [0,0,0] is located at the center of the bottom face of the main body.

$fn = 60;

section = false;

module smd_slide_switch_2pin() {
    body();
    lever();
    terminals();
    alignment_pins();
}

module body() {
    // Main plastic housing
    color([0.15, 0.15, 0.15]) // Black/Dark Gray
    difference() {
	    // Centered in X and Y, sitting on Z=0
	    translate([0, 0, 2.45])
		cube([10, 4.8, 4.9], center=true);


        // clip
        translate([-5, 0, 3.5]) cube([1, 1.5, 3.5], center=true);
        translate([ 5, 0, 3.5]) cube([1, 1.5, 3.5], center=true);

        // Top lever operating slot (6.5mm long, centered above)
        translate([0.5, 0.5, 3.5]) cube([6.5, 0.8, 4.0], center=true);
        translate([-2.5,0.9,3]) rotate([90,0,0]) cylinder(h=0.8, r=1.2);
        // Pivot pin visualization hole on the side
        translate([-2.5, 0, 3.0]) rotate([90, 0, 0]) cylinder(h=10, r=0.4, center=true);
    }
}

module lever() {
    // Lever modeled as an arc centered at the pivot point
    // Pivot origin: X = -2.5, Z = 3.0
    // The tip reaches exactly X = 2.1, Z = 7.0 (relative to absolute origin)
    
    pivot_x = -2.5;
    pivot_z = 3.0;
    
    // Calculate radius to reach the [2.1, 7.0] tip
    // dx = 2.1 - (-2.5) = 4.6
    // dz = 7.0 - 3.0 = 4.0
    // r_outer = sqrt(4.6^2 + 4.0^2) ≈ 6.1
    r_outer = 6.1;
    
    color([0.95, 0.95, 0.95]) // White plastic
    translate([pivot_x, 0.5, pivot_z])
    rotate([90, 0, 0])
    linear_extrude(height = 0.5, center = true) {
        union(){
			difference(){			 
				circle(r=1);
				circle(r=0.4);
			}
			intersection() {
				circle(r = r_outer);
				// Bounding wedge to form the arc sweep
				// Starts at ~41 degrees (to hit the tip coordinate) and sweeps backwards
				polygon([
					[0, 0],
					[10 * sin(50), 10 * cos(50)],
					[10 * sin(80), 10 * cos(80)]
				]);
			}
		}
    }
	color([0.75, 0.75, 0.8]) translate([pivot_x, 0, pivot_z]) rotate([90,0,0]) cylinder(h=4.8, r=0.4, center=true);
}

module terminals() {
    // 2 SMD Gull-Wing Pins on the front side
    // Pitch is 5.0mm (Centered at X = -2.5 and X = 2.5)
    pin(-2.5);
    pin(2.5);
}

module pin(x_pos) {
    // Front face of the body is at Y = 2.4
    y_face = 2.4; 
    
  color([0.75, 0.75, 0.8]) // Silver metal finish
  translate([x_pos - 0.5, y_face, 0])
  cube([1.0, 2.3, 0.5]);
}

module alignment_pins() {
    // Plastic alignment pins on the bottom, 1mm deep
    // Located at the same X positions as the electrical pins
    color([0.15, 0.15, 0.15]) {
        translate([-2.5, 0, -1.0]) cylinder(h=1.0, r=0.4);
    }
}

// Render the switch
if(section){
 intersection(){
  translate([-12.5,0,0]) cube(20, center=true);
  smd_slide_switch_2pin();
  }
}
else{
	smd_slide_switch_2pin();
}