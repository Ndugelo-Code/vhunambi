# ComfyUI & SDXL Integration Blueprint for AI Music App

This document outlines the architecture, data payloads, and hosting strategies required to integrate automated album art and profile asset generation into our AI Music Generator platform using [RunPod](https://www.runpod.io) and [ComfyUI](https://github.com/comfyanonymous/ComfyUI).

---

## 1. ComfyUI JSON API Payload

To communicate with ComfyUI programmatically, ensure **"Enable Dev mode"** is checked in ComfyUI settings, then click **"Save (API Format)"**. This exports the exact node IDs needed for direct HTTP requests.

Submit a POST request to `http://<YOUR-RUNPOD-ENDPOINT>/prompt` with the following dynamic JSON payload:

```json
{
  "client_id": "music_app_user_123",
  "prompt": {
    "3": {
      "inputs": {
        "ckpt_name": "sd_xl_base_1.0.safetensors"
      },
      "class_type": "CheckpointLoaderSimple"
    },
    "6": {
      "inputs": {
        "text": "Album cover art, synthwave aesthetic, futuristic sports car driving into a neon sunset, high resolution, professional graphic design, 8k",
        "clip": [
          "3",
          1
        ]
      },
      "class_type": "CLIPTextEncode"
    },
    "7": {
      "inputs": {
        "text": "blurry, low quality, text, words, watermark, bad anatomy, ugly",
        "clip": [
          "3",
          1
        ]
      },
      "class_type": "CLIPTextEncode"
    },
    "5": {
      "inputs": {
        "width": 1024,
        "height": 1024,
        "batch_size": 1
      },
      "class_type": "EmptyLatentImage"
    },
    "10": {
      "inputs": {
        "seed": 4239847239,
        "steps": 25,
        "cfg": 7.0,
        "sampler_name": "euler",
        "scheduler": "normal",
        "denoise": 1.0,
        "model": [
          "3",
          0
        ],
        "positive": [
          "6",
          0
        ],
        "negative": [
          "7",
          0
        ],
        "latent_image": [
          "5",
          0
        ]
      },
      "class_type": "KSampler"
    },
    "12": {
      "inputs": {
        "samples": [
          "10",
          0
        ],
        "vae": [
          "3",
          2
        ]
      },
      "class_type": "VAEDecode"
    },
    "15": {
      "inputs": {
        "filename_prefix": "album_cover",
        "images": [
          "12",
          0
        ]
      },
      "class_type": "SaveImage"
    }
  }
}
```

### Dynamic Parameters to Mutate:
* **Node `6` (`inputs.text`)**: Insert the custom generated positive visual prompt here.
* **Node `10` (`inputs.seed`)**: Provide a unique randomized integer for every request to guarantee variation.

---

## 2. Automated Prompt Extraction (LLM Pipeline)

Since end-users typically lack stable diffusion prompt engineering knowledge, our application intercepting layer passes song metadata through a fast LLM (e.g., GPT-4o-mini or Claude) first.

### LLM System Prompt
```text
You are an expert prompt engineer for SDXL. Your job is to take raw song metadata, genre details, or lyrics, and convert them into a visually stunning, descriptive, single-paragraph image prompt for an album cover. Output only the prompt text itself. No introductory pleasantries, no conversational text.
```

### Data Pipeline Logic
1. **User Request Context:** `Genre: Lo-fi Hip Hop`, `Lyrics: "Staring at the rain against my bedroom window pane..."`, `Theme Selection: Anime`.
2. **LLM Output:** `"Lo-fi anime style album cover art, a melancholic character sitting by a bedroom window, rain droplets sliding down the glass, warm indoor lighting, lo-fi aesthetic, highly detailed, cozy mood, 8k resolution."`
3. **App Backend Execution:** Inject this string programmatically into node `6` of the ComfyUI API payload prior to firing the task off to the GPU.

---

## 3. RunPod Hardware & Deployment Strategy

SDXL checkpoints require a minimum of **12GB to 16GB VRAM** to guarantee stable runtime performance.

| GPU Model | VRAM | Estimated Cost / Hr | Primary Use Case |
| :--- | :---: | :---: | :--- |
| **NVIDIA RTX 4090** | 24 GB | ~$0.44 - $0.50 | **Development & Early Launch.** Rapid execution loops (3–5 seconds per 1024x1024 frame). Highly cost-effective. |
| **NVIDIA L4** | 24 GB | ~$0.30 - $0.35 | **Production Economy Tier.** Energy-efficient architecture with slightly reduced clock speed compared to 4090. |
| **NVIDIA A100 / H100** | 80 GB | ~$1.50 - $2.50 | **Custom LoRA Training Only.** High bandwidth/capacity required for deep batch-weight fine-tuning. Avoid using for regular generation tasks. |

### Production Implementation Note
Do not manage persistent, idle hardware instances. For scale production, package the ComfyUI container into **RunPod Serverless**. This guarantees:
* **Scaling to Zero:** Zero compute costs incurred when platform user generation velocity drops to zero.
* **Autoscaling Pools:** Instantly boots parallel GPU environments to absorb sudden spikes in user demand.
* **By-the-Second Billing:** Platform bills compute metrics strictly based on execution time cycles.

---

## 4. Monetization & Licensing Guardrails

Ensure only fully permissive, open-weight assets are loaded inside active distribution targets.

* **Commercially Safe Options:** **FLUX.1 [schnell]** (Apache 2.0 license structure allows uncapped monetization) and **SDXL 1.0**.
* **Restricted Licenses:** **FLUX.1 [dev]** is strictly limited to non-commercial/academic parameters. **Stable Diffusion 3.5** includes active tier ceilings (free only if global corporate revenue scales below \$1M USD annually).