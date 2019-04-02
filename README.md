# iOSDH

App designed to provide drivers with an outlet to autonomously, hands-free, report potholes they encounter to the relevant government agencies. Built mainly natively in Swift, and makes calls to a Firebase realtime database and our ML model in our Google ML Engine.

## Modes of Use

iOSDH has 2 modes:

1. Continuous Capture: The app will continuously take pictures, store them in a buffer, and send them to our Deep Learning ML model for pothole image verification; our app will in turn file a report to our webapp at the following address: https://www.johndang.me/DeepHole/

2. Voice Activation: The app will respond to the word 'Report', and manually send a report to our web app.

## Web App

Our web app can be found at: https://github.com/jamqd/DeepHole
