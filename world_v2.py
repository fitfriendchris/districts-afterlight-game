#!/usr/bin/env python3
"""world_v2.py — Districts: Afterlight V2: "Meridian District".

Stylized Tactical Low-Poly downtown, per Chris's visual master spec:
  - clean low-poly geometry, SmoothPlastic/matte, crisp edges
  - cool charcoal/slate base (#2C3539 family) with Neon Cyan / Gold /
    Hazard Amber accents
  - INTERIORS you can walk into (store, armory, cafe, warehouse, clan hall,
    home, safehouse)

GAMEPLAY CONTRACT: gameplay coordinates + instance names stay exactly where
services expect. build_meridian_v2() also RETURNS the coordinate overrides so
build_place.py emits WorldLayout.lua from the same values (no drift).
"""
import math
from build_place import part, model, Node, surface_text, billboard, add_light

# ------------------------------------------------------------- palette ----
GROUNDC = (58, 62, 66)       # city slate ground
ROAD = (44, 48, 52)
ROAD_LINE = (222, 218, 200)
PAVE = (152, 154, 150)
PAVE_D = (128, 130, 128)
CONC = (150, 152, 148)
SLATE = (86, 96, 102)        # #565F66-ish buildings
SLATE_D = (62, 72, 78)
CHARCOAL = (44, 53, 57)      # #2C3539
CHARCOAL_D = (34, 40, 44)
STEEL = (110, 116, 122)
STEEL_D = (72, 78, 84)
GLASSC = (150, 200, 230)     # cyan window glow
GLASS_T = 0.42
WOOD = (116, 92, 68)
WOOD_D = (92, 72, 54)
GOLD = (250, 200, 92)
CYAN = (96, 196, 255)
HAZARD = (232, 148, 42)
NEON_MAG = (255, 110, 160)
GREEN = (108, 174, 96)

LIGHT_COOL = (168, 208, 255)
LIGHT_AMBER = (255, 178, 96)


def lamp(name, x, y, z, color=LIGHT_COOL, brightness=1.15, range_=16.0, size=(1.0, 0.7, 1.0)):
    return add_light(part(name, size, (x, y, z), color=color, material="Neon"),
                     color, brightness, range_)


def crate(name, x, z, s=2.2, yaw=0.0, color=(140, 130, 112)):
    return part(name, (s, s, s), (x, 0.5 + s / 2.0, z), yaw=yaw,
                color=color, material="SmoothPlastic")


def keeper(name, x, z, shirt=(52, 62, 90), skin=(222, 185, 148), yaw=0.0):
    return model(name,
                 part("Torso", (2.2, 2.0, 1.1), (x, 3.1, z), yaw=yaw, color=shirt, material="Fabric"),
                 part("Head", (1.3, 1.3, 1.3), (x, 4.75, z), yaw=yaw, color=skin, material="SmoothPlastic"),
                 part("LegL", (0.95, 2.0, 0.95), (x - 0.5, 1.05, z), yaw=yaw, color=(52, 56, 66), material="SmoothPlastic"),
                 part("LegR", (0.95, 2.0, 0.95), (x + 0.5, 1.05, z), yaw=yaw, color=(52, 56, 66), material="SmoothPlastic"),
                 part("ArmL", (0.9, 2.0, 0.9), (x - 1.55, 3.1, z), yaw=yaw, color=shirt, material="Fabric"),
                 part("ArmR", (0.9, 2.0, 0.9), (x + 1.55, 3.1, z), yaw=yaw, color=shirt, material="Fabric"))


def head_of(m):
    for c in m.children:
        if c.name == "Head":
            return c
    return m


# --------------------------------------------------- enterable buildings --
def enterable(cname, cx, cz, w, d, h, door_face="+z", door_w=3.6, door_h=6.2,
              wall=SLATE, mat="SmoothPlastic", floor_mat="SmoothPlastic",
              floor_color=(96, 100, 104), windows=2, sign=None, sign_color=CYAN,
              canopy=True, lamp_count=2, lamp_color=LIGHT_COOL, trim=None,
              roof_color=(56, 62, 66)):
    """Hollow building: floor, 4 walls (door gap on one face, glass windows on
    the others), roof, parapet, marquee sign, interior lamps."""
    P = []
    P.append(part(cname + "Floor", (w, 0.5, d), (cx, 0.05, cz), color=floor_color, material=floor_mat))
    base_y = 0.3
    hw, hd = w / 2.0, d / 2.0
    faces = {"+z": (0, cz + hd), "-z": (0, cz - hd), "+x": (cx + hw, 0), "-x": (cx - hw, 0)}
    trim = trim or CHARCOAL_D
    for face in ("+z", "-z", "+x", "-x"):
        pos = faces[face]
        along_x = face in ("+z", "-z")          # wall runs along X
        run_len = w if along_x else d
        if face == door_face:
            seg = (run_len - door_w) / 2.0
            if along_x:
                P.append(part(cname + "DoorSegL", (seg, h, 0.6), (cx - door_w / 2.0 - seg / 2.0,
                              base_y + h / 2.0, pos[1]), color=wall, material=mat))
                P.append(part(cname + "DoorSegR", (seg, h, 0.6), (cx + door_w / 2.0 + seg / 2.0,
                              base_y + h / 2.0, pos[1]), color=wall, material=mat))
                P.append(part(cname + "DoorLintel", (door_w, h - door_h, 0.6),
                              (cx, door_h + (h - door_h) / 2.0, pos[1]), color=wall, material=mat))
                P.append(part(cname + "TrimL", (0.35, door_h, 0.8), (cx - door_w / 2.0 - 0.18,
                              door_h / 2.0, pos[1]), color=trim, material="SmoothPlastic"))
                P.append(part(cname + "TrimR", (0.35, door_h, 0.8), (cx + door_w / 2.0 + 0.18,
                              door_h / 2.0, pos[1]), color=trim, material="SmoothPlastic"))
            else:
                P.append(part(cname + "DoorSegL", (0.6, h, seg), (pos[0], base_y + h / 2.0,
                              cz - door_w / 2.0 - seg / 2.0), color=wall, material=mat))
                P.append(part(cname + "DoorSegR", (0.6, h, seg), (pos[0], base_y + h / 2.0,
                              cz + door_w / 2.0 + seg / 2.0), color=wall, material=mat))
                P.append(part(cname + "DoorLintel", (0.6, h - door_h, door_w),
                              (pos[0], door_h + (h - door_h) / 2.0, cz), color=wall, material=mat))
                P.append(part(cname + "TrimL", (0.8, door_h, 0.35), (pos[0], door_h / 2.0,
                              cz - door_w / 2.0 - 0.18), color=trim, material="SmoothPlastic"))
                P.append(part(cname + "TrimR", (0.8, door_h, 0.35), (pos[0], door_h / 2.0,
                              cz + door_w / 2.0 + 0.18), color=trim, material="SmoothPlastic"))
        else:
            P.append(part(cname + "W" + face, (w if along_x else 0.6, h, d if not along_x else 0.6),
                          (pos[0], base_y + h / 2.0, pos[1]), color=wall, material=mat))
            # glass window row
            if windows > 0:
                gl_w, gl_h = 2.6, 3.2
                wy = h * 0.6
                gap = max((run_len - windows * gl_w - 2.0) / max(windows - 1, 1), 1.0)
                span = windows * gl_w + (windows - 1) * gap
                start = -span / 2.0 + gl_w / 2.0
                push = 0.45 if face[0] == "+" else -0.45
                for i in range(windows):
                    off = start + i * (gl_w + gap)
                    if along_x:
                        P.append(part("%sWin%s%d" % (cname, face, i + 1), (gl_w, gl_h, 0.3),
                                      (cx + off, wy + gl_h / 2.0, pos[1] + push),
                                      color=GLASSC, material="Glass", transparency=GLASS_T))
                    else:
                        P.append(part("%sWin%s%d" % (cname, face, i + 1), (0.3, gl_h, gl_w),
                                      (pos[0] + push, wy + gl_h / 2.0, cz + off),
                                      color=GLASSC, material="Glass", transparency=GLASS_T))
    # roof + parapet
    roof_y = base_y + h + 0.4
    P.append(part(cname + "Roof", (w + 1.4, 0.8, d + 1.4), (cx, roof_y, cz), color=roof_color, material="SmoothPlastic"))
    py = roof_y + 0.9
    P.append(part(cname + "ParaN", (w + 1.4, 1.0, 0.6), (cx, py, cz - d / 2.0 - 0.4), color=wall, material=mat))
    P.append(part(cname + "ParaS", (w + 1.4, 1.0, 0.6), (cx, py, cz + d / 2.0 + 0.4), color=wall, material=mat))
    P.append(part(cname + "ParaW", (0.6, 1.0, d + 1.4), (cx - w / 2.0 - 0.4, py, cz), color=wall, material=mat))
    P.append(part(cname + "ParaE", (0.6, 1.0, d + 1.4), (cx + w / 2.0 + 0.4, py, cz), color=wall, material=mat))
    # marquee sign on door face — SurfaceGui Face=Front renders on local −Z, so
    # yaw must rotate −Z toward the street: +z→180, −z→0, +x→−90, −x→+90
    if sign:
        if door_face in ("+z", "-z"):
            zoff = (d / 2.0 + 0.95) * (1 if door_face == "+z" else -1)
            sp = part(cname + "Sign", (min(w * 0.72, 16), 1.8, 0.3), (cx, base_y + h - 1.0, cz + zoff),
                      yaw=(180 if door_face == "+z" else 0),
                      color=CHARCOAL_D, material="SmoothPlastic")
        else:
            xoff = (w / 2.0 + 0.95) * (1 if door_face == "+x" else -1)
            sp = part(cname + "Sign", (0.3, 1.8, min(d * 0.72, 14)), (cx + xoff, base_y + h - 1.0, cz),
                      yaw=(-90 if door_face == "+x" else 90),
                      color=CHARCOAL_D, material="SmoothPlastic")
        surface_text(sp, sign, headline_name="SignHead")
        add_light(sp, sign_color, 0.8, 9.0)
        P.append(sp)
    # canopy
    if canopy:
        if door_face in ("+z", "-z"):
            P.append(part(cname + "Canopy", (door_w + 3.6, 0.28, 3.0),
                          (cx, door_h + 0.3, cz + (d / 2.0 + 1.6) * (1 if door_face == "+z" else -1)),
                          color=HAZARD, material="SmoothPlastic"))
        else:
            P.append(part(cname + "Canopy", (3.0, 0.28, door_w + 3.6),
                          (cx + (w / 2.0 + 1.6) * (1 if door_face == "+x" else -1), door_h + 0.3, cz),
                          color=HAZARD, material="SmoothPlastic"))
    # interior lamps
    for i in range(lamp_count):
        f = (i + 0.5) / lamp_count - 0.5
        if door_face in ("+z", "-z"):
            pos = (cx + f * w, base_y + h - 1.0, cz)
        else:
            pos = (cx, base_y + h - 1.0, cz + f * d)
        P.append(lamp(cname + "Lamp%d" % (i + 1), pos[0], pos[1], pos[2], lamp_color,
                      1.25, max(w, d) * 0.8, size=(0.9, 0.25, 0.9)))
    return P


