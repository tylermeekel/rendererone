package main

// Super inefficient rudimentary implementation for now
create_plane :: proc(x_size, z_size: f32, x_divisions, z_divisions: i32) -> []Vertex {
    // 6 vertices per square, xdiv by ydiv squared
    verts := make([]Vertex, 6 * x_divisions * z_divisions)

    division_x_size := x_size / f32(x_divisions)
    division_z_size := z_size / f32(z_divisions)

    // to center on 0,0. x must go from -(x/2) to x/2 and z must go from -(z/2) to z/2
    index := 0
    for z in 0..< z_divisions {
        near_z := -(z_size/2) + (f32(z) * division_z_size)
        far_z := -(z_size/2) + (f32(z + 1) * division_z_size)

        for x in 0..< x_divisions {
            left_x := -(x_size/2) + (f32(x) * division_x_size)
            right_x := -(x_size/2) + (f32(x + 1) * division_x_size)

            // Triangle 1
            // far left
            verts[index] = Vertex{{left_x, 0, far_z}}
            // near right
            verts[index + 1] = Vertex{{right_x, 0, near_z}}
            // near left
            verts[index + 2] = Vertex{{left_x, 0, near_z}}

            // Triangle 2
            // far left
            verts[index + 3] = Vertex{{left_x, 0, far_z}}
            // far right
            verts[index + 4] = Vertex{{right_x, 0, far_z}}
            // near right
            verts[index + 5] = Vertex{{right_x, 0, near_z}}

            index += 6
        }
    }

    return verts
}