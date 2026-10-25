#!/usr/bin/env python3
"""
build_place.py — Districts: Afterlight (Phase 0+1 vertical slice) place builder.

Packs src/** Luau scripts plus a programmatically-generated "Meridian Heights"
world blockout into build/DistrictsAfterlight.rbxlx, which opens directly in
Roblox Studio. No Rojo required.

Also regenerates src/ReplicatedStorage/Shared/WorldLayout.lua so services and
the world always agree on interaction coordinates (single source of truth).

Run:  python3 build_place.py
"""
import math
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "src")
OUT_DIR = os.path.join(ROOT, "build")
OUT = os.path.join(OUT_DIR, "DistrictsAfterlight.rbxlx")
WORLD_LAYOUT = os.path.join(SRC, "ReplicatedStorage", "Shared", "WorldLayout.lua")

MATERIALS = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512,
    "WoodPlanks": 528, "Slate": 800, "Concrete": 816, "Pavement": 836,
    "Brick": 848, "Cobblestone": 880, "DiamondPlate": 1056, "Foil": 1072,
    "Metal": 1088, "Grass": 1280, "LeafyGrass": 1284, "Sand": 1296,
    "Fabric": 1312, "Ground": 1360, "Asphalt": 1376, "Glass": 1568,
    "Rubber": 2311,
}
PART_TYPE = {"Ball": 0, "Block": 1, "Cylinder": 2}
ACTUATOR = {"None": 0, "Motor": 1, "Servo": 2}

_ref_counter = [0]


def newref():
    _ref_counter[0] += 1
    return "RBX%d" % _ref_counter[0]


# ---------------------------------------------------------------- math ----
def rot_matrix(yaw_deg: float, roll_deg: float):
    """R = Ry(yaw) @ Rz(roll), returned as 3x3 list (rows)."""
    y = math.radians(yaw_deg)
    r = math.radians(roll_deg)
    cy, sy = math.cos(y), math.sin(y)
    cr, sr = math.cos(r), math.sin(r)
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rz = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]
    out = [[0.0] * 3 for _ in range(3)]
    for i in range(3):
        for j in range(3):
            out[i][j] = sum(ry[i][k] * rz[k][j] for k in range(3))
    return out


def pack_color(r, g, b):
    return (255 << 24) | (int(r) << 16) | (int(g) << 8) | int(b)


def num(v):
    return ("%.6f" % float(v)).rstrip("0").rstrip(".")


# ------------------------------------------------------------- XML nodes ----
class Node:
    def __init__(self, cls, name=None):
        self.cls = cls
        self.name = name
        self.props = []      # list of (kind, pname, args)
        self.children = []
        self.ref = newref()

    def p(self, kind, pname, *args):
        self.props.append((kind, pname, args))
        return self

    def add(self, *kids):
        self.children.extend(kids)
        return self


def vec_str(v):
    return "<X>%s</X><Y>%s</Y><Z>%s</Z>" % (num(v[0]), num(v[1]), num(v[2]))


def render_props(node, indent):
    out = []
    pad = "  " * indent
    for kind, pname, args in node.props:
        if kind == "string":
            out.append('%s<string name="%s">%s</string>' % (pad, pname, escape(str(args[0]))))
        elif kind == "psource":
            out.append('%s<ProtectedString name="%s">%s</ProtectedString>' % (pad, pname, escape(str(args[0]))))
        elif kind == "bool":
            out.append('%s<bool name="%s">%s</bool>' % (pad, pname, "true" if args[0] else "false"))
        elif kind == "int":
            out.append('%s<int name="%s">%d</int>' % (pad, pname, int(args[0])))
        elif kind == "float":
            out.append('%s<float name="%s">%s</float>' % (pad, pname, num(args[0])))
        elif kind == "double":
            out.append('%s<double name="%s">%s</double>' % (pad, pname, num(args[0])))
        elif kind == "token":
            out.append('%s<token name="%s">%d</token>' % (pad, pname, int(args[0])))
        elif kind == "vec3":
            out.append('%s<Vector3 name="%s">%s</Vector3>' % (pad, pname, vec_str(args[0])))
        elif kind == "vec2":
            out.append('%s<Vector2 name="%s"><X>%s</X><Y>%s</Y></Vector2>' % (pad, pname, num(args[0][0]), num(args[0][1])))
        elif kind == "cframe":
            pos, yaw, roll = args
            m = rot_matrix(yaw, roll)
            # CFrame rotation stores column-vectors as R00..R22 (row-major read of rows).
            xvec = (m[0][0], m[1][0], m[2][0])
            yvec = (m[0][1], m[1][1], m[2][1])
            zvec = (m[0][2], m[1][2], m[2][2])
            body = ("<X>%s</X><Y>%s</Y><Z>%s</Z>"
                    "<R00>%s</R00><R01>%s</R01><R02>%s</R02>"
                    "<R10>%s</R10><R11>%s</R11><R12>%s</R12>"
                    "<R20>%s</R20><R21>%s</R21><R22>%s</R22>") % (
                num(pos[0]), num(pos[1]), num(pos[2]),
                num(xvec[0]), num(yvec[0]), num(zvec[0]),
                num(xvec[1]), num(yvec[1]), num(zvec[1]),
                num(xvec[2]), num(yvec[2]), num(zvec[2]))
            out.append('%s<CoordinateFrame name="%s">%s</CoordinateFrame>' % (pad, pname, body))
        elif kind == "color":
            out.append('%s<Color3uint8 name="Color3uint8">%d</Color3uint8>' % (pad, pack_color(*args[0])))
        elif kind == "color3":
            r, g, b = args[0]
            out.append('%s<Color3 name="%s"><R>%s</R><G>%s</G><B>%s</B></Color3>'
                       % (pad, pname, num(r / 255.0), num(g / 255.0), num(b / 255.0)))
        elif kind == "ref":
            target = args[0]
            out.append('%s<Ref name="%s">%s</Ref>' % (pad, pname, target.ref if target is not None else "nil"))
        elif kind == "udim2":
            sx, ox, sy, oy = args[0]
            out.append('%s<UDim2 name="%s"><XS>%s</XS><XO>%s</XO><YS>%s</YS><YO>%s</YO></UDim2>'
                       % (pad, pname, num(sx), num(ox), num(sy), num(oy)))
        else:
            raise ValueError("unknown prop kind " + kind)
    return out