# ----------------------------------------------------------------- plaza --
def build_plaza_v2():
    P = []
    slab = part("Slab", (56, 0.3, 56), (0, -0.02, 0), color=PAVE, material="Pavement")
    ring = part("PlazaRing", (4.4, 0.08, 4.4), (0, 0.15, 0), shape="Cylinder",
                color=GOLD, material="SmoothPlastic", cancollide=False)
    P.append(slab)
    # fountain, 3 tiers
    basin = part("FountainBase", (0.9, 11.5, 11.5), (0, 0.58, 0), roll=90, shape="Cylinder",
                 color=CONC, material="SmoothPlastic")
    water = part("FountainWater", (0.55, 10.2, 10.2), (0, 0.6, 0), roll=90, shape="Cylinder",
                 color=(96, 168, 216), material="Glass", transparency=0.45, cancollide=False)
    pedestal = part("FountainPillar", (1.7, 2.4, 1.7), (0, 2.15, 0), color=CONC, material="SmoothPlastic")
    midb = part("FountainMid", (0.7, 5.0, 5.0), (0, 3.3, 0), roll=90, shape="Cylinder",
                color=CONC, material="SmoothPlastic")
    midw = part("FountainMidWater", (0.45, 4.2, 4.2), (0, 3.33, 0), roll=90, shape="Cylinder",
                color=(110, 182, 226), material="Glass", transparency=0.45, cancollide=False)
    column = part("FountainColumn", (1.1, 2.4, 1.1), (0, 4.2, 0), color=(140, 142, 138), material="SmoothPlastic")
    orb = part("FountainOrb", (2.2, 2.2, 2.2), (0, 5.7, 0), shape="Ball", color=GOLD, material="Neon")
    add_light(orb, (255, 208, 120), 2.2, 22)
    jet = part("FountainJet", (0.35, 2.6, 0.35), (0, 6.8, 0), color=(170, 214, 244),
               material="Glass", transparency=0.5, cancollide=False)
    P.append(model("Fountain", basin, water, pedestal, midb, midw, column, orb, jet))
    P.append(ring)
    # spawn
    spawn = Node("SpawnLocation", "SpawnPoint")
    spawn.p("vec3", "size", (10, 0.2, 10))
    spawn.p("cframe", "CFrame", (0, 0.24, 20), 0, 0)
    spawn.p("color", "Color", PAVE_D)
    spawn.p("bool", "Neutral", True)
    spawn.p("int", "Duration", 0)
    P.append(spawn)
    marcus = keeper("Marcus", 6, -5.5, shirt=(44, 60, 92))
    billboard(head_of(marcus), "Marcus — Courier veteran", 150, 34, 0.4)
    P.append(marcus)
    # corner planters + hedges
    for i, (px, pz) in enumerate(((-23, -23), (23, -23), (-23, 23), (23, 23)), start=1):
        P.append(part("Planter%d" % i, (5.4, 1.3, 5.4), (px, 0.65, pz), color=CHARCOAL, material="SmoothPlastic"))
        P.append(part("Hedge%d" % i, (4.5, 2.1, 4.5), (px, 2.25, pz), shape="Ball",
                      color=GREEN, material="SmoothPlastic"))
    # benches
    for i, (bx, bz, byaw) in enumerate(((-9, 13, 180), (10, 13, 180), (-11, -13, 0),
                                        (12, -12, -90), (-13, 1, 90), (13, 4, 90)), start=1):
        s = part("Seat%d" % i, (3.6, 0.35, 1.4), (bx, 0.75, bz), yaw=byaw, color=WOOD, material="Wood")
        P.append(model("Bench%d" % i, s,
                       part("Legs", (3.2, 0.5, 1.0), (bx, 0.3, bz), yaw=byaw, color=CHARCOAL, material="SmoothPlastic"),
                       part("Back%d" % i, (3.4, 1.1, 0.25),
                            (bx + (-0.55 if byaw == 90 else 0.55 if byaw == -90 else 0),
                             1.5, bz + (-0.55 if byaw == 180 else 0.55 if byaw == 0 else 0)),
                            yaw=byaw, color=WOOD, material="Wood")))
    # two market stalls
    for i, (sx, sz) in enumerate(((-15, 19), (15, 19)), start=1):
        P.append(model("Stall%d" % i,
                       part("Counter", (6.5, 1.1, 2.6), (sx, 0.85, sz), color=SLATE_D, material="SmoothPlastic"),
                       part("RoofStrip", (7.4, 0.3, 3.6), (sx, 5.2, sz), color=HAZARD, material="SmoothPlastic"),
                       part("PostL", (0.25, 4.8, 0.25), (sx - 3.0, 2.6, sz - 1.2), color=CHARCOAL_D, material="SmoothPlastic"),
                       part("PostR", (0.25, 4.8, 0.25), (sx + 3.0, 2.6, sz - 1.2), color=CHARCOAL_D, material="SmoothPlastic"),
                       crate("GoodsA", sx - 1.5, sz, s=1.2),
                       crate("GoodsB", sx + 1.6, sz, s=1.4, yaw=14)))
    # lamp posts
    for i, (lx, lz) in enumerate(((-24, -14), (24, -14), (-24, 14), (24, 14),
                                  (-14, -24), (14, -24), (-14, 24), (14, 24)), start=1):
        P.append(model("PlazaLamp%d" % i,
                       part("Pole", (0.4, 8.6, 0.4), (lx, 4.4, lz), color=CHARCOAL_D, material="SmoothPlastic"),
                       lamp("Bulb", lx, 8.8, lz, LIGHT_COOL, 1.35, 18, size=(1.15, 0.75, 1.15))))
    # JobBoard (name+coords fixed)
    board = part("JobBoard", (5.4, 4.6, 0.35), (12, 4.0, -19), yaw=180, color=(120, 88, 60), material="SmoothPlastic")
    surface_text(board, "MERIDIAN COURIER CO.", headline_name="Headline", sub="Take Contract (E) — steady pay")
    P.append(model("JobBoard", board,
                   part("LegL", (0.5, 3.7, 0.5), (12 - 2.2, 1.95, -19), color=CHARCOAL_D, material="SmoothPlastic"),
                   part("LegR", (0.5, 3.7, 0.5), (12 + 2.2, 1.95, -19), color=CHARCOAL_D, material="SmoothPlastic"),
                   part("Cap", (5.9, 0.4, 1.2), (12, 6.4, -19), color=HAZARD, material="SmoothPlastic")))
    # PackageDepot parcel cage (name via wrapper below; ContractService waits plaza child)
    depot = part("ParcelStack", (3.4, 3.2, 3.4), (20, 1.87, -12), color=(176, 132, 84), material="SmoothPlastic")
    billboard(depot, "Courier Depot", 140, 30, 1.8, color=GOLD)
    crate2 = part("DepotCrate2", (3.0, 3.0, 3.0), (20.3, 5.8, -11.7), color=(140, 130, 112), material="SmoothPlastic")
    pallet = part("DepotPallet", (5.4, 0.4, 5.4), (20, 0.4, -12), color=(110, 84, 56), material="WoodPlanks")
    rails = []
    k = 0
    for rx, rz, rw, rd in ((20, -14.8, 8.0, 0.18), (20, -9.2, 8.0, 0.18), (16.3, -12, 0.18, 5.2), (23.7, -12, 0.18, 5.2)):
        k += 1
        rails.append(part("DepotRail%d" % k, (rw, 1.0, rd), (rx, 0.9, rz), color=STEEL_D, material="Metal"))
    depot_model = model("PackageDepot", depot, crate2, pallet, *rails)
    # NewsScreen (name fixed, coords fixed)
    news = part("NewsScreen", (14.0, 8.2, 0.6), (-22, 5.06, -12), yaw=-90, color=CHARCOAL_D, material="SmoothPlastic")
    surface_text(news, "MERIDIAN EVENING NEWS", headline_name="Headline",
                 sub="Harbor bridge traffic • sunny weekend ahead • harbor facility 'unplanned outage' officials say")
    news_model = model("NewsScreen", news,
                       part("LegL", (0.7, 4.7, 0.7), (-22, 2.35, -16.6), color=STEEL_D, material="Metal"),
                       part("LegR", (0.7, 4.7, 0.7), (-22, 2.35, -7.4), color=STEEL_D, material="Metal"),
                       part("Cap", (0.8, 0.5, 10.6), (-22, 9.35, -12), color=STEEL_D, material="Metal"),
                       part("Glowbar", (0.25, 0.4, 9.6), (-21.6, 1.4, -12), color=CYAN, material="Neon"))
    P.append(depot_model)
    P.append(news_model)
    return model("Plaza", *P)


