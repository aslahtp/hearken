from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import whisper
import logging
import requests
from werkzeug.utils import secure_filename
import tempfile

# Initialize Flask app
app = Flask(__name__)

# Configure CORS with specific options
CORS(app, resources={
    r"/process-audio": {
        "origins": "*",
        "methods": ["POST", "OPTIONS"],
        "allow_headers": ["Content-Type", "Accept", "ngrok-skip-browser-warning", "Connection"],
        "max_age": 3600
    }
})

# Set up logging with more detail
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Configure allowed extensions
ALLOWED_EXTENSIONS = {'mp3', 'wav', 'm4a', 'aac', 'wma'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Load Whisper model
try:
    model = whisper.load_model("tiny")
    logging.info("Whisper model loaded successfully")
except Exception as e:
    logging.error(f"Failed to load Whisper model: {e}")
    model = None

def download_audio_file(url):
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        # Create a temporary file with the correct extension
        extension = url.split('.')[-1].lower()
        if extension not in ALLOWED_EXTENSIONS:
            extension = 'mp3'  # Default to mp3 if extension not recognized
            
        with tempfile.NamedTemporaryFile(suffix=f'.{extension}', delete=False) as temp_file:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    temp_file.write(chunk)
            return temp_file.name
    except Exception as e:
        logging.error(f"Failed to download audio file: {e}")
        raise

@app.route('/process-audio', methods=['POST', 'OPTIONS'])
def process_audio():
    if request.method == 'OPTIONS':
        return '', 204

    try:
        logging.info(f"Received request with Content-Type: {request.content_type}")
        logging.info(f"Request headers: {dict(request.headers)}")

        # Handle both direct file upload and URL-based processing
        if request.content_type and 'application/json' in request.content_type:
            # Process audio from URL
            data = request.get_json()
            audio_url = data.get('audio_url')
            
            if not audio_url:
                return jsonify({'error': 'No audio URL provided'}), 400

            logging.info(f"Processing audio from URL: {audio_url}")
            temp_file_path = download_audio_file(audio_url)
            
        elif request.content_type and 'multipart/form-data' in request.content_type:
            # Process direct file upload
            if 'audio' not in request.files:
                return jsonify({'error': 'No audio file part'}), 400
            
            file = request.files['audio']
            if file.filename == '':
                return jsonify({'error': 'No selected file'}), 400
                
            if not allowed_file(file.filename):
                return jsonify({'error': f'Invalid file type. Allowed types: {", ".join(ALLOWED_EXTENSIONS)}'}), 400
            
            filename = secure_filename(file.filename)
            temp_file_path = os.path.join(tempfile.gettempdir(), filename)
            file.save(temp_file_path)
            
        else:
            return jsonify({'error': 'Invalid content type'}), 400

        try:
            # Process with Whisper
            if model is None:
                return jsonify({'error': 'Speech recognition model not initialized'}), 500

            logging.info("Starting transcription...")
            result = model.transcribe(temp_file_path)
            transcript = result["text"]
            logging.info("Transcription completed successfully")

            return jsonify({
                'message': 'Success',
                'transcript': transcript
            })

        finally:
            # Clean up temporary file
            try:
                if os.path.exists(temp_file_path):
                    os.remove(temp_file_path)
                    logging.info(f"Cleaned up temporary file: {temp_file_path}")
            except Exception as e:
                logging.warning(f"Failed to clean up temporary file: {str(e)}")

    except Exception as e:
        logging.error(f"Request processing error: {str(e)}")
        logging.exception("Full traceback:")
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None
    })

if __name__ == '__main__':
    logging.info("Server starting...")
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True,
        threaded=True
    ) 