def render(node, indent=0, out=None):
    if out is None:
        out = []
    pad = "  " * indent
    out.append('%s<Item class="%s" referent="%s">' % (pad, node.cls, node.ref))
    out.append("%s  <Properties>" % pad)
    out.append('%s    <string name="Name">%s</string>' % (pad, escape(node.name or node.cls)))
    out.extend(render_props(node, indent + 2))
    out.append("%s  </Properties>" % pad)
    for child in node.children:
        render(child, indent + 1, out)
    out.append('%s</Item>' % pad)
    return out


# ----------------------------------------------------------- scene atoms ----
def part(name, size, pos, yaw=0.0, roll=0.0, color=(163, 162, 165), material=None,
         transparency=None, shape=None, anchored=True, cancollide=None, reflectance=None):
    n = Node("Part", name)
    n.p("vec3", "size", size)
    n.p("cframe", "CFrame", tuple(pos), yaw, roll)
    n.p("color", "Color", color)
    n.p("bool", "Anchored", anchored)
    if material:
        n.p("token", "Material", MATERIALS[material])
    if transparency is not None:
        n.p("float", "Transparency", transparency)
    if shape:
        n.p("token", "Shape", PART_TYPE[shape])
    if cancollide is not None:
        n.p("bool", "CanCollide", cancollide)
    if reflectance is not None:
        n.p("float", "Reflectance", reflectance)
    return n


def vehicle_seat(name, size, pos, color):
    n = Node("VehicleSeat", name)
    n.p("vec3", "size", size)
    n.p("cframe", "CFrame", tuple(pos), 0.0, 0.0)
    n.p("color", "Color", color)
    n.p("bool", "Anchored", False)
    n.p("float", "MaxSpeed", 24.0)
    n.p("float", "TurnSpeed", 6.0)
    return n


def attachment(parent_node, pos, yaw=0.0, roll=0.0):
    n = Node("Attachment", "Attachment")
    n.p("cframe", "CFrame", tuple(pos), yaw, roll)
    parent_node.add(n)
    return n


def weld(name, part0, cframe0, part1, cframe1):
    n = Node("WeldConstraint", name)
    n.p("ref", "Part0", part0)
    n.p("ref", "Part1", part1)
    n.p("cframe", "CFrame0", cframe0, 0.0, 0.0)
    n.p("cframe", "CFrame1", cframe1, 0.0, 0.0)
    return n


def hinge(name, attach0, attach1, actuator="None", torque=None, target_angle=None, angular_speed=None):
    n = Node("HingeConstraint", name)
    n.p("ref", "Attachment0", attach0)
    n.p("ref", "Attachment1", attach1)
    n.p("token", "ActuatorType", ACTUATOR[actuator])
    if actuator == "Motor":
        n.p("float", "MotorMaxTorque", torque or 9000.0)
        n.p("float", "MotorMaxAcceleration", 200000.0)
    elif actuator == "Servo":
        n.p("float", "ServoMaxTorque", torque or 250000.0)
        if target_angle is not None:
            n.p("float", "TargetAngle", target_angle)
        if angular_speed is not None:
            n.p("float", "AngularSpeed", angular_speed)
    return n


def model(name, *children):
    return Node("Model", name).add(*children)


def billboard(part_node, text, width, height, offset_y, color=(255, 240, 200), size=24, always_on_top=True):
    bb = Node("BillboardGui", "Billboard")
    bb.p("udim2", "Size", (0, width, 0, height))
    bb.p("vec3", "StudsOffsetWorldSpace", (0, offset_y, 0))
    bb.p("bool", "AlwaysOnTop", always_on_top)
    label = Node("TextLabel", "Label")
    label.p("udim2", "Size", (1, 0, 1, 0))
    label.p("color3", "TextColor3", color)
    label.p("float", "BackgroundTransparency", 1.0)
    label.p("bool", "TextScaled", True)
    label.p("string", "Text", text)
    label.p("int", "BorderSizePixel", 0)
    bb.add(label)
    part_node.add(bb)
    return part_node


