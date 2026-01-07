# Lumen Reader — AI Proxy (Gemini)

## Objetivo
Backend simples (Node.js + Express) para manter a chave do Gemini no servidor e expor um endpoint HTTP consumido pelo app Flutter.

## Endpoints
- `GET /health`
- `POST /v1/ai/ask`

Payload:
```json
{
  "question": "...",
  "contextText": "...",
  "sourceLabel": "Capítulo 1, página 3"
}
```

Resposta:
```json
{
  "text": "..."
}
```

## Rodar local
```bash
npm install
GEMINI_API_KEY=... npm start
```

## Deploy no Render
- Crie um **Web Service** apontando para esta pasta.
- Configure a variável de ambiente `GEMINI_API_KEY`.
- O Render expõe uma URL como `https://<nome>.onrender.com`.

## Observações
- MVP sem login, com rate limit por IP.