# HeroKiosk: HeroService waits Meridian:WaitForChild("HeroKiosk") → the part
# itself must be a DIRECT BasePart child of Meridian.
def build_hero_kiosk_v2():
    base = part("KioskBase", (3.2, 0.5, 1.9), (16, 0.25, -17), color=CHARCOAL_D, material="SmoothPlastic")
    kiosk = part("HeroKiosk", (2.8, 3.6, 1.2), (16, 2.2, -17), yaw=205, color=(30, 44, 56), material="Metal")
    surface_text(kiosk, "HEROES HALL", headline_name="Headline", sub="Recruit • Evolve ★ • Deploy — press E")
    add_light(kiosk, CYAN, 1.6, 12)
    flagpole = part("KioskFlagPole", (0.2, 5.0, 0.2), (14.2, 2.5, -18.2), color=CHARCOAL_D, material="Metal")
    flag = part("KioskFlag", (0.3, 1.2, 0.9), (14.2, 4.4, -17.7), yaw=0, color=CYAN, material="SmoothPlastic")
    return model("HeroKioskDeco", base, flagpole, flag), kiosk


# commerce row ------------------------------------------------------------
def build_outfitters():
    P = enterable("Outfitters", 58, 20, 18, 16, 10, door_face="-x", door_w=4.2,
                  wall=SLATE, windows=2, sign="MERIDIAN OUTFITTERS", sign_color=GOLD,
                  lamp_count=2, floor_color=(100, 104, 108))
    P.append(part("ShopAwning", (3.0, 0.3, 10.5), (58 - 10.6, 6.9, 20), color=GOLD, material="SmoothPlastic"))
    P.append(part("ShopConsole", (7.4, 1.3, 2.6), (62.6, 1.05, 20), color=(70, 74, 86), material="DiamondPlate"))
    P.append(part("ShopReg", (1.4, 0.9, 0.9), (60.4, 2.05, 20), color=CHARCOAL_D, material="Metal"))
    P += shelf_row_v2("ShelfN", 62.5, 25.4, length=8.0, along="x")
    P += shelf_row_v2("ShelfS", 62.5, 14.6, length=8.0, along="x")
    P.append(keeper("ShopKeeper", 65, 23, shirt=(58, 70, 96)))
    P.append(part("Rug", (7.0, 0.08, 9.0), (62, 0.33, 20), color=(60, 70, 86), material="SmoothPlastic"))
    return model("Shop", *P)


def shelf_row_v2(name, x, z, length=8.0, along="x", tiers=4):
    out = []
    for t in range(tiers):
        yy = 0.6 + t * 1.1
        out.append(part("%sB%d" % (name, t + 1),
                        (length, 0.16, 1.4) if along == "x" else (1.4, 0.16, length),
                        (x, yy, z), color=CHARCOAL_D, material="Wood"))
        for c in range(4):
            gx = x - length / 2.0 + 1.2 + c * (length / 4.0)
            out.append(part("%sG%d%d" % (name, t, c), (0.7, 0.62, 0.9), (gx, yy + 0.5, z),
                            color=(176, 182, 186), material="SmoothPlastic"))
    return out


def build_armory():
    P = enterable("Armory", 58, -10, 16, 14, 9, door_face="-x", door_w=3.8,
                  wall=SLATE_D, windows=1, sign="ARMORY & SALVAGE", sign_color=HAZARD,
                  lamp_count=2, floor_color=(88, 92, 96))
    P.append(part("ArmoryCounter", (5.6, 1.2, 2.2), (61.5, 1.0, -10), color=(56, 60, 66), material="DiamondPlate"))
    P.append(part("Case", (0.4, 1.6, 7.2), (63.9, 1.6, -10), color=GLASSC, material="Glass", transparency=0.55))
    for i, wy in enumerate((-13.8, -10.0, -6.2), start=1):
        P.append(part("Rack%d" % i, (0.4, 3.4, 2.2), (66.2, 2.15, wy), color=CHARCOAL_D, material="Metal"))
        P.append(part("RackItem%d" % i, (0.5, 0.5, 1.5), (65.9, 3.2, wy), color=(140, 146, 150), material="Metal"))
    P.append(part("ArmoryNeon", (0.25, 0.4, 6.4), (58 - 7.95, 6.5, -10), color=HAZARD, material="Neon"))
    return model("ArmoryBlock", *P)


def build_cafe():
    P = enterable("Cafe", 52, 42, 14, 12, 8, door_face="-z", door_w=3.2,
                  wall=(168, 128, 100), mat="SmoothPlastic", windows=2,
                  sign="CAFÉ MERIDIAN", sign_color=NEON_MAG, lamp_count=1,
                  lamp_color=LIGHT_AMBER, floor_color=(112, 96, 84))
    tpos = ((49, 45), (55, 45), (49, 39), (55, 39))
    for i, (tx, tz) in enumerate(tpos, start=1):
        P.append(part("CafeTable%d" % i, (2.2, 0.15, 2.2), (tx, 1.5, tz), shape="Cylinder",
                      color=(196, 190, 176), material="SmoothPlastic"))
        P.append(part("CafeLeg%d" % i, (0.4, 1.35, 0.4), (tx, 0.8, tz), color=CHARCOAL_D, material="Metal"))
        P.append(part("Cup%d" % i, (0.35, 0.5, 0.35), (tx + 0.6, 1.82, tz), shape="Cylinder",
                      color=(232, 226, 210), material="SmoothPlastic"))
        P.append(part("CafeStool%d" % i, (1.0, 1.0, 1.0), (tx - 2.0, 0.65, tz), shape="Cylinder",
                      color=(150, 106, 70), material="Fabric"))
        P.append(part("CafeStool%d b" % i, (1.0, 1.0, 1.0), (tx + 2.0, 0.65, tz), shape="Cylinder",
                      color=(150, 106, 70), material="Fabric"))
    return model("CafeBlock", *P)