def surface_text(part_node, lines, headline_name=None, sub=None, width=500, height=300):
    gui = Node("SurfaceGui", "SurfaceGui")
    gui.p("vec2", "CanvasSize", (width, height))
    if headline_name:
        t = Node("TextLabel", headline_name)
        t.p("udim2", "Size", (1, -24, 0.55, 0))
        t.p("udim2", "Position", (0, 12, 0, 10))
        t.p("color3", "TextColor3", (255, 214, 130))
        t.p("float", "BackgroundTransparency", 1.0)
        t.p("bool", "TextScaled", True)
        t.p("string", "Text", lines)
        t.p("int", "BorderSizePixel", 0)
        gui.add(t)
    if sub:
        sublabel = Node("TextLabel", "Sub")
        sublabel.p("udim2", "Size", (1, -24, 0.36, 0))
        sublabel.p("udim2", "Position", (0, 12, 0.6, 0))
        sublabel.p("color3", "TextColor3", (225, 225, 232))
        sublabel.p("float", "BackgroundTransparency", 1.0)
        sublabel.p("bool", "TextScaled", True)
        sublabel.p("string", "Text", sub)
        sublabel.p("int", "BorderSizePixel", 0)
        gui.add(sublabel)
    part_node.add(gui)
    return part_node


# ------------------------------------------------------------ world build ----
DRIVE_CONTROLLER_LUAU = """-- DriveController: maps VehicleSeat input to hinge motors/servos (server-side)
local van = script.Parent
local seat = van:WaitForChild("Seat")
local rear = { van:FindFirstChild("DriveHingeL"), van:FindFirstChild("DriveHingeR") }
local steer = { van:FindFirstChild("SteerHingeL"), van:FindFirstChild("SteerHingeR") }
local MAX_SPEED = 26 -- studs/s

seat:GetPropertyChangedSignal("Throttle"):Connect(function()
	for _, hingeItem in ipairs(rear) do
		if hingeItem then
			hingeItem.MotorMaxTorque = 20000
			hingeItem.MotorAngularVelocity = seat.Throttle * MAX_SPEED
		end
	end
end)

seat:GetPropertyChangedSignal("Steering"):Connect(function()
	for _, hingeItem in ipairs(steer) do
		if hingeItem then
			hingeItem.AngularSpeed = 8
			hingeItem.TargetAngle = -seat.Steering * 0.45 -- rad; flip the sign if steering feels reversed in Studio
		end
	end
end)

seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	if not seat.Occupant then
		for _, hingeItem in ipairs(rear) do
			if hingeItem then hingeItem.MotorAngularVelocity = 0 end
		end
		for _, hingeItem in ipairs(steer) do
			if hingeItem then hingeItem.TargetAngle = 0 end
		end
	end
end)
"""


def build_van(name, x, z, color=(228, 228, 232)):
    m = Node("Model", name)
    chassis = part("Chassis", (6.4, 1.2, 11), (x, 2.3, z), anchored=False, color=color, material="SmoothPlastic")
    box = part("CargoBox", (6.4, 1.5, 5), (x, 3.35, z + 3), anchored=False, color=color, material="SmoothPlastic")
    glass = part("Windshield", (6.0, 1.0, 0.25), (x, 3.35, z - 2.6), anchored=False,
                 color=(160, 205, 225), material="Glass", transparency=0.5)
    seat = vehicle_seat("Seat", (2.2, 0.9, 2.2), (x - 1.4, 3.05, z - 0.8), (90, 92, 100))
    m.add(chassis, box, glass, seat)

    # weld accessories relative to chassis
    m.add(weld("WeldBox", chassis, (0, 0, 0), box, (0, 0, 0)))
    m.add(weld("WeldGlass", chassis, (0, 0, 0), glass, (0, 0, 0)))
    m.add(weld("WeldSeat", chassis, (0, 0, 0), seat, (0, 0, 0)))

    wheel_size = (1.6, 2.8, 2.8)
    wheel_color = (35, 35, 38)
    for side in (-1, 1):
        # rear wheel: motor-driven
        wpos = (x + side * 4.3, 1.4, z + 4.2)
        wheel = part("WheelRear%s" % ("L" if side < 0 else "R"), wheel_size, wpos, anchored=False,
                     color=wheel_color, material="Rubber", shape="Cylinder")
        a0 = attachment(chassis, wpos)
        a1 = attachment(wheel, wpos)
        m.add(wheel)
        m.add(hinge("DriveHinge%s" % ("L" if side < 0 else "R"), a0, a1, actuator="Motor", torque=20000.0))
        # front wheel: steering servo + free-spin hinge
        fpos = (x + side * 4.3, 1.4, z - 4.2)
        mount = part("SteerMount%s" % ("L" if side < 0 else "R"), (0.6, 0.6, 0.6), (fpos[0], 1.5, fpos[2]), anchored=False,
                     color=(120, 120, 126), material="Metal")
        m.add(mount, weld("WeldMount%s" % ("L" if side < 0 else "R"), chassis, (0, 0, 0), mount, (0, 0, 0)))
        sa0 = attachment(chassis, fpos, roll=90.0)   # hinge axis -> Y (vertical steering axis)
        sa1 = attachment(mount, fpos, roll=90.0)
        m.add(hinge("SteerHinge%s" % ("L" if side < 0 else "R"), sa0, sa1, actuator="Servo",
                    target_angle=0.0, angular_speed=8.0))
        wheel_f = part("WheelFront%s" % ("L" if side < 0 else "R"), (1.6, 2.8, 2.8), fpos, anchored=False,
                       color=wheel_color, material="Rubber", shape="Cylinder")
        fa0 = attachment(mount, fpos)
        fa1 = attachment(wheel_f, fpos)
        m.add(wheel_f)
        m.add(hinge("SpinHinge%s" % ("L" if side < 0 else "R"), fa0, fa1, actuator="None"))
    ctrl = Node("Script", "DriveController")
    ctrl.p("psource", "Source", DRIVE_CONTROLLER_LUAU)
    m.add(ctrl)
    return m


