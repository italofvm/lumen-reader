import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import { z } from 'zod';
import { GoogleGenerativeAI } from '@google/generative-ai';

dotenv.config();

const PORT = process.env.PORT || 10000;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-flash-latest';

if (!GEMINI_API_KEY.trim()) {
  // Intencionalmente não encerra o processo: permite subir no Render sem a env
  // e retornar erro claro.
  console.warn('WARN: GEMINI_API_KEY não configurada.');
}

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

const app = express();

app.use(express.json({ limit: '1mb' }));
app.use(
  cors({
    origin: '*',
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }),
);

app.use(
  rateLimit({
    windowMs: 60 * 1000,
    limit: 30,
    standardHeaders: true,
    legacyHeaders: false,
  }),
);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', ts: new Date().toISOString() });
});

async function listAvailableModels() {
  if (!GEMINI_API_KEY.trim()) return [];

  const endpoints = [
    'https://generativelanguage.googleapis.com/v1/models',
    'https://generativelanguage.googleapis.com/v1beta/models',
  ];

  let lastErr;
  for (const endpoint of endpoints) {
    try {
      const url = new URL(endpoint);
      url.searchParams.set('key', GEMINI_API_KEY);

      const resp = await fetch(url, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
        },
      });

      const bodyText = await resp.text();
      if (!resp.ok) {
        throw new Error(`ListModels falhou em ${endpoint} (HTTP ${resp.status}): ${bodyText}`);
      }

      const data = JSON.parse(bodyText);
      const models = Array.isArray(data?.models) ? data.models : [];
      return models.map((m) => ({
        name: m?.name,
        displayName: m?.displayName,
        supportedGenerationMethods: m?.supportedGenerationMethods,
      }));
    } catch (e) {
      lastErr = e;
    }
  }

  throw lastErr ?? new Error('ListModels falhou.');
}

async function generateContentViaRest({ modelName, prompt }) {
  if (!GEMINI_API_KEY.trim()) {
    throw new Error('GEMINI_API_KEY não configurada no servidor.');
  }

  const normalized = modelName.startsWith('models/') ? modelName : `models/${modelName}`;
  const endpoints = [
    `https://generativelanguage.googleapis.com/v1/${normalized}:generateContent`,
    `https://generativelanguage.googleapis.com/v1beta/${normalized}:generateContent`,
  ];

  let last;
  for (const endpoint of endpoints) {
    const url = new URL(endpoint);
    url.searchParams.set('key', GEMINI_API_KEY);

    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
        },
      }),
    });

    const bodyText = await resp.text();

    if (resp.ok) {
      const data = JSON.parse(bodyText);
      const text =
        data?.candidates?.[0]?.content?.parts
          ?.map((p) => (typeof p?.text === 'string' ? p.text : ''))
          .join('') ??
        '';
      return text;
    }

    // 404 de modelo: tentar próximo endpoint/modelo.
    if (resp.status === 404 && bodyText.includes('models/')) {
      last = new Error(`Model not found at ${endpoint}: ${bodyText}`);
      continue;
    }

    throw new Error(`GenerateContent falhou em ${endpoint} (HTTP ${resp.status}): ${bodyText}`);
  }

  throw last ?? new Error('Falha ao gerar conteúdo.');
}

app.get('/v1/ai/models', async (req, res) => {
  try {
    if (!GEMINI_API_KEY.trim()) {
      return res.status(500).json({
        error: 'GEMINI_API_KEY não configurada no servidor.',
      });
    }

    const models = await listAvailableModels();
    res.json({ models });
  } catch (e) {
    const message =
      e && typeof e === 'object' && 'message' in e ? String(e.message) : String(e);
    console.error('ListModels error:', { message });
    res.status(500).json({ error: 'Erro ao listar modelos.', cause: message });
  }
});

const askSchema = z.object({
  question: z.string().min(1).max(2000),
  contextText: z.string().min(1).max(20000),
  sourceLabel: z.string().min(1).max(200),
});

app.post('/v1/ai/ask', async (req, res) => {
  try {
    if (!GEMINI_API_KEY.trim()) {
      return res.status(500).json({
        error: 'GEMINI_API_KEY não configurada no servidor.',
      });
    }

    const parsed = askSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Payload inválido.',
        details: parsed.error.flatten(),
      });
    }

    const { question, contextText, sourceLabel } = parsed.data;

    const prompt =
      'Você é um assistente de leitura. Responda a pergunta abaixo usando APENAS o contexto fornecido.\n\n' +
      'REGRAS:\n' +
      '- Se o contexto não for suficiente, diga explicitamente que não encontrou no trecho fornecido.\n' +
      '- Ao final, inclua uma seção "Citações" com 1 a 3 trechos curtos do contexto (copiados) e informe a origem como: ' +
      sourceLabel +
      '.\n\n' +
      'PERGUNTA:\n' +
      question +
      '\n\n' +
      'CONTEXTO (' +
      sourceLabel +
      '):\n"""\n' +
      contextText +
      '\n"""\n';

    const modelCandidates = [
      GEMINI_MODEL,
      'gemini-flash-latest',
      'gemini-pro-latest',
      'gemini-2.0-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash-lite',
    ].map((m) => m.trim()).filter((m) => m.length > 0);

    const ac = new AbortController();
    const timeout = setTimeout(() => ac.abort(), 15000);

    try {
      let lastError;
      let text;

      for (const modelName of modelCandidates) {
        try {
          // Preferimos REST v1 (estável). O SDK Node ainda usa v1beta e pode retornar 404.
          text = await generateContentViaRest({ modelName, prompt });
          break;
        } catch (err) {
          lastError = err;
          const msg =
            err && typeof err === 'object' && 'message' in err
              ? String(err.message)
              : String(err);

          const isModel404 = msg.includes('404') && msg.includes('models/');
          if (!isModel404) {
            throw err;
          }

          // Melhor diagnóstico: tenta listar modelos disponíveis para esta key.
          try {
            const models = await listAvailableModels();
            console.error('Model not found. Available models (sample):',
              models.slice(0, 10).map((m) => ({
                name: m.name,
                supportedGenerationMethods: m.supportedGenerationMethods,
              })),
            );
          } catch (listErr) {
            const listMsg =
              listErr && typeof listErr === 'object' && 'message' in listErr
                ? String(listErr.message)
                : String(listErr);
            console.error('Failed to list models after 404:', { listMsg });
          }
        }
      }

      if (!text || text.trim().isEmpty) {
        throw lastError ?? new Error('Falha ao gerar conteúdo com modelos candidatos.');
      }
      res.json({ text });
    } finally {
      clearTimeout(timeout);
      // @google/generative-ai ainda não aceita AbortController em todas as versões,
      // então o timeout é best-effort.
    }
  } catch (e) {
    const message =
      e && typeof e === 'object' && 'message' in e ? String(e.message) : String(e);

    // Alguns erros do SDK vêm com detalhes adicionais; mantemos o retorno sanitizado.
    const status =
      e && typeof e === 'object' && 'status' in e && Number.isFinite(Number(e.status))
        ? Number(e.status)
        : undefined;

    console.error('AI ask error:', {
      message,
      status,
    });

    res.status(500).json({
      error: 'Erro interno ao processar IA.',
      cause: message,
      status,
    });
  }
});

app.listen(PORT, () => {
  console.log(`AI proxy listening on :${PORT}`);
});