def build_warehouse():
    P = enterable("Warehouse", 22, -46, 30, 24, 14, door_face="+z", door_w=9.0, door_h=8.6,
                  wall=(108, 112, 118), mat="SmoothPlastic", canopy=False, lamp_count=3,
                  floor_color=(92, 96, 100), sign="COURIER DEPOT 7", sign_color=CYAN)
    for i, tz in enumerate((-54, -47, -40), start=1):
        P.append(part("Truss%d" % i, (28, 0.5, 0.5), (22, 12.4, tz), color=STEEL_D, material="Metal"))
    P.append(part("Conveyor", (22, 0.8, 3.0), (24, 0.85, -44), color=STEEL_D, material="DiamondPlate"))
    for i in range(5):
        P.append(part("ConvLeg%d" % (i + 1), (0.4, 0.7, 0.4), (14 + i * 5, 0.45, -44), color=CHARCOAL_D, material="Metal"))
    for i, (rx, rz) in enumerate(((11, -53), (11, -40)), start=1):
        P += shelf_row_v2("WHRack%d" % i, rx, rz, length=9.0, along="z", tiers=3)
    for i, (bx, bz, s) in enumerate(((17, -50, 2.0), (18.6, -50, 1.7), (27, -53, 2.2), (29, -41, 2.0),
                                     (27, -41, 1.7), (15, -43, 1.9)), start=1):
        P.append(crate("WHCrate%d" % i, bx, bz, s=s, yaw=(i * 13) % 40 - 20))
    P.append(part("Office", (7.5, 6.2, 5.5), (30, 3.4, -53), color=(160, 164, 170), material="SmoothPlastic"))
    P.append(part("OfficeGlass", (0.25, 2.8, 3.8), (26.1, 3.1, -53), color=GLASSC, material="Glass", transparency=0.5))
    P.append(lamp("WHLampA", 22, 12.0, -50, LIGHT_COOL, 1.6, 30, size=(2.4, 0.3, 2.4)))
    P.append(lamp("WHLampB", 16, 12.0, -42, LIGHT_AMBER, 1.25, 24, size=(2.0, 0.25, 2.0)))
    P.append(part("DockStripe", (12, 0.06, 1.3), (22, 0.31, -31.6), color=HAZARD, material="SmoothPlastic", cancollide=False))
    P.append(part("DockStripe2", (1.3, 0.06, 12), (14.9, 0.31, -31.6), color=HAZARD, material="SmoothPlastic", cancollide=False))
    return model("WarehouseBlock", *P)


# clan hall ----------------------------------------------------------------
def build_clan_hall_v2():
    P = enterable("ClanHallB", 12, -38, 22, 20, 13, door_face="+z", door_w=5.0, door_h=7.2,
                  wall=(72, 80, 96), mat="SmoothPlastic", windows=2, sign="CLAN HALL",
                  sign_color=CYAN, lamp_count=3, floor_color=(96, 90, 102))
    for i, bx in enumerate((5.0, 19.0), start=1):
        P.append(part("ClanBanner%d" % i, (1.7, 4.6, 0.4), (bx, 9.2, -27.7), color=(52, 74, 130),
                      material="SmoothPlastic"))
        P.append(part("ClanEmblem%d" % i, (0.7, 0.7, 0.1), (bx, 9.2, -27.45), color=CYAN, material="Neon"))
    pole = part("ClanPole", (0.5, 3.8, 0.5), (12, 1.9, -26), color=CHARCOAL_D, material="SmoothPlastic")
    board = part("ClanBoard", (4.2, 2.0, 0.3), (12, 2.94, -26), yaw=0, color=(64, 92, 134), material="Metal")
    surface_text(board, "CLAN HALL", headline_name="Headline", sub="Found • Join • Group contracts — press E")
    add_light(board, CYAN, 1.3, 10)
    P.append(part("WarTable", (9.6, 0.45, 4.6), (12, 1.5, -40), color=CHARCOAL_D, material="Wood"))
    P.append(part("WarMap", (7.4, 0.12, 3.4), (12, 1.78, -40), color=(60, 96, 140), material="Neon", cancollide=False))
    for i in range(6):
        sx = 8.0 + (i % 3) * 4.0
        sz = -42.8 if i < 3 else -37.2
        P.append(part("HallSeat%d" % (i + 1), (1.4, 0.95, 1.4), (sx, 0.88, sz), color=(84, 62, 50), material="Fabric"))
    P.append(part("Hearth", (3.4, 3.8, 1.5), (12, 2.2, -47.9), color=CHARCOAL, material="Metal"))
    P.append(lamp("HearthFire", 12, 1.5, -47.2, (255, 150, 70), 2.2, 15, size=(1.8, 0.7, 1.1)))
    P.append(part("HallBannerL", (2.6, 6.4, 0.3), (3.4, 6.4, -38), color=(52, 74, 130), material="SmoothPlastic"))
    P.append(part("HallBannerR", (2.6, 6.4, 0.3), (20.6, 6.4, -38), color=(52, 74, 130), material="SmoothPlastic"))
    return model("ClanHall", pole, board, *P)


# home ---------------------------------------------------------------------
def build_home_v2(hx, hz):
    walls = (178, 160, 142)
    P = [
        part("Floor", (24, 0.5, 18), (hx, 0.05, hz), color=(112, 96, 80), material="WoodPlanks"),
        part("WallBack", (24, 8, 0.6), (hx, 4.3, hz - 8.7), color=walls, material="SmoothPlastic"),
        part("WallWest", (0.6, 8, 16.8), (hx - 11.7, 4.3, hz), color=walls, material="SmoothPlastic"),
        part("WallEast", (0.6, 8, 16.8), (hx + 11.7, 4.3, hz), color=walls, material="SmoothPlastic"),
        part("WallFrontL", (5.75, 8, 0.6), (hx - 9.125, 4.3, hz + 8.7), color=walls, material="SmoothPlastic"),
        part("WallFrontR", (13.25, 8, 0.6), (hx + 5.375, 4.3, hz + 8.7), color=walls, material="SmoothPlastic"),
        part("WallLintel", (5.6, 1.8, 0.6), (hx - 3.75, 7.3, hz + 8.7), color=walls, material="SmoothPlastic"),
        part("DoorTrimL", (0.35, 6.6, 0.75), (hx - 6.55, 3.5, hz + 8.85), color=(70, 60, 52), material="SmoothPlastic"),
        part("DoorTrimR", (0.35, 6.6, 0.75), (hx - 0.95, 3.5, hz + 8.85), color=(70, 60, 52), material="SmoothPlastic"),
        part("Roof", (26.5, 0.7, 19.5), (hx, 10.35, hz), color=(96, 74, 60), material="SmoothPlastic"),
        part("ParaN", (27.3, 0.7, 0.6), (hx, 10.85, hz - 9.6), color=(108, 84, 68), material="SmoothPlastic"),
        part("ParaS", (27.3, 0.7, 0.6), (hx, 10.85, hz + 9.6), color=(108, 84, 68), material="SmoothPlastic"),
        part("ParaW", (0.6, 0.7, 19.8), (hx - 13.35, 10.85, hz), color=(108, 84, 68), material="SmoothPlastic"),
        part("ParaE", (0.6, 0.7, 19.8), (hx + 13.35, 10.85, hz), color=(108, 84, 68), material="SmoothPlastic"),
        part("ACUnit", (3.2, 1.6, 2.6), (hx + 8, 11.65, hz - 5), color=(150, 152, 148), material="Metal"),
        part("Vent", (0.7, 2.0, 0.7), (hx - 8, 11.9, hz + 5), color=(120, 122, 126), material="Metal"),
        part("PorchFloor", (9.5, 0.4, 3.4), (hx - 3.75, 0.2, hz + 10.7), color=(146, 124, 102), material="WoodPlanks"),
        part("PorchRoof", (11.0, 0.4, 4.6), (hx - 3.75, 8.0, hz + 11.2), color=(96, 74, 60), material="SmoothPlastic"),
        part("PorchPostL", (0.4, 7.6, 0.4), (hx - 8.6, 4.0, hz + 12.5), color=(70, 60, 52), material="SmoothPlastic"),
        part("PorchPostR", (0.4, 7.6, 0.4), (hx + 1.1, 4.0, hz + 12.5), color=(70, 60, 52), material="SmoothPlastic"),
        part("WinW", (0.3, 3.2, 3.6), (hx - 11.95, 4.7, hz - 1), color=GLASSC, material="Glass", transparency=GLASS_T),
        part("WinE", (0.3, 3.2, 3.6), (hx + 11.95, 4.7, hz - 1), color=GLASSC, material="Glass", transparency=GLASS_T),
        part("WinB", (3.6, 3.2, 0.3), (hx + 5, 4.7, hz - 9.05), color=GLASSC, material="Glass", transparency=GLASS_T),
        part("Rug", (7.5, 0.08, 9.5), (hx + 2, 0.33, hz), color=(104, 72, 66), material="Fabric"),
        part("Bed", (5.0, 1.0, 7.5), (hx + 7, 0.8, hz + 4), color=(132, 104, 84), material="Wood"),
        part("Mattress", (4.7, 0.7, 7.2), (hx + 7, 1.6, hz + 4), color=(226, 220, 206), material="Fabric"),
        part("Bookshelf", (0.8, 5.0, 3.2), (hx - 10.9, 2.8, hz + 2), color=WOOD_D, material="Wood"),
        part("TableHome", (3.4, 0.3, 2.0), (hx - 5, 1.5, hz - 3), color=WOOD, material="Wood"),
        part("ChairHome", (1.4, 1.8, 1.4), (hx - 5, 1.15, hz - 5.6), color=WOOD_D, material="Wood"),
        part("HomeConsole", (2.2, 2.4, 1.1), (hx - 4, 1.2, hz - 8.1), color=(48, 52, 64), material="Metal"),
        part("HomeScreen", (3.8, 2.2, 0.35), (hx - 4, 3.6, hz - 8.45), color=(110, 170, 200), material="Neon"),
    ]
    sign = part("HomeSign", (6.4, 1.7, 0.3), (hx - 3.75, 6.6, hz + 9.15), yaw=180, color=CHARCOAL_D)
    surface_text(sign, "APARTMENT 3B", headline_name="Sign")
    P.append(sign)
    P.append(lamp("HomeLamp", hx + 2, 7.5, hz, LIGHT_AMBER, 1.35, 19, size=(1.1, 0.3, 1.1)))
    P.append(part("Mailbox", (0.35, 1.6, 0.35), (hx - 3.75, 1.0, hz + 13.2), color=(120, 126, 134), material="Metal"))
    P.append(part("Path", (3.2, 0.1, 8.0), (hx - 3.75, 0.12, hz + 15.5), color=PAVE_D, material="Pavement"))
    m = model("Home", *P)
    m.interior = (hx, 0.0, hz)
    return m


