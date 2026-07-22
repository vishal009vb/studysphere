from PIL import Image, ImageDraw

def create_gradient_bg():
    width, height = 1080, 1920
    img = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(img)
    
    # Gradient colors:
    # 0xff1d4ed8 -> (29, 78, 216)
    # 0xff2563eb -> (37, 99, 235)
    # 0xff38bdf8 -> (56, 189, 248)
    
    # We will interpolate across the diagonal (top-left to bottom-right)
    # Max distance is sqrt(w^2 + h^2)
    max_dist = (width**2 + height**2)**0.5
    
    for y in range(height):
        for x in range(width):
            # Distance along diagonal direction: (x/width + y/height) / 2
            # Value from 0.0 to 1.0
            t = (x / width + y / height) / 2
            
            if t < 0.5:
                # Interpolate from color 1 to color 2
                t2 = t * 2
                r = int(29 + (37 - 29) * t2)
                g = int(78 + (99 - 78) * t2)
                b = int(216 + (235 - 216) * t2)
            else:
                # Interpolate from color 2 to color 3
                t2 = (t - 0.5) * 2
                r = int(37 + (56 - 37) * t2)
                g = int(99 + (189 - 99) * t2)
                b = int(235 + (248 - 235) * t2)
                
            draw.point((x, y), fill=(r, g, b))
            
    img.save("assets/splash_bg.png")
    print("Gradient background created successfully!")

if __name__ == "__main__":
    create_gradient_bg()