def build_building(name, cx, cz, w, d, h, face, body_color):
    parts = []
    body = part(name, (w, h, d), (cx, h / 2.0, cz), color=body_color, material="Concrete")
    parts.append(body)
    parts.append(part(name + "Roof", (w + 1.8, 0.7, d + 1.8), (cx, h + 0.35, cz),
                      color=(66, 68, 74), material="Cobblestone"))
    if face == "+z":
        door_pos = (cx, 3.0, cz + d / 2.0 + 0.16)
        wy = max(4.0, h * 0.52)
        parts.append(part(name + "WinL", (w * 0.14, 4.2, 0.3), (cx - w * 0.26, wy, cz + d / 2.0 + 0.16),
                          color=(52, 66, 88), material="Glass", transparency=0.35))
        parts.append(part(name + "WinR", (w * 0.14, 4.2, 0.3), (cx + w * 0.26, wy, cz + d / 2.0 + 0.16),
                          color=(52, 66, 88), material="Glass", transparency=0.35))
    elif face == "-z":
        door_pos = (cx, 3.0, cz - d / 2.0 - 0.16)
        wy = max(4.0, h * 0.52)
        parts.append(part(name + "WinL", (w * 0.14, 4.2, 0.3), (cx - w * 0.26, wy, cz - d / 2.0 - 0.16),
                          color=(52, 66, 88), material="Glass", transparency=0.35))
        parts.append(part(name + "WinR", (w * 0.14, 4.2, 0.3), (cx + w * 0.26, wy, cz - d / 2.0 - 0.16),
                          color=(52, 66, 88), material="Glass", transparency=0.35))
    elif face == "+x":
        door_pos = (cx + w / 2.0 + 0.16, 3.0, cz)
        wy = max(4.0, h * 0.52)
        parts.append(part(name + "WinL", (0.3, 4.2, d * 0.14), (cx + w / 2.0 + 0.16, wy, cz - d * 0.26),
                          color=(52, 66, 88), material="Glass", transparency=0.35))
        parts.append(part(name + "WinR", (0.3, 4.2, d * 0.14), (cx + w / 2.0 + 0.16, wy, cz + d * 0.26),
                          color=(52, 66, 88), material="Glass", transparency=0.35))
    else:  # -x
        door_pos = (cx - w / 2.0 - 0.16, 3.0, cz)
        wy = max(4.0, h * 0.52)
        parts.append(part(name + "WinL", (0.3, 4.2, d * 0.14), (cx - w / 2.0 - 0.16, wy, cz - d * 0.26),
                          color=(52, 66, 88), material="Glass", transparency=0.35))
        parts.append(part(name + "WinR", (0.3, 4.2, d * 0.14), (cx - w / 2.0 - 0.16, wy, cz + d * 0.26),
                          color=(52, 66, 88), material="Glass", transparency=0.35))
    parts.append(part(name + "Door", (2.4 if face in ("+z", "-z") else 0.3, 6,
                                      2.4 if face in ("+x", "-x") else 0.3),
                      door_pos, color=(30, 34, 40), material="SmoothPlastic"))
    return model(name + "Block", *parts)


def build_home(hx, hz):
    interior_origin = (hx, 0.0, hz)
    walls = (206, 178, 148)
    floor = part("Floor", (24, 0.4, 18), (hx, -0.2, hz), color=(88, 74, 60), material="WoodPlanks")
    back = part("WallBack", (24, 8, 0.6), (hx, 4.0, hz - 8.7), color=walls, material="Cobblestone")
    west = part("WallWest", (0.6, 8, 16.8), (hx - 11.7, 4.0, hz), color=walls, material="Cobblestone")
    east = part("WallEast", (0.6, 8, 16.8), (hx + 11.7, 4.0, hz), color=walls, material="Cobblestone")
    front_l = part("WallFrontL", (5.75, 8, 0.6), (hx - 9.125, 4.0, hz + 8.7), color=walls, material="Cobblestone")
    front_r = part("WallFrontR", (13.25, 8, 0.6), (hx + 5.375, 4.0, hz + 8.7), color=walls, material="Cobblestone")
    lintel = part("WallLintel", (5.0, 2.0, 0.6), (hx - 3.75, 7.0, hz + 8.7), color=walls, material="Cobblestone")
    roof = part("Roof", (25.5, 0.8, 19.5), (hx, 8.4, hz), color=(70, 58, 50), material="WoodPlanks")
    console = part("HomeConsole", (2.2, 2.4, 1.1), (hx - 4, 1.2, hz - 8.1), color=(48, 52, 64), material="Metal")
    screen = part("HomeScreen", (3.8, 2.2, 0.35), (hx - 4, 3.6, hz - 8.35), color=(70, 150, 170), material="Neon")
    sign = part("HomeSign", (6.0, 1.6, 0.3), (hx - 3.75, 6.0, hz + 9.05), yaw=180, color=(28, 28, 32))
    surface_text(sign, "APARTMENT 3B", headline_name="Sign")
    m = model("Home", floor, back, west, east, front_l, front_r, lintel, roof, console, screen, sign)
    m.interior = interior_origin  # python-side handle for layout emission
    return m


