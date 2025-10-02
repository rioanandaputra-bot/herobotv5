<?php

namespace App\Services;

use App\Services\Contracts\ChatServiceInterface;
use App\Services\Contracts\EmbeddingServiceInterface;
use App\Services\Contracts\SpeechToTextServiceInterface;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GeminiService implements ChatServiceInterface, EmbeddingServiceInterface, SpeechToTextServiceInterface
{
    protected $apiKey;
    protected $model;
    protected $embeddingModel;
    protected $baseUrl;
    protected $client;

    public function __construct()
    {
        $this->apiKey = config('services.gemini.api_key');
        $this->model = config('services.gemini.model');
        $this->embeddingModel = config('services.gemini.embedding_model');
        $this->baseUrl = "https://generativelanguage.googleapis.com/v1beta";
        $this->client = Http::baseUrl($this->baseUrl)
            ->withHeaders([
                'Content-Type' => 'application/json',
                'x-goog-api-key' => $this->apiKey,
            ]);
    }

    /**
     * Get the configured provider name
     */
    public function getProvider(): string
    {
        return 'Gemini';
    }

    /**
     * Get the configured chat model name
     */
    public function getModel(): string
    {
        return $this->model;
    }

    /**
     * Get the configured embedding model name
     */
    public function getEmbeddingModel(): string
    {
        return $this->embeddingModel;
    }

    /**
     * Set the chat model
     */
    public function setModel(string $model): void
    {
        $this->model = $model;
    }

    /**
     * Set the embedding model
     */
    public function setEmbeddingModel(string $embeddingModel): void
    {
        $this->embeddingModel = $embeddingModel;
    }

    /**
     * Set the API key
     */
    public function setApiKey(string $apiKey): void
    {
        $this->apiKey = $apiKey;
        $this->client = Http::baseUrl($this->baseUrl)
            ->withHeaders([
                'Content-Type' => 'application/json',
                'x-goog-api-key' => $this->apiKey,
            ]);
    }

    public function generateResponse(array $messages, ?string $model = null, ?string $media = null, ?string $mimeType = null, array $tools = []): array
    {
        $model = $model ?? $this->model;

        $contents = [];
        $systemPrompt = '';

        foreach ($messages as $message) {
            if ($message['role'] === 'system') {
                $systemPrompt = $message['content'];
            } elseif (in_array($message['role'], ['user', 'assistant'])) {
                $role = $message['role'] === 'assistant' ? 'model' : 'user';
                $contents[] = [
                    'role' => $role,
                    'parts' => [['text' => $message['content']]]
                ];
            }
        }

        if ($media) {
            $detectedMimeType = '';
            Log::info('GeminiService: Detected media', [
                'media_length' => strlen($media),
                'mime_type' => $mimeType,
            ]);
            if ($mimeType) {
                if (stripos($mimeType, 'audio') !== false) {
                    $detectedMimeType = 'audio/mp3';
                } else if (stripos($mimeType, 'image') !== false) {
                    $detectedMimeType = 'image/jpeg';
                }
            }
            $media = preg_replace('/^data:[a-zA-Z0-9\/\-\.]+;base64,/', '', $media);
            $lastIndex = count($contents) - 1;
            if ($lastIndex >= 0) {
                $contents[$lastIndex]['parts'][] = [
                    'inline_data' => [
                        'mime_type' => $detectedMimeType,
                        'data' => $media
                    ]
                ];
            }
        }

        $payload = [
            'contents' => $contents
        ];

        // Only add system instruction if it exists and no image is provided
        if (!empty($systemPrompt) && !$media) {
            $payload['system_instruction'] = [
                'parts' => [['text' => $systemPrompt]]
            ];
        }

        // Add tools if provided
        if (!empty($tools)) {
            $payload['tools'] = $this->formatToolsForGemini($tools);
        }

        $response = $this->client->post("models/{$model}:generateContent", $payload);

        if (!$response->successful()) {
            $body = $response->body();
            Log::error('Gemini API', [
                'status' => $response->status(),
                'request' => $payload,
                'response' => $body
            ]);
            throw new \Exception('Gemini chat request failed: ' . $body);
        }

        $responseData = $response->json();

        Log::info('Gemini API', [
            'status' => $response->status(),
            'request' => $payload,
            'response' => $responseData
        ]);

        $candidate = $responseData['candidates'][0] ?? null;
        if (!$candidate) {
            throw new \Exception('Invalid Gemini chat response format: no candidates');
        }

        // Extract token usage data
        $usage = $responseData['usageMetadata'] ?? [];
        $tokenUsage = [
            'input_tokens' => $usage['promptTokenCount'] ?? 0,
            'output_tokens' => $usage['candidatesTokenCount'] ?? 0,
            'total_tokens' => $usage['totalTokenCount'] ?? 0,
        ];

        // Check for function calls
        if (isset($candidate['content']['parts'])) {
            $functionCalls = [];
            $textContent = '';
            
            foreach ($candidate['content']['parts'] as $part) {
                if (isset($part['functionCall'])) {
                    $functionCalls[] = [
                        'id' => 'call_' . uniqid(),
                        'type' => 'function',
                        'function' => [
                            'name' => $part['functionCall']['name'],
                            'arguments' => json_encode($part['functionCall']['args'] ?? [])
                        ]
                    ];
                } elseif (isset($part['text'])) {
                    $textContent .= $part['text'];
                }
            }
            
            if (!empty($functionCalls)) {
                return [
                    'content' => $textContent,
                    'tool_calls' => $functionCalls,
                    'token_usage' => $tokenUsage
                ];
            }
            
            if (!empty($textContent)) {
                return [
                    'content' => $textContent,
                    'token_usage' => $tokenUsage
                ];
            }
        }

        throw new \Exception('Invalid Gemini chat response format: no content found');
    }

    public function createEmbedding(string|array $text): array
    {
        try {
            if (is_array($text)) {
                return $this->createBatchEmbeddings($text);
            }

            $payload = [
                'model' => "models/$this->embeddingModel",
                'content' => ['parts' => [['text' => $text]]],
                'output_dimensionality' => 768,
            ];

            $response = $this->client->post("models/{$this->embeddingModel}:embedContent", $payload);

            if (!$response->successful()) {
                $body = $response->body();
                Log::error('Gemini Embedding API', [
                    'status' => $response->status(),
                    'request' => $payload,
                    'response' => $body
                ]);
                throw new \Exception('Failed to create embedding: ' . $body);
            }

            $responseData = $response->json();

            Log::info('Gemini Embedding API', [
                'status' => $response->status(),
                'request' => $payload,
                'response' => $responseData
            ]);

            return [
                'embeddings' => [$responseData['embedding']['values'] ?? []],
                'token_usage' => [
                    'input_tokens' => $responseData['usageMetadata']['promptTokenCount'] ?? 0,
                    'output_tokens' => 0, // Embeddings don't have output tokens
                    'total_tokens' => $responseData['usageMetadata']['totalTokenCount'] ?? 0,
                ]
            ];
        } catch (\Exception $e) {
            Log::error('Gemini Embedding Error', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    /**
     * Create embeddings for multiple texts in a single batch request
     *
     * @param array $texts Array of text strings to embed
     * @return array Array of embedding vectors, indexed by input order
     */
    public function createBatchEmbeddings(array $texts): array
    {
        try {
            $requests = [];

            foreach ($texts as $text) {
                $requests[] = [
                    'model' => "models/$this->embeddingModel",
                    'content' => [
                        'parts' => [['text' => $text]]
                    ],
                    'output_dimensionality' => 768,
                ];
            }

            $payload = ['requests' => $requests];

            $response = $this->client->post("models/{$this->embeddingModel}:batchEmbedContents", $payload);

            if (!$response->successful()) {
                $body = $response->body();
                Log::error('Gemini Batch Embedding API', [
                    'status' => $response->status(),
                    'request' => $payload,
                    'response' => $body
                ]);
                throw new \Exception('Failed to create batch embeddings: ' . $body);
            }

            $responseData = $response->json();
            $embeddings = [];

            if (isset($responseData['embeddings'])) {
                foreach ($responseData['embeddings'] as $embedding) {
                    $embeddings[] = $embedding['values'] ?? [];
                }
            }

            return [
                'embeddings' => $embeddings,
                'token_usage' => [
                    'input_tokens' => $responseData['usageMetadata']['promptTokenCount'] ?? 0,
                    'output_tokens' => 0, // Embeddings don't have output tokens
                    'total_tokens' => $responseData['usageMetadata']['totalTokenCount'] ?? 0,
                ]
            ];
        } catch (\Exception $e) {
            Log::error('Gemini Batch Embedding Error', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    public function transcribe(string $audioData, string $mimeType, ?string $language = null): string
    {
        try {
            // Remove data URL prefix if present
            $audioData = preg_replace('/^data:[a-zA-Z0-9\/\-\.]+;base64,/', '', $audioData);

            $contents = [
                [
                    'role' => 'user',
                    'parts' => [
                        ['text' => 'Please transcribe the audio content exactly as spoken. Return only the transcribed text without any additional commentary or formatting.'],
                        [
                            'inline_data' => [
                                'mime_type' => $mimeType,
                                'data' => $audioData
                            ]
                        ]
                    ]
                ]
            ];

            $payload = [
                'contents' => $contents
            ];

            $response = $this->client->post("models/{$this->model}:generateContent", $payload);

            if (!$response->successful()) {
                $body = $response->body();
                Log::error('Gemini Transcription API', [
                    'status' => $response->status(),
                    'request' => $payload,
                    'response' => $body
                ]);
                throw new \Exception('Gemini transcription request failed: ' . $body);
            }

            $responseData = $response->json();

            if (!isset($responseData['candidates'][0]['content']['parts'][0]['text'])) {
                throw new \Exception('Invalid Gemini transcription response format');
            }

            return trim($responseData['candidates'][0]['content']['parts'][0]['text']);
        } catch (\Exception $e) {
            Log::error('Gemini Transcription Error', ['error' => $e->getMessage()]);
            throw new \Exception('Speech-to-text transcription failed: ' . $e->getMessage());
        }
    }

    /**
     * Format tools array for Gemini API
     */
    private function formatToolsForGemini(array $tools): array
    {
        $functionDeclarations = [];
        
        foreach ($tools as $tool) {
            if ($tool['type'] === 'function') {
                $functionDeclarations[] = [
                    'name' => $tool['function']['name'],
                    'description' => $tool['function']['description'],
                    'parameters' => $tool['function']['parameters']
                ];
            }
        }

        return [
            [
                'function_declarations' => $functionDeclarations
            ]
        ];
    }
}
