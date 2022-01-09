# Importing the threading module
import enum
import threading
import time
import cv2
import mediapipe as mp

import socket
import struct

rightHandPoints = [0.0] * (21 * 3)
leftHandPoints  = [0.0] * (21 * 3)

newFrameAvailable = False

STOP_RUNNING = False
def mediapipe():
    global STOP_RUNNING
    global rightHandPoints
    global leftHandPoints
    global newFrameAvailable
    
    
    mp_drawing = mp.solutions.drawing_utils
    mp_drawing_styles = mp.solutions.drawing_styles
    mp_hands = mp.solutions.hands

    prevTime = 0.1
    fps = 30

    # For webcam input:
    cap = cv2.VideoCapture(0 + cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FPS, 60)
    with mp_hands.Hands(
        model_complexity=0, 
        min_detection_confidence=0.5, 
        min_tracking_confidence=0.5,
        max_num_hands=2
    ) as hands:
        while cap.isOpened():
            success, image = cap.read()
            if not success:
                print("Ignoring empty camera frame.")
                # If loading a video, use 'break' instead of 'continue'.
                continue

            # To improve performance, optionally mark the image as not writeable to
            # pass by reference.
            image.flags.writeable = False
            image = cv2.cvtColor(cv2.flip(image, -1), cv2.COLOR_BGR2RGB)
            results = hands.process(image)

            # Draw the hand annotations on the image.
            image.flags.writeable = True
            image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

            if results.multi_hand_landmarks:
                ## Check if the frame was used, if not, dont update the frame
                if newFrameAvailable == False:
                    for handidx in range(len(results.multi_hand_landmarks)):
                        rightHand = True if 'R' == results.multi_handedness[handidx].classification[0].label[0] else False
                        if rightHand:
                            for i, dataPoint in enumerate(results.multi_hand_landmarks[handidx].landmark):
                                rightHandPoints[i*3 + 0] = dataPoint.x
                                rightHandPoints[i*3 + 1] = dataPoint.y
                                rightHandPoints[i*3 + 2] = dataPoint.z
                        else:
                            for i, dataPoint in enumerate(results.multi_hand_landmarks[handidx].landmark):
                                leftHandPoints[i*3 + 0] = dataPoint.x
                                leftHandPoints[i*3 + 1] = dataPoint.y
                                leftHandPoints[i*3 + 2] = dataPoint.z
                    newFrameAvailable = True

                for hand_landmarks in results.multi_hand_landmarks:
                    mp_drawing.draw_landmarks(
                        image,
                        hand_landmarks,
                        mp_hands.HAND_CONNECTIONS,
                        mp_drawing_styles.get_default_hand_landmarks_style(),
                        mp_drawing_styles.get_default_hand_connections_style())
                
            # Calculate fps
            curTime = time.time()
            fps = fps*0.90 + (1 / (curTime - prevTime))*0.1
            prevTime = curTime

            image = cv2.flip(image, -1)
            
            #print("FPS = %.2f" % fps)
            # Add fps text to image
            cv2.putText(image, "FPS: {:.1f}".format(fps), (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

            # Display the image.
            cv2.imshow('MediaPipe Hands', image)
            
            if cv2.waitKey(5) & 0xFF == 27:
                STOP_RUNNING = True
                break
    cap.release()

def sendLoop():
    global STOP_RUNNING
    global rightHandPoints
    global leftHandPoints
    global newFrameAvailable

    handMarkerCount = 21*3 * 2

    floatList = [0.0]*handMarkerCount
    structPackStr = '%sf' % handMarkerCount
    
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(('localhost', 50052))
    s.listen(1)
    s.settimeout(0.75)

    connectionMade = False
    while connectionMade == False and STOP_RUNNING == False:
        try:
            conn, addr = s.accept()
            print("Connection made")
            connectionMade = True
            break
        except:
            print("Connection timeout")
            if STOP_RUNNING == True:
                return
        
    while newFrameAvailable == False:
        print("Waiting for hands")
        time.sleep(0.1)

    secondOffset = len(rightHandPoints)
    while STOP_RUNNING == False:
        if newFrameAvailable == True:

            for i, xyz in enumerate(rightHandPoints):
                floatList[i] = xyz

            for i, xyz in enumerate(leftHandPoints):
                floatList[i + secondOffset] = xyz

            buf = struct.pack(structPackStr, *floatList)
            conn.sendall(buf)

            time.sleep(0.01)

            newFrameAvailable = False
    
    conn.close()
    

def main():
    global newFrameAvailable
    
    global STOP_RUNNING
    
    t1 = threading.Thread(target=mediapipe, daemon=False)
    t1.start()
#   
    t2 = threading.Thread(target=sendLoop, daemon=False)
    t2.start()
    


if __name__ == '__main__':
    main()