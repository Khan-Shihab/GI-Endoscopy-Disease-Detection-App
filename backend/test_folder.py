import requests
from pathlib import Path

base = Path(r"D:\Programming\Thesis\Dataset\Augmented_Resized Image")

for class_folder in base.iterdir():
    if class_folder.is_dir():
        # Test first image from each class
        images = list(class_folder.glob("*.jpg"))
        if images:
            with open(images[0], "rb") as f:
                response = requests.post(
                    "http://localhost:8000/predict",
                    files={"file": (images[0].name, f, "image/jpeg")}
                )
            result = response.json()
            print(f"[{class_folder.name}] → {result['status']} ({result['confidence']}%)")
