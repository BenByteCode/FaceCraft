import cv2
import mediapipe as mp
import sys
from pathlib import Path

def detect_face_contours(image_path):
    # 1. Initialize MediaPipe Face Mesh
    mp_face_mesh = mp.solutions.face_mesh
    mp_drawing = mp.solutions.drawing_utils
    mp_drawing_styles = mp.solutions.drawing_styles

    # static_image_mode=True: Tells it this is a photo, not a video stream
    # max_num_faces=5: How many faces to look for
    # refine_landmarks=True: Adds detailed landmarks for eyes and lips
    face_mesh = mp_face_mesh.FaceMesh(
        static_image_mode=True,
        max_num_faces=5,
        refine_landmarks=True,
        min_detection_confidence=0.5
    )

    # 2. Load image
    img = cv2.imread(str(image_path))
    if img is None:
        print("Error: Could not load image.")
        return

    # 3. Convert Color Space
    # OpenCV uses BGR, but MediaPipe needs RGB
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # 4. Process the image to find landmarks
    results = face_mesh.process(img_rgb)

    # 5. Draw the contours
    if results.multi_face_landmarks:
        print(f"Found {len(results.multi_face_landmarks)} faces.")
        
        for face_landmarks in results.multi_face_landmarks:
            
            # Draw the Face Mesh (The netting over the face)
            mp_drawing.draw_landmarks(
                image=img,
                landmark_list=face_landmarks,
                connections=mp_face_mesh.FACEMESH_TESSELATION,
                landmark_drawing_spec=None,
                connection_drawing_spec=mp_drawing_styles.get_default_face_mesh_tesselation_style()
            )

            # Draw the Contours (The main lines: eyes, lips, face oval)
            mp_drawing.draw_landmarks(
                image=img,
                landmark_list=face_landmarks,
                connections=mp_face_mesh.FACEMESH_CONTOURS,
                landmark_drawing_spec=None,
                connection_drawing_spec=mp_drawing_styles.get_default_face_mesh_contours_style()
            )
    else:
        print("No faces found.")

    # 6. Show and Save
    cv2.imshow('Face Contours', img)
    cv2.imwrite('./output/detected_contours.jpg', img)
    print("Result saved as './output/detected_contours.jpg'")
    
    cv2.waitKey(0)
    cv2.destroyAllWindows()

if __name__ == "__main__":
    url = "./data/brendan.jpeg"
    image_path = Path(url)
    
    if not image_path.exists():
        print(f"❌ Image file not found at: {image_path.absolute()}")
        sys.exit(1)
    
    detect_face_contours(image_path)