def build_safehouse_v2(hx, hz):
    ax = hx + 3.75     # BarricadeAnchor x (fixed by service)
    # anchor stays at (hx - 3.75, 3, hz + 8.7) — keep that; shed wraps plaza-side corner
    anchor = part("BarricadeAnchor", (0.4, 6, 4.4), (hx - 3.75, 3.0, hz + 8.7),
                  color=(140, 96, 50), material="Wood", transparency=1, cancollide=False)
    sx, sz = hx - 3.75, hz + 8.7
    P = [
        anchor,
        part("ShedFloor", (10, 0.4, 9), (sx, 0.2, sz + 9.5), color=(104, 108, 104), material="Concrete"),
        part("ShedBack", (10, 7, 0.5), (sx, 3.7, sz + 13.9), color=(120, 124, 120), material="SmoothPlastic"),
        part("ShedL", (0.5, 7, 9), (sx - 4.75, 3.7, sz + 9.5), color=(120, 124, 120), material="SmoothPlastic"),
        part("ShedR", (0.5, 7, 9), (sx + 4.75, 3.7, sz + 9.5), color=(120, 124, 120), material="SmoothPlastic"),
        part("ShedRoof", (11, 0.5, 10), (sx, 7.4, sz + 9.5), color=(88, 92, 88), material="SmoothPlastic"),
        part("ShedDoorL", (2.0, 6.0, 0.35), (sx - 1.45, 3.2, sz + 4.85), color=(126, 132, 122), material="DiamondPlate"),
        part("ShedDoorR", (2.0, 6.0, 0.35), (sx + 1.45, 3.2, sz + 4.85), color=(126, 132, 122), material="DiamondPlate"),
    ]
    return model("Safehouse", *P)


# ------------------------------------------------------------ streets -----
def lane_stripes(axis, at, along_from, along_to, spacing=8.0, size=(0.9, 0.06, 3.4)):
    out = []
    n = int((along_to - along_from) / spacing)
    for i in range(n):
        v = along_from + i * spacing
        if axis == "z":   # road runs along z, stripe thin in x
            out.append(part("Stz%d" % len(out), (size[0], 0.06, size[2]), (at, 0.31, v),
                            color=ROAD_LINE, material="SmoothPlastic", cancollide=False))
        else:
            out.append(part("Stx%d" % len(out), (size[2], 0.06, size[0]), (v, 0.31, at),
                            color=ROAD_LINE, material="SmoothPlastic", cancollide=False))
    return out


def crosswalk(cx, cz, axis, half=7.0):
    """Zebra: 6 stripes across a road of width ~14."""
    out = []
    for i in range(6):
        off = -half + 1.2 + i * (2.4)
        if axis == "z":
            out.append(part("Cross%d" % len(out), (12.6, 0.06, 1.15), (cx, 0.31, cz + off),
                            color=ROAD_LINE, material="SmoothPlastic", cancollide=False))
        else:
            out.append(part("Cross%d" % len(out), (1.15, 0.06, 12.6), (cx + off, 0.31, cz),
                            color=ROAD_LINE, material="SmoothPlastic", cancollide=False))
    return out


def sidewalk_ring(road_at, other_axis_from, other_axis_to):
    pass


