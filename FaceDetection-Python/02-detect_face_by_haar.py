import cv2
import numpy as np
import sys
from pathlib import Path

def detect_faces_in_image(image_url):
    # 1. Load the Haar Cascade (included with OpenCV)
    cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    face_cascade = cv2.CascadeClassifier(cascade_path)
    
    # 2. Load the image
    img = cv2.imread(str(image_url))   
    if img is None:
        print("Error: Could not load image.")
        return

    # 3. Convert to Grayscale (Required for Haar Cascade)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # 4. Detect Faces
    # scaleFactor=1.1: Reduces image size by 10% each pass to find faces of different sizes
    # minNeighbors=5: Higher values = fewer false positives
    faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
    
    print(f"Found {len(faces)} faces!")

    # 5. Draw Rectangles
    for (x, y, w, h) in faces:
        cv2.rectangle(img, (x, y), (x + w, y + h), (255, 0, 0), 2)
     
    # 6. Show and Save the result
    cv2.imshow('Detected Faces', img)
    cv2.imwrite('./output/detected_faces.jpg', img)
    print("Result saved as './output/detected_faces.jpg'")
    
    cv2.waitKey(0)
    cv2.destroyAllWindows()


if __name__ == "__main__":
    url = "./data/sample_faces.jpeg"
    #url = "./data/brendan.jpeg"
    # url = "./data/ryan.jpeg"
    # url = "./data/brendan_ryan.jpeg"

    image_path = Path(url)
    if not image_path.exists():
        print("❌ Image file not found")
        sys.exit(1)
    
    detect_faces_in_image(url)