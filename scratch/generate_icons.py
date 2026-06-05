import os
from PIL import Image

logo_path = r"c:\Users\biagi\Desktop\yamilink\assets\logo.png"
if not os.path.exists(logo_path):
    print(f"Error: Logo not found at {logo_path}")
    exit(1)

img = Image.open(logo_path)

# Convert to RGBA if not already
if img.mode != 'RGBA':
    img = img.convert('RGBA')

# 1. Android Mipmaps
android_dir = r"c:\Users\biagi\Desktop\yamilink\android\app\src\main\res"
android_sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192
}
for folder, size in android_sizes.items():
    dest_path = os.path.join(android_dir, folder, "ic_launcher.png")
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    img.resize((size, size), Image.Resampling.LANCZOS).save(dest_path, "PNG")
    print(f"Generated Android icon: {dest_path} ({size}x{size})")

# 2. Windows Icon
windows_ico_path = r"c:\Users\biagi\Desktop\yamilink\windows\runner\resources\app_icon.ico"
os.makedirs(os.path.dirname(windows_ico_path), exist_ok=True)
img.save(windows_ico_path, format="ICO", sizes=[(16,16), (32,32), (48,48), (256,256)])
print(f"Generated Windows icon: {windows_ico_path}")

# 3. iOS Icons
ios_dir = r"c:\Users\biagi\Desktop\yamilink\ios\Runner\Assets.xcassets\AppIcon.appiconset"
if os.path.exists(ios_dir):
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024
    }
    for filename, size in ios_sizes.items():
        dest_path = os.path.join(ios_dir, filename)
        img.resize((size, size), Image.Resampling.LANCZOS).save(dest_path, "PNG")
        print(f"Generated iOS icon: {dest_path} ({size}x{size})")

# 4. macOS Icons
macos_dir = r"c:\Users\biagi\Desktop\yamilink\macos\Runner\Assets.xcassets\AppIcon.appiconset"
if os.path.exists(macos_dir):
    macos_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024
    }
    for filename, size in macos_sizes.items():
        dest_path = os.path.join(macos_dir, filename)
        img.resize((size, size), Image.Resampling.LANCZOS).save(dest_path, "PNG")
        print(f"Generated macOS icon: {dest_path} ({size}x{size})")

print("All icons successfully generated!")
