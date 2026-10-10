shader_type canvas_item;
uniform float sway_pixels = 0.0;
void vertex() {
	// Move the crown only; the bottom vertices and the root stay fixed.
	float height_weight = 1.0-UV.y;
	VERTEX.x += sway_pixels*height_weight;
	VERTEX.y += sway_pixels*0.08*height_weight;
}
