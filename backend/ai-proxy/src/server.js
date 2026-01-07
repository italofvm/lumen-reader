import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import { z } from 'zod';
import { GoogleGenerativeAI } from '@google/generative-ai';

dotenv.config();

const PORT = process.env.PORT || 10000;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';

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

    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const ac = new AbortController();
    const timeout = setTimeout(() => ac.abort(), 15000);

    try {
      const result = await model.generateContent({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
        },
      });

      const text = result.response.text();
      res.json({ text });
    } finally {
      clearTimeout(timeout);
      // @google/generative-ai ainda não aceita AbortController em todas as versões,
      // então o timeout é best-effort.
    }
  } catch (e) {
    console.error('AI ask error:', e);
    res.status(500).json({ error: 'Erro interno ao processar IA.' });
  }
});

app.listen(PORT, () => {
  console.log(`AI proxy listening on :${PORT}`);
});
