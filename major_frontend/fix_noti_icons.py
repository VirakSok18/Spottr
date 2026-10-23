from PIL import Image
import os

def process_and_save(img, size, out_path):
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    datas = resized.getdata()
    new_data = []
    for item in datas:
        r, g, b, a = item
        brightness = (r + g + b) / 3
        # Threshold for white "S" part
        if brightness > 220:
            new_data.append((255, 255, 255, a))
        else:
            new_data.append((255, 255, 255, 0))
    resized.putdata(new_data)
    resized.save(out_path, 'PNG')
    print(f"Saved {out_path} ({size}x{size})")

def create_notification_icons():
    source_path = 'assets/images/app_logo.png'
    if not os.path.exists(source_path):
        print(f"Error: {source_path} not found")
        return
    img = Image.open(source_path).convert('RGBA')
    sizes = {
        'drawable-mdpi': 24,
        'drawable-hdpi': 36,
        'drawable-xhdpi': 48,
        'drawable-xxhdpi': 72,
        'drawable-xxxhdpi': 96
    }
    res_base = 'android/app/src/main/res'
    icon_name = 'ic_notification.png'
    for folder, size in sizes.items():
        folder_path = os.path.join(res_base, folder)
        if not os.path.exists(folder_path): os.makedirs(folder_path)
        process_and_save(img, size, os.path.join(folder_path, icon_name))

    # Also save to base drawable folder as fallback (use 72x72)
    base_drawable = os.path.join(res_base, 'drawable')
    if not os.path.exists(base_drawable): os.makedirs(base_drawable)
    process_and_save(img, 72, os.path.join(base_drawable, icon_name))
    print("Done generating notification icons.")

if __name__ == "__main__":
    create_notification_icons()
