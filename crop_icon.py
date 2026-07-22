from PIL import Image

def process_icon():
    img_path = "assets/icon.png"
    img = Image.open(img_path)
    
    width, height = img.size
    
    # We want to crop the center. The image is 1024x1024.
    # If we crop a 650x650 area from the center and resize it back to 1024x1024,
    # the logo will appear much larger and fill the adaptive icon mask.
    
    crop_size = 650
    left = (width - crop_size) / 2
    top = (height - crop_size) / 2
    right = (width + crop_size) / 2
    bottom = (height + crop_size) / 2
    
    cropped_img = img.crop((left, top, right, bottom))
    resized_img = cropped_img.resize((1024, 1024), Image.Resampling.LANCZOS)
    
    resized_img.save("assets/icon.png")
    print("Icon cropped and resized successfully!")

if __name__ == "__main__":
    process_icon()
