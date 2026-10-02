Backend 
cd /Users/harshitthakur/Documents/Build_with_ai/medivoice
source .venv/bin/activate
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000

Flutter
cd /Users/harshitthakur/Documents/Build_with_ai/medivoice/app

flutter run -d a569fecd \
  --dart-define=DEMO_MODE=false \
  --dart-define=API_BASE_URL=http://10.7.249.208:8000


Mirror
  scrcpy --video-codec=h264

