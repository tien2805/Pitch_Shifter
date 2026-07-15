import numpy as np
import os

def float_to_q(val, frac_bits=23):
    """Convert float to Q1.23 fixed-point integer"""
    max_val = (1 << 23) - 1
    min_val = -(1 << 23)
    q_val = int(round(val * (1 << frac_bits)))
    if q_val > max_val: q_val = max_val
    if q_val < min_val: q_val = min_val
    # Output as 24-bit unsigned integer equivalent for hex formatting
    return q_val & 0xFFFFFF

def cordic_sw(angle, n_iter=16):
    """Software CORDIC model — cycle-exact to hardware"""
    K = 0.6072529350088814  # CORDIC gain constant
    x, y, z = K, 0.0, angle
    if z > (np.pi / 2):
        x, y, z = -x, -y, z - np.pi
    elif z < -(np.pi / 2):
        x, y, z = -x, -y, z + np.pi
    for i in range(n_iter):
        d = 1.0 if z >= 0 else -1.0
        x_new = x - d * y * (2**(-i))
        y_new = y + d * x * (2**(-i))
        z_new = z - d * np.arctan(2**(-i))
        x, y, z = x_new, y_new, z_new
    return x, y  # cos, sin

def generate_vectors():
    # Test angles from -pi to pi (excluding exact pi to avoid overflow in Q format)
    angles = np.linspace(-np.pi + 0.001, np.pi - 0.001, 1000)
    
    with open("cordic_vectors.txt", "w") as f:
        for a in angles:
            cos_ref, sin_ref = cordic_sw(a)
            # Map angle from [-pi, pi] to [-1.0, 1.0) for the FPGA
            angle_q = float_to_q(a / np.pi)  
            cos_q   = float_to_q(cos_ref)
            sin_q   = float_to_q(sin_ref)
            # Write out as Hex strings
            f.write(f"{angle_q:06X} {cos_q:06X} {sin_q:06X}\n")

if __name__ == "__main__":
    generate_vectors()
    print("Generated cordic_vectors.txt successfully.")