def build_streets():
    P = []
    # road slabs (over the ground)
    P.append(model("Roads",
                   part("RoadN", (300, 0.5, 12), (0, 0.05, -36), color=ROAD, material="Asphalt"),
                   part("RoadS", (300, 0.5, 12), (0, 0.05, 36), color=ROAD, material="Asphalt"),
                   part("RoadE", (12, 0.5, 300), (36, 0.05, 0), color=ROAD, material="Asphalt"),
                   part("RoadW", (12, 0.5, 300), (-36, 0.05, 0), color=ROAD, material="Asphalt")))
    # curbs: 4 per road band
    curb = 0.18
    for (cx, cz, sx, sz, tag) in (
            (0, -43.2, 300, 2.4, "NCurbO"), (0, -29.0, 300, 2.4, "NCurbI"),
            (0, 43.2, 300, 2.4, "SCurbO"), (0, 29.0, 300, 2.4, "SCurbI"),
            (-43.2, 0, 2.4, 300, "WCurbO"), (-29.0, 0, 2.4, 300, "WCurbI"),
            (43.2, 0, 2.4, 300, "ECurbO"), (29.0, 0, 2.4, 300, "ECurbI")):
        P.append(part("Curb_%s" % tag, (sx, curb, sz), (cx, 0.09, cz),
                      color=PAVE_D, material="Pavement"))
    # lane center dashes
    P += lane_stripes("z", -36, -140, -2.0)
    P += lane_stripes("z", -36, 2.0, 140)
    P += lane_stripes("z", 36, -140, -2.0)
    P += lane_stripes("z", 36, 2.0, 140)
    P += lane_stripes("x", -36, -140, -2.0)
    P += lane_stripes("x", -36, 2.0, 140)
    P += lane_stripes("x", 36, -140, -2.0)
    P += lane_stripes("x", 36, 2.0, 140)
    # crosswalks at plaza corners
    P += crosswalk(-30, -36, "x") + crosswalk(30, -36, "x")
    P += crosswalk(-30, 36, "x") + crosswalk(30, 36, "x")
    P += crosswalk(-36, -30, "z") + crosswalk(-36, 30, "z")
    P += crosswalk(36, -30, "z") + crosswalk(36, 30, "z")
    # hydrants
    for i, (hx2, hz2) in enumerate(((28.5, -25), (-28.5, 25), (25, 28.5), (-43.5, -31)), start=1):
        P.append(model("Hydrant%d" % i,
                       part("Body", (0.9, 1.9, 0.9), (hx2, 0.95, hz2), shape="Cylinder",
                            color=HAZARD, material="SmoothPlastic")))
    # street name signs
    for i, (sx2, sz2, txt) in enumerate(((38.5, -48, "MERIDIAN AVE"), (-38.5, -52, "COURIER ST"),
                                         (38.5, 52, "MERIDIAN AVE"), (-38.5, 58, "COURIER ST")), start=1):
        pole = part("SN%d" % i, (0.22, 3.0, 0.22), (sx2, 1.7, sz2), color=STEEL_D, material="Metal")
        plate = part("SNP%d" % i, (2.8, 0.5, 0.18), (sx2, 3.4, sz2), color=CHARCOAL_D, material="SmoothPlastic")
        surface_text(plate, txt, headline_name="SignHead")
        P.append(model("StreetSign%d" % i, pole, plate))
    # bus stop (east main street)
    P.append(model("BusStop",
                   part("Shelter", (9.0, 0.3, 4.0), (43, 6.2, -58), color=GLASSC, material="Glass", transparency=0.6),
                   part("FrameB", (9.4, 0.25, 4.4), (43, 4.1, -58), color=CHARCOAL_D, material="Metal"),
                   part("BenchB", (7.0, 0.3, 1.2), (43, 0.6, -59.2), color=WOOD, material="Wood"),
                   part("PostBL", (0.3, 4.2, 0.3), (39.2, 2.1, -56.5), color=CHARCOAL_D, material="Metal"),
                   part("PostBR", (0.3, 4.2, 0.3), (46.8, 2.1, -56.5), color=CHARCOAL_D, material="Metal")))
    # dumpsters
    for i, (dx, dz, dyaw) in enumerate(((30, -20, -90), (30, -26, -90), (-42, 14, 90)), start=1):
        P.append(model("Dumpster%d" % i,
                       part("Body", (3.4, 1.9, 2.2), (dx, 1.25, dz), yaw=dyaw, color=(86, 120, 96),
                            material="Metal"),
                       part("Lid", (3.6, 0.25, 2.4), (dx, 2.35, dz), yaw=dyaw, color=(70, 100, 82),
                            material="SmoothPlastic")))
    # power poles + lines along the west street
    for i, pz in enumerate((-80, -40, 0, 40, 80), start=1):
        pole = part("PowPole%d" % i, (0.5, 12, 0.5), (-44.5, 6.0, pz), color=WOOD_D, material="Wood")
        bar = part("PowBar%d" % i, (2.6, 0.3, 0.3), (-44.5, 10.6, pz), color=WOOD_D, material="Wood")
        P.append(model("PowLine%d" % i, pole, bar))
    # thin cable strips between poles (narrow, cancollide false, high up)
    for i in range(4):
        z0 = -80 + i * 40
        P.append(part("Wire%d" % (i + 1), (0.12, 0.12, 40), (-44.5, 10.4, z0 + 20),
                      color=(40, 42, 46), material="SmoothPlastic", cancollide=False))
    return model("Streets", *P)


# ------------------------------------------------------------ vehicles ----
def car(name, x, z, yaw=0.0, body=(120, 130, 142)):
    """Static parked sedan; yaw must be 0 or 90 (axis-aligned) so offsets are
    computed exactly: yaw=0 → length along Z; yaw=90 → length along X."""
    L = yaw == 90.0
    def wp(dx, dy, dz, sx, sy, sz):
        return ((x + dz, dy, z + dx) if L else (x + dx, dy, z + dz), (sz, sy, sx) if L else (sx, sy, sz))
    def pl(nm, dx, dy, dz, sx, sy, sz, color, material="SmoothPlastic", **kw):
        (px, py, pz), (sx2, sy2, sz2) = wp(dx, dy, dz, sx, sy, sz)
        return part(nm, (sx2, sy2, sz2), (px, py, pz), color=color, material=material, **kw)
    m = model(name,
              pl("Body", 0, 1.25, 0, 4.6, 1.3, 10.5, body),
              pl("Cabin", 0, 2.45, 0.5, 4.1, 1.2, 5.4, body),
              pl("GlassF", 0, 2.45, -2.35, 3.9, 1.0, 0.3, GLASSC, "Glass", transparency=0.45),
              pl("GlassR", 0, 2.45, 2.55, 3.9, 1.0, 0.3, GLASSC, "Glass", transparency=0.45),
              pl("Hoodline", 0, 1.95, -4.4, 4.2, 0.18, 1.2, (36, 40, 44)),
              pl("BumperF", 0, 0.85, -5.3, 4.8, 0.5, 0.4, CHARCOAL_D),
              pl("BumperR", 0, 0.85, 5.3, 4.8, 0.5, 0.4, CHARCOAL_D),
              pl("LampL", -1.75, 1.5, -5.35, 0.5, 0.3, 0.25, (255, 230, 170), "Neon"),
              pl("LampR", 1.75, 1.5, -5.35, 0.5, 0.3, 0.25, (255, 230, 170), "Neon"))
    for sx in (-1, 1):
        for wz in (-3.6, 3.6):
            if L:
                m.add(part("Wheel%s%s" % (sx, wz), (1.35, 1.35, 0.6), (x + wz, 0.7, z + sx * 2.35),
                           color=(30, 30, 32), material="SmoothPlastic"))
            else:
                m.add(part("Wheel%s%s" % (sx, wz), (0.6, 1.35, 1.35), (x + sx * 2.35, 0.7, z + wz),
                           color=(30, 30, 32), material="SmoothPlastic"))
    return m


