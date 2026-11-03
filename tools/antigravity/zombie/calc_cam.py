import numpy as np

# Camera transform from the FBX:
# basis:
# [ 0,  0, -703.27 ]
# [ 0, 703.27, 0   ]
# [ 703.27, 0, 0   ]
# translation: [-17.4521, 124.979, -75.0941]

cam_basis = np.array([
    [0.000125754, -1.76672e-12, -703.27],
    [0, 703.27, -1.76672e-12],
    [703.27, 3.15914e-19, 0.000125754]
])
cam_origin = np.array([-17.4521, 124.979, -75.0941])

# Normalizing the scale of the basis:
scale = np.linalg.norm(cam_basis[:, 0])
rot = cam_basis / scale

print("Camera scale in FBX:", scale)
print("Camera rotation matrix:\n", rot)
print("Camera pos in FBX:", cam_origin)
