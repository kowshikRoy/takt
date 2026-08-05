import gradio as gr
from main import app as fastapi_app

# Create a clean Gradio interface for testing
with gr.Blocks(title="OmniScribe API & Service") as demo:
    gr.Markdown("# OmniScribe Media Transcription & Translation API")
    gr.Markdown("FastAPI backend service for German media transcription and English translation.")
    gr.Markdown("Mobile App Endpoints: `/submit-media`, `/status/{task_id}`, `/word-info/{word}`")

# Mount FastAPI app so all API endpoints are available on root
app = gr.mount_gradio_app(fastapi_app, demo, path="/demo")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