def build_marcus(px, pz):
    base = 0.13  # plaza slab top
    torso = part("Torso", (2.2, 2.0, 1.1), (px, base + 3.07, pz), color=(44, 60, 92), material="Fabric" if "Fabric" in MATERIALS else "SmoothPlastic")
    head = part("Head", (1.3, 1.3, 1.3), (px, base + 4.72, pz), color=(222, 185, 148), material="SmoothPlastic")
    leg_l = part("LegL", (0.95, 2.0, 0.95), (px - 0.5, base + 1.07, pz), color=(52, 56, 66), material="SmoothPlastic")
    leg_r = part("LegR", (0.95, 2.0, 0.95), (px + 0.5, base + 1.07, pz), color=(52, 56, 66), material="SmoothPlastic")
    arm_l = part("ArmL", (0.9, 2.0, 0.9), (px - 1.55, base + 3.07, pz), color=(44, 60, 92), material="SmoothPlastic")
    arm_r = part("ArmR", (0.9, 2.0, 0.9), (px + 1.55, base + 3.07, pz), color=(44, 60, 92), material="SmoothPlastic")
    brim = part("CapBrim", (1.9, 0.15, 1.9), (px, base + 5.52, pz), color=(30, 30, 34), material="SmoothPlastic")
    top = part("CapTop", (1.45, 0.55, 1.45), (px, base + 5.87, pz), color=(30, 30, 34), material="SmoothPlastic")
    billboard(head, "Marcus — Courier veteran", 150, 34, 0.4)
    return model("Marcus", torso, head, leg_l, leg_r, arm_l, arm_r, brim, top)


def build_plaza():
    base = 0.13  # plaza slab top
    slab = part("Slab", (48, 0.3, 48), (0, -0.02, 0), color=(172, 168, 160), material="Pavement")
    fountain_base = part("FountainBase", (0.9, 9, 9), (0, 0.6, 0), roll=90, shape="Cylinder", color=(190, 188, 180), material="Concrete")
    water = part("FountainWater", (0.5, 7.6, 7.6), (0, 0.85, 0), roll=90, shape="Cylinder",
                 color=(90, 160, 210), material="Glass", transparency=0.35, cancollide=False)
    pillar = part("FountainPillar", (1.4, 2.8, 1.4), (0, 2.4, 0), color=(190, 188, 180), material="Concrete")
    orb = part("FountainOrb", (2.0, 2.0, 2.0), (0, 4.0, 0), shape="Ball", color=(255, 200, 120), material="Neon")
    spawn = Node("SpawnLocation", "SpawnPoint")
    spawn.p("vec3", "size", (8, 0.2, 8))
    spawn.p("cframe", "CFrame", (0, 0.23, 20), 0, 0)
    spawn.p("color", "Color", (120, 126, 136))
    spawn.p("bool", "Neutral", True)
    spawn.p("int", "Duration", 0)
    marcus = build_marcus(6, -5.5)

    board = part("JobBoard", (4.6, 4.6, 0.35), (12, 4.0, -19), yaw=180, color=(120, 88, 60), material="Wood")
    surface_text(board, "MERIDIAN COURIER CO.", headline_name="Headline", sub="Take Contract (E) — steady pay")
    board.leg_l = part("BoardLegL", (0.5, 3.6, 0.5), (12 - 1.7, 1.93, -19), color=(96, 70, 48), material="Wood")
    board.leg_r = part("BoardLegR", (0.5, 3.6, 0.5), (12 + 1.7, 1.93, -19), color=(96, 70, 48), material="Wood")
    board_node = model("JobBoardPart", board, board.leg_l, board.leg_r)
    # rename: service expects plaza child named "JobBoard"
    board_node.name = "JobBoard"

    depot = part("PackageDepot", (3.4, 3.2, 3.4), (20, 1.87, -12), color=(176, 132, 84), material="Wood")
    billboard(depot, "Courier Depot", 140, 30, 1.8, color=(255, 220, 160))
    crate2 = part("Crate2", (3.0, 3.0, 3.0), (20.3, 5.8, -11.7), color=(168, 126, 82), material="Wood")
    pallet = part("Pallet", (5.4, 0.4, 5.4), (20, 0.4, -12), color=(110, 84, 56), material="WoodPlanks")
    depot_model = model("DepotModel", depot, crate2, pallet)
    depot_model.name = "PackageDepot"

    news = part("NewsScreen", (13.4, 8, 0.6), (-22, 5.06, -12), yaw=-90, color=(20, 22, 26), material="SmoothPlastic")
    surface_text(news, "MERIDIAN EVENING NEWS", headline_name="Headline",
                 sub="Harbor bridge traffic • sunny weekend ahead • harbor facility 'unplanned outage' officials say")
    nl = part("NewsLegL", (0.7, 4.4, 0.7), (-22, 2.2, -12 - 4.6), color=(50, 52, 58), material="Metal")
    nr = part("NewsLegR", (0.7, 4.4, 0.7), (-22, 2.2, -12 + 4.6), color=(50, 52, 58), material="Metal")
    news_model = model("NewsScreenBlock", news, nl, nr)
    news_model.name = "NewsScreen"

    lamps = []
    for lx, lz in ((-22, -22), (22, -22), (-22, 22), (22, 22)):
        pole = part("LampPole", (0.35, 7.5, 0.35), (lx, base + 3.75, lz), color=(60, 62, 68), material="Metal")
        bulb = part("LampBulb", (1.1, 0.8, 1.1), (lx, base + 7.9, lz), color=(255, 214, 150), material="Neon")
        lamps.append(model("Lamp", pole, bulb))
    benches = []
    for bx, bz, byaw in ((-8, 12, 180), (10, 12, 180), (-10, -12, 0)):
        seat = part("BenchSeat", (3.5, 0.35, 1.3), (bx, base + 0.62, bz), color=(120, 90, 62), material="Wood")
        back = part("BenchBack", (3.5, 1.1, 0.3), (bx, base + 1.35, bz + (0.55 if byaw == 180 else -0.55)),
                    color=(120, 90, 62), material="Wood")
        benches.append(model("Bench", seat, back))

    plaza_node = model("Plaza", slab, fountain_base, water, pillar, orb, spawn, marcus,
                       board_node, depot_model, news_model, *lamps, *benches)
    return plaza_node


