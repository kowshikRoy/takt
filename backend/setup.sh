#!/bin/bash

echo "Setting up spaCy backend service..."

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt

# Download German language model
echo "Downloading German spaCy model..."
python -m spacy download de_core_news_sm

echo ""
echo "✓ Setup complete!"
echo ""
echo "To start the server:"
echo "  source venv/bin/activate"
echo "  python app.py"
echo ""
echo "Or for production:"
echo "  gunicorn -w 4 -b 0.0.0.0:5000 app:app"
