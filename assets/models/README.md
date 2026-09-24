# YOLOv8-OBB Model Assets

Please place the trained YOLOv8-OBB Rubik's cube model weights here:
- Filename: `rubik_obb.tflite` (or `rubik_obb.onnx`)

Export command from Ultralytics PyTorch model:
```bash
yolo export model=rubik_obb_best.pt format=tflite int8=True
cp rubik_obb_saved_model/rubik_obb_int8.tflite assets/models/rubik_obb.tflite
```