def build_shop():
    counter = part("ShopConsole", (7.4, 1.3, 2.6), (52.6, 0.72, 20), color=(70, 74, 86), material="DiamondPlate")
    billboard(counter, "Meridian Outfitters", 170, 32, 2.2, color=(255, 214, 130))
    back = part("ShopBack", (8.0, 6.5, 0.8), (57.4, 3.25, 20), color=(96, 78, 60), material="Cobblestone")
    awning = part("ShopAwning", (9.5, 0.5, 4.5), (53.5, 6.9, 20), color=(190, 60, 60), material="Fabric" if "Fabric" in MATERIALS else "SmoothPlastic")
    pole_l = part("AwningPoleL", (0.3, 6.6, 0.3), (50.2, 3.3, 18.2), color=(80, 82, 88), material="Metal")
    pole_r = part("AwningPoleR", (0.3, 6.6, 0.3), (50.2, 3.3, 21.8), color=(80, 82, 88), material="Metal")
    return model("Shop", counter, back, awning, pole_l, pole_r)


def build_targets():
    targets = Node("Model", "DeliveryTargets")
    coords = [
        (-70, 0.23, -57.9),
        (26, 0.23, -69.9),
        (76.9, 0.23, 10.0),
        (-49.9, 0.23, 58.0),
    ]
    for i, (tx, ty, tz) in enumerate(coords, start=1):
        mat = part("Target%d" % i, (4, 0.3, 4), (tx, ty, tz), color=(198, 150, 64), material="Concrete")
        billboard(mat, "DELIVERY POINT %d" % i, 170, 34, 1.4, color=(255, 200, 110))
        targets.add(mat)
    return targets


def build_props():
    props = []
    trees = [(-95, 25, 4.6), (115, 45, 5.2), (6, -112, 5.6), (-32, 98, 4.4), (112, -38, 4.8), (-112, -28, 5.0)]
    for i, (tx, tz, th) in enumerate(trees, start=1):
        trunk = part("TreeTrunk%d" % i, (0.9, th, 0.9), (tx, th / 2.0, tz), color=(96, 72, 50), material="Wood")
        ball = part("TreeTop%d" % i, (5.4, 5.0, 5.4), (tx, th + 2.2, tz), shape="Ball", color=(70, 122, 64), material="LeafyGrass")
        props.append(model("Tree%d" % i, trunk, ball))
    for i, (lx, lz) in enumerate(((-56, -56), (56, -56), (-56, 56), (56, 56)), start=1):
        pole = part("RoadLampPole%d" % i, (0.4, 8.5, 0.4), (lx, 4.05, lz), color=(60, 62, 68), material="Metal")
        bulb = part("RoadLampBulb%d" % i, (1.2, 0.8, 1.2), (lx, 8.9, lz), color=(255, 220, 160), material="Neon")
        props.append(model("RoadLamp%d" % i, pole, bulb))
    return props


def build_settlement_board(hx, hz):
    """Phase 4: settlement board sign at the yard entrance."""
    pole = part("BoardPole", (0.4, 3.0, 0.4), (hx + 8, 1.5, hz - 22), color=(84, 70, 56), material="Wood")
    board = part("Board", (3.6, 1.5, 0.24), (hx + 8, 2.6, hz - 22), color=(132, 108, 78), material="Wood")
    surface_text(board, "SETTLEMENT BOARD", headline_name="Headline", sub="Foundations — press E")
    return model("SettlementBoard", pole, board)


def build_hero_kiosk():
    """Phase 3: Heroes Hall recruitment kiosk in the plaza."""
    kiosk = part("HeroKiosk", (2.6, 3.4, 1.3), (16, 1.83, -17), yaw=205, color=(52, 60, 86), material="Metal")
    surface_text(kiosk, "HEROES HALL", headline_name="Headline", sub="Recruit • Evolve ★ • Deploy — press E")
    kiosk_base = part("KioskBase", (3.0, 0.3, 1.7), (16, 0.28, -17), color=(40, 46, 60), material="Metal")
    lamp = part("KioskLamp", (0.5, 0.24, 0.5), (16, 3.7, -17), color=(150, 200, 255), material="Neon")
    return model("HeroKioskBlock", kiosk, kiosk_base, lamp)