# --------------------------------------------------- skyline + perimeter --
def skyline_tower(name, cx, cz, w, d, h, wall=SLATE, rows=3, sign=None,
                  sign_color=CYAN, windows_on=True, tank=True):
    P = enterable(name, cx, cz, w, d, h, door_face="NONE", windows=0, canopy=False,
                  lamp_count=0, wall=wall, mat="SmoothPlastic", sign=None)
    # replace walls with taller band look: add window band rows
    for r in range(rows):
        y = 6.0 + r * max((h - 12.0) / max(rows - 1, 1), 4.5) if rows > 1 else 8.0
        if y < h - 3:
            for face in ("+z", "-z", "+x", "-x"):
                push = (d / 2.0 if face in ("+z", "-z") else w / 2.0) + 0.0
                along_x = face in ("+z", "-z")
                span = w if along_x else d
                n = int(span // 4.6)
                for i in range(n):
                    off = -span / 2.0 + 2.3 + i * 4.6
                    if along_x:
                        P.append(part("%sWin%s%d_%d" % (name, face, r, i), (3.4, 2.2, 0.25),
                                      (cx + off, y, cz + (d / 2.0 + 0.1) * (1 if face == "+z" else -1)),
                                      color=GLASSC, material="Glass", transparency=0.62))
                    else:
                        P.append(part("%sWin%s%d_%d" % (name, face, r, i), (0.25, 2.2, 3.4),
                                      (cx + (w / 2.0 + 0.1) * (1 if face == "+x" else -1), y, cz + off),
                                      color=GLASSC, material="Glass", transparency=0.62))
    # rooftop clutter: AC boxes + water tank + antenna
    P.append(part(name + "AC1", (3.2, 1.6, 2.6), (cx - w * 0.25, h + 0.8 + 0.3, cz + d * 0.2),
                  color=(120, 124, 128), material="Metal"))
    P.append(part(name + "AC2", (2.4, 1.2, 2.0), (cx + w * 0.28, h + 0.75 + 0.3, cz - d * 0.24),
                  color=(120, 124, 128), material="Metal"))
    if tank:
        P.append(part(name + "Tank", (0.5, 4.4, 0.5), (cx + w * 0.18, h + 3.6, cz + d * 0.18),
                      color=(126, 130, 134), material="Metal"))
        P.append(part(name + "TankTop", (2.8, 0.4, 2.8), (cx + w * 0.18, h + 5.7, cz + d * 0.18),
                      shape="Cylinder", roll=90, color=(126, 130, 134), material="Metal"))
    if sign:
        sp = part(name + "RoofSign", (min(w * 0.8, 18), 2.2, 0.35), (cx, h + 2.2, cz + d / 2.0 + 0.3),
                  color=CHARCOAL_D, material="SmoothPlastic")
        surface_text(sp, sign, headline_name="SignHead")
        add_light(sp, sign_color, 1.1, 12)
        P.append(sp)
    return model(name, *P)


def build_skyline():
    P = [skyline_tower("TowerHotel", 0, -92, 40, 24, 52, SLATE, rows=4, sign="MERIDIAN HOTEL", sign_color=CYAN),
         skyline_tower("TowerNE", 78, -88, 30, 26, 44, (96, 106, 118), rows=3, tank=False),
         skyline_tower("TowerE", 96, 30, 28, 30, 60, CHARCOAL, rows=4, sign="KSLZ APARTMENTS", sign_color=NEON_MAG),
         skyline_tower("TowerSE", 86, 86, 34, 22, 36, SLATE_D, rows=2, tank=False),
         skyline_tower("TowerS", -20, 100, 44, 26, 40, (128, 130, 126), rows=3, sign="GRAND MIDWAY", sign_color=GOLD),
         skyline_tower("TowerW", -88, 40, 30, 28, 48, SLATE, rows=3),
         skyline_tower("TowerNW", -92, -40, 34, 26, 56, (100, 108, 116), rows=4, sign="FOUNDRY 12", sign_color=HAZARD),
         # west block near home
         skyline_tower("TowerW2", -88, -78, 30, 24, 30, SLATE_D, rows=2, tank=False)]
    P.append(part("SkyBackdrop", (420, 90, 2), (0, 44, -205), color=(36, 40, 44), material="SmoothPlastic"))
    P.append(part("SkyBackdropE", (2, 90, 420), (205, 44, 0), color=(36, 40, 44), material="SmoothPlastic"))
    P.append(part("SkyBackdropW", (2, 90, 420), (-205, 44, 0), color=(36, 40, 44), material="SmoothPlastic"))
    P.append(part("SkyBackdropS", (420, 90, 2), (0, 44, 205), color=(36, 40, 44), material="SmoothPlastic"))
    return model("Skyline", *P)


def build_perimeter():
    """City wall ring at ±115 with a south gate."""
    P = []
    t = 1.4
    h = 9.0
    P.append(part("WallN", (232, h, t), (0, h / 2.0, -115), color=(120, 122, 118), material="Concrete"))
    P.append(part("WallS", (232, h, t), (0, h / 2.0, 115), color=(120, 122, 118), material="Concrete"))
    P.append(part("WallW", (t, h, 232), (-115, h / 2.0, 0), color=(120, 122, 118), material="Concrete"))
    P.append(part("WallE", (t, h, 232), (115, h / 2.0, 0), color=(120, 122, 118), material="Concrete"))
    # copings
    for (cx, cz, sx, sz) in ((0, -115, 234, 2.0), (0, 115, 234, 2.0), (-115, 0, 2.0, 234), (115, 0, 2.0, 234)):
        P.append(part("Coping%d" % len(P), (sx, 0.6, sz), (cx, h + 0.3, cz), color=(88, 90, 86), material="Concrete"))
    # south gate: two pillars + arch + open gates
    P.append(part("GateArch", (26, 3.0, 2.0), (0, 12.5, 115), color=(110, 112, 108), material="Concrete"))
    for s in (-1, 1):
        P.append(part("GatePillar%d" % (s + 2), (4.0, 12.0, 4.0), (s * 17, 6.0, 115),
                      color=(110, 112, 108), material="Concrete"))
        P.append(part("GateDoor%d" % (s + 2), (14.0, 8.5, 0.5), (s * 24.5, 4.25, 115),
                      color=(96, 84, 64), material="WoodPlanks"))
        P.append(lamp("GateLamp%d" % (s + 2), s * 17, 13.2, 112.5, LIGHT_AMBER, 1.6, 20, size=(1.1, 0.6, 1.1)))
    # watchtowers at 4 corners
    for i, (wx, wz) in enumerate(((-115, -115), (115, -115), (-115, 115), (115, 115)), start=1):
        P.append(model("Watchtower%d" % i,
                       part("Cab", (6.0, 5.0, 6.0), (wx, 12.5, wz), color=SLATE_D, material="SmoothPlastic"),
                       part("CabGlass", (6.4, 1.6, 6.4), (wx, 13.6, wz), color=GLASSC, material="Glass", transparency=0.5),
                       part("RoofT", (7.0, 0.5, 7.0), (wx, 15.4, wz), color=(58, 62, 64), material="SmoothPlastic"),
                       part("LegsA", (5.6, 10.0, 0.5), (wx, 5.25, wz - 2.7), color=CHARCOAL_D, material="SmoothPlastic"),
                       part("LegsB", (5.6, 10.0, 0.5), (wx, 5.25, wz + 2.7), color=CHARCOAL_D, material="SmoothPlastic"),
                       part("Beacon", (0.9, 0.5, 0.9), (wx, 15.9, wz), color=HAZARD, material="Neon")))
        P.append(lamp("WatchLight%d" % i, wx, 14.0, wz, HAZARD, 1.5, 26, size=(1.2, 0.4, 1.2)))
    return model("Perimeter", *P)


def build_park():
    P = []
    P.append(part("ParkLawn", (30, 0.25, 34), (-84, 0.12, 74), color=(96, 140, 84), material="LeafyGrass"))
    P.append(part("ParkPath", (3.0, 0.12, 30), (-74, 0.13, 74), color=PAVE_D, material="Pavement"))
    for i, (tx, tz) in enumerate(((-92, 62), (-92, 86), (-78, 66), (-78, 84), (-86, 74)), start=1):
        P.append(part("TreeTrunk%d" % i, (0.95, 4.4, 0.95), (tx, 2.4, tz), color=WOOD_D, material="Wood"))
        P.append(part("TreeTop%d a" % i, (5.0, 4.6, 5.0), (tx, 6.6, tz), shape="Ball", color=GREEN, material="SmoothPlastic"))
        P.append(part("TreeTop%d b" % i, (3.6, 3.2, 3.6), (tx + 0.8, 8.6, tz - 0.6), shape="Ball",
                      color=(120, 170, 104), material="SmoothPlastic"))
    for i, (bx, bz) in enumerate(((-72, 66), (-72, 82)), start=1):
        P.append(part("ParkBench%d" % i, (3.6, 0.35, 1.4), (bx, 0.75, bz), color=WOOD, material="Wood"))
        P.append(part("ParkBenchLegs%d" % i, (3.0, 0.5, 1.0), (bx, 0.3, bz), color=CHARCOAL_D, material="SmoothPlastic"))
    P.append(lamp("ParkLamp", -74, 8.8, 74, LIGHT_COOL, 1.2, 18, size=(1.1, 0.7, 1.1)))
    P.append(model("ParkPole", part("PPole", (0.35, 9.0, 0.35), (-74, 4.5, 74), color=CHARCOAL_D, material="Metal")))
    return model("Park", *P)


def build_trees():
    P = []
    spots = [(6, -108, 5.6), (112, -38, 4.8), (-112, -28, 5.0), (-100, 108, 4.8),
             (108, 104, 5.2), (-52, -110, 4.6), (60, 108, 4.6), (-108, 8, 5.0)]
    for i, (tx, tz, _) in enumerate(spots, start=1):
        P.append(model("CityTree%d" % i,
                       part("Trunk", (0.9, 4.2, 0.9), (tx, 2.3, tz), color=WOOD_D, material="Wood"),
                       part("Top", (4.8, 4.2, 4.8), (tx, 6.4, tz), shape="Ball", color=GREEN, material="SmoothPlastic"),
                       part("Top2", (3.2, 2.8, 3.2), (tx + 0.7, 8.2, tz - 0.5), shape="Ball",
                            color=(118, 166, 100), material="SmoothPlastic")))
    return model("Trees", *P)


# ------------------------------------------------- gameplay-kept blocks --
def build_targets():
    targets = Node("Model", "DeliveryTargets")
    coords = [(-70, 0.23, -57.9), (26, 0.23, -69.9), (76.9, 0.23, 10.0), (-49.9, 0.23, 58.0)]
    for i, (tx, ty, tz) in enumerate(coords, start=1):
        mat = part("Target%d" % i, (4, 0.3, 4), (tx, ty, tz), color=(226, 168, 60), material="SmoothPlastic")
        billboard(mat, "DELIVERY POINT %d" % i, 170, 34, 1.4, color=GOLD)
        targets.add(mat)
    return targets


def build_phase2_nodes_v2():
    rubble = Node("Model", "Rubble")
    pile_spots = [(34, -52), (-44, -48), (66, -28)]
    for i, (px, pz) in enumerate(pile_spots, start=1):
        base = part("RubbleBase%d" % i, (4.8, 1.2, 4.8), (px, 0.8, pz), color=(112, 108, 100), material="Concrete")
        chunk = part("RubbleChunk%d" % i, (2.0, 1.1, 1.8), (px + 1.4, 1.0, pz + 0.8), yaw=24, color=(96, 92, 86), material="Cobblestone")
        slab = part("RubbleSlab%d" % i, (2.6, 0.4, 3.4), (px - 1.2, 1.5, pz - 0.7), yaw=-38, color=(128, 108, 76), material="Wood")
        rod = part("Rebar%d" % i, (0.25, 3.2, 0.25), (px + 0.4, 2.2, pz - 0.3), yaw=14, color=(120, 70, 60), material="Metal")
        rubble.add(model("Rubble%d" % i, base, chunk, slab, rod))
    spawns = Node("Model", "InfectedSpawns")
    for i, (px, pz) in enumerate(((8, -64), (-30, -76), (54, -52)), start=1):
        marker = part("Spawn%d" % i, (1, 3, 1), (px, 3.0, pz), color=(40, 90, 40),
                      material="Grass", transparency=1, cancollide=False)
        spawns.add(marker)
    rubble_p = model("Phase2Nodes", rubble, spawns)
    return rubble_p


def build_settlement_pads_v2(hx, hz):
    pads = []
    BUILD = []
    for i, (dx, dz) in enumerate([(-6.0, -30.0), (2.0, -30.0), (-6.0, -38.0), (2.0, -38.0)]):
        idx = i + 1
        x, z = hx + dx, hz + dz
        pads.append(part("Pad%d" % idx, (4.6, 0.24, 4.6), (x, 0.12, z), color=(104, 108, 116), material="Concrete"))
        pads.append(part("Pad%dOutline" % idx, (5.6, 0.06, 5.6), (x, 0.035, z), color=HAZARD, material="SmoothPlastic", cancollide=False))
        BUILD.append((x, 0.24, z))
    return model("SettlementPads", *pads), BUILD


def build_settlement_board_v2(hx, hz):
    pole = part("BoardPole", (0.4, 3.2, 0.4), (hx + 8, 1.6, hz - 22), color=CHARCOAL_D, material="SmoothPlastic")
    board = part("Board", (4.0, 1.8, 0.26), (hx + 8, 2.9, hz - 22), color=(150, 150, 148), material="SmoothPlastic")
    surface_text(board, "SETTLEMENT BOARD", headline_name="Headline", sub="Foundations — press E")
    add_light(board, (200, 210, 255), 0.7, 8)
    return model("SettlementBoard", pole, board), (hx + 8, 2.9, hz - 22)


def build_territory_flags_v2():
    banner_colors = {"PLAZA": (210, 212, 216), "DEPOT": (210, 212, 216), "YARD": (210, 212, 216)}
    zones = [("PLAZA", 0.0, 0.0), ("DEPOT", 20.0, -12.0), ("YARD", -62.0, -42.0)]
    out = []
    for (key, x, z) in zones:
        out.append(part("TerritoryPole_%s" % key, (0.4, 4.6, 0.4), (x + 6, 2.3, z - 6),
                        color=CHARCOAL_D, material="Metal"))
        out.append(part("TerritoryBanner_%s" % key, (0.18, 1.8, 1.2), (x + 6, 3.9, z - 5.3),
                        color=banner_colors[key], material="SmoothPlastic"))
        out.append(part("TerritoryTop_%s" % key, (0.24, 0.3, 0.24), (x + 6, 4.75, z - 6),
                        color=GOLD, material="Neon"))
    return model("TerritoryFlags", *out)


def build_support_terminal_v2():
    """Support terminal: the SCREEN part is named 'SupportTerminal' (the wrapper
    model must NOT share that name — MonetizationService does a recursive
    FindFirstChild then requires IsA('BasePart'))."""
    stand = part("TerminalStand", (0.5, 1.7, 0.5), (-9, 0.85, -17), color=CHARCOAL_D, material="Metal")
    screen = part("SupportTerminal", (1.9, 1.25, 0.2), (-9, 1.95, -17), yaw=205, color=CHARCOAL_D, material="Metal")
    add_light(screen, GOLD, 1.7, 12)
    surface_text(screen, "SUPPORT MERIDIAN", headline_name="Headline", sub="Press E when options go live")
    halo = part("TerminalHalo", (0.9, 0.18, 0.9), (-9, 2.7, -17), yaw=205, color=GOLD, material="Neon")
    return model("SupportKiosk", stand, screen, halo), screen


def build_community_board_v2():
    pole = part("CommunityPole", (0.45, 3.6, 0.45), (-8, 1.8, -18), color=CHARCOAL_D, material="Metal")
    board = part("CommunityBoardPanel", (4.4, 2.4, 0.28), (-8, 3.15, -18), yaw=205,
                 color=(70, 76, 84), material="SmoothPlastic")
    surface_text(board, "COMMUNITY GOAL 0/25", headline_name="Headline",
                 sub="Deliveries + defenses count — everyone banks the reward")
    add_light(board, CYAN, 1.1, 10)
    return model("CommunityBoard", pole, board), board


# ------------------------------------------------------------- assembly --
def build_meridian_v2():
    from build_place import build_van

    hx, hz = -60.0, -8.0
    home = build_home_v2(hx, hz)
    plaza = build_plaza_v2()
    kiosk_block, kiosk_part = build_hero_kiosk_v2()
    terminal_model, _screen = build_support_terminal_v2()
    community_model, _panel = build_community_board_v2()
    hall = build_clan_hall_v2()
    warehouse = build_warehouse()
    outfitters = build_outfitters()
    armory = build_armory()
    cafe = build_cafe()
    pads_model, build_pads = build_settlement_pads_v2(hx, hz)
    board_model, _ = build_settlement_board_v2(hx, hz)
    flags = build_territory_flags_v2()
    phase2 = build_phase2_nodes_v2()
    safehouse = build_safehouse_v2(hx, hz)
    targets = build_targets()
    streets = build_streets()
    skyline = build_skyline()
    perimeter = build_perimeter()
    park = build_park()
    trees = build_trees()

    van1 = build_van("Van1", 46, -8)
    van2 = build_van("Van2", 46, 16)
    vans = model("Vans", van1, van2)

    cars = model("Cars",
                 car("Car1", 24, -22, yaw=90, body=(120, 130, 142)),
                 car("Car2", 24, 6, yaw=90, body=(140, 90, 84)),
                 car("Car3", -24, 24, yaw=90, body=(104, 128, 108)),
                 car("Car4", 12, -46, yaw=90, body=(72, 78, 88)),
                 car("Car5", -48, -60, yaw=90, body=(146, 140, 120)))

    meridian = model("Meridian",
                     part("Ground", (420, 2, 420), (0, -1, 0), color=GROUNDC, material="Asphalt"),
                     part("CurbRing", (420, 0.4, 420), (0, -0.1, 0), color=(40, 42, 46),
                          material="Concrete"),
                     streets, plaza, home, outfitters, armory, cafe, warehouse, hall,
                     kiosk_part, model("Buildings", kiosk_block),
                     targets, phase2, pads_model, board_model, flags, safehouse,
                     community_model, terminal_model, vans, cars, park, trees,
                     skyline, perimeter)
    meridian.interior = (hx, 0.0, hz)

    overrides = {
        "DELIVERY_TARGETS": [(-70.0, 0.23, -57.9), (26.0, 0.23, -69.9),
                             (76.9, 0.23, 10.0), (-49.9, 0.23, 58.0)],
        "PACKAGE_DEPOT": (20.0, 1.87, -12.0),
        "RUBBLE_PILES": [(34.0, 0.8, -52.0), (-44.0, 0.8, -48.0), (66.0, 0.8, -28.0)],
        "INFECTED_SPAWNS": [(8.0, 3.0, -64.0), (-30.0, 3.0, -76.0), (54.0, 3.0, -52.0)],
        "TERRITORY_ZONES": [("PLAZA", "Meridian Plaza", 0.0, 0.0, 16.0),
                            ("DEPOT", "Courier Depot", 20.0, -12.0, 12.0),
                            ("YARD", "Home Yard Pads", -62.0, -42.0, 16.0)],
        "PAD_OFFSETS": [(-6.0, -30.0), (2.0, -30.0), (-6.0, -38.0), (2.0, -38.0)],
        "BUILD_PADS": build_pads,
        "CLAN_HALL": (12.0, 2.94, -26.0),
        "HERO_KIOSK": (16.0, 2.2, -17.0),
        "HOME_INTERIOR": (hx, 0.0, hz),
        "KIOSK_PART": kiosk_part,
        "TERMINAL_MODEL": terminal_model,
        "COMMUNITY_MODEL": community_model,
        "PLAZA": plaza,
    }
    return meridian, overrides