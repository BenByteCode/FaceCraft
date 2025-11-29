import cv2
import numpy as np
import matplotlib.pyplot as plt

def generate_sample_face():
    """
    Generates a synthetic image of a face using basic shapes.
    Returns: A numpy array representing the image.
    """
    # Create a black background (300x300 pixels)
    img = np.zeros((300, 300, 3), dtype="uint8")

    # Draw the Face (White Circle)
    center_coordinates = (150, 150)
    axesLength = (100, 120) # Oval shape
    angle = 0
    startAngle = 0
    endAngle = 360
    color = (255, 255, 255) # White
    thickness = -1 # Fill
    cv2.ellipse(img, center_coordinates, axesLength, angle, startAngle, endAngle, color, thickness)

    # Draw Eyes (Black Circles)
    cv2.circle(img, (110, 130), 15, (0, 0, 0), -1)
    cv2.circle(img, (190, 130), 15, (0, 0, 0), -1)

    # Draw Mouth (Black Ellipse arc)
    cv2.ellipse(img, (150, 180), (40, 20), 0, 0, 180, (0, 0, 0), 5)
    
    return img

def detect_face_edges(img):
    """
    Detects the face using Canny Edge Detection and Contours.
    """
    # 1. Convert to Grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 2. Apply Gaussian Blur (Reduces noise for better edge detection)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # 3. Perform Canny Edge Detection
    # Thresholds 50 and 150 determine which edges are kept
    edges = cv2.Canny(blurred, 50, 150)

    # 4. Find Contours based on the edges
    # RETR_EXTERNAL retrieves only the extreme outer contours
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Create a copy of the image to draw results on
    result_img = img.copy()

    face_detected = False
    
    # 5. Analyze Contours to find the "Face"
    for contour in contours:
        # Calculate area to ignore small noise
        area = cv2.contourArea(contour)
        
        # If the shape is large enough, we assume it's our face
        if area > 1000:
            # Draw a green bounding box around the detected face
            x, y, w, h = cv2.boundingRect(contour)
            cv2.rectangle(result_img, (x, y), (x + w, y + h), (0, 255, 0), 2)
            face_detected = True

    return edges, result_img, face_detected

# --- Main Execution ---

# 1. Generate the image
original_img = generate_sample_face()

# 2. Run detection
edge_map, final_result, found = detect_face_edges(original_img)

# 3. Visualization
plt.figure(figsize=(12, 4))

# Show Original
plt.subplot(1, 3, 1)
plt.imshow(cv2.cvtColor(original_img, cv2.COLOR_BGR2RGB))
plt.title("1. Generated Sample Image")
plt.axis("off")

# Show Edges (Canny Output)
plt.subplot(1, 3, 2)
plt.imshow(edge_map, cmap='gray')
plt.title("2. Canny Edge Detection")
plt.axis("off")

# Show Result with Bounding Box
plt.subplot(1, 3, 3)
plt.imshow(cv2.cvtColor(final_result, cv2.COLOR_BGR2RGB))
plt.title("3. Detected Face Contour")
plt.axis("off")

plt.tight_layout()
plt.show()

if found:
    print("Success: Face shape detected via edge analysis.")
else:
    print("No face-like edges found.")