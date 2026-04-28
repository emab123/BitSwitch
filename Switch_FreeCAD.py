import FreeCAD as App
import Part
import math

def create_switch():
    # Create a new document
    doc = App.newDocument("SMD_Slide_Switch")
    
    # --- Body ---
    # Main housing: 10x4.8x4.9 centered in X/Y
    body_box = Part.makeBox(10, 4.8, 4.9)
    body_box.translate(App.Vector(-5, -2.4, 0))
    
    # Side clips
    clip_l = Part.makeBox(1, 1.5, 3.5)
    clip_l.translate(App.Vector(-5.5, -0.75, 1.75)) # Adjusted to match translate([-5, 0, 3.5]) cube([1,1.5,3.5], center=true)
    
    clip_r = Part.makeBox(1, 1.5, 3.5)
    clip_r.translate(App.Vector(4.5, -0.75, 1.75))
    
    # Lever slot
    slot = Part.makeBox(6.5, 0.8, 4.0)
    slot.translate(App.Vector(0.5 - 3.25, 0.5 - 0.4, 3.5 - 2.0))
    
    # Pivot clearance
    clearance = Part.makeCylinder(1.2, 0.9, App.Vector(-2.5, 0, 3), App.Vector(0, -1, 0))
    
    # Main Body subtraction
    body_final = body_box.cut(clip_l).cut(clip_r).cut(slot).cut(clearance)
    body_obj = doc.addObject("Part::Feature", "Housing")
    body_obj.Shape = body_final
    body_obj.ViewObject.ShapeColor = (0.15, 0.15, 0.15)

    # --- Lever Arm ---
    pivot_x, pivot_z = -2.5, 3.0
    r_outer = 6.1
    # Angles derived from the SCAD polygon (50 to 80 degrees relative to Y in SCAD circle logic)
    # In FreeCAD Part.makeCircle/Arc, 0 degrees is +X.
    start_angle = 40.0 
    end_angle = 80.0
    
    # 1. Outer Arc
    arc_outer = Part.ArcOfCircle(App.Vector(pivot_x, 0.25, pivot_z), r_outer, start_angle, end_angle).toShape()
    # 2. Inner Circle part (the pivot ring)
    ring_outer = Part.makeCircle(1.0, App.Vector(pivot_x, 0.25, pivot_z), App.Vector(0, 1, 0))
    ring_inner = Part.makeCircle(0.4, App.Vector(pivot_x, 0.25, pivot_z), App.Vector(0, 1, 0))
    
    # 3. Constructing the wedge face
    p1 = App.Vector(pivot_x, 0.25, pivot_z)
    p2 = App.Vector(pivot_x + r_outer * math.cos(math.radians(start_angle)), 0.25, pivot_z + r_outer * math.sin(math.radians(start_angle)))
    p3 = App.Vector(pivot_x + r_outer * math.cos(math.radians(end_angle)), 0.25, pivot_z + r_outer * math.sin(math.radians(end_angle)))
    
    edge1 = Part.makeLine(p1, p2)
    edge2 = arc_outer
    edge3 = Part.makeLine(p3, p1)
    
    wedge_wire = Part.Wire([edge1, edge2, edge3])
    wedge_face = Part.Face(wedge_wire)
    
    # Ring face
    ring_face = Part.Face(Part.Wire(ring_outer)).cut(Part.Face(Part.Wire(ring_inner)))
    
    # Combine and Extrude
    lever_profile = wedge_face.fuse(ring_face)
    lever_arm = lever_profile.extrude(App.Vector(0, 0.5, 0))
    lever_arm.translate(App.Vector(0, -0.25, 0)) # Center the 0.5 thickness
    
    lever_obj = doc.addObject("Part::Feature", "Lever_Arm")
    lever_obj.Shape = lever_arm
    lever_obj.ViewObject.ShapeColor = (0.95, 0.95, 0.95)

    # --- Pivot Pin ---
    pin_cyl = Part.makeCylinder(0.4, 4.8, App.Vector(pivot_x, 2.4, pivot_z), App.Vector(0, -1, 0))
    pin_obj = doc.addObject("Part::Feature", "Pivot_Pin")
    pin_obj.Shape = pin_cyl
    pin_obj.ViewObject.ShapeColor = (0.75, 0.75, 0.8)

    # --- Terminals ---
    def add_terminal(x_pos, name):
        t = Part.makeBox(1.0, 2.3, 0.5)
        t.translate(App.Vector(x_pos - 0.5, 2.4, 0))
        t_obj = doc.addObject("Part::Feature", name)
        t_obj.Shape = t
        t_obj.ViewObject.ShapeColor = (0.75, 0.75, 0.8)

    add_terminal(-2.5, "Terminal_1")
    add_terminal(2.5, "Terminal_2")

    # --- Alignment Pins ---
    align = Part.makeCylinder(0.4, 1.0, App.Vector(-2.5, 0, 0), App.Vector(0, 0, -1))
    align_obj = doc.addObject("Part::Feature", "Alignment_Pin")
    align_obj.Shape = align
    align_obj.ViewObject.ShapeColor = (0.15, 0.15, 0.15)

    doc.recompute()
    print("Switch generation complete.")

if __name__ == "__main__":
    create_switch()
