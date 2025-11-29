import cv2
import numpy as np
import sys
from pathlib import Path

def detect_features(image_path):
    # 1. Load the Haar Cascades (Face AND Eye)
    face_cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    eye_cascade_path = cv2.data.haarcascades + 'haarcascade_eye.xml'
    
    face_cascade = cv2.CascadeClassifier(face_cascade_path)
    eye_cascade = cv2.CascadeClassifier(eye_cascade_path)
    
    # 2. Load the image
    # Convert path object to string for OpenCV
    img = cv2.imread(str(image_path))   
    if img is None:
        print("Error: Could not load image.")
        return

    # 3. Convert to Grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # 4. Detect Faces first
    faces = face_cascade.detectMultiScale(
        gray, 
        scaleFactor=1.1, 
        minNeighbors=5, 
        minSize=(30, 30)
    )
    
    print(f"Found {len(faces)} faces.")

    # 5. Analyze each detected face
    for (x, y, w, h) in faces:
        # Draw Blue rectangle around the face
        cv2.rectangle(img, (x, y), (x + w, y + h), (255, 0, 0), 2)
        
        # --- ROI (Region of Interest) Logic ---
        # We slice the image to create a smaller image containing ONLY the face.
        # This saves processing power and improves accuracy.
        roi_gray = gray[y:y+h, x:x+w]
        roi_color = img[y:y+h, x:x+w]
        
        # Detect Eyes ONLY within the face region (roi_gray)
        # We can be slightly less strict with eyes (minNeighbors) since we know they are on a face
        eyes = eye_cascade.detectMultiScale(roi_gray, scaleFactor=1.1, minNeighbors=3)
        
        for (ex, ey, ew, eh) in eyes:
            # Draw Green rectangles around the eyes
            # Note: ex, ey are relative to the ROI, not the main image
            cv2.rectangle(roi_color, (ex, ey), (ex + ew, ey + eh), (0, 255, 0), 2)

    # 6. Show and Save the result
    cv2.imshow('Detected Faces and Eyes', img)
    cv2.imwrite('./output/detected_features.jpg', img)
    print("Result saved as './output/detected_features.jpg'")
    
    cv2.waitKey(0)
    cv2.destroyAllWindows()

if __name__ == "__main__":
    # Ensure your directory and image exist
    url = "./data/sample_faces.jpeg" 
    image_path = Path(url)
    
    if not image_path.exists():
        print(f"❌ Image file not found at: {image_path.absolute()}")
        sys.exit(1)
    
    detect_features(image_path)