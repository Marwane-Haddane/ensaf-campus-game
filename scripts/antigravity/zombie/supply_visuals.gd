extends RefCounted
## Recognizable, lightweight field supplies; dimensions are in meters.
const G = preload("res://scripts/antigravity/zombie/prop_geometry.gd")

static func build(parent: Node3D, kind: String, weapon: String) -> void:
	var dark := G.metal(Color("232c32"), 0.4)
	var steel := G.metal(Color("a3adb0"), 0.7)
	var brass := G.metal(Color("d3a556"), 0.65)
	var white := G.metal(Color("e5e9dc"), 0.0)
	match kind:
		"ammo":
			if weapon == "shotgun":
				var red := G.metal(Color("b43f29"), 0.0)
				G.box(parent, Vector3(.34,.06,.25), Vector3(0,-.06,0), dark)
				for x in [-.11,0.0,.11]:
					for z in [-.06,.06]:
						G.cylinder(parent,.035,.14,Vector3(x,.035,z),red)
						G.cylinder(parent,.037,.025,Vector3(x,-.025,z),brass)
				stencil(parent,"12 GA",Vector3(0,-.045,.128),0.0013)
			else:
				for x in [-.075,.075]:
					G.box(parent,Vector3(.085,.075,.27),Vector3(x,-.01,0),dark)
					G.box(parent,Vector3(.105,.025,.045),Vector3(x,-.01,.14),steel)
					for z in [-.07,-.015,.04,.095]:
						G.box(parent,Vector3(.088,.008,.009),Vector3(x,.032,z),steel)
					var cartridge := G.cylinder(parent,.016,.065,Vector3(x,.04,-.10),brass)
					cartridge.rotation_degrees.z = 90
				stencil(parent,"9mm" if weapon == "pistol" else "SMG",Vector3(0,.01,.165),0.0012)
		"medkit":
			var teal := G.metal(Color("23796c"),0.05)
			G.box(parent,Vector3(.40,.25,.16),Vector3.ZERO,white)
			G.box(parent,Vector3(.41,.04,.17),Vector3(0,.075,0),teal)
			for x in [-.07,.07]:
				G.box(parent,Vector3(.025,.07,.035),Vector3(x,.15,0),dark)
			G.box(parent,Vector3(.16,.025,.035),Vector3(0,.18,0),dark)
			for z in [-.083,.083]:
				G.box(parent,Vector3(.15,.15,.008),Vector3(0,-.015,z),teal)
				G.box(parent,Vector3(.10,.032,.012),Vector3(0,-.015,z),white)
				G.box(parent,Vector3(.032,.10,.012),Vector3(0,-.015,z),white)
		"scrap":
			var rust := G.metal(Color("80523b"),.55)
			for i in range(3):
				var part := G.box(parent,Vector3(.33,.025,.075),Vector3(0,-.06+i*.03,(i-1)*.07),rust if i == 1 else steel)
				part.rotation_degrees.y = -24+i*23
			for x in [-.10,.10]:
				var pipe := G.cylinder(parent,.025,.28,Vector3(x,.04,0),steel)
				pipe.rotation_degrees.x = 90
			G.box(parent,Vector3(.035,.14,.29),Vector3.ZERO,dark)
		"weapon":
			G.box(parent,Vector3(.40,.16,.30),Vector3.ZERO,dark)
			G.box(parent,Vector3(.41,.025,.31),Vector3(0,.06,0),steel)
			for x in [-.13,.13]:
				G.box(parent,Vector3(.04,.06,.025),Vector3(x,.025,.16),brass)
			for x in [-.06,.06]:
				G.box(parent,Vector3(.02,.025,.07),Vector3(x,0,.18),steel)
			G.box(parent,Vector3(.14,.025,.025),Vector3(0,0,.21),dark)
			stencil(parent,"PISTOL",Vector3(0,.015,.154),.0012)

static func stencil(parent: Node3D, title: String, at: Vector3, pixels: float) -> void:
	var label := Label3D.new()
	label.text = title
	label.position = at
	label.font_size = 36
	label.pixel_size = pixels
	label.outline_size = 0
	label.modulate = Color("f0e8ce")
	parent.add_child(label)