def build_phase2_nodes(hx, hz):
    """Phase 2: scavenge rubble, infected spawn markers, safehouse barricade anchor."""
    rubble = Node("Model", "Rubble")
    pile_spots = [(34, -52), (-44, -48), (66, -28)]
    for i, (px, pz) in enumerate(pile_spots, start=1):
        base = part(f"RubblePile{i}", (4.5, 1.3, 4.5), (px, 0.8, pz), color=(112, 108, 100), material="Cobblestone")
        shard = part(f"RubbleShard{i}a", (1.6, 0.9, 1.6), (px + 1.2, 0.9, pz + 0.9), yaw=25,
                     color=(96, 92, 86), material="Concrete")
        shard_b = part(f"RubbleShard{i}b", (1.1, 0.7, 1.1), (px - 1.1, 0.7, pz - 0.9), yaw=-40,
                       color=(128, 108, 76), material="Wood")
        beam = part(f"RubbleBeam{i}", (0.5, 0.5, 4.2), (px - 0.4, 1.1, pz + 0.2), yaw=65,
                    color=(126, 92, 58), material="Wood")
        rubble.add(model(f"Rubble{i}", base, shard, shard_b, beam))

    spawns = Node("Model", "InfectedSpawns")
    for i, (px, pz) in enumerate(((8, -64), (-30, -76), (54, -52)), start=1):
        marker = part(f"Spawn{i}", (1, 3, 1), (px, 3.0, pz), color=(40, 90, 40),
                      material="Grass", transparency=1, cancollide=False)
        spawns.add(marker)

    safehouse = Node("Model", "Safehouse")
    anchor = part("BarricadeAnchor", (0.4, 6, 4.4), (hx - 3.75, 3.0, hz + 8.7),
                  color=(140, 96, 50), material="Wood", transparency=1, cancollide=False)
    safehouse.add(anchor)

    return model("Phase2Nodes", rubble, spawns, safehouse)


def build_world():
    home = build_home(-60, -8)
    meridian = Node("Model", "Meridian")
    meridian.add(
        part("Ground", (420, 2, 420), (0, -1, 0), color=(58, 58, 62), material="Asphalt"),
        model("Roads",
              part("RoadN", (300, 0.5, 12), (0, 0.05, -36), color=(74, 74, 78), material="Asphalt"),
              part("RoadS", (300, 0.5, 12), (0, 0.05, 36), color=(74, 74, 78), material="Asphalt"),
              part("RoadE", (12, 0.5, 300), (36, 0.05, 0), color=(74, 74, 78), material="Asphalt"),
              part("RoadW", (12, 0.5, 300), (-36, 0.05, 0), color=(74, 74, 78), material="Asphalt")),
        build_plaza(),
        home,
        build_shop(),
        model("Buildings",
              build_building("Building1", -70, -70, 28, 20, 30, "+z", (176, 182, 196)),
              build_building("Building2", 26, -84, 30, 24, 46, "+z", (154, 160, 178)),
              build_building("Building3", 88, -64, 26, 22, 20, "-x", (198, 166, 126)),
              build_building("Building4", 94, 10, 30, 26, 38, "-x", (126, 170, 168)),
              build_building("Building5", 78, 84, 26, 20, 16, "-z", (184, 112, 98)),
              build_building("Building6", 6, 92, 34, 22, 24, "-z", (152, 152, 158)),
              build_building("Building7", -66, 58, 28, 20, 34, "+x", (150, 162, 148))),
        build_targets(),
        build_phase2_nodes(-60, -8),
        build_hero_kiosk(),
        build_settlement_pads(-60, -8),
        build_settlement_board(-60, -8),
        model("Vans", build_van("Van1", 46, -8), build_van("Van2", 46, 16)),
        model("Props", *build_props()),
    )
    workspace = Node("Workspace", "Workspace").add(meridian)
    return workspace, home.interior


# --------------------------------------------------- WorldLayout emission ----
DELIVERY_TARGETS = [
    (-70.0, 0.23, -57.9),
    (26.0, 0.23, -69.9),
    (76.9, 0.23, 10.0),
    (-49.9, 0.23, 58.0),
]
PACKAGE_DEPOT = (20.0, 1.9, -12.0)
RUBBLE_PILES = [(34.0, 0.8, -52.0), (-44.0, 0.8, -48.0), (66.0, 0.8, -28.0)]
INFECTED_SPAWNS = [(8.0, 3.0, -64.0), (-30.0, 3.0, -76.0), (54.0, 3.0, -52.0)]
# Phase 4: settlement foundation pads — offsets from the home lot (north yard)
PAD_OFFSETS = [(-6.0, -30.0), (2.0, -30.0), (-6.0, -38.0), (2.0, -38.0)]
BUILD_PADS: list = []  # filled by build_settlement_pads()


def build_settlement_pads(hx, hz):
    """Phase 4: four foundation pads in the yard behind the home lot."""
    pads = []
    for i, (dx, dz) in enumerate(PAD_OFFSETS):
        idx = i + 1
        x, z = hx + dx, hz + dz
        pad = part("Pad%d" % idx, (4.6, 0.24, 4.6), (x, 0.12, z), color=(96, 100, 108), material="Concrete")
        outline = part("Pad%dOutline" % idx, (5.6, 0.06, 5.6), (x, 0.035, z), color=(64, 68, 76), material="Concrete")
        pads.append(pad)
        pads.append(outline)
        BUILD_PADS.append((x, 0.24, z))
    return model("SettlementPads", *pads)


def write_world_layout(home_interior):
    home_x, home_y, home_z = home_interior
    lines = [
        "-- GENERATED by build_place.py — DO NOT hand-edit.",
        "-- Single source of truth for interaction coordinates used by services.",
        "return {",
        "\tHOME_INTERIOR = { x = %s, y = %s, z = %s }," % (num(home_x), num(home_y), num(home_z)),
        "\tPACKAGE_DEPOT = { x = %s, y = %s, z = %s }," % tuple(num(v) for v in PACKAGE_DEPOT),
        "\tDELIVERY_TARGETS = {",
    ]
    for (x, y, z) in DELIVERY_TARGETS:
        lines.append("\t\t{ x = %s, y = %s, z = %s }," % (num(x), num(y), num(z)))
    lines.append("\t},")
    lines.append("\tBARRICADE = { x = %s, y = 3.0, z = %s }," % (num(home_x - 3.75), num(home_z + 8.7)))
    lines.append("\tRUBBLE_PILES = {")
    for (x, y, z) in RUBBLE_PILES:
        lines.append("\t\t{ x = %s, y = %s, z = %s }," % (num(x), num(y), num(z)))
    lines.append("\t},")
    lines.append("\tINFECTED_SPAWNS = {")
    for (x, y, z) in INFECTED_SPAWNS:
        lines.append("\t\t{ x = %s, y = %s, z = %s }," % (num(x), num(y), num(z)))
    lines.append("\t},")
    lines.append("\tHERO_KIOSK = { x = 16.0, y = 1.83, z = -17.0 },")
    lines.append("\tBUILD_PADS = {")
    for (x, y, z) in BUILD_PADS:
        lines.append("\t\t{ x = %s, y = %s, z = %s }," % (num(x), num(y), num(z)))
    lines.append("\t},")
    lines.append("}")
    with open(WORLD_LAYOUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote %s" % os.path.relpath(WORLD_LAYOUT, ROOT))


# -------------------------------------------------------- script tree map ----
def script_kind(filename: str, path: str):
    base = os.path.splitext(filename)[0]
    if base.endswith(".server"):
        return "Script", base[: -len(".server")]
    if base.endswith(".client"):
        return "LocalScript", base[: -len(".client")]
    return "ModuleScript", base


def read_source(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def script_node(class_name, script_name, path):
    n = Node(class_name, script_name)
    n.p("bool", "Enabled", True)
    n.p("psource", "Source", read_source(path))
    return n


def map_dir_to_folder(dir_path, folder_name):
    folder = Node("Folder", folder_name)
    entries = sorted(os.listdir(dir_path))
    for entry in entries:
        full = os.path.join(dir_path, entry)
        if os.path.isdir(full):
            folder.add(map_dir_to_folder(full, entry))
        elif entry.endswith(".lua"):
            cls, name = script_kind(entry, full)
            folder.add(script_node(cls, name, full))
    return folder


def build_replicated_storage():
    node = Node("ReplicatedStorage", "ReplicatedStorage")
    node.add(map_dir_to_folder(os.path.join(SRC, "ReplicatedStorage"), "Contents"))
    # contents of the temporary "Contents" folder should live directly at the root:
    node.children = node.children[0].children
    return node


def build_server_script_service():
    node = Node("ServerScriptService", "ServerScriptService")
    bootstrap = script_node("Script", "Bootstrap", os.path.join(SRC, "ServerScriptService", "Bootstrap.server.lua"))
    services = map_dir_to_folder(os.path.join(SRC, "ServerScriptService", "Services"), "Services")
    node.add(bootstrap, services)
    return node


def build_starter_player():
    sp = Node("StarterPlayer", "StarterPlayer")
    sps = Node("StarterPlayerScripts", "StarterPlayerScripts")
    sps_dir = os.path.join(SRC, "StarterPlayer", "StarterPlayerScripts")
    for entry in sorted(os.listdir(sps_dir)):
        full = os.path.join(sps_dir, entry)
        if entry.endswith(".lua"):
            cls, name = script_kind(entry, full)
            sps.add(script_node(cls, name, full))
    sp.add(sps)
    return sp


# --------------------------------------------------------------------- doc ----
def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    workspace, home_interior = build_world()
    write_world_layout(home_interior)

    doc = ['<roblox xmlns:xmime="http://schemas.microsoft.com/2003/10/Serialization/" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">']
    xml_lines = []
    for top in (workspace, build_replicated_storage(), build_server_script_service(), build_starter_player()):
        render(top, 1, xml_lines)
    doc.extend(xml_lines)
    doc.append("</roblox>")

    xml = "\n".join(doc)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)

    # validate
    from xml.dom import minidom
    dom = minidom.parseString(xml)
    items = dom.getElementsByTagName("Item")
    classes = {}
    for it in items:
        classes[it.getAttribute("class")] = classes.get(it.getAttribute("class"), 0) + 1
    scripts = sum(classes.get(k, 0) for k in ("Script", "LocalScript", "ModuleScript"))
    print("wrote %s" % os.path.relpath(OUT, ROOT))
    print("items: %d total | classes: %s" % (len(items), ", ".join("%s=%d" % kv for kv in sorted(classes.items()))))
    print("scripts: %d" % scripts)
    _ref_counter[0] = 0


if __name__ == "__main__":
    main()