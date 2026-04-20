import { GoogleGenAI } from "@google/genai";

const MODEL_NAME = "gemini-3-flash-preview";

export async function analyzeBallisticImage(base64Image: string): Promise<any> {
  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY || "" });
  
  const prompt = `
    Actúa como un experto en balística forense. Analiza esta imagen de una bala o cartucho y proporciona la siguiente información en formato JSON:
    {
      "caliber": "calibre estimado (ej. 9mm, .45 ACP)",
      "ammoType": "tipo de munición (ej. Full Metal Jacket, Hollow Point)",
      "compatibleWeapon": "tipo de arma probable (ej. Pistola semiautomática, Revólver)",
      "estimatedLength": "longitud aproximada en mm",
      "possibleBrands": ["lista de posibles fabricantes"],
      "confidence": 0.95,
      "description": "breve descripción técnica de los hallazgos"
    }
    
    Sé preciso y utiliza terminología técnica en español. Si la imagen no es de una bala o cartucho, indica que no se pudo identificar.
  `;

  try {
    const response = await ai.models.generateContent({
      model: MODEL_NAME,
      contents: [
        {
          parts: [
            { text: prompt },
            {
              inlineData: {
                mimeType: "image/jpeg",
                data: base64Image.split(",")[1] || base64Image,
              },
            },
          ],
        },
      ],
      config: {
        responseMimeType: "application/json",
      }
    });

    const text = response.text;
    if (!text) throw new Error("No se recibió respuesta del modelo.");
    return JSON.parse(text);
  } catch (error) {
    console.error("Error in Gemini analysis:", error);
    throw error;
  }
